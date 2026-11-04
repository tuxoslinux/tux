#!/bin/bash
# Builds the TuxOS installer ISO.
#
# Copies the profile and the patched buildiso into the Artix build chroot
# (~/tuxos/artix-root), runs the build there, and puts the ISO
# (tuxos-<date>-<time>-x86_64.iso) and its .sha256 into a new folder
# ~/tuxos/out/build<N>, N being one more than the highest existing build
# folder, so no earlier build is ever overwritten. Each build gets a line in
# out/BUILDS.md; tools/mark-build records test results there.
# BUILD_DIR=build<N> ./build.sh rebuilds into an existing folder instead,
# replacing its ISO (only when the owner asks for that build to be redone).
# CHROOT_DIR=... uses another build chroot (made by tools/make-chroot.sh),
# OUT_DIR=... another folder for the builds.
# Run as your normal user; it uses sudo where needed.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
chroot_dir="$(cd "${CHROOT_DIR:-${here}/../artix-root}" && pwd)"
out_dir="${OUT_DIR:-$(cd "${here}/.." && pwd)/out}"
workspace="${chroot_dir}/root/artools-workspace"
log_dir="${here}/logs"
stamp="$(date +%Y%m%d-%H%M)"
build_name="tuxos-${stamp}-x86_64.iso"

mkdir -p "${log_dir}" "${out_dir}"
# next build folder: out/build<N+1>
n=0
for d in "${out_dir}"/build[0-9]*/; do
    [[ -d "$d" ]] || continue
    d="${d%/}"; d="${d##*/build}"
    if [[ "$d" =~ ^[0-9]+$ ]] && (( 10#$d > n )); then n=$(( 10#$d )); fi
done
build_dir="${BUILD_DIR:-build$(( n + 1 ))}"
if [[ -z "${BUILD_DIR:-}" && -e "${out_dir}/${build_dir}" ]]; then
    echo "ERROR: ${out_dir}/${build_dir} already exists" >&2
    exit 1
fi
echo "==> This build: ${out_dir}/${build_dir}/${build_name}"

echo "==> Generating artwork"
"${here}/branding/make-assets.sh"

echo "==> Installing profile into the build chroot"
sudo rm -rf "${workspace}/iso-profiles/tuxos"
sudo cp -r "${here}/profile/tuxos" "${workspace}/iso-profiles/tuxos"
sudo chown -R root:root "${workspace}/iso-profiles/tuxos"
sudo chmod -R go+rX,go-w "${workspace}/iso-profiles/tuxos"
# wildcards under the chroot's /root are expanded as root: that folder is
# not readable by the build user
sudo sh -c 'chmod 0440 "$1"/iso-profiles/tuxos/live-overlay/etc/sudoers.d/*' sh "${workspace}"

echo "==> Installing tuxos-buildiso into the build chroot"
sudo install -Dm755 "${here}/tools/tuxos-buildiso" "${chroot_dir}/usr/local/bin/tuxos-buildiso"
sudo rm -rf "${chroot_dir}/usr/local/share/tuxos-buildiso"
sudo mkdir -p "${chroot_dir}/usr/local/share/tuxos-buildiso"
sudo cp -r "${here}/tools/lib" "${chroot_dir}/usr/local/share/tuxos-buildiso/lib"
sudo chown -R root:root "${chroot_dir}/usr/local/share/tuxos-buildiso"
# pacman configuration of the build (adds lib32, Arch and CachyOS repos);
# artools reads it from the build user's config directory
sudo install -Dm644 "${here}/tools/pacman.conf.d/iso-x86_64.conf" \
    "${chroot_dir}/root/.config/artools/pacman.conf.d/iso-x86_64.conf"

run_in_chroot() {
    sudo arch-chroot "${chroot_dir}" /usr/bin/env -i \
        HOME=/root USER=root TERM="${TERM:-xterm}" LANG=C.UTF-8 \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/bin "$@"
}

echo "==> Preparing the build chroot (Arch and CachyOS repositories)"
sudo install -Dm755 "${here}/tools/prepare-chroot.sh" "${chroot_dir}/usr/local/bin/tuxos-prepare-chroot"
run_in_chroot /usr/local/bin/tuxos-prepare-chroot

echo "==> Building (log: ${log_dir}/build-${stamp}.log)"
sudo sh -c 'rm -f "$1"/iso/tuxos/tuxos-*.iso' sh "${workspace}"
run_in_chroot /usr/local/bin/tuxos-buildiso -p tuxos -i dinit 2>&1 | tee "${log_dir}/build-${stamp}.log"

# old tuxos-*.iso files were removed before the build, so this is the new one
iso=$(sudo find "${workspace}/iso/tuxos" -maxdepth 1 -name 'tuxos-*.iso' -print -quit)
[[ -n "${iso}" ]] || { echo "ERROR: no ISO produced" >&2; exit 1; }

echo "==> Adding ${build_name} to ${out_dir}/${build_dir}"
if [[ -n "${BUILD_DIR:-}" ]]; then
    # rebuild of an existing build: the new ISO replaces the old one
    mkdir -p "${out_dir}/${build_dir}"
    rm -f "${out_dir}/${build_dir}"/tuxos-*.iso "${out_dir}/${build_dir}"/tuxos-*.iso.sha256
else
    mkdir "${out_dir}/${build_dir}"
fi
sudo install -m644 -o "$(id -u)" -g "$(id -g)" "${iso}" "${out_dir}/${build_dir}/${build_name}"
(cd "${out_dir}/${build_dir}" && sha256sum "${build_name}" > "${build_name}.sha256")

builds="${out_dir}/BUILDS.md"
if [[ ! -f "${builds}" ]]; then
    cat > "${builds}" <<'EOF'
# TuxOS builds

Every run of `tuxos-build/build.sh` adds a folder build<N> with the ISO
and its .sha256; nothing is ever overwritten. `tuxos-build/tools/mark-build` records test results.

| ISO | Built | Size | SHA-256 | Tests |
| --- | --- | --- | --- | --- |
EOF
fi
printf '| %s | %s | %s | `%s` | not tested yet |\n' \
    "${build_dir}/${build_name}" "$(date '+%Y-%m-%d %H:%M')" \
    "$(du -h "${out_dir}/${build_dir}/${build_name}" | cut -f1)" \
    "$(cut -c1-16 "${out_dir}/${build_dir}/${build_name}.sha256")" >> "${builds}"

echo "==> Done: ${out_dir}/${build_dir}/${build_name}"
