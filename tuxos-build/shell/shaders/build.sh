#!/bin/sh
# Compiles TuxOS' shader wallpapers for Qt 6 (qsb, from qt6-shadertools)
# into src/assets/shaders/. package.sh and dev/sync.sh run this.
here="$(cd "$(dirname "$0")" && pwd)"
qsb=$(command -v qsb || echo /usr/lib/qt6/bin/qsb)
mkdir -p "$here/../src/assets/shaders"
for f in "$here"/*.frag; do
    out="$here/../src/assets/shaders/$(basename "$f").qsb"
    [ "$out" -nt "$f" ] && continue
    "$qsb" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" "$f" || exit 1
done
