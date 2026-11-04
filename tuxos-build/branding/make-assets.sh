#!/bin/bash
# Generates every TuxOS graphic (GRUB themes, Calamares branding, pixmaps,
# wallpaper, login screen) from branding/Tux.png and branding/tux-ascii.txt. Output goes to tuxos-build/branding/out/.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tux_src="${here}/../../branding/Tux.png"
out="${here}/out"
font_bold=/usr/share/fonts/noto/NotoSans-Black.ttf
font_reg=/usr/share/fonts/noto/NotoSans-Regular.ttf

bg_top='#000000'
bg_bottom='#000000'
accent='#f5b800'
white='#f4f6f8'
grey='#a3a3a3'

rm -rf "${out}"
mkdir -p "${out}"/{grub-live/icons,grub-installed/icons,calamares,pixmaps}

# Tux with a thin dark-grey rim: his body is black, so without it his
# outline disappears on the black TuxOS backgrounds
tux="${out}/tux-rim.png"
magick "${tux_src}" -bordercolor none -border 8 \
    \( +clone -alpha extract -morphology Dilate Disk:4 -blur 0x1 \
       -background '#3a3a3a' -alpha shape \) \
    +swap -background none -layers merge +repage "PNG32:${tux}"

# Black canvas that stays in colour (a plain black canvas would be stored
# as greyscale and turn everything composited onto it grey)
black_canvas() { # WIDTHxHEIGHT dest
    magick -size "$1" "xc:${bg_bottom}" -colorspace sRGB -type TrueColor "PNG24:$2"
}

# Tux on a transparent square canvas
square() { # size dest
    magick "${tux}" -resize "$(( $1 * 92 / 100 ))x$(( $1 * 92 / 100 ))" \
        -background none -gravity center -extent "$1x$1" "$2"
}

# "TuxOS" wordmark: Tux in white (or the given colour), OS in accent yellow
wordmark() { # pointsize dest [tux-colour]
    magick -background none \
        \( -font "${font_bold}" -pointsize "$1" -fill "${3:-${white}}" label:Tux \) \
        \( -font "${font_bold}" -pointsize "$1" -fill "${accent}" label:OS \) \
        +append -trim +repage "$2"
}

square 512 "${out}/pixmaps/tuxos-logo.png"
square 256 "${out}/calamares/tuxos-logo.png"
square 64 "${out}/calamares/tuxos-icon.png"

# Chosen designs (make-designs.py): "Corner glow" wallpaper, "Terminal"
# GRUB backgrounds and menu pixmaps
python3 -I "${here}/make-designs.py" "${tux_src}" "${here}/tux-ascii.txt" "${out}"

# GRUB fonts (Noto Sans Mono) and menu icons
for t in grub-live grub-installed; do
    d="${out}/${t}"
    grub-mkfont -s 16 -o "${d}/NotoSansMono-Regular-16.pf2" /usr/share/fonts/noto/NotoSansMono-Regular.ttf 2>/dev/null
    grub-mkfont -s 16 -o "${d}/NotoSansMono-Bold-16.pf2" /usr/share/fonts/noto/NotoSansMono-Bold.ttf 2>/dev/null
    magick "${tux}" -resize 28x28 -background none -gravity center -extent 32x32 "${d}/icons/tuxos.png"
done
cp "${out}/grub-live/icons/tuxos.png" "${out}/grub-live/icons/tuxos.x86_64.png"

# Calamares welcome image: Tux beside the wordmark on a dark card, so it
# reads the same whatever the Qt colour scheme is
tmp="$(mktemp -d)"
magick "${tux}" -resize x300 "${tmp}/tux.png"
wordmark 150 "${tmp}/word.png"
magick -background none "${tmp}/tux.png" \( -size 50x1 xc:none \) "${tmp}/word.png" \
    -gravity center +append "${tmp}/content.png"
read -r cw ch < <(magick identify -format '%w %h\n' "${tmp}/content.png")
w=$(( cw + 120 )) h=$(( ch + 100 ))
magick -size "${w}x${h}" xc:black -fill white \
    -draw "roundrectangle 0,0 $(( w - 1 )),$(( h - 1 )) 36,36" "${tmp}/mask.png"
magick -size "${w}x${h}" "gradient:${bg_top}-${bg_bottom}" "${tmp}/mask.png" \
    -alpha off -compose CopyOpacity -composite -compose Over \
    "${tmp}/content.png" -gravity center -composite "${out}/calamares/tuxos-welcome.png"
# Banner sits on the installer's light page background: dark "Tux"
wordmark 150 "${tmp}/word-dark.png" "${bg_top}"
magick -background none "${tmp}/tux.png" -resize x90 \( -size 18x1 xc:none \) \
    \( "${tmp}/word-dark.png" -resize x64 \) -gravity center +append "${out}/calamares/tuxos-banner.png"
rm -rf "${tmp}"

# Wordmark alone for the slideshow
wordmark 120 "${out}/calamares/tuxos-wordmark.png"

# Cards for the desktop chooser page in the installer
card() { # id title subtitle
    magick -size 900x560 "gradient:${bg_top}-${bg_bottom}" \
        \( "${tux}" -resize x150 \) -gravity northwest -geometry +56+56 -composite \
        -font "${font_bold}" -pointsize 72 -fill "${white}" -gravity west -annotate +56+40 "$2" \
        -fill "${accent}" -draw "roundrectangle 56,370 156,378 4,4" \
        -font "${font_reg}" -pointsize 30 -fill "${grey}" -gravity southwest -annotate +56+86 "$3" \
        "${out}/calamares/desktop-$1.png"
}
card plasma   "KDE Plasma" "Modern, polished and very customizable"
card hyprland "Hyprland"   "Tiling Wayland compositor with animations"
card cinnamon "Cinnamon"   "Traditional, friendly and easy to use"
card budgie   "Budgie"     "Elegant and simple, with the Raven side bar"
card lxqt     "LXQt"       "Lightweight Qt desktop for any computer"
card labwc    "Labwc"      "Simple, fast stacking Wayland compositor"
card xfce     "XFCE"       "Light, fast and dependable"
card i3       "i3"         "Keyboard-driven tiling window manager"
card console  "No desktop" "Text console only; add a desktop later"
card drivers-recommended "Best drivers" "Official drivers for the detected hardware"
card drivers-opensource  "Open-source"  "Mesa and nouveau, already included"
card gaming-yes "Ready to play" "Steam, Proton-CachyOS, MangoHud, gamemode"
card gaming-no  "No gaming apps" "Add them later: sudo tuxos-gaming"

# GRUB only decodes 8-bit truecolour PNGs (no 16-bit, palette or grey),
# so store every image as 8-bit RGBA, and the GRUB backgrounds as RGB
find "${out}" -name '*.png' -print0 | while IFS= read -r -d '' f; do
    magick "$f" -strip -depth 8 "PNG32:$f"
done
for f in "${out}"/grub-*/background.png; do
    magick "$f" -strip -depth 8 -alpha off -define png:color-type=2 "PNG24:$f"
done

# Install into the profile
profile="${here}/../profile/tuxos"
cp -r "${out}"/grub-live/. "${profile}"/grub/themes/tuxos/
cp -r "${out}"/grub-installed/. "${profile}"/root-overlay/usr/share/grub/themes/tuxos/
cp "${out}"/pixmaps/tuxos-logo.png "${profile}"/root-overlay/usr/share/pixmaps/
cp "${out}"/calamares/*.png "${profile}"/live-overlay/usr/share/calamares/branding/tuxos/
desktop="${profile}"/live-overlay/usr/share/tuxos/desktop/common/root
mkdir -p "${desktop}"/usr/share/backgrounds/tuxos "${desktop}"/usr/share/wallpapers/TuxOS/contents/images
cp "${out}"/desktop/tuxos-wallpaper.jpg "${desktop}"/usr/share/backgrounds/tuxos/
cp "${out}"/desktop/tuxos-wallpaper.jpg "${desktop}"/usr/share/wallpapers/TuxOS/contents/images/3840x2160.jpg
cp "${out}"/desktop/tuxos-wallpaper.jpg "${desktop}"/usr/share/sddm/themes/tuxos/background.jpg
# Login screen: the "Terminal" SDDM theme with the ASCII Tux built in
python3 -I "${here}/make-sddm-terminal.py" "${here}/tux-ascii.txt" "${desktop}/usr/share/sddm/themes/tuxos/Main.qml"
# fastfetch logo: the classic ASCII Tux ($1 body, $2 feet)
install -Dm644 "${here}/tux-ascii.txt" "${profile}/root-overlay/usr/share/tuxos/fastfetch/tux.txt"
# Light dropdown arrow for the login screen's dark fields
magick -size 24x24 xc:none -stroke "${grey}" -strokewidth 2.5 -fill none \
    -draw "polyline 7,10 12,15 17,10" -strip "PNG32:${desktop}/usr/share/sddm/themes/tuxos/angle-down.png"

echo "Assets written to ${out} and installed into the profile"
