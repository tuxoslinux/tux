#!/bin/bash
# drag.sh X1 Y1 X2 Y2 : left-button drag in the dev VM (1280x800 screen)
here="$(cd "$(dirname "$0")" && pwd)"
Q() { python3 -I "${here}/../../test/qmp.py" "${here}/../../test/run/${VM:-shelldev}.qmp" "$@" >/dev/null; }
mv() { Q cmd "{\"name\":\"input-send-event\",\"events\":[{\"type\":\"abs\",\"data\":{\"axis\":\"x\",\"value\":$(( $1 * 32767 / 1279 ))}},{\"type\":\"abs\",\"data\":{\"axis\":\"y\",\"value\":$(( $2 * 32767 / 799 ))}}]}"; }
btn() { Q cmd "{\"name\":\"input-send-event\",\"events\":[{\"type\":\"btn\",\"data\":{\"down\":$1,\"button\":\"left\"}}]}"; }
mv "$1" "$2"; sleep 0.15; btn true; sleep 0.15
for i in 1 2 3 4 5 6 7 8; do mv $(( $1 + ($3 - $1) * i / 8 )) $(( $2 + ($4 - $2) * i / 8 )); sleep 0.05; done
sleep 0.2; btn false
