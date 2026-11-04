#!/bin/bash
# Creates the Artix build chroot that build.sh builds in.
#
#   tools/make-chroot.sh ARTIX_ISO [DIR]
#
# ARTIX_ISO is any Artix dinit live ISO (https://artixlinux.org/download.php;
# TuxOS was set up from artix-xfce-dinit-20260813-x86_64.iso). DIR defaults
# to ../artix-root next to tuxos-build, where build.sh looks for it
# (CHROOT_DIR=DIR ./build.sh uses another one). The ISO's root file system
# is unpacked into DIR, updated, and gets artools (buildiso) and an empty
# artools workspace; build.sh adds everything else before each build
# (tools/prepare-chroot.sh: Arch and CachyOS repositories and keys).
#
# Needs on the host: arch-chroot (arch-install-scripts), bsdtar (libarchive),
# unsquashfs (squashfs-tools), sudo, and about 10 GB of space in DIR.
# Run as your normal user; it uses sudo where needed.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
iso="${1:?usage: make-chroot.sh ARTIX_ISO [DIR]}"
dir="${2:-${here}/../../artix-root}"

[[ -f "${iso}" ]] || { echo "ERROR: ${iso} not found" >&2; exit 1; }
if [[ -e "${dir}" ]]; then
    echo "ERROR: ${dir} already exists (remove it first to make a new one)" >&2
    exit 1
fi
for tool in arch-chroot bsdtar unsquashfs; do
    command -v "${tool}" >/dev/null || { echo "ERROR: ${tool} is missing" >&2; exit 1; }
done

# the ISO's squashfs is large: unpack it next to DIR, not in /tmp
dir="$(mkdir -p "$(dirname "${dir}")" && cd "$(dirname "${dir}")" && pwd)/$(basename "${dir}")"
tmp="$(mktemp -d "${dir}.unpack.XXXXXX")"
trap 'rm -rf "${tmp}"' EXIT

echo "==> Unpacking the root file system of ${iso}"
bsdtar -xf "${iso}" -C "${tmp}" LiveOS/rootfs.img
sudo unsquashfs -q -d "${dir}" "${tmp}/LiveOS/rootfs.img"
rm -rf "${tmp}"

run_in_chroot() {
    sudo arch-chroot "${dir}" /usr/bin/env -i \
        HOME=/root USER=root TERM="${TERM:-xterm}" LANG=C.UTF-8 \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/bin "$@"
}

echo "==> Updating the chroot and installing artools"
# a live ISO's keyring is only set up when the live system boots
# and pacman's free-space check fails in a chroot that is no mount point
# ("could not determine cachedir mount point")
run_in_chroot /bin/sh -c '
    set -e
    sed -i "s/^CheckSpace/#CheckSpace/" /etc/pacman.conf
    if [ ! -s /etc/pacman.d/gnupg/pubring.gpg ]; then
        pacman-key --init
        pacman-key --populate artix
    fi
    pacman -Sy --noconfirm --needed artix-keyring
    pacman -Su --noconfirm
    pacman -S --noconfirm --needed artools-iso
    mkdir -p /root/artools-workspace/iso-profiles
'

echo "==> Done: ${dir}"
echo "    Build with: $(cd "${here}/.." && pwd)/build.sh"
