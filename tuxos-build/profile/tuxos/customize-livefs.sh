#!/bin/bash
# Runs inside the live layer during the build (see tools/tuxos-buildiso).
set -euo pipefail

# Live session: TuxOS live setup, then greetd logs the live user into the
# TuxOS desktop (initial_session below), where the installer opens by
# itself; after a logout greetd shows the TuxOS login screen
rm -f /etc/dinit.d/boot.d/artix-live
ln -sf /etc/dinit.d/tuxos-live /etc/dinit.d/boot.d/tuxos-live
ln -sf /etc/dinit.d/greetd /etc/dinit.d/boot.d/greetd

# artix-live switches on a swap partition it finds on the computer's disks:
# the installer then treats that disk as in use and hides "Erase disk"
sed -i 's/^configure_swap$/: # TuxOS: no swap from the disks (configure_swap)/' /usr/bin/artix-live
if grep -q '^configure_swap$' /usr/bin/artix-live; then
    echo "artix-live still turns on swap" >&2
    exit 1
fi

# The TuxOS desktop, as installed systems get it (wallpapers, shell, apps,
# login screen); the wallpaper links install-desktop makes on installs
cp -a /usr/share/tuxos/desktop/common/root/. /
cp -a /usr/share/tuxos/desktop/tuxos/root/. /
ln -sf ../backgrounds/tuxos/tuxos-wallpaper.jpg /usr/share/tuxos/wallpaper.png
ln -sf ../../backgrounds/tuxos/tuxos-wallpaper.jpg /usr/share/tuxos/wallpapers/tuxos-mountain.jpg
ln -sf ../../backgrounds/tuxos/tuxos-corner-glow.jpg /usr/share/tuxos/wallpapers/tuxos-corner-glow.jpg
# The greeter keeps its state here (installs make it in install-desktop)
install -d -o greeter -g greeter -m 700 /var/lib/tuxos-greeter
# Live mode for the session and the shell: no lock, no Welcome, no session
# restore; Hyprland opens the installer (tuxos-session reads this)
echo "TuxOS live session" > /etc/tuxos-live
# greetd: log the live user in once at boot, the login screen after that
cat >> /etc/greetd/config.toml <<'TOML'

# TuxOS live ISO: the live user ("tuxos", password "tuxos") is logged in
# at boot; the login screen shows only after logging out
[initial_session]
command = "tuxos-session"
user = "tuxos"
TOML

# Only the TuxOS installer and its "Install TuxOS" launcher may be shown
rm -rf /usr/share/calamares/branding/artix /usr/share/calamares/branding/artix-next
rm -f /usr/share/applications/calamares.desktop
rm -f /usr/share/applications/calamares-config-switcher.desktop

# Artix' live desktop items (an installer icon of its own)
rm -f /etc/skel/.config/autostart/live-session.desktop
rm -f /home/*/.config/autostart/live-session.desktop
