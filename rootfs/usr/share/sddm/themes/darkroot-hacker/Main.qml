// Darkroot Hacker - terminal-style SDDM login (design: Figma "Login - Hacker")
import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#000000"
    focus: true

    readonly property color green: "#00ff9c"
    readonly property color text: "#c8ffd9"
    readonly property color muted: "#3faf6a"
    readonly property string mono: config.font ? config.font : "JetBrains Mono"
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property int bootSeconds: 0

    Image {
        anchors.fill: parent
        source: config.background ? config.background : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // scanlines
    Column {
        anchors.fill: parent
        Repeater {
            model: Math.ceil(root.height / 4)
            Rectangle { width: root.width; height: 4; color: "transparent"
                Rectangle { width: parent.width; height: 1; color: root.green; opacity: 0.03 } }
        }
    }

    // ---------- title with fake glow ----------
    Item {
        id: title
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.16
        width: titleText.width; height: titleText.height
        Repeater {
            model: [ [0,0,0.18], [2,0,0.12], [-2,0,0.12], [0,2,0.12], [0,-2,0.12] ]
            Text { x: modelData[0]; y: modelData[1]; opacity: modelData[2]; text: titleText.text; font: titleText.font; color: root.green }
        }
        Text {
            id: titleText
            text: "> DARKROOT" + (cursorOn ? "_" : " ")
            property bool cursorOn: true
            color: root.green
            font.family: root.mono
            font.pixelSize: 84
            font.bold: true
            font.letterSpacing: 6
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: title.bottom
        anchors.topMargin: 18
        text: "[ secure terminal session · runit · " + Qt.formatDateTime(new Date(), "yyyy-MM-dd") + " ]"
        color: root.muted
        font.family: root.mono
        font.pixelSize: 16
    }
    Timer { interval: 530; running: true; repeat: true; onTriggered: titleText.cursorOn = !titleText.cursorOn }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.bootSeconds++ }

    function doLogin() {
        status.text = "> authenticating " + userField.text + " ..."
        status.color = root.muted
        sddm.login(userField.text, password.text, root.sessionIndex)
    }

    // ---------- auth panel ----------
    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.42
        width: 640
        height: col.implicitHeight + 56
        color: "#07110b"
        border.color: Qt.rgba(0, 1, 0.61, 0.5)
        border.width: 1
        radius: 4
        transform: Translate { id: shake; x: 0 }

        // outer glow
        Rectangle { anchors.fill: parent; anchors.margins: -8; radius: 10; color: "transparent"; border.color: root.green; border.width: 8; opacity: 0.06; z: -1 }

        Column {
            id: col
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            spacing: 16

            Row {
                spacing: 12
                Text { text: "darkroot login:"; color: root.muted; font.family: root.mono; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                TextField {
                    id: userField
                    width: 360
                    text: userModel.lastUser
                    color: root.text
                    font.family: root.mono; font.pixelSize: 20; font.bold: true
                    background: Item {}
                    selectByMouse: true
                    KeyNavigation.tab: password
                    onAccepted: password.forceActiveFocus()
                }
            }
            Row {
                spacing: 12
                Text { text: "password:"; color: root.muted; font.family: root.mono; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                TextField {
                    id: password
                    width: 420
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.green
                    font.family: root.mono; font.pixelSize: 20; font.bold: true
                    background: Item {}
                    cursorVisible: true
                    KeyNavigation.tab: userField
                    onAccepted: root.doLogin()
                }
            }
            Text {
                text: "> session: " + (sessionList.currentItem ? sessionList.currentItem.sname : "?") + "   [F2]"
                color: root.muted
                font.family: root.mono; font.pixelSize: 15
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.nextSession() }
            }
            Text {
                id: status
                text: keyboard.capsLock ? "> warning: CAPS LOCK is on" : ""
                color: root.muted
                font.family: root.mono; font.pixelSize: 15
            }
        }
    }

    ListView {
        id: sessionList
        width: 1; height: 1; opacity: 0
        model: sessionModel
        currentIndex: root.sessionIndex
        delegate: Item { width: 1; height: 1; property string sname: model.name }
    }
    function nextSession() {
        if (sessionModel.rowCount() > 0) root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -12; duration: 40 }
        NumberAnimation { target: shake; property: "x"; to: 12; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: -6; duration: 50 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 40 }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            status.text = "> ACCESS DENIED"
            status.color = "#ff4d6d"
            shakeAnim.start()
            password.forceActiveFocus()
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_F2) { root.nextSession(); event.accepted = true }
        else if (event.key === Qt.Key_F10 && sddm.canReboot) { sddm.reboot(); event.accepted = true }
        else if (event.key === Qt.Key_F12 && sddm.canPowerOff) { sddm.powerOff(); event.accepted = true }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        text: "[F2] session   [F10] reboot   [F12] poweroff   ·   uptime " +
              ("0" + Math.floor(root.bootSeconds / 60)).slice(-2) + ":" + ("0" + root.bootSeconds % 60).slice(-2) +
              "   ·   darkroot os"
        color: root.muted
        font.family: root.mono
        font.pixelSize: 14
    }

    Component.onCompleted: (userField.text === "" ? userField : password).forceActiveFocus()
}
