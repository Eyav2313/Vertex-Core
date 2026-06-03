import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#000000"

    property bool bootDone: false
    property bool loginVisible: false
    property bool customizeVisible: false
    property bool loginError: false
    property int shakeOffset: 0
    property int hintIndex: 0
    property string selectedFont: config.font
    property string backgroundSource: config.background
    readonly property var hints: ["Click anywhere to unlock", "Hold to customize"]

    function refreshClock() {
        var now = new Date()
        timeText.text = Qt.formatTime(now, "hh:mm")
        dateText.text = Qt.formatDate(now, "dddd, MMM d")
    }

    function doLogin() {
        sddm.login(userBox.currentText, passwordBox.text, sessionBox.currentIndex)
    }

    Timer {
        interval: 3200
        running: true
        repeat: false
        onTriggered: root.bootDone = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshClock()
    }

    Timer {
        interval: 4000
        running: root.bootDone && !root.loginVisible && !root.customizeVisible
        repeat: true
        onTriggered: root.hintIndex = (root.hintIndex + 1) % root.hints.length
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.backgroundSource
        fillMode: Image.PreserveAspectCrop
        opacity: root.bootDone ? 1 : 0
        scale: root.loginVisible || root.customizeVisible ? 1.05 : (root.bootDone ? 1 : 1.1)

        Behavior on opacity { NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 1200; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        color: root.loginVisible || root.customizeVisible ? "#99000000" : "#22000000"
        opacity: root.bootDone ? 1 : 0
        Behavior on color { ColorAnimation { duration: 550; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.bootDone
        onClicked: {
            if (!root.customizeVisible && !root.loginVisible) {
                root.loginVisible = true
                passwordBox.forceActiveFocus()
            }
        }
        onPressAndHold: {
            if (!root.loginVisible) {
                root.customizeVisible = true
            }
        }
    }

    Item {
        id: island
        width: 160
        height: 36
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.bootDone ? 1 : 0
        z: 20

        Behavior on opacity { NumberAnimation { duration: 700 } }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: "#000000"
            border.width: 1
            border.color: "#22FFFFFF"
        }

        Item {
            id: lockIcon
            width: 18
            height: 18
            anchors.left: parent.left
            anchors.leftMargin: 15
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                x: 4
                y: 1
                width: 10
                height: 10
                radius: 5
                color: "transparent"
                border.width: 2
                border.color: "#FFFFFFFF"
            }

            Rectangle {
                x: 2
                y: 8
                width: 14
                height: 10
                radius: 3
                color: "#FFFFFFFF"
            }
        }
    }

    Column {
        id: clockBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(96, parent.height * 0.12)
        spacing: 5
        opacity: root.bootDone && !root.loginVisible ? 1 : 0
        z: 10

        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#FFFFFFFF"
            font.family: root.selectedFont
            font.pixelSize: 24
            font.weight: Font.Bold
        }

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#FFFFFFFF"
            font.family: root.selectedFont
            font.pixelSize: 150
            font.weight: Font.Black
            lineHeight: 0.86
        }
    }

    Column {
        id: bottomShelf
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 25
        spacing: 15
        opacity: root.bootDone && !root.loginVisible && !root.customizeVisible ? 1 : 0
        z: 10

        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hints[root.hintIndex]
            color: "#B3FFFFFF"
            font.family: root.selectedFont
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Rectangle {
            width: 130
            height: 5
            radius: 3
            color: "#55FFFFFF"
        }
    }

    Item {
        id: loginModule
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.loginVisible ? 1 : 0
        z: 100

        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors.centerIn: parent
            spacing: 16

            Rectangle {
                width: 78
                height: 78
                radius: 39
                color: "#1FFFFFFF"
                border.width: 1
                border.color: "#26FFFFFF"
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    anchors.centerIn: parent
                    width: 52
                    height: 52
                    source: config.logo
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
            }

            ComboBox {
                id: userBox
                width: 260
                model: userModel
                textRole: "name"
                visible: count > 1
                font.family: root.selectedFont
            }

            ComboBox {
                id: sessionBox
                width: 260
                model: sessionModel
                textRole: "name"
                visible: false
            }

            Rectangle {
                id: passWrap
                width: 318
                height: 52
                radius: 26
                color: root.loginError ? "#33FF4D4D" : "#26FFFFFF"
                border.width: 1
                border.color: root.loginError ? "#FFFF4D4D" : "#1AFFFFFF"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.shakeOffset

                PasswordBox {
                    id: passwordBox
                    anchors.left: parent.left
                    anchors.right: unlockButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 20
                    anchors.rightMargin: 10
                    height: 36
                    placeholderText: "Password"
                    font.family: root.selectedFont
                    font.pixelSize: 14
                    color: "#FFFFFFFF"
                    focus: root.loginVisible
                    onAccepted: root.doLogin()
                }

                Rectangle {
                    id: unlockButton
                    width: 34
                    height: 34
                    radius: 17
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#FFFFFFFF"

                    Text {
                        anchors.centerIn: parent
                        text: ">"
                        color: "#000000"
                        font.family: root.selectedFont
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.doLogin()
                    }
                }
            }

            Text {
                text: "Cancel"
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#66FFFFFF"
                font.family: root.selectedFont
                font.pixelSize: 13

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.loginVisible = false
                        passwordBox.text = ""
                    }
                }
            }
        }
    }

    Item {
        id: customizeOverlay
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.customizeVisible ? 1 : 0
        z: 120

        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: customWindow
            width: 380
            height: 430
            radius: 40
            anchors.centerIn: parent
            color: "#0DFFFFFF"
            border.width: 1
            border.color: "#1AFFFFFF"

            Column {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 16

                Text {
                    text: "Appearance"
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#FFFFFFFF"
                    font.family: root.selectedFont
                    font.pixelSize: 26
                    font.weight: Font.Light
                }

                Text {
                    text: "TIME TRANSPARENCY"
                    color: "#80FFFFFF"
                    font.family: root.selectedFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    topPadding: 8
                }

                Slider {
                    width: parent.width
                    from: 0.1
                    to: 1
                    value: clockBlock.opacity
                    onMoved: clockBlock.opacity = value
                }

                Text {
                    text: "WALLPAPERS"
                    color: "#80FFFFFF"
                    font.family: root.selectedFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                Row {
                    spacing: 10
                    Repeater {
                        model: ["Alpine", "Night", "Canyon", "Forest"]
                        delegate: Button {
                            text: modelData
                            onClicked: root.backgroundSource = config.background
                        }
                    }
                }

                Text {
                    text: "CLOCK FONTS"
                    color: "#80FFFFFF"
                    font.family: root.selectedFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                Row {
                    spacing: 10
                    Repeater {
                        model: ["Inter", "Noto Sans", "Sans"]
                        delegate: Button {
                            text: modelData
                            onClicked: root.selectedFont = modelData
                        }
                    }
                }

                Button {
                    width: parent.width
                    height: 48
                    text: "Done"
                    onClicked: root.customizeVisible = false
                }
            }
        }
    }

    Rectangle {
        id: bootScreen
        anchors.fill: parent
        color: "#000000"
        opacity: root.bootDone ? 0 : 1
        visible: opacity > 0
        z: 10000

        Behavior on opacity { NumberAnimation { duration: 1000; easing.type: Easing.OutCubic } }

        Item {
            anchors.centerIn: parent
            width: 180
            height: 180
            clip: true

            Image {
                anchors.fill: parent
                source: config.logo
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Rectangle {
                id: bootShine
                width: 58
                height: 300
                y: -60
                color: "#99FFFFFF"
                opacity: 0.0
                rotation: 18

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    PropertyAction { value: -130 }
                    PauseAnimation { duration: 450 }
                    ParallelAnimation {
                        NumberAnimation { to: 260; duration: 1550; easing.type: Easing.OutCubic }
                        SequentialAnimation {
                            NumberAnimation { target: bootShine; property: "opacity"; to: 0.0; duration: 1 }
                            NumberAnimation { target: bootShine; property: "opacity"; to: 0.65; duration: 280 }
                            NumberAnimation { target: bootShine; property: "opacity"; to: 0.0; duration: 520 }
                        }
                    }
                    PauseAnimation { duration: 800 }
                }
            }
        }
    }

    SequentialAnimation {
        id: shake
        PropertyAnimation { target: root; property: "shakeOffset"; to: -8; duration: 55 }
        PropertyAnimation { target: root; property: "shakeOffset"; to: 8; duration: 90 }
        PropertyAnimation { target: root; property: "shakeOffset"; to: 0; duration: 55 }
    }

    Timer {
        id: clearError
        interval: 500
        repeat: false
        onTriggered: root.loginError = false
    }

    Connections {
        target: sddm
        ignoreUnknownSignals: true
        function onLoginFailed() {
            root.loginError = true
            passwordBox.text = ""
            shake.restart()
            clearError.restart()
            passwordBox.forceActiveFocus()
        }
    }
}
