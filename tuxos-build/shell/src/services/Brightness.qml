pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness through brightnessctl (laptop backlights). PCs without a
// backlight report available = false, and the shell hides the slider
// (SPEC: missing hardware hides its UI). External monitors over DDC/CI come
// later in this service.
Singleton {
    id: bright
    property bool available: false
    property real value: 0          // 0..1

    function set(v) {
        v = Math.max(0.01, Math.min(1, v));
        value = v;
        setter.command = ["brightnessctl", "-q", "set", Math.round(v * 100) + "%"];
        setter.running = true;
    }
    function refresh() { reader.running = true; }

    Process {
        id: reader
        // -m: "device,class,current,percent%,max"
        command: ["sh", "-c", "brightnessctl -m -c backlight info 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(",");
                if (parts.length >= 5) {
                    bright.available = true;
                    bright.value = parseInt(parts[2]) / Math.max(1, parseInt(parts[4]));
                } else {
                    bright.available = false;
                }
            }
        }
    }
    Process { id: setter }
}
