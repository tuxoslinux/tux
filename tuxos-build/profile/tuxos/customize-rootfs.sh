#!/bin/bash
# Runs inside the installed-system layer during the build (see tools/tuxos-buildiso).
set -euo pipefail

# Comments and descriptions people read: say TuxOS
sed -i 's/for Artix --/for TuxOS --/' /etc/rc.local /etc/rc.shutdown
sed -i 's/^# sshd_config defaults on Artix Linux$/# sshd_config defaults on TuxOS/' \
    /etc/ssh/sshd_config.d/99-artixlinux.conf
usermod -c "TuxOS Package Management" alpm
rm -f /etc/passwd-   # backup usermod leaves with the old text

# The upstream logos are replaced by /usr/share/pixmaps/tuxos-logo.png
# (pacman.conf NoExtract keeps them from coming back on updates); programs
# that still ask for artixlinux-logo.png get the TuxOS logo.
rm -f /usr/share/pixmaps/artixlinux-logo*.svg
cp /usr/share/pixmaps/tuxos-logo.png /usr/share/pixmaps/artixlinux-logo.png

# Arch marker installed by artix-archlinux-support (pacman.conf NoExtract
# keeps it from coming back)
rm -f /etc/arch-release

# Performance layer (see /etc/tuxos/performance.conf, tuxos-tune status)
for service in tuxos-zram tuxos-tweaks tuxos-gamed tuxos-bootok ananicy-cpp scx_loader power-profiles-daemon earlyoom; do
    if [[ ! -f "/etc/dinit.d/${service}" ]]; then
        echo "customize-rootfs: missing dinit service ${service}" >&2
        exit 1
    fi
    ln -sf "/etc/dinit.d/${service}" "/etc/dinit.d/boot.d/${service}"
done
# ananicy-cpp links libsystemd.so.0 (installed before the pacman hook
# that provides it existed)
/usr/lib/tuxos/libsystemd-compat
# Shader caches large enough for big games (the defaults of 1 GB make them
# compile shaders again: stutter)
cat >> /etc/environment <<'ENV'

# TuxOS: large shader caches (fewer shader compile stutters)
MESA_SHADER_CACHE_MAX_SIZE=10G
__GL_SHADER_DISK_CACHE_SIZE=10737418240
__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
ENV
