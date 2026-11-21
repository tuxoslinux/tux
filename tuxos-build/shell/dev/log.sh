#!/bin/bash
# Shows Quickshell's messages since its last (re)load in the dev VM (errors
# while loading included: they come before "Configuration Loaded").
here="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(cd "${here}/../../test" && pwd)"
python3 -I "${here}/../../../bench/qga.py" "${test_dir}/run/${VM:-shelldev}-qga.sock" exec 20 /bin/sh -c \
  'sed "s/\x1b\[[0-9;]*m//g" /run/user/1000/tuxos-shell.log | awk "/Reloading configuration/{buf=\"\"} {buf=buf\$0\"\n\"} END{printf \"%s\", buf}" | grep -a -v "^ *$" | tail -n ${1:-30}' sh "${1:-30}"
