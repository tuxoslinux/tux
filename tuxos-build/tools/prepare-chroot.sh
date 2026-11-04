#!/bin/bash
# Runs inside the build chroot (from build.sh) before every build. Makes the
# chroot able to use the Arch and CachyOS repositories that the TuxOS build
# pacman configuration lists: their mirror lists and package signing keys.
# Safe to run again; it only does what is missing.
set -euo pipefail

# CachyOS packaging key, used to verify the cachyos-keyring package itself
cachyos_key=F3B607488DB35A47
cachyos_repo=https://mirror.cachyos.org/repo/x86_64/cachyos

if ! pacman -Q artix-archlinux-support &>/dev/null; then
    echo "==> Installing Arch repository support"
    pacman -Sy --noconfirm --needed artix-archlinux-support
fi
pacman-key --populate archlinux >/dev/null

if ! pacman -Q cachyos-keyring cachyos-mirrorlist &>/dev/null; then
    echo "==> Installing the CachyOS keyring and mirror list"
    pacman-key --recv-keys "${cachyos_key}" --keyserver hkps://keyserver.ubuntu.com
    pacman-key --lsign-key "${cachyos_key}"
    tmp="$(mktemp -d)"
    curl -sfL "${cachyos_repo}/cachyos.db" | bsdtar -xf - -C "${tmp}"
    urls=()
    for pkg in cachyos-keyring cachyos-mirrorlist; do
        desc=$(ls -d "${tmp}/${pkg}"-[0-9]*/desc | head -n1)
        urls+=("${cachyos_repo}/$(sed -n '/%FILENAME%/{n;p}' "${desc}")")
    done
    rm -rf "${tmp}"
    # pacman downloads each package with its signature and checks it
    pacman -U --noconfirm "${urls[@]}"
fi
pacman-key --populate cachyos >/dev/null
echo "==> Build chroot ready for the Artix, Arch and CachyOS repositories"
