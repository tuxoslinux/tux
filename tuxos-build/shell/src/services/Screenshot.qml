pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// Screenshots (SPEC: Super + Shift + S = click for the whole screen under
// the pointer, drag for an area; Print = whole screen). Copied to the
// clipboard only, nowhere else; the image stays in RAM (/run/user) just
// long enough for the "Copy text" (OCR, English + Bulgarian) button.
Singleton {
    id: shot

    readonly property string tmp: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/tuxos-shot.png"

    Process {
        id: proc
        onExited: code => {
            if (code === 0) Sounds.play("screenshot");
            if (code === 0)
                Toasts.show(Tr.t("Screenshot copied"), Tr.t("Paste it anywhere with Ctrl + V"), Icons.monitorScreenshot, null,
                            [{ text: "Edit", primary: true, run: () => shot.edit() }, { text: "Copy text", primary: false, run: () => shot.ocr() }], 6000);
            else Toasts.show(Tr.t("Screenshot failed"), Tr.t("grim could not capture the screen"), Icons.alertOutline);
        }
    }
    function capture(args) {
        proc.command = ["sh", "-c", "grim \"$@\" \"$TUXOS_SHOT\" && wl-copy -t image/png < \"$TUXOS_SHOT\"", "sh"].concat(args);
        proc.environment = { TUXOS_SHOT: tmp };
        proc.running = true;
    }
    function full(output) { capture(output ? ["-o", output] : []); }
    function area(x, y, w, h) { capture(["-g", `${Math.round(x)},${Math.round(y)} ${Math.round(w)}x${Math.round(h)}`]); }

    // crop / draw on it (Image viewer's editor); keep a copy of this shot so a
    // newer one does not replace it while editing
    function edit() {
        const copy = tmp.replace(/\.png$/, "-" + Date.now() + ".png");
        Quickshell.execDetached(["sh", "-c", "cp -f \"$1\" \"$2\" && exec tuxos-app images --page \"edit:$2\"", "sh", tmp, copy]);
    }
    Process {
        id: ocrProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t) { Quickshell.clipboardText = t; Toasts.show(Tr.t("Text copied"), t.length > 120 ? t.slice(0, 120) + "…" : t, Icons.textIcon); }
                else Toasts.show(Tr.t("No text found"), Tr.t("The screenshot has no readable text"), Icons.textIcon);
            }
        }
    }
    function ocr() {
        ocrProc.command = ["sh", "-c", "tesseract \"$1\" - -l eng+bul 2>/dev/null || tesseract \"$1\" - 2>/dev/null", "sh", tmp];
        ocrProc.running = true;
    }
}
