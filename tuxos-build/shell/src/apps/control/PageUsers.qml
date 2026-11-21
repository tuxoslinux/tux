import QtQuick
import Quickshell
import QtQuick.Dialogs
import qs.theme
import qs.components
import qs.services

// Users: your name, picture (login screen) and password.
Column {
    id: page
    spacing: 16
    PageHeader { title: Tr.t("Users"); description: Tr.t("Your account on this PC.") }
    readonly property string user: Quickshell.env("USER")
    SettingCard {
        SettingRow { title: Tr.t("Name"); description: Tr.t("Used in greetings")
            Rectangle { width: 220; height: 34; radius: 10; color: Theme.ink(0.05); border.width: 1; border.color: Theme.glassLine
                TextInput { id: nm; anchors { fill: parent; leftMargin: 12; rightMargin: 12 } verticalAlignment: TextInput.AlignVCenter; text: Prefs.userName
                    font.family: Theme.font; font.pixelSize: Theme.px(14); color: Theme.text; clip: true; onEditingFinished: Prefs.userName = text
                    Text { visible: nm.text === ""; text: page.user; font: nm.font; color: Theme.dim } } } }
        SettingRow { title: Tr.t("Picture"); description: Tr.t("Shown on the login screen"); Btn { text: Tr.t("Choose..."); onClicked: pic.open() } }
        SettingRow { title: Tr.t("Password"); last: true; Btn { text: Tr.t("Change..."); onClicked: Quickshell.execDetached(["kitty", "--title", "Change password", "sh", "-c", "passwd; read -p 'Enter closes' x"]) } }
    }
    FileDialog {
        id: pic
        title: Tr.t("Your picture")
        nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: Quickshell.execDetached(["sh", "-c", "pkexec \"$@\" || exit 1", "sh", "sh", "-c", "install -Dm644 \"$1\" \"/var/lib/AccountsService/icons/$2\"", "sh", decodeURIComponent(selectedFile.toString().replace("file://", "")), page.user])
    }
}
