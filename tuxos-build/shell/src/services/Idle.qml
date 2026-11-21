pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

// The screen turns off and the PC sleeps after a while without input
// (Settings > Power): screen off after 10 min, sleep on battery after
// 20 min, never on AC by default. Apps that ask the compositor to stay awake
// (video, games) hold both off. Big downloads (Steam, system updates, the
// Store, browsers) hold sleep off too (SPEC round 8 #12); when they finish
// while the PC is still idle, it sleeps then.
Singleton {
    id: idle

    readonly property int sleepMinutes: SmartPower.onBattery ? Prefs.sleepBattery : Prefs.sleepAc
    readonly property bool downloading: Activities.bigDownload

    // an IdleMonitor keeps the timeout it was made with: a new one for each
    // setting (Instantiator remakes its delegate when the model changes)
    property bool screenIsIdle: false
    property bool sleepIsIdle: false
    Instantiator {
        model: Prefs.screenOffMinutes > 0 && !Shell.live ? [Prefs.screenOffMinutes] : []
        delegate: IdleMonitor {
            required property int modelData
            timeout: modelData * 60
            respectInhibitors: true
            onIsIdleChanged: {
                idle.screenIsIdle = isIdle;
                Shell.dispatch(`hl.dsp.dpms({ action = "${isIdle ? "off" : "on"}" })`, isIdle ? "dpms off" : "dpms on");
            }
        }
    }
    Instantiator {
        model: idle.sleepMinutes > 0 && !Shell.live ? [idle.sleepMinutes] : []
        delegate: IdleMonitor {
            required property int modelData
            timeout: modelData * 60
            respectInhibitors: true
            onIsIdleChanged: { idle.sleepIsIdle = isIdle; if (isIdle) idle.trySleep(); }
        }
    }
    onDownloadingChanged: if (!downloading && sleepIsIdle) trySleep()
    function trySleep() {
        if (idle.sleepMinutes <= 0 || !sleepIsIdle) return;
        if (downloading || Notifs.gameRunning || Recorder.recording) return;   // later, when that ends
        Power.suspend();
    }
}
