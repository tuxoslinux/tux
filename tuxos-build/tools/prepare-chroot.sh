#!/bin/bash
# Runs inside the build chroot (from build.sh) before every build. Makes the
# chroot able to use the Arch and CachyOS repositories that the TuxOS build
# pacman configuration lists: their mirror lists and package signing keys.
# Safe to run again; it only does what is missing.
set -euo pipefail

# Newer host kernels refuse the new mount API (fsopen ...) to a process
# inside a chroot, and util-linux' mount / umount use it first ("must be
# superuser to use mount", with root; leftover mounts then keep the live
# layer busy); the classic mount(2) / umount2(2) still work. mount and
# umount in /usr/local/bin (first in the build's PATH) run copies without
# the setuid bit (libmount ignores the environment in setuid programs) with
# LIBMOUNT_FORCE_MOUNT2=always. Refreshed every build (util-linux updates).
for tool in mount umount; do
    install -Dm755 "/usr/bin/${tool}" "/usr/local/lib/tuxos-buildiso/${tool}"
    printf '#!/bin/sh\nLIBMOUNT_FORCE_MOUNT2=always exec /usr/local/lib/tuxos-buildiso/%s "$@"\n' "${tool}" > "/usr/local/bin/${tool}"
    chmod 755 "/usr/local/bin/${tool}"
done

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
