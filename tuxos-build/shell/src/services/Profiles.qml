pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Power profile helper (focus modes, smart power on laptops, launcher).
Singleton {
    function set(name) {
        if (name === "performance" && PowerProfiles.hasPerformanceProfile) PowerProfiles.profile = PowerProfile.Performance;
        else if (name === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver;
        else if (name === "balanced") PowerProfiles.profile = PowerProfile.Balanced;
    }
    readonly property string current: PowerProfiles.profile === PowerProfile.Performance ? "performance"
        : PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver" : "balanced"
}
