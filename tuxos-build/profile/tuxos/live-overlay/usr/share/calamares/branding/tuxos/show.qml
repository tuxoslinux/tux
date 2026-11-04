/* TuxOS installer slideshow, shown while the system is being installed. */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        id: advanceTimer
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#000000"
        }
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.8
            spacing: 24

            Image {
                source: "tuxos-logo.png"
                width: 140; height: 140
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Welcome to TuxOS"
                color: "#f4f6f8"
                font.pixelSize: 30
                font.bold: true
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: 64; height: 4; radius: 2
                color: "#f5b800"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Sit back and relax while TuxOS is installed on your computer. This only takes a few minutes."
                color: "#c8c8c8"
                font.pixelSize: 18
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#000000"
        }
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.8
            spacing: 24

            Image {
                source: "tuxos-logo.png"
                width: 140; height: 140
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Fast and lightweight"
                color: "#f4f6f8"
                font.pixelSize: 30
                font.bold: true
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: 64; height: 4; radius: 2
                color: "#f5b800"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "TuxOS uses dinit, a small and fast service manager, so your computer starts quickly and stays responsive."
                color: "#c8c8c8"
                font.pixelSize: 18
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#000000"
        }
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.8
            spacing: 24

            Image {
                source: "tuxos-logo.png"
                width: 140; height: 140
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Always up to date"
                color: "#f4f6f8"
                font.pixelSize: 30
                font.bold: true
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: 64; height: 4; radius: 2
                color: "#f5b800"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "TuxOS is a rolling release. Keep everything current with a single command: sudo pacman -Syu"
                color: "#c8c8c8"
                font.pixelSize: 18
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#000000"
        }
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.8
            spacing: 24

            Image {
                source: "tuxos-logo.png"
                width: 140; height: 140
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Join the community"
                color: "#f4f6f8"
                font.pixelSize: 30
                font.bold: true
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: 64; height: 4; radius: 2
                color: "#f5b800"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Questions or ideas? Find the TuxOS community on Discord at discord.gg/jvGzaWEB77"
                color: "#c8c8c8"
                font.pixelSize: 18
                width: parent.width
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() {
    }
}
