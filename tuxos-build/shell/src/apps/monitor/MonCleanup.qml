import QtQuick
import qs.theme
import qs.components

// Cleanup (SPEC system care #11): one click, with what each part frees.
Column {
    spacing: 16
    PageHeader { title: Tr.t("Cleanup"); description: Tr.t("Free space in one click. Nothing you made is touched; Trash only if it is ticked.") }
    CleanupCard { width: parent.width }
}
