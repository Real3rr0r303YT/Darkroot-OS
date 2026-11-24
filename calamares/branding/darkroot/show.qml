// Darkroot OS - Calamares installation slideshow
import QtQuick 2.15
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() { presentation.goToNextSlide() }
    Timer { id: advance; interval: 9000; running: presentation.activatedInCalamares; repeat: true; onTriggered: nextSlide() }

    Rectangle { anchors.fill: parent; color: "#0b0b12"; z: -1 }

    component DarkSlide: Slide {
        property string eyebrow
        property string title
        property string body
        property color accent: "#8b5cf6"
        property string fontFamily: "Inter"
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.78
            spacing: 16
            Image { source: "logo.png"; width: 72; height: 72; anchors.horizontalCenter: parent.horizontalCenter; smooth: true }
            Text { text: eyebrow; color: accent; font.family: "JetBrains Mono"; font.pixelSize: 13; font.letterSpacing: 2; anchors.horizontalCenter: parent.horizontalCenter }
            Text { text: title; color: "#f5f5f7"; font.family: fontFamily; font.pixelSize: 34; font.bold: true; wrapMode: Text.WordWrap; width: parent.width; horizontalAlignment: Text.AlignHCenter }
            Text { text: body; color: "#9a9ab0"; font.family: fontFamily; font.pixelSize: 16; lineHeight: 1.4; wrapMode: Text.WordWrap; width: parent.width; horizontalAlignment: Text.AlignHCenter }
        }
    }

    DarkSlide { eyebrow: "WELCOME"; title: "Gentoo power. Apple calm."; body: "Darkroot OS is being installed. Grab a coffee - packages come from Gentoo's binary host, so this is quick." }
    DarkSlide { eyebrow: "DARKROOT RUNIT"; title: "Boots in seconds"; body: "Darkroot uses its own runit init. Manage services with dr-sv: dr-sv list, sudo dr-sv enable bluetoothd." }
    DarkSlide { eyebrow: "DARKROOT SHELL"; title: "Hyprland keys"; body: "SUPER+Return terminal · SUPER+Space search · SUPER+Q close · SUPER+1..9 workspaces · SUPER+T switch Apple/Hacker look." }
    DarkSlide { eyebrow: "READY TO CODE"; title: "VS Code + Claude Code"; body: "VS Code is preinstalled. Claude Code and Spicetify are set up by the welcome assistant on your first login." }
    DarkSlide { eyebrow: "// HACKER_MODE"; title: "root@darkroot:~#"; accent: "#00ff9c"; fontFamily: "JetBrains Mono"; body: "Enable it any time with darkroot-hacker --install, and switch looks with darkroot-theme hacker." }
}
