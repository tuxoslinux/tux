#!/bin/bash
# Builds the files of the TuxOS desktop (shell, tools, login screen, apps,
# look) as a root tree: build.sh copies it into the ISO profile as
# desktop/tuxos/root, and the installer copies it into the new system when
# "TuxOS desktop" is chosen. Needs python3 with Pillow (cursors) and a C
# compiler (tuxos-hudctl).
#   package.sh OUTDIR
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$1"
rm -rf "${out}"
mkdir -p "${out}"

# the shell (also the login screen and TuxOS' own apps): Quickshell config "tuxos"
install -d "${out}/etc/xdg/quickshell"
"${here}/shaders/build.sh"   # shader wallpapers -> src/assets/shaders
cp -r "${here}/src" "${out}/etc/xdg/quickshell/tuxos"
# its version (tuxos-shell keeps the last version that worked, to go back to)
printf '%s\n' "$(date -u +%Y%m%d%H%M%S)-$(git -C "${here}" rev-parse --short HEAD 2>/dev/null || echo local)" > "${out}/etc/xdg/quickshell/tuxos/VERSION"

# tools
install -Dm755 -t "${out}/usr/bin" "${here}"/bin/*
for c in "${here}"/helpers/*.c; do
    # (the portal uses GLib's D-Bus)
    extra=""; grep -q '<gio/gio.h>' "${c}" && extra="$(pkg-config --cflags --libs gio-2.0)"
    # (the GPU check uses Mesa's EGL, GLES and GBM)
    grep -q '<gbm.h>' "${c}" && extra="$(pkg-config --cflags --libs egl glesv2 gbm)"
    # shellcheck disable=SC2086
    cc -O2 -Wall -include stddef.h -o "${out}/usr/bin/$(basename "${c}" .c)" "${c}" ${extra}
done

# login screen (greetd + cage), session, PAM
install -Dm644 "${here}/system/greetd/config.toml" "${out}/etc/greetd/config.toml"
install -Dm644 "${here}/system/wayland-sessions/tuxos.desktop" "${out}/usr/share/wayland-sessions/tuxos.desktop"
install -Dm644 -t "${out}/etc/pam.d" "${here}"/pam/*
# TuxOS' file chooser for xdg-desktop-portal (D-Bus activated)
install -Dm644 "${here}/system/portal/tuxos.portal" "${out}/usr/share/xdg-desktop-portal/portals/tuxos.portal"
install -Dm644 "${here}/system/portal/tuxos-portals.conf" "${out}/usr/share/xdg-desktop-portal/tuxos-portals.conf"
install -Dm644 "${here}/system/portal/org.freedesktop.impl.portal.desktop.tuxos.service" "${out}/usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.tuxos.service"
# Helium (the default browser): the accent colour and TuxOS' new-tab page
install -Dm644 "${here}/system/helium/tuxos.json" "${out}/etc/chromium/policies/managed/tuxos.json"
install -Dm644 "${here}/system/helium/index.html" "${out}/usr/share/tuxos/newtab/index.html"
# system services of the desktop (enabled by install-desktop)
install -Dm644 -t "${out}/etc/dinit.d" "${here}"/system/dinit/*

# apps, Hyprland defaults, Game HUD look, wallpapers, cursors
install -Dm644 -t "${out}/usr/share/applications" "${here}"/system/applications/*.desktop
install -Dm644 "${here}/system/hyprland.lua" "${out}/usr/share/tuxos/hyprland.lua"
install -Dm644 "${here}/system/MangoHud.conf" "${out}/usr/share/tuxos/MangoHud.conf"
install -Dm644 "${here}/system/hypridle.conf" "${out}/usr/share/tuxos/hypridle.conf"
install -Dm644 "${here}/system/mpv/tuxos.conf" "${out}/usr/share/tuxos/mpv/tuxos.conf"
install -Dm644 -t "${out}/usr/share/polkit-1/actions" "${here}"/system/polkit/*.policy
# TuxOS' own apps are the defaults in the TuxOS session
install -Dm644 "${here}/system/tuxos-mimeapps.list" "${out}/etc/xdg/tuxos-mimeapps.list"
install -Dm644 -t "${out}/usr/share/tuxos/wallpapers" "${here}"/wallpapers/*.png
# the default wallpaper (the mountain) and "Corner glow" are installed
# with every desktop; install-desktop links them as
# usr/share/tuxos/wallpaper.png and wallpapers/tuxos-mountain.jpg +
# tuxos-corner-glow.jpg. No links here: the ISO build copies this tree
# following links, and their targets are not in it
python3 "${here}/cursors/make-cursors.py" "${out}/usr/share/icons/TuxOS" >/dev/null
rm -f "${out}/usr/share/icons/TuxOS/preview.png"

echo "packaged the TuxOS desktop into ${out}"
