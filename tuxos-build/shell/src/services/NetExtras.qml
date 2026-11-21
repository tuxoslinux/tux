pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// VPN connections and private DNS for the status droplet (NetworkManager
// through nmcli; read only when the droplet opens).
//   VPN: WireGuard / OpenVPN connections imported in Settings, up / down.
//   Private DNS: the active connection uses AdGuard DNS (blocks ads and
//   trackers) instead of the network's DNS; off = back to automatic.
Singleton {
    id: ne

    property var vpns: []            // [{ name, active }]
    property bool privateDns: false
    property string activeConn: ""
    readonly property string dnsServers: "94.140.14.14 94.140.15.15"

    Process {
        id: read
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE,ACTIVE connection show; echo ---; c=$(nmcli -t -f NAME,DEVICE connection show --active | grep -v ':lo$' | grep -v -i 'wireguard\\|vpn' | head -1 | cut -d: -f1); echo \"$c\"; nmcli -g ipv4.dns,ipv4.ignore-auto-dns connection show \"$c\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [a, b] = text.split("---\n");
                ne.vpns = a.split("\n").filter(l => /:(wireguard|vpn):/.test(l)).map(l => { const p = l.split(":"); return { name: p[0], active: p[2] === "yes" }; });
                const rest = (b || "").split("\n");
                ne.activeConn = rest[0] || "";
                ne.privateDns = (rest[1] || "").indexOf("94.140.14.14") !== -1;
            }
        }
    }
    function refresh() { if (!read.running) read.running = true; }
    function toggleVpn(v) { Quickshell.execDetached(["nmcli", "connection", v.active ? "down" : "up", v.name]); later.restart(); }
    function togglePrivateDns() {
        if (!activeConn) return;
        const on = !privateDns;
        Quickshell.execDetached(["sh", "-c", on
            ? `nmcli connection modify "$1" ipv4.dns "${dnsServers}" ipv4.ignore-auto-dns yes && nmcli connection up "$1"`
            : `nmcli connection modify "$1" ipv4.dns "" ipv4.ignore-auto-dns no && nmcli connection up "$1"`, "sh", activeConn]);
        privateDns = on;
        later.restart();
    }
    Timer { id: later; interval: 2500; onTriggered: ne.refresh() }
}
