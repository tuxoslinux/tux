pragma Singleton

import QtQuick
import Quickshell
import qs.theme

// The shell's own messages, shown like notifications (top right) but never
// kept in the history: Do not disturb on/off, "While you were away", drive
// plugged in, long command finished, warnings, boot time.
// show(title, body, icon, onClick, buttons[{ text, run, primary }], timeoutMs, imageUrl)
Singleton {
    id: t

    property var list: []
    property int nextId: 1

    function show(title, body, icon, onClick, buttons, timeout, image) {
        const toast = { id: nextId++, title: title, body: body || "", icon: icon || Icons.informationOutline,
                        onClick: onClick || null, buttons: buttons || [], timeout: timeout === undefined ? 5000 : timeout, at: Date.now(), image: image || "" };
        list = [toast].concat(list).slice(0, 4);
        return toast.id;
    }
    function drop(id) { list = list.filter(x => x.id !== id); }
    // extra lines a toast shows while hovered
    function setMore(id, text) { list = list.map(x => x.id === id ? Object.assign({}, x, { more: text }) : x); }
}
