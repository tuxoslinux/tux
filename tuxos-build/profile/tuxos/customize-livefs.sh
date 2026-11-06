#!/bin/bash
# Runs inside the live layer during the build (see tools/tuxos-buildiso).
set -euo pipefail

# Live session: TuxOS live setup, then SDDM logs the live user into COSMIC
# (/etc/sddm.conf.d/20-tuxos-live.conf), where the installer opens by
# itself
rm -f /etc/dinit.d/boot.d/artix-live
ln -sf /etc/dinit.d/tuxos-live /etc/dinit.d/boot.d/tuxos-live
ln -sf /etc/dinit.d/sddm /etc/dinit.d/boot.d/sddm

# artix-live switches on a swap partition it finds on the computer's disks:
# the installer then treats that disk as in use and hides "Erase disk"
sed -i 's/^configure_swap$/: # TuxOS: no swap from the disks (configure_swap)/' /usr/bin/artix-live
if grep -q '^configure_swap$' /usr/bin/artix-live; then
    echo "artix-live still turns on swap" >&2
    exit 1
fi

# The same login screen as installed systems
cp -a /usr/share/tuxos/desktop/common/root/. /

# Stock COSMIC look, but only its default wallpaper (the other ten are
# 12 MB the ISO does not need)
default_bg="$(sed -n 's|.*Path("\(.*\)").*|\1|p' \
    /usr/share/cosmic/com.system76.CosmicBackground/v1/all)"
if [[ -f "${default_bg}" ]]; then
    find /usr/share/backgrounds/cosmic -type f ! -path "${default_bg}" -delete
fi

# Only the TuxOS installer and its "Install TuxOS" launcher may be shown
rm -rf /usr/share/calamares/branding/artix /usr/share/calamares/branding/artix-next
rm -f /usr/share/applications/calamares.desktop
rm -f /usr/share/applications/calamares-config-switcher.desktop

# Artix' live desktop items (an installer icon of its own)
rm -f /etc/skel/.config/autostart/live-session.desktop
rm -f /home/*/.config/autostart/live-session.desktop
