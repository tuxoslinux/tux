#!/bin/bash
# Installs the shell system-wide in the dev VM exactly as the ISO gets it:
# package.sh builds the root tree (shell, tools, helpers, login screen,
# session, PAM, portal, dinit files, Hyprland / hypridle / MangoHud / mpv
# defaults, polkit, cursors) and it is unpacked over the VM's /. Then the
# few things install-desktop does on a real install for the TuxOS desktop
# (greeter folders, the keyring on greetd). (Dev only.)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(cd "${here}/../../test" && pwd)"
G() { python3 -I "${here}/../../../bench/qga.py" "${test_dir}/run/${VM:-shelldev}-qga.sock" "$@"; }
work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT
"${here}/../package.sh" "${work}/root" >/dev/null
tar -C "${work}/root" -cf "${work}/sys.tar" .
G put "${work}/sys.tar" /tmp/tuxos-sys.tar >/dev/null
G exec 300 /bin/sh -c '
set -e
rm -rf /etc/xdg/quickshell/tuxos /usr/share/icons/TuxOS
tar -xf /tmp/tuxos-sys.tar -C / --no-same-owner --no-overwrite-dir; rm /tmp/tuxos-sys.tar
install -d -o greeter -g greeter -m700 /var/lib/tuxos-greeter
install -d -m1777 /var/lib/tuxos-login-wallpapers
grep -q pam_gnome_keyring /etc/pam.d/greetd || { sed -i "/^auth.*include.*system-local-login/a auth       optional     pam_gnome_keyring.so" /etc/pam.d/greetd; sed -i "/^session.*include.*system-local-login/a session    optional     pam_gnome_keyring.so auto_start" /etc/pam.d/greetd; }
echo installed'
