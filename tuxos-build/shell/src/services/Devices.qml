pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.theme

// Batteries of things around the PC (SPEC top bar): the laptop battery's
// warnings (15 % / 5 %), a gaming headset's battery through HeadsetControl
// (e.g. Logitech G PRO X 2 LIGHTSPEED; toast at 10 %), controllers and other
// UPower devices (Bluetooth mice, controllers).
Singleton {
    id: dev

    // ---- headset (HeadsetControl): checked once a minute, only if installed
    property bool headsetPresent: false
    property int headsetBattery: -1
    property bool headsetCharging: false
    property string headsetName: ""
    property bool warnedHeadset: false
    Component.onCompleted: hc.running = true
    Connections { target: Tick; function onMinute() { if (!hc.running) hc.running = true; } }
    Process {
        id: hc
        command: ["sh", "-c", "command -v headsetcontrol >/dev/null || exit 3; headsetcontrol -o json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const d = (j.devices || [])[0];
                    if (!d || !d.battery) { dev.headsetPresent = false; return; }
                    dev.headsetPresent = d.battery.status !== "BATTERY_UNAVAILABLE";
                    dev.headsetBattery = d.battery.level;
                    dev.headsetCharging = d.battery.status === "BATTERY_CHARGING";
                    dev.headsetName = d.product || d.device || "Headset";
                    if (dev.headsetPresent && !dev.headsetCharging && dev.headsetBattery >= 0 && dev.headsetBattery <= 10 && !dev.warnedHeadset) {
                        dev.warnedHeadset = true;
                        Toasts.show(`${dev.headsetName}: ${dev.headsetBattery} %`, Tr.t("Headset battery is low - plug it in soon"), Icons.batteryCharging);
                    }
                    if (dev.headsetBattery > 20) dev.warnedHeadset = false;
                } catch (e) { dev.headsetPresent = false; }
            }
        }
    }

    // ---- controllers and other battery devices (UPower)
    readonly property var gadgets: UPower.devices.values.filter(d => d.isPresent && !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower
                                                                && d.percentage > 0 && d.type !== UPowerDeviceType.Unknown)
    readonly property var controllers: gadgets.filter(d => d.type === UPowerDeviceType.GamingInput)
    function pct(d) { return Math.round(d.percentage * (d.percentage <= 1 ? 100 : 1)); }

    // ---- laptop battery warnings
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery && battery.isPresent
    readonly property int batteryPct: hasBattery ? pct(battery) : 100
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge)
    property int warned: 100
    onBatteryPctChanged: {
        if (!hasBattery || charging) { warned = 100; return; }
        if (batteryPct <= 5 && warned > 5) {
            warned = 5;
            Toasts.show(Tr.t("Battery 5 %"), Tr.t("Plug in now - the PC will sleep soon"), Icons.alertOutline, null, [], 0);
        } else if (batteryPct <= 15 && warned > 15) {
            warned = 15;
            Toasts.show(Tr.t("Battery 15 %"), Tr.t("Power saver is on. Plug in soon."), Icons.alertOutline);
            Profiles.set("power-saver");
        }
    }
    function time(sec) {
        if (!sec || sec <= 0) return "";
        const h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }
}
