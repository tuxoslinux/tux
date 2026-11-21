import QtQuick
import QtMultimedia

// A video wallpaper: muted, looping, filling the screen; paused while a
// game or full-screen app runs, on battery and while locked. Loaded only
// when a video is the wallpaper (Qt Multimedia stays out of the shell
// otherwise).
Item {
    id: lv
    property string file: ""
    property bool paused: false
    MediaPlayer {
        id: mp
        source: lv.file ? "file://" + lv.file : ""
        loops: MediaPlayer.Infinite
        videoOutput: out
        audioOutput: null
        onSourceChanged: if (!lv.paused) play()
        Component.onCompleted: if (!lv.paused) play()
    }
    onPausedChanged: paused ? mp.pause() : mp.play()
    VideoOutput { id: out; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectCrop }
}
