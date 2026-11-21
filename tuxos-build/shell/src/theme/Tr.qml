pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Translations (SPEC: English + Bulgarian, all text translatable). Every
// visible string goes through Tr.t("English text"); with Language set to
// Bulgarian (Settings > Language & region, saved as "language" in
// ~/.config/tuxos/shell.json) it comes from i18n/<lang>.json, else the
// English text is used as is. Missing entries fall back to English.
Singleton {
    id: tr

    readonly property string lang: Theme.user.language || "en"
    property var dict: ({})
    FileView {
        path: tr.lang === "en" ? "" : Qt.resolvedUrl("../i18n/" + tr.lang + ".json").toString().replace("file://", "")
        printErrors: false
        onLoaded: { try { tr.dict = JSON.parse(text()); } catch (e) { tr.dict = {}; } }
        onPathChanged: if (path === "") tr.dict = {}
    }
    function t(s) {
        if (lang === "en") return s;
        const d = dict[s];
        return d !== undefined && d !== "" ? d : s;
    }
    // dates with day / month names in the chosen language
    readonly property var locale: Qt.locale(lang === "bg" ? "bg_BG" : "en_GB")
    function date(d, fmt) { return (d instanceof Date ? d : new Date(d)).toLocaleString(locale, fmt); }
    // "{n} apps" style: t() then fill the {name} slots
    function f(s, args) {
        let out = t(s);
        for (const k in args) out = out.split("{" + k + "}").join(args[k]);
        return out;
    }
}
