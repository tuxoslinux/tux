#!/bin/bash
# Runs inside the live layer during the build (see tools/tuxos-buildiso).
set -euo pipefail

# Live session: TuxOS live setup, then SDDM logs the live user into KDE
# Plasma (/etc/sddm.conf.d/20-tuxos-live.conf), where the installer opens
# by itself
rm -f /etc/dinit.d/boot.d/artix-live
ln -sf /etc/dinit.d/tuxos-live /etc/dinit.d/boot.d/tuxos-live
ln -sf /etc/dinit.d/sddm /etc/dinit.d/boot.d/sddm

# The same login screen and Plasma wallpaper as installed systems
cp -a /usr/share/tuxos/desktop/common/root/. /
for f in /usr/share/plasma/look-and-feel/org.kde.breeze*.desktop/contents/defaults; do
    if [[ -f "$f" ]]; then
        sed -i 's/^Image=.*/Image=TuxOS/' "$f"
    fi
done

# Only the TuxOS installer and its "Install TuxOS" launcher may be shown
rm -rf /usr/share/calamares/branding/artix /usr/share/calamares/branding/artix-next
rm -f /usr/share/applications/calamares.desktop
rm -f /usr/share/applications/calamares-config-switcher.desktop

# Artix' live desktop items (an installer icon of its own)
rm -f /etc/skel/.config/autostart/live-session.desktop
rm -f /home/*/.config/autostart/live-session.desktop
