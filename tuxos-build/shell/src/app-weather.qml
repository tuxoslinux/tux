//@ pragma UseQApplication
//@ pragma AppId tuxos-weather
import QtQuick
import Quickshell
import qs.apps.weather

// TuxOS Weather, started by `tuxos-app weather` (and from the clock droplet).
ShellRoot {
    WeatherApp {}
}
