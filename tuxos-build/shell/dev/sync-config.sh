#!/bin/bash
# Copies system/hyprland.lua into the dev VM and reloads Hyprland (tools: install-system.sh).
here="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(cd "${here}/../../test" && pwd)"
G() { python3 -I "${here}/../../../bench/qga.py" "${test_dir}/run/${VM:-shelldev}-qga.sock" "$@"; }
G put "${here}/../system/hyprland.lua" /home/tester/.config/hypr/hyprland.lua >/dev/null
G exec 10 /bin/chown tester:tester /home/tester/.config/hypr/hyprland.lua
"${here}/as-user.sh" 'hyprctl reload; sleep 0.5; hyprctl configerrors'
