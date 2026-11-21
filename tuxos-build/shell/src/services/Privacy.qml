pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.theme

// Privacy indicators (SPEC round 2 #10): which apps use the microphone, the
// camera or share the screen right now, from PipeWire: streams that take
// audio in (microphone), video in from a camera, or video from the screen
// (the screen-cast portal). The bar shows an orange pill; its droplet names
// the apps and has Stop. Notifications stay hidden while the screen is shared.
Singleton {
    id: pv

    readonly property var nodes: Pipewire.nodes.values || []      // empty for a moment while PipeWire (re)connects
    PwObjectTracker { objects: pv.nodes.filter(n => n.isStream || /^xdg-desktop-portal/.test(n.name || "")) }
    // (a link group's state is only known while it is bound: without this
    // every link read as unlinked and the indicator never lit up)
    PwObjectTracker { objects: (Pipewire.linkGroups.values || []).filter(g => (g.source && g.source.isStream) || (g.target && g.target.isStream)) }

    function cls(n) { return (n.properties && n.properties["media.class"]) || ""; }
    function app(n) {
        const p = n.properties || {};
        return p["application.name"] || p["application.process.binary"] || p["node.name"] || n.name || "An app";
    }
    function pid(n) { const p = n.properties || {}; return p["application.process.id"] || ""; }

    // a stream counts while it is linked (running), not just open
    function active(n) {
        return (Pipewire.linkGroups.values || []).some(g => (g.target === n || g.source === n) && g.state === PwLinkState.Active);
    }
    readonly property var mic: nodes.filter(n => n.isStream && cls(n) === "Stream/Input/Audio" && !/cava|pavucontrol|peak/i.test(app(n)) && active(n))
    // screen sharing: a capture stream from the portal, or the portal's own
    // video source (it exists exactly while an app was given the screen)
    readonly property var screen: nodes.filter(n => (n.isStream && cls(n) === "Stream/Input/Video" && /screen|portal|xdph|hyprland/i.test(JSON.stringify(n.properties || {})) && active(n))
                                                 || (!n.isStream && cls(n) === "Video/Source" && /^xdg-desktop-portal/.test(n.name || "")))
    readonly property var camera: nodes.filter(n => n.isStream && cls(n) === "Stream/Input/Video" && screen.indexOf(n) === -1 && active(n))
    readonly property bool any: (mic.length + camera.length + screen.length) > 0

    onScreenChanged: Notifs.screenShared = screen.length > 0
    // nothing in use any more: its droplet has nothing to show
    onAnyChanged: if (!any && Shell.panel === "privacy") Shell.close()

    readonly property var list: {
        const out = [];
        for (const n of mic) out.push({ kind: "Microphone", app: app(n), pid: pid(n), node: n.id });
        for (const n of camera) out.push({ kind: "Camera", app: app(n), pid: pid(n), node: n.id });
        for (const n of screen) out.push({ kind: "Screen sharing", app: /^xdg-desktop-portal/.test(n.name || "") ? Tr.t("An app") : app(n), pid: pid(n), node: n.id });
        return out;
    }
    // Stop: ends the app's capture by closing the app's stream process
    // (native PipeWire apps keep their process id on their client, not on
    // the stream: then it is looked up from the stream's client)
    function stop(item) {
        if (item.pid) { Quickshell.execDetached(["kill", String(item.pid)]); return; }
        if (item.node === undefined) return;
        Quickshell.execDetached(["sh", "-c", "c=$(pw-dump \"$1\" | jq -r '.[0].info.props[\"client.id\"] // empty'); [ -n \"$c\" ] || exit 0; "
            + "p=$(pw-dump \"$c\" | jq -r '.[0].info.props | (.[\"application.process.id\"] // .[\"pipewire.sec.pid\"] // empty)'); [ -n \"$p\" ] && kill \"$p\"", "sh", String(item.node)]);
    }
}
