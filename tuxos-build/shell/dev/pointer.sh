#!/bin/bash
# pointer.sh X Y  - moves the dev VM's pointer to X,Y (screen 1280x800) without clicking
test_dir="$(cd "$(dirname "$0")/../../test" && pwd)"
x=$(( $1 * 32767 / 1280 )); y=$(( $2 * 32767 / 800 ))
python3 -I "${test_dir}/qmp.py" "${test_dir}/run/${VM:-shelldev}.qmp" cmd "{\"name\": \"input-send-event\", \"events\": [{\"type\": \"abs\", \"data\": {\"axis\": \"x\", \"value\": $x}}, {\"type\": \"abs\", \"data\": {\"axis\": \"y\", \"value\": $y}}]}" >/dev/null
