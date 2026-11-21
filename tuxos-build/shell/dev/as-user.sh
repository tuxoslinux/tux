#!/bin/bash
# Runs a command in the dev VM as tester inside the Hyprland session.
here="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(cd "${here}/../../test" && pwd)"
python3 -I "${here}/../../../bench/qga.py" "${test_dir}/run/${VM:-shelldev}-qga.sock" exec "${T:-30}" /bin/su tester -c \
  "export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus LANG=C.UTF-8; export HYPRLAND_INSTANCE_SIGNATURE=\$(ls -t /run/user/1000/hypr | head -1); $*"
