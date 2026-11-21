#!/bin/bash
# Pushes the shell source (../src) into the dev VM as
# ~tester/.config/quickshell/tuxos; Quickshell's file watcher reloads it.
#   sync.sh            copy the source
#   sync.sh shot NAME  copy, wait a moment, screenshot to dev/shots/NAME.png
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(cd "${here}/../../test" && pwd)"
name="${VM:-shelldev}"
G() { python3 -I "${here}/../../../bench/qga.py" "${test_dir}/run/${name}-qga.sock" "$@"; }
Q() { python3 -I "${test_dir}/qmp.py" "${test_dir}/run/${name}.qmp" "$@"; }

"${here}/../shaders/build.sh"
tarball="$(mktemp --suffix=.tar)"
trap 'rm -f "${tarball}"' EXIT
tar -C "${here}/../src" -cf "${tarball}" .
G put "${tarball}" /tmp/tuxos-shell.tar >/dev/null
G exec 30 /bin/sh -c 'd=/home/tester/.config/quickshell/tuxos; mkdir -p "$d" && tar -xf /tmp/tuxos-shell.tar -C "$d" && sleep 0.3 && touch "$d/shell.qml" && chown -R tester:tester /home/tester/.config/quickshell && rm -f /tmp/tuxos-shell.tar'
# Quickshell's hot reload does not register QML files that were added (a new
# component or singleton is "not a type" / "not defined"): when the set of
# files changed, the shell process restarts instead (tuxos-shell brings it back)
list="${here}/.synced-files"
now="$(cd "${here}/../src" && find . -name '*.qml' | sort | md5sum | cut -c1-32)"
if [[ "$(cat "${list}" 2>/dev/null)" != "${now}" ]]; then
    echo "${now}" > "${list}"
    "${here}/as-user.sh" 'for p in $(pgrep -u tester -f "^qs -c tuxos$"); do kill "$p"; done; true' >/dev/null 2>&1 || true
fi

if [[ "${1:-}" == shot ]]; then
    sleep "${WAIT:-3}"
    mkdir -p "${here}/shots"
    Q shot "${here}/shots/${2:-shot}.png"
    echo "${here}/shots/${2:-shot}.png"
fi
