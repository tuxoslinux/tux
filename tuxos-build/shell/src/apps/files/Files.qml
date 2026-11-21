import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

// Files (Super + F; mockup apps/09-files): places, drives, a grid or list
// of the folder, a preview panel for the selected item, quick look (Space),
// copy / cut / paste (also with other apps through the clipboard; a copied
// image pastes as a PNG), Trash with Undo instead of "are you sure",
// rename (F2), new folder, archives (extract / compress with bsdtar),
// search (typing filters the folder, Enter searches below it).
AppWindow {
    id: app
    appName: picking ? (Quickshell.env("TUXOS_PICK_TITLE") || (pickMode === "save" ? Tr.t("Save as") : pickMode === "folder" ? Tr.t("Choose a folder") : Tr.t("Open"))) : "Files"
    appIcon: Icons.folder
    searchable: true
    searchHint: Tr.f("Search in {p}", { p: crumbName(cwd) })
    keyTarget: keyRoot

    readonly property string home: Quickshell.env("HOME")
    readonly property string trashDir: home + "/.local/share/Trash/files"
    property string cwd: {
        const p = Quickshell.env("TUXOS_PAGE") || "";
        return p.startsWith("file://") ? decodeURIComponent(p.slice(7)) : (p.startsWith("/") ? p : home);
    }
    IpcHandler { target: "files"; function page(id: string): void { app.go(id.startsWith("file://") ? decodeURIComponent(id.slice(7)) : id); } }

    // ---- pick mode (TuxOS file chooser: tuxos-portal starts Files with
    // TUXOS_PICK = open / openmulti / folder / save; the choice is written
    // to TUXOS_PICK_OUT as file:// lines, nothing when cancelled)
    readonly property string pickMode: Quickshell.env("TUXOS_PICK") || ""
    readonly property bool picking: pickMode !== ""
    readonly property var pickFilters: (Quickshell.env("TUXOS_PICK_FILTER") || "").split(";").filter(x => x)
    property string saveName: Quickshell.env("TUXOS_PICK_NAME") || ""
    FileView { id: pickOut; path: Quickshell.env("TUXOS_PICK_OUT") || "/dev/null"; printErrors: false }
    function pickDone(paths) {
        if (paths && paths.length) pickOut.setText(paths.map(p => "file://" + encodeURI(p)).join("\n") + "\n");
        pickQuit.restart();
    }
    Timer { id: pickQuit; interval: 120; onTriggered: Qt.quit() }
    function pickConfirm() {
        if (pickMode === "save") { if (saveName.trim()) pickDone([cwd + "/" + saveName.trim()]); return; }
        if (pickMode === "folder") { pickDone([selected.length === 1 && isDirPath(selected[0]) ? selected[0] : cwd]); return; }
        const files = targets().filter(p => !isDirPath(p));
        if (files.length) pickDone(pickMode === "openmulti" ? files : [files[0]]);
    }
    function isDirPath(p) { for (let i = 0; i < fm.count; i++) if (fm.get(i, "filePath") === p) return fm.get(i, "fileIsDir"); return false; }

    property var back: []
    property var forward: []
    property bool grid: true
    property bool hidden: false
    property var selected: []                 // paths
    property string focusPath: ""             // keyboard / preview item
    property bool quickLook: false
    property string renaming: ""
    property var clip: ({ mode: "", paths: [] })
    property var searchResults: null          // null = folder view
    property string banner: ""
    property var bannerUndo: null
    readonly property bool inTrash: cwd === trashDir

    function go(p, keepHistory) {
        if (!p || p === cwd) return;
        if (!keepHistory) { back = back.concat([cwd]); forward = []; }
        cwd = p.length > 1 ? p.replace(/\/$/, "") : p;
        selected = []; focusPath = ""; quickLook = false; renaming = ""; searchResults = null; app.search = "";
    }
    function goBack() { if (!back.length) return; const p = back[back.length - 1]; forward = [cwd].concat(forward); back = back.slice(0, -1); go(p, true); }
    function goForward() { if (!forward.length) return; const p = forward[0]; back = back.concat([cwd]); forward = forward.slice(1); go(p, true); }
    function goUp() { if (cwd !== "/") go(cwd.substring(0, cwd.lastIndexOf("/")) || "/"); }
    function base(p) { return p.substring(p.lastIndexOf("/") + 1); }
    function crumbName(p) { return p === home ? Tr.t("Home") : (p === "/" ? "/" : (p === trashDir ? Tr.t("Trash") : base(p))); }

    // ---- the folder
    FolderListModel {
        id: fm
        folder: "file://" + app.cwd
        showDirsFirst: true
        showHidden: app.hidden
        showDotAndDotDot: false
        caseSensitive: false
        sortField: app.sortBy === "date" ? FolderListModel.Time : (app.sortBy === "size" ? FolderListModel.Size : FolderListModel.Name)
        sortReversed: app.sortBy !== "name"
        nameFilters: app.search && app.searchResults === null ? ["*" + app.search + "*"] : (app.picking && app.pickFilters.length ? app.pickFilters : ["*"])
        showFiles: app.pickMode !== "folder"
        onStatusChanged: if (status === FolderListModel.Ready) countProc.run()
    }
    property string sortBy: "name"
    // how many items each sub-folder holds ("12 items")
    property var counts: ({})
    Cmd {
        id: countProc
        command: ["sh", "-c", "cd \"$1\" 2>/dev/null || exit 0; for d in */ .*/; do [ -d \"$d\" ] || continue; case $d in ./|../) continue;; esac; printf '%s\\t%s\\n' \"${d%/}\" \"$(ls -A \"$d\" 2>/dev/null | wc -l)\"; done | head -n 400", "sh", app.cwd]
        onDone: out => { const c = {}; for (const l of out.split("\n")) { const t = l.split("\t"); if (t.length === 2) c[t[0]] = +t[1]; } app.counts = c; }
    }

    // the items shown: the folder, or search results. fm.get() does not
    // notify bindings, so every model change bumps rev, which itemAt reads.
    property int rev: 0
    Connections {
        target: fm
        function onDataChanged() { app.rev++; }
        function onRowsInserted() { app.rev++; }
        function onRowsRemoved() { app.rev++; }
        function onRowsMoved() { app.rev++; }
        function onModelReset() { app.rev++; }
        function onLayoutChanged() { app.rev++; }
    }
    readonly property int itemCount: searchResults !== null ? searchResults.length : fm.count
    function itemAt(i) {
        void rev;
        if (searchResults !== null) {
            const r = searchResults[i];
            return { name: base(r.path), path: r.path, dir: r.dir, size: r.size, time: r.time, suffix: r.dir ? "" : suffixOf(base(r.path)) };
        }
        return { name: fm.get(i, "fileName"), path: fm.get(i, "filePath"), dir: fm.get(i, "fileIsDir"), size: fm.get(i, "fileSize"),
                 time: fm.get(i, "fileModified"), suffix: suffixOf(fm.get(i, "fileName")) };
    }

    // ---- kinds, symbols, sizes
    function suffixOf(n) { const i = n.lastIndexOf("."); return i > 0 ? n.slice(i + 1).toLowerCase() : ""; }
    readonly property var kinds: ({
        png: "image", jpg: "image", jpeg: "image", webp: "image", gif: "image", svg: "image", avif: "image", bmp: "image", heic: "image",
        mp4: "video", mkv: "video", webm: "video", mov: "video", avi: "video",
        mp3: "audio", flac: "audio", ogg: "audio", opus: "audio", wav: "audio", m4a: "audio",
        pdf: "pdf", zip: "archive", gz: "archive", xz: "archive", zst: "archive", bz2: "archive", "7z": "archive", rar: "archive", tar: "archive", tgz: "archive",
        sh: "code", py: "code", js: "code", qml: "code", c: "code", h: "code", cpp: "code", rs: "code", go: "code", lua: "code", json: "code", toml: "code", yaml: "code", yml: "code", conf: "code",
        md: "text", txt: "text", log: "text", csv: "text", desktop: "text",
        doc: "doc", docx: "doc", odt: "doc", xls: "doc", xlsx: "doc", ods: "doc", ppt: "doc", pptx: "doc", odp: "doc",
        iso: "disc", img: "disc", exe: "windows", msi: "windows", AppImage: "app", appimage: "app"
    })
    function kindOf(it) { return it.dir ? "folder" : (kinds[it.suffix] || "file"); }
    readonly property var symbols: ({ folder: 0xf024b, image: 0xf021f, video: 0xf022b, audio: 0xf0223, pdf: 0xf0226, archive: 0xf05c4, code: 0xf022e,
                                      text: 0xf0219, doc: 0xf0219, disc: 0xf02ca, windows: 0xf05b3, app: 0xf003b, file: 0xf0214 })
    readonly property var kindNames: ({ folder: "Folder", image: "Image", video: "Video", audio: "Audio", pdf: "PDF document", archive: "Archive", code: "Code",
                                        text: "Text", doc: "Document", disc: "Disk image", windows: "Windows program", app: "App", file: "File" })
    function size(b) {
        if (b < 1024) return b + " B";
        if (b < 1048576) return Math.round(b / 1024) + " KB";
        if (b < 1073741824) return (b / 1048576).toFixed(b < 10485760 ? 1 : 0) + " MB";
        return (b / 1073741824).toFixed(1) + " GB";
    }
    function when(d) {
        const t = new Date(d), now = new Date();
        if (t.toDateString() === now.toDateString()) return Tr.t("Today") + ", " + Qt.formatTime(t, "HH:mm");
        return Tr.date(t, t.getFullYear() === now.getFullYear() ? "d MMM, HH:mm" : "d MMM yyyy");
    }
    function sub(it) {
        if (it.dir) return app.counts[it.name] !== undefined ? Tr.f(app.counts[it.name] === 1 ? "{n} item" : "{n} items", { n: app.counts[it.name] }) : "";
        return size(it.size);
    }

    // ---- actions
    function open(it) {
        if (it.dir) { go(it.path); return; }
        if (picking) { if (pickMode === "save") saveName = it.name; else pickDone([it.path]); return; }
        Quickshell.execDetached(["gio", "open", it.path]);
    }
    // clicking files or the view gives the keys back to the view (Ctrl + C /
    // V, Delete, Space), away from the search field
    function takeKeys() { keyRoot.forceActiveFocus(); }
    function select(path, add) {
        takeKeys();
        focusPath = path;
        if (add) selected = selected.indexOf(path) === -1 ? selected.concat([path]) : selected.filter(p => p !== path);
        else selected = [path];
    }
    function targets() { return selected.length ? selected : (focusPath ? [focusPath] : []); }
    function copy(cut) {
        const t = targets();
        if (!t.length) return;
        clip = { mode: cut ? "cut" : "copy", paths: t };
        // other apps can paste them too
        Quickshell.execDetached(["sh", "-c", "for p in \"$@\"; do printf 'file://%s\\r\\n' \"$p\"; done | wl-copy -t text/uri-list", "sh"].concat(t));
        flash(Tr.f(cut ? "{n} cut" : "{n} copied", { n: t.length === 1 ? base(t[0]) : Tr.f("{n} items", { n: t.length }) }));
    }
    function paste() {
        opTitle = clip.paths.length ? Tr.f(clip.mode === "cut" ? "Moving {n} to {d}" : "Copying {n} to {d}", { n: clip.paths.length === 1 ? base(clip.paths[0]) : Tr.f("{n} items", { n: clip.paths.length }), d: crumbName(cwd) }) : Tr.t("Pasting");
        // our own clipboard first, then files or an image from other apps
        ops.run(["sh", "-c", `
dest="$1"; mode="$2"; shift 2
uniq() { n="$1"; [ -e "$dest/$n" ] || { echo "$n"; return; }; s="\${n%.*}"; e="\${n##*.}"; [ "$s" = "$n" ] && e="" || e=".$e"; i=2; while [ -e "$dest/$s ($i)$e" ]; do i=$((i+1)); done; echo "$s ($i)$e"; }
if [ "$mode" = copy ] || [ "$mode" = cut ]; then
  for p in "$@"; do n=$(uniq "$(basename "$p")"); if [ "$mode" = cut ]; then mv -- "$p" "$dest/$n"; else cp -a -- "$p" "$dest/$n"; fi; done; echo done; exit; fi
types=$(wl-paste --list-types 2>/dev/null)
if printf '%s' "$types" | grep -qx 'text/uri-list'; then
  wl-paste -t text/uri-list | tr -d '\\r' | while read -r u; do case $u in file://*) p=$(printf '%b' "$(printf %s "\${u#file://}" | sed 's/%/\\\\x/g')"); n=$(uniq "$(basename "$p")"); cp -a -- "$p" "$dest/$n";; esac; done; echo done
elif printf '%s' "$types" | grep -q '^image/png'; then
  n=$(uniq "Pasted image $(date '+%Y-%m-%d %H.%M.%S').png"); wl-paste -t image/png > "$dest/$n" && echo "image $n"
elif printf '%s' "$types" | grep -q '^image/'; then
  t=$(printf '%s' "$types" | grep -m1 '^image/'); n=$(uniq "Pasted image $(date '+%Y-%m-%d %H.%M.%S').\${t#image/}"); wl-paste -t "$t" > "$dest/$n" && echo "image $n"
else echo nothing; fi`, "sh", cwd, clip.mode].concat(clip.paths), out => {
            if (clip.mode === "cut") clip = { mode: "", paths: [] };
            if (out.indexOf("image ") === 0) flash(Tr.f("Image pasted as {n}", { n: out.slice(6).trim() }));
            else if (out.trim() === "nothing") flash(Tr.t("Nothing to paste"));
        });
    }
    function trash() {
        const t = targets();
        if (!t.length) return;
        if (inTrash) { ops.run(["sh", "-c", "for p in \"$@\"; do n=$(basename \"$p\"); rm -rf -- \"$p\" \"$HOME/.local/share/Trash/info/$n.trashinfo\"; done", "sh"].concat(t)); flash(Tr.t("Deleted for good")); return; }
        ops.run(["gio", "trash", "--"].concat(t));
        const names = t.map(base);
        flash(Tr.f(t.length === 1 ? "{n} moved to Trash" : "{n} items moved to Trash", { n: t.length === 1 ? names[0] : t.length }),
              () => restoreNames(names));
    }
    function restore() {
        restoreNames(targets().map(base));
        flash(Tr.t("Restored"));
    }
    // back to where they were, from the freedesktop Trash's .trashinfo files
    function restoreNames(names) {
        ops.run(["sh", "-c", `
T="$HOME/.local/share/Trash"
for n in "$@"; do
  i="$T/info/$n.trashinfo"; [ -f "$i" ] || continue
  p=$(sed -n 's/^Path=//p' "$i" | head -n1)
  p=$(printf '%b' "$(printf %s "$p" | sed 's/%/\\\\x/g')")
  mkdir -p -- "$(dirname -- "$p")"
  [ -e "$p" ] && p="$p (restored)"
  mv -- "$T/files/$n" "$p" && rm -f -- "$i"
done`, "sh"].concat(names));
    }
    function newFolder() {
        ops.run(["sh", "-c", "n='New folder'; i=2; while [ -e \"$1/$n\" ]; do n=\"New folder $i\"; i=$((i+1)); done; mkdir -- \"$1/$n\" && echo \"$1/$n\"", "sh", cwd],
                out => { const p = out.trim(); if (p) { app.select(p, false); app.renaming = p; } });
    }
    function rename(path, name) {
        renaming = "";
        name = name.trim();
        if (!name || name === base(path) || name.indexOf("/") !== -1) return;
        const to = path.substring(0, path.lastIndexOf("/")) + "/" + name;
        ops.run(["mv", "-n", "--", path, to], () => { app.select(to, false); });
    }
    function extract(path) {
        const dir = path.replace(/\.(tar\.(gz|xz|zst|bz2)|tgz|zip|7z|rar|tar|gz|xz|zst)$/i, "");
        ops.run(["sh", "-c", "d=\"$2\"; i=2; while [ -e \"$d\" ]; do d=\"$2 ($i)\"; i=$((i+1)); done; mkdir -p -- \"$d\" && bsdtar -xf \"$1\" -C \"$d\" && echo \"$d\"", "sh", path, dir],
                out => flash(out.trim() ? Tr.f("Extracted to {n}", { n: base(out.trim()) }) : Tr.t("Could not extract")));
    }
    function compress() {
        const t = targets();
        if (!t.length) return;
        const name = (t.length === 1 ? base(t[0]) : "Archive") + ".zip";
        ops.run(["sh", "-c", "cd \"$1\" && shift && n=\"$1\" && shift && bsdtar -acf \"$n\" -- \"$@\" && echo ok", "sh", cwd, name].concat(t.map(base)),
                out => flash(out.trim() === "ok" ? Tr.f("Saved {n}", { n: name }) : Tr.t("Could not compress")));
    }
    function terminalHere() { Quickshell.execDetached(["sh", "-c", "cd \"$1\" && exec \"$2\"", "sh", cwd, Prefs.terminal || "kitty"]); }
    function emptyTrash() { ops.run(["gio", "trash", "--empty"]); flash(Tr.t("Trash emptied")); }

    // a long file operation shows as a live activity in the bar (after 1 s)
    property string opTitle: ""
    property bool longOp: false
    Timer { id: longT; interval: 1000; onTriggered: app.longOp = runner.running }
    Connections { target: runner; function onRunningChanged() { if (runner.running) longT.restart(); else { longT.stop(); app.longOp = false; app.opTitle = ""; } } }
    ActivityFile {
        key: "files"
        active: app.longOp
        title: app.opTitle || Tr.t("Working on files")
        sub: Tr.t("Files")
        icon: Icons.folder
    }

    // one runner for file operations; the folder model refreshes itself
    QtObject {
        id: ops
        property var queue: []
        function run(cmd, done) { queue = queue.concat([{ cmd: cmd, done: done }]); if (!runner.running) next(); }
        function next() {
            if (!queue.length) return;
            const j = queue[0]; queue = queue.slice(1);
            runner.done = j.done || null; runner.command = j.cmd; runner.running = true;
        }
    }
    Process {
        id: runner
        property var done: null
        stdout: StdioCollector { id: runnerOut }
        onExited: { const d = done; if (d) d(runnerOut.text); ops.next(); }
    }

    function flash(text, undo) { banner = text; bannerUndo = undo || null; bannerTimer.restart(); }
    Timer { id: bannerTimer; interval: 6000; onTriggered: { app.banner = ""; app.bannerUndo = null; } }

    // recursive search (Enter in the search field)
    onSearchAccepted: {
        if (!app.search.trim()) { searchResults = null; return; }
        searchProc.run();
    }
    onSearchChanged: if (!app.search) searchResults = null
    Cmd {
        id: searchProc
        command: ["sh", "-c", "find \"$1\" -mindepth 1 \\( -name '.*' -prune \\) -o -iname \"*$2*\" -printf '%y\\t%s\\t%T@\\t%p\\n' 2>/dev/null | head -n 300", "sh", app.cwd, app.search.trim()]
        onDone: out => {
            const r = [];
            for (const l of out.split("\n")) { const f = l.split("\t"); if (f.length === 4) r.push({ dir: f[0] === "d", size: +f[1], time: new Date(+f[2] * 1000), path: f[3] }); }
            app.searchResults = r;
        }
    }

    // ---- drives (lsblk); click mounts and opens
    property var drives: []
    Cmd {
        id: drivesProc
        command: ["lsblk", "-J", "-b", "-o", "NAME,LABEL,SIZE,FSAVAIL,MOUNTPOINT,RM,HOTPLUG,TYPE,FSTYPE,TRAN,MODEL"]
        Component.onCompleted: run()
        onDone: out => {
            let j = null; try { j = JSON.parse(out); } catch (e) { return; }
            const l = [];
            const walk = (dev, parent) => {
                const kids = dev.children || [];
                if ((dev.type === "part" || (dev.type === "disk" && kids.length === 0)) && dev.fstype && dev.fstype !== "swap" && dev.fstype !== "LVM2_member" && dev.fstype !== "crypto_LUKS") {
                    const mp = dev.mountpoint || "";
                    if (!/^\/(boot|efi|boot\/efi)$|^\[SWAP\]$/.test(mp)) {
                        const removable = (parent || dev).rm || (parent || dev).hotplug || (parent || dev).tran === "usb";
                        l.push({ dev: "/dev/" + dev.name, name: mp === "/" ? Tr.t("System disk") : (dev.label || ((parent && parent.model) ? parent.model.trim() : dev.name)),
                                 size: +dev.size, free: +dev.fsavail || 0, mount: mp, removable: !!removable });
                    }
                }
                for (const k of kids) walk(k, parent || dev);
            };
            for (const d of j.blockdevices || []) walk(d, null);
            app.drives = l;
        }
    }
    Timer { interval: 4000; repeat: true; running: true; onTriggered: drivesProc.run() }
    function openDrive(d) {
        if (d.mount) { go(d.mount); return; }
        ops.run(["sh", "-c", "udisksctl mount -b \"$1\" 2>/dev/null | sed -n 's/.* at //p' | sed 's/\\.$//'", "sh", d.dev], out => { if (out.trim()) app.go(out.trim()); drivesProc.run(); });
    }
    function eject(d) { ops.run(["sh", "-c", "udisksctl unmount -b \"$1\" && udisksctl power-off -b \"$1\" 2>/dev/null; true", "sh", d.dev], () => { flash(Tr.t("Safe to remove ✓")); drivesProc.run(); if (app.cwd.startsWith(d.mount)) app.go(app.home); }); }

    // ---- layout
    Item {
        id: keyRoot
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => app.key(event)
        Component.onCompleted: forceActiveFocus()

        // sidebar
        Flickable {
            id: side
            x: 12; y: 12; width: 230; height: parent.height - 24
            contentHeight: sideCol.implicitHeight
            clip: true
            Column {
                id: sideCol
                width: parent.width
                spacing: 4
                SideHeader { text: Tr.t("PLACES") }
                Repeater {
                    model: [["Home", app.home, 0xf02dc], ["Desktop", app.home + "/Desktop", 0xf01c4], ["Documents", app.home + "/Documents", 0xf0219],
                            ["Downloads", app.home + "/Downloads", 0xf01da], ["Pictures", app.home + "/Pictures", 0xf021f], ["Music", app.home + "/Music", 0xf0387],
                            ["Videos", app.home + "/Videos", 0xf022b], ["Trash", app.trashDir, 0xf0a7a]]
                    delegate: SideItem {
                        required property var modelData
                        label: Tr.t(modelData[0]); icon: modelData[2]
                        active: app.cwd === modelData[1]
                        onClicked: { Quickshell.execDetached(["mkdir", "-p", modelData[1]]); app.go(modelData[1]); }
                    }
                }
                SideHeader { text: Tr.t("DRIVES"); visible: app.drives.length > 0 }
                Repeater {
                    model: app.drives
                    delegate: SideItem {
                        required property var modelData
                        label: modelData.name
                        icon: modelData.removable ? 0xf0553 : 0xf02ca
                        extra: app.size(modelData.free || modelData.size)
                        active: modelData.mount !== "" && app.cwd === modelData.mount
                        ejectable: modelData.removable && modelData.mount !== ""
                        onClicked: app.openDrive(modelData)
                        onEjected: app.eject(modelData)
                    }
                }
            }
        }
        Rectangle { x: side.x + side.width + 11; y: 0; width: 1; height: parent.height; color: Theme.glassLine }

        // toolbar: back, forward, up, path, view, sort, new folder
        Row {
            id: tools
            x: side.x + side.width + 28; y: 16
            width: rightTools.x - x - 12      // a long path is cut, not drawn under the buttons
            clip: true
            spacing: 8
            ToolBtn { icon: Icons.arrowLeft; enabled2: app.back.length > 0; tip: "Back"; onClicked: app.goBack() }
            ToolBtn { icon: Icons.arrowRight; enabled2: app.forward.length > 0; tip: "Forward"; onClicked: app.goForward() }
            ToolBtn { icon: Icons.arrowUp; enabled2: app.cwd !== "/"; tip: "Up"; onClicked: app.goUp() }
            Item { width: 6; height: 1 }
            // the path; when it does not fit: "… / current folder" ("…" goes up)
            Item {
                id: crumbBox
                width: tools.width - x; height: 36
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                readonly property var model: {
                    const inHome = app.cwd === app.home || app.cwd.startsWith(app.home + "/");
                    // on a drive (USB stick, second disk): the path starts at the drive
                    const dm = /^(\/run\/media\/[^/]+\/[^/]+|\/media\/[^/]+|\/mnt\/[^/]+)/.exec(app.cwd);
                    const rootPath = inHome ? app.home : (dm ? dm[1] : "");
                    const rel = app.cwd.slice(rootPath.length);
                    const parts = rel.split("/").filter(x => x);
                    const out = [{ name: inHome ? Tr.t("Home") : (dm ? dm[1].split("/").pop() : "/"), path: rootPath || "/" }];
                    let acc = rootPath;
                    for (const p of parts) { acc += "/" + p; out.push({ name: acc === app.trashDir ? Tr.t("Trash") : p, path: acc }); }
                    return app.searchResults !== null ? out.concat([{ name: Tr.f("Results for \"{q}\"", { q: app.search }), path: "" }]) : out;
                }
                // the whole path, measured off screen
                Row {
                    id: measure
                    visible: false; spacing: 8
                    Repeater { model: crumbBox.model; delegate: Text { required property var modelData; required property int index; text: (index > 0 ? "/  " : "") + modelData.name; font.family: Theme.font; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold } }
                }
                readonly property bool tight: measure.implicitWidth > width && model.length > 1
                Row {
                    id: crumbs
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, crumbBox.width)
                    Text {
                        visible: crumbBox.tight
                        text: "…  /"; color: up.hovered ? Theme.text : Theme.muted; font.family: Theme.font; font.pixelSize: Theme.px(14)
                        anchors.verticalCenter: parent.verticalCenter
                        HoverHandler { id: up; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: app.goUp() }
                    }
                    Repeater {
                        model: crumbBox.model
                        delegate: Row {
                            required property var modelData
                            required property int index
                            readonly property bool last: index === crumbBox.model.length - 1
                            visible: !crumbBox.tight || last
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Text { visible: index > 0 && !crumbBox.tight; text: "/"; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.px(14) }
                            Text {
                                text: modelData.name
                                width: crumbBox.tight ? Math.min(implicitWidth, crumbBox.width - 40) : implicitWidth
                                elide: Text.ElideRight
                                font.family: Theme.font; font.pixelSize: Theme.px(14)
                                font.weight: modelData.path === app.cwd ? Font.DemiBold : Font.Normal
                                color: modelData.path === app.cwd || !modelData.path ? Theme.text : (ch.hovered ? Theme.text : Theme.muted)
                                HoverHandler { id: ch; cursorShape: modelData.path ? Qt.PointingHandCursor : Qt.ArrowCursor }
                                TapHandler { onTapped: if (modelData.path) app.go(modelData.path) }
                            }
                        }
                    }
                }
            }
        }
        Row {
            id: rightTools
            anchors { right: preview.left; rightMargin: 20; verticalCenter: tools.verticalCenter }
            spacing: 8
            ToolBtn { visible: app.inTrash; icon: Icons.deleteOutline; label: "Empty"; onClicked: app.emptyTrash() }
            ToolBtn { visible: !app.inTrash; icon: 0xf0b9d; tip: "New folder (Ctrl + Shift + N)"; onClicked: app.newFolder() }
            ToolBtn { icon: Icons.sort; tip: app.sortBy === "name" ? "Sorted by name" : app.sortBy === "date" ? "Newest first" : "Largest first"
                      onClicked: app.sortBy = app.sortBy === "name" ? "date" : app.sortBy === "date" ? "size" : "name" }
            ToolBtn { icon: app.hidden ? Icons.eye : Icons.eyeOff; tip: "Hidden files (Ctrl + H)"; onClicked: app.hidden = !app.hidden }
            ToolBtn { icon: app.grid ? 0xf0279 : 0xf0570; tip: app.grid ? "List" : "Grid"; onClicked: app.grid = !app.grid }
        }

        // the items
        Item {
            id: main
            x: side.x + side.width + 24; y: 64
            width: preview.x - x - 16
            height: parent.height - y - 12 - (app.picking ? 64 : 0)

            GridView {
                id: gv
                visible: app.grid
                anchors.fill: parent
                clip: true
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 140))); cellHeight: 152
                model: app.itemCount
                boundsBehavior: Flickable.StopAtBounds
                delegate: FileTile {
                    required property int index
                    readonly property var it: app.itemAt(index)
                    width: gv.cellWidth; height: gv.cellHeight
                    item: it
                    view: app
                }
            }
            ListView {
                id: lv
                visible: !app.grid
                anchors.fill: parent
                clip: true
                model: app.itemCount
                boundsBehavior: Flickable.StopAtBounds
                delegate: FileRow {
                    required property int index
                    width: lv.width
                    item: app.itemAt(index)
                    view: app
                }
            }
            // empty folder
            Column {
                anchors.centerIn: parent
                visible: app.itemCount === 0 && (app.searchResults !== null || fm.status === FolderListModel.Ready)
                spacing: 8
                Image { anchors.horizontalCenter: parent.horizontalCenter; source: Qt.resolvedUrl(Theme.light ? "../../assets/tux-line-dark.svg" : "../../assets/tux-line.svg"); width: 66; height: 77; sourceSize: Qt.size(132, 154); opacity: 0.5 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: app.searchResults !== null ? Tr.t("Nothing found") : (app.inTrash ? Tr.t("Trash is empty") : Tr.t("This folder is empty")); font.family: Theme.font; font.pixelSize: Theme.px(16); font.weight: Font.DemiBold; color: Theme.text }
                Text { anchors.horizontalCenter: parent.horizontalCenter; visible: !app.inTrash; text: Tr.t("Paste files or an image here with Ctrl + V"); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.muted }
            }
            // clicks on empty space: left clears the selection, right opens
            // the folder menu (items handle their own clicks)
            function emptyAt(p) {
                const v = app.grid ? gv : lv;
                return v.indexAt(p.x + v.contentX, p.y + v.contentY) === -1;
            }
            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: (ev, button) => {
                    if (!main.emptyAt(ev.position)) return;
                    app.takeKeys();
                    if (button === Qt.RightButton) app.menuAt(null, ev.position.x + main.x, ev.position.y + main.y);
                    else { app.selected = []; app.focusPath = ""; }
                }
            }
            TapHandler { acceptedDevices: PointerDevice.TouchScreen; onLongPressed: if (main.emptyAt(point.position)) app.menuAt(null, point.position.x + main.x, point.position.y + main.y) }
        }

        // preview panel
        Preview {
            id: preview
            anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 16; bottom: parent.bottom; bottomMargin: app.picking ? 80 : 16 }
            width: 300
            view: app
        }

        // banner (Undo)
        Rectangle {
            visible: app.banner !== ""
            anchors { horizontalCenter: main.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
            width: bannerRow.implicitWidth + 32; height: 44; radius: 14
            color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
            Row {
                id: bannerRow
                anchors.centerIn: parent
                spacing: 12
                Text { anchors.verticalCenter: parent.verticalCenter; text: app.banner; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text }
                Btn { visible: app.bannerUndo !== null; text: "Undo"; primary: true; onClicked: { const u = app.bannerUndo; app.banner = ""; app.bannerUndo = null; if (u) u(); } }
            }
        }

        // pick mode: what to do with the choice
        Rectangle {
            visible: app.picking
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 64
            color: Theme.ink(0.04)
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Theme.glassLine }
            Row {
                anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                spacing: 10
                visible: app.pickMode === "save"
                Text { anchors.verticalCenter: parent.verticalCenter; text: Tr.t("Name"); font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted }
                Rectangle {
                    width: 360; height: 36; radius: 11; color: Theme.ink(0.05); border.width: 1; border.color: nameIn.activeFocus ? Theme.accentLine : Theme.glassLine
                    TextInput { id: nameIn; anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: TextInput.AlignVCenter; clip: true
                                text: app.saveName; onTextEdited: app.saveName = text; onAccepted: app.pickConfirm()
                                font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text
                                Component.onCompleted: if (app.pickMode === "save") { forceActiveFocus(); select(0, text.lastIndexOf(".") > 0 ? text.lastIndexOf(".") : text.length); } }
                }
            }
            Text {
                visible: app.pickMode !== "save"
                anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                text: app.pickMode === "folder" ? Tr.f("Folder: {p}", { p: app.cwd.replace(app.home, "~") }) : (app.selected.length ? app.selected.map(p => app.base(p)).join(", ") : Tr.t("Pick a file (double-click opens it)"))
                width: parent.width - 320; elide: Text.ElideMiddle
                font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.muted
            }
            Row {
                anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                spacing: 8
                Btn { text: Tr.t("Cancel"); onClicked: app.pickDone([]) }
                Btn { primary: true
                      text: app.pickMode === "save" ? Tr.t("Save") : app.pickMode === "folder" ? Tr.t("Choose this folder") : Tr.t("Open")
                      enabled2: app.pickMode === "save" ? app.saveName.trim() !== "" : app.pickMode === "folder" ? true : app.targets().some(p => !app.isDirPath(p))
                      onClicked: app.pickConfirm() }
            }
        }

        // quick look (Space)
        QuickLook { anchors.fill: parent; view: app; visible: app.quickLook }

        // context menu
        property var menuFor: null
        FileMenu { id: menu; view: app }
    }
    function menuAt(it, x, y) {
        if (it && selected.indexOf(it.path) === -1) select(it.path, false);
        menu.show(it, x, y);
    }

    // ---- keyboard
    function indexOfPath(p) { for (let i = 0; i < itemCount; i++) if (itemAt(i).path === p) return i; return -1; }
    function key(e) {
        const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier, alt = e.modifiers & Qt.AltModifier;
        if (renaming) return;
        if (quickLook && (e.key === Qt.Key_Space || e.key === Qt.Key_Escape)) { quickLook = false; e.accepted = true; return; }
        const cols = grid ? Math.max(1, Math.floor(gv.width / gv.cellWidth)) : 1;
        let i = indexOfPath(focusPath);
        const moveTo = n => { n = Math.max(0, Math.min(itemCount - 1, n)); if (n >= 0 && itemCount) { select(itemAt(n).path, false); (grid ? gv : lv).positionViewAtIndex(n, ItemView.Contain); } };
        if (e.key === Qt.Key_Right && !alt) moveTo(i + 1);
        else if (e.key === Qt.Key_Left && !alt) moveTo(i - 1);
        else if (e.key === Qt.Key_Down) moveTo(i < 0 ? 0 : i + cols);
        else if (e.key === Qt.Key_Up && !alt) moveTo(i < 0 ? 0 : i - cols);
        else if (e.key === Qt.Key_Up && alt) goUp();
        else if ((e.key === Qt.Key_Left && alt) || e.key === Qt.Key_Backspace) goBack();
        else if (e.key === Qt.Key_Right && alt) goForward();
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { if (i >= 0) open(itemAt(i)); }
        else if (e.key === Qt.Key_Space) { if (focusPath) quickLook = true; }
        else if (e.key === Qt.Key_Delete) trash();
        else if (e.key === Qt.Key_F2) { if (focusPath) renaming = focusPath; }
        else if (ctrl && e.key === Qt.Key_C) copy(false);
        else if (ctrl && e.key === Qt.Key_X) copy(true);
        else if (ctrl && e.key === Qt.Key_V) paste();
        else if (ctrl && e.key === Qt.Key_A) selected = Array.from({ length: itemCount }, (_, n) => itemAt(n).path);
        else if (ctrl && e.key === Qt.Key_H) hidden = !hidden;
        else if (ctrl && shift && e.key === Qt.Key_N) newFolder();
        else if (e.key === Qt.Key_Escape) { selected = []; focusPath = ""; }
        else return;
        e.accepted = true;
    }

    component SideHeader: Text {
        leftPadding: 8; topPadding: 12; bottomPadding: 4
        font.family: Theme.font; font.pixelSize: Theme.px(11); font.weight: Font.DemiBold; font.letterSpacing: 1.2; color: Theme.muted
    }
    component SideItem: Rectangle {
        id: si
        property string label
        property int icon
        property string extra: ""
        property bool active: false
        property bool ejectable: false
        signal clicked()
        signal ejected()
        width: sideCol.width; height: 38; radius: 11
        color: active ? Theme.accentFill : (sh.hovered ? Theme.fill : "transparent")
        border.width: active ? 1 : 0; border.color: Theme.accentLine
        Row {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: 12
            Text { text: String.fromCodePoint(si.icon); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: si.active ? Theme.accent : Theme.muted; anchors.verticalCenter: parent.verticalCenter }
            Text { text: si.label; width: si.width - 110; elide: Text.ElideRight; font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
        }
        Text { visible: !si.ejectable && si.extra !== ""; anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: si.extra; font.family: Theme.font; font.pixelSize: Theme.px(11); color: Theme.dim }
        HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: si.clicked() }
        Rectangle {
            visible: si.ejectable
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            width: 28; height: 28; radius: 9
            color: eh.hovered ? Theme.fillHover : "transparent"
            Text { anchors.centerIn: parent; text: String.fromCodePoint(0xf01ea); font.family: Theme.symbols; font.pixelSize: Theme.px(15); color: Theme.muted }
            HoverHandler { id: eh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: si.ejected() }
        }
    }
    component ToolBtn: Rectangle {
        id: tb
        property int icon
        property string label: ""
        property string tip: ""
        property bool enabled2: true
        signal clicked()
        width: label ? tbRow.implicitWidth + 24 : 36; height: 36; radius: 11
        color: th.hovered && enabled2 ? Theme.fillHover : Theme.fill
        border.width: 1; border.color: Theme.glassLine
        opacity: enabled2 ? 1 : 0.4
        Row {
            id: tbRow
            anchors.centerIn: parent
            spacing: 4
            Text { text: String.fromCodePoint(tb.icon); font.family: Theme.symbols; font.pixelSize: Theme.px(16); color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Text { visible: tb.label !== ""; text: Tr.t(tb.label); font.family: Theme.font; font.pixelSize: Theme.px(13); color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
        }
        HoverHandler { id: th; cursorShape: tb.enabled2 ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { onTapped: if (tb.enabled2) tb.clicked() }
        ToolTipText { visible: th.hovered && tb.tip !== ""; text: Tr.t(tb.tip) }
    }
    component ToolTipText: Rectangle {
        property alias text: tt.text
        y: parent.height + 6; anchors.horizontalCenter: parent.horizontalCenter
        width: tt.implicitWidth + 16; height: 26; radius: 8; z: 10
        color: Theme.glassPanel; border.width: 1; border.color: Theme.glassLine
        Text { id: tt; anchors.centerIn: parent; font.family: Theme.font; font.pixelSize: Theme.px(12); color: Theme.text }
    }
}
