#!/usr/bin/env python3
# TuxOS disk encryption (SPEC round 7 #17). The partition module makes the
# encrypted disk LUKS2 (partition.conf: luksGeneration); this job, run after
# luksbootkeyfile and before the boot loader:
#   - turns every key slot it can open into PBKDF2 (GRUB unlocks LUKS2 only
#     with PBKDF2, not Argon2id), and
#   - adds a recovery key (8 groups of 6 digits) to each encrypted partition.
# The recovery key is kept root-only in /var/lib/tuxos/recovery-key; the
# Welcome app shows it once at the first login (tuxos-recovery-key) and it is
# then deleted from the disk.
import os
import re
import secrets
import subprocess

import libcalamares


def pretty_name():
    return "Securing the encrypted disk"


def run():
    parts = libcalamares.globalstorage.value("partitions") or []
    root = libcalamares.globalstorage.value("rootMountPoint")
    luks = [p for p in parts if p.get("luksMapperName") and p.get("luksPassphrase") and p.get("device")]
    if not luks or not root:
        return None
    key = "-".join(str(secrets.randbelow(10 ** 6)).zfill(6) for _ in range(8))
    keyfile = "/run/tuxos-recovery-key"
    fd = os.open(keyfile, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.write(fd, key.encode())
    os.close(fd)
    done = []
    try:
        for p in luks:
            dev, pw = p["device"], p["luksPassphrase"].encode()
            # LUKS2 only: LUKS1 has no Argon2 and nothing to convert
            dump = subprocess.run(["cryptsetup", "luksDump", dev], capture_output=True, text=True).stdout
            m = re.search(r"^Version:\s*(\d+)", dump, re.M)
            if m and m.group(1) == "2":
                r = subprocess.run(["cryptsetup", "luksConvertKey", "--pbkdf", "pbkdf2", "--key-file=-", dev], input=pw, capture_output=True)
                if r.returncode != 0:
                    libcalamares.utils.warning(f"tuxoscrypt: could not convert the key slot of {dev}: {r.stderr.decode().strip()}")
                    return ("The encrypted disk could not be prepared",
                            "GRUB could not read its key slot (PBKDF2 conversion failed). See /var/log/Calamares.log.")
                # the installer's key file slot too (only the initramfs reads it, but one kind is simpler)
                kf = os.path.join(root, "crypto_keyfile.bin")
                if os.path.isfile(kf):
                    subprocess.run(["cryptsetup", "luksConvertKey", "--pbkdf", "pbkdf2", "--key-file", kf, dev], capture_output=True)
            r = subprocess.run(["cryptsetup", "luksAddKey", "--pbkdf", "pbkdf2", "--key-file=-", dev, keyfile], input=pw, capture_output=True)
            if r.returncode == 0:
                uuid = subprocess.run(["blkid", "-s", "UUID", "-o", "value", dev], capture_output=True, text=True).stdout.strip()
                done.append(f"{p.get('mountPoint') or dev} {uuid}")
            else:
                libcalamares.utils.warning(f"tuxoscrypt: no recovery key for {dev}: {r.stderr.decode().strip()}")
    finally:
        os.remove(keyfile)
    if done:
        d = os.path.join(root, "var/lib/tuxos")
        os.makedirs(d, exist_ok=True)
        f = os.path.join(d, "recovery-key")
        fd = os.open(f, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        os.write(fd, ("key " + key + "\n" + "".join("disk " + x + "\n" for x in done)).encode())
        os.close(fd)
    return None
