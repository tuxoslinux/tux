#!/hint/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

#{{{ mount

track_img() {
    msg2 "mount: [%s]" "$2"
    mount "$@" && IMG_ACTIVE_MOUNTS=("$2" "${IMG_ACTIVE_MOUNTS[@]}")
}

mount_img() {
    IMG_ACTIVE_MOUNTS=()
    mkdir -p "$2"
    track_img "$1" "$2"
}

umount_img() {
    if [[ -n "${IMG_ACTIVE_MOUNTS[*]}" ]];then
        msg2 "umount: [%s]" "${IMG_ACTIVE_MOUNTS[@]}"
        umount "${IMG_ACTIVE_MOUNTS[@]}"
        unset IMG_ACTIVE_MOUNTS
        rm -r "$1"
    fi
}

track_fs() {
    msg2 "overlayfs mount: [%s]" "$5"
    mount "$@" && FS_ACTIVE_MOUNTS=("$5" "${FS_ACTIVE_MOUNTS[@]}")
}

mount_overlayfs(){
    FS_ACTIVE_MOUNTS=()
    local lower upper="$1" work="$2"
    # a work directory left by an aborted build carries an index of another
    # upper directory, and overlayfs then refuses to mount
    rm -rf "${mnt_dir}/work"
    mkdir -p "${mnt_dir}/work"
    mkdir -p "$upper"
    case $upper in
        */livefs) lower="$work/rootfs" ;;
        */bootfs)
            lower="$work/rootfs"
            [[ -d "$work/livefs" ]] && lower="$work/livefs:$work/rootfs"
        ;;
    esac
    # shellcheck disable=2140
    track_fs -t overlay overlay -olowerdir="$lower",upperdir="$upper",workdir="${mnt_dir}/work" "$upper"
}

# Processes started inside a layer (a daemon from a package hook, a gpg-agent
# or keyboxd, ...) keep it busy; stop them. Only processes whose root is in
# the layer are touched: anything else reading its files (a virus scanner on
# the host, for one) is left alone and waited for.
stop_layer_processes(){
    local m="$1" p root
    for p in /proc/[0-9]*; do
        root=$(readlink "$p/root" 2>/dev/null) || continue
        if [[ "$root" == "$m" || "$root" == "$m"/* ]]; then
            warning "Stopping %s (pid %s), still running in %s" \
                "$(cat "$p/comm" 2>/dev/null)" "${p##*/}" "$m"
            kill "${p##*/}" 2>/dev/null || true
        fi
    done
}

# Names the processes outside the layer that still have files of it open.
report_layer_readers(){
    local m="$1" p fd file
    for p in /proc/[0-9]*; do
        for fd in "$p"/fd/*; do
            file=$(readlink "$fd" 2>/dev/null) || continue
            if [[ "$file" == "$m"/* ]]; then
                msg2 "Waiting for %s (pid %s), reading %s" \
                    "$(cat "$p/comm" 2>/dev/null)" "${p##*/}" "$file"
                break
            fi
        done
    done
}

umount_overlayfs(){
    if [[ -n "${FS_ACTIVE_MOUNTS[*]}" ]];then
        msg2 "overlayfs umount: [%s]" "${FS_ACTIVE_MOUNTS[@]}"
        local m try
        for m in "${FS_ACTIVE_MOUNTS[@]}"; do
            for try in {1..90}; do
                umount "$m" 2>/dev/null && break
                (( try == 2 )) && stop_layer_processes "$m"
                (( try % 15 == 5 )) && report_layer_readers "$m"
                sleep 2
            done
            if mountpoint -q "$m"; then
                # everything was written before; only readers remain, so
                # detaching leaves the finished layer directory as it is
                warning "%s still busy after 3 minutes; detaching it" "$m"
                umount -l "$m"
            fi
        done
        unset FS_ACTIVE_MOUNTS
        rm -rf "${mnt_dir}/work"
    fi
}

#}}}
