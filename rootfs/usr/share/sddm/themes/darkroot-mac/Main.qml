// Darkroot Mac - macOS-inspired SDDM login (design: Figma "Login - Apple")
import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0b0b12"

    readonly property color accent: config.accent ? config.accent : "#8b5cf6"
    readonly property string fontName: config.font ? config.font : "Inter"
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    // ---------- background ----------
    Image {
        id: bg
        anchors.fill: parent
        source: config.background ? config.background : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
    }
    Rectangle {
        anchors.fill: parent
        visible: bg.status !== Image.Ready
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1b1036" }
            GradientStop { position: 0.45; color: "#3a1a5e" }
            GradientStop { position: 0.75; color: "#1d2c5e" }
            GradientStop { position: 1.0; color: "#0a1730" }
        }
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: 0.18 }

    // ---------- clock ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.08
        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ebffffff"
            font.family: root.fontName
            font.pixelSize: 26
            font.weight: Font.Medium
        }
        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#f2ffffff"
            font.family: root.fontName
            font.pixelSize: 110
            font.weight: Font.DemiBold
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            timeText.text = Qt.formatTime(now, "HH:mm")
            dateText.text = Qt.formatDate(now, "dddd, d MMMM")
        }
    }

    // hidden list that exposes the selected user's name
    ListView {
        id: users
        width: 1; height: 1; opacity: 0
        model: userModel
        currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
        delegate: Item {
            width: 1; height: 1
            property string uname: model.name
            property string rname: model.realName
        }
    }
    readonly property string userName: users.currentItem ? users.currentItem.uname : userModel.lastUser
    readonly property string displayName: users.currentItem && users.currentItem.rname !== ""
                                          ? users.currentItem.rname : userName

    function doLogin() {
        errorText.text = ""
        sddm.login(root.userName, password.text, root.sessionIndex)
    }

    // ---------- user + password ----------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.60
        spacing: 14

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96; height: 96; radius: 48
            color: "#33ffffff"
            border.color: "#55ffffff"; border.width: 1
            Text {
                anchors.centerIn: parent
                text: root.displayName.length > 0 ? root.displayName.charAt(0).toUpperCase() : "?"
                color: "white"
                font.family: root.fontName
                font.pixelSize: 42
                font.weight: Font.Medium
            }
            MouseArea {   // click to switch user
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: users.count > 1
                onClicked: { users.currentIndex = (users.currentIndex + 1) % users.count; password.text = ""; password.forceActiveFocus() }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.displayName
            color: "white"
            font.family: root.fontName
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 260; height: 36
            transform: Translate { id: shake; x: 0 }

            TextField {
                id: password
                anchors.fill: parent
                echoMode: TextInput.Password
                placeholderText: "Enter Password"
                placeholderTextColor: "#b8ffffff"
                color: "white"
                font.family: root.fontName
                font.pixelSize: 14
                leftPadding: 16
                rightPadding: 40
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                background: Rectangle {
                    radius: 18
                    color: "#33ffffff"
                    border.color: password.activeFocus ? "#88ffffff" : "#44ffffff"
                    border.width: 1
                }
                onAccepted: root.doLogin()
                Keys.onEscapePressed: text = ""
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 26; height: 26; radius: 13
                visible: password.text.length > 0
                color: arrowArea.pressed ? root.accent : "#55ffffff"
                Text { anchors.centerIn: parent; text: "→"; color: "white"; font.pixelSize: 15; font.bold: true }
                MouseArea { id: arrowArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
            }
        }

        Text {
            id: errorText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ffd0d0"
            font.family: root.fontName
            font.pixelSize: 13
            text: keyboard.capsLock ? "Caps Lock is on" : ""
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shake; property: "x"; to: -14; duration: 50 }
        NumberAnimation { target: shake; property: "x"; to: 14; duration: 70 }
        NumberAnimation { target: shake; property: "x"; to: -9; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: 9; duration: 60 }
        NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            errorText.text = "Incorrect password"
            shakeAnim.start()
            password.forceActiveFocus()
        }
    }

    // ---------- bottom bar ----------
    component PowerButton: Column {
        property string icon
        property string label
        signal activated()
        spacing: 6
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44; height: 44; radius: 22
            color: ma.containsMouse ? "#55ffffff" : "#2affffff"
            Behavior on color { ColorAnimation { duration: 120 } }
            Text { anchors.centerIn: parent; text: icon; color: "white"; font.pixelSize: 20 }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: activated() }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: label; color: "#ddffffff"; font.family: root.fontName; font.pixelSize: 12
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        spacing: 36
        PowerButton { icon: "☾"; label: "Sleep"; visible: sddm.canSuspend; onActivated: sddm.suspend() }
        PowerButton { icon: "⟳"; label: "Restart"; visible: sddm.canReboot; onActivated: sddm.reboot() }
        PowerButton { icon: "⏻"; label: "Shut Down"; visible: sddm.canPowerOff; onActivated: sddm.powerOff() }
    }

    ComboBox {
        id: sessionBox
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 30
        width: 240
        model: sessionModel
        textRole: "name"
        currentIndex: root.sessionIndex
        onActivated: root.sessionIndex = currentIndex
        font.family: root.fontName
        contentItem: Text {
            leftPadding: 14
            text: sessionBox.displayText
            color: "white"
            font: sessionBox.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle { radius: 16; color: "#2affffff"; border.color: "#44ffffff"; implicitHeight: 32 }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 30
        spacing: 8
        Image { source: "logo.svg"; width: 18; height: 18; sourceSize.width: 36; sourceSize.height: 36; anchors.verticalCenter: parent.verticalCenter }
        Text { text: "Darkroot OS"; color: "#88ffffff"; font.family: root.fontName; font.pixelSize: 13; font.weight: Font.Medium }
    }

    Component.onCompleted: password.forceActiveFocus()
}
