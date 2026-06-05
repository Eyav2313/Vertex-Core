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
    property bool accessibilityBoost: false
    property bool loginError: false
    property int shakeOffset: 0
    property int hintIndex: 0
    property string selectedFont: config.font
    property string backgroundSource: config.background
    readonly property var hints: ["Click anywhere to unlock", "Press Enter to unlock", "Hold anywhere to personalize"]

    function refreshClock() {
        var now = new Date()
        var time = Qt.formatTime(now, "hh:mm")
        var date = Qt.formatDate(now, "dddd, MMM d")
        timeText.text = time
        dateText.text = date
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
        color: root.loginVisible || root.customizeVisible ? "#99000000" : (root.accessibilityBoost ? "#33000000" : "#22000000")
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
            color: "#D9FFFFFF"
            font.family: root.selectedFont
            font.pixelSize: 24
            font.weight: Font.Light
            style: Text.Outline
            styleColor: "#55000000"
        }

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#E0FFFFFF"
            font.family: root.selectedFont
            font.pixelSize: 142
            font.weight: Font.Light
            lineHeight: 0.86
            style: Text.Outline
            styleColor: "#66000000"
        }
    }

    Column {
        id: bottomShelf
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 25
        spacing: 10
        opacity: root.bootDone && !root.loginVisible && !root.customizeVisible ? 1 : 0
        z: 10

        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.hints[root.hintIndex]
            color: "#B3FFFFFF"
            font.family: root.selectedFont
            font.pixelSize: 12
            font.weight: Font.Normal
        }

        Rectangle {
            width: 130
            height: 5
            radius: 3
            color: "#55FFFFFF"
        }
    }

    Row {
        id: systemWidgets
        anchors.right: parent.right
        anchors.rightMargin: 34
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 30
        spacing: 15
        opacity: root.bootDone && !root.loginVisible && !root.customizeVisible ? 0.78 : 0
        z: 11

        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

        Item {
            width: 24
            height: 24

            Canvas {
                anchors.centerIn: parent
                width: 17
                height: 17
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = "#FFFFFFFF"
                    ctx.lineWidth = 1.35
                    ctx.lineCap = "round"
                    ctx.shadowColor = "rgba(0, 0, 0, 0.55)"
                    ctx.shadowBlur = 4
                    ctx.beginPath()
                    ctx.moveTo(2.2, 6.5)
                    ctx.bezierCurveTo(6.2, 3.4, 10.8, 3.4, 14.8, 6.5)
                    ctx.moveTo(5.1, 9.9)
                    ctx.bezierCurveTo(7.1, 8.4, 9.9, 8.4, 11.9, 9.9)
                    ctx.moveTo(7.6, 13)
                    ctx.bezierCurveTo(8.3, 12.6, 9, 12.6, 9.7, 13)
                    ctx.stroke()
                }
            }
        }

        Item {
            width: 30
            height: 24

            Rectangle {
                width: 21
                height: 10
                radius: 3
                color: "transparent"
                border.width: 1
                border.color: "#FFFFFFFF"
                anchors.centerIn: parent

                Rectangle {
                    width: 13
                    height: 5
                    radius: 1
                    color: "#FFFFFFFF"
                    anchors.left: parent.left
                    anchors.leftMargin: 3
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: 2
                height: 4
                radius: 1
                color: "#FFFFFFFF"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.horizontalCenter
                anchors.leftMargin: 12
            }
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
                width: 300
                height: 42
                radius: 21
                color: root.loginError ? "#33FF4D4D" : "#10FFFFFF"
                border.width: 1
                border.color: root.loginError ? "#FFFF4D4D" : "#1AFFFFFF"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.shakeOffset

                PasswordBox {
                    id: passwordBox
                    anchors.left: parent.left
                    anchors.right: unlockButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    anchors.rightMargin: 8
                    height: 30
                    placeholderText: "Password"
                    font.family: root.selectedFont
                    font.pixelSize: 13
                    color: "#FFFFFFFF"
                    focus: root.loginVisible
                    onAccepted: root.doLogin()
                }

                Rectangle {
                    id: unlockButton
                    width: 30
                    height: 30
                    radius: 15
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#E6FFFFFF"

                    Canvas {
                        anchors.centerIn: parent
                        width: 15
                        height: 15
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#E6000000"
                            ctx.lineWidth = 2
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(2, 7.5)
                            ctx.lineTo(13, 7.5)
                            ctx.moveTo(8.2, 3)
                            ctx.lineTo(13, 7.5)
                            ctx.lineTo(8.2, 12)
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.doLogin()
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                Item {
                    width: 26
                    height: 26
                    opacity: root.accessibilityBoost ? 0.95 : 0.66

                    Canvas {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#FFFFFFFF"
                            ctx.lineWidth = 1.35
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.arc(8, 3, 1.5, 0, Math.PI * 2)
                            ctx.moveTo(2.6, 6)
                            ctx.lineTo(13.4, 6)
                            ctx.moveTo(8, 6.1)
                            ctx.lineTo(8, 10)
                            ctx.moveTo(5.2, 15)
                            ctx.lineTo(8, 10)
                            ctx.lineTo(10.8, 15)
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.accessibilityBoost = !root.accessibilityBoost
                    }
                }

                Item {
                    width: 26
                    height: 26
                    opacity: 0.66

                    Canvas {
                        anchors.centerIn: parent
                        width: 17
                        height: 17
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#FFFFFFFF"
                            ctx.lineWidth = 1.35
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.moveTo(2.2, 6.5)
                            ctx.bezierCurveTo(6.2, 3.4, 10.8, 3.4, 14.8, 6.5)
                            ctx.moveTo(5.1, 9.9)
                            ctx.bezierCurveTo(7.1, 8.4, 9.9, 8.4, 11.9, 9.9)
                            ctx.moveTo(7.6, 13)
                            ctx.bezierCurveTo(8.3, 12.6, 9, 12.6, 9.7, 13)
                            ctx.stroke()
                        }
                    }
                }

                Item {
                    width: 26
                    height: 26
                    opacity: 0.66

                    Canvas {
                        anchors.centerIn: parent
                        width: 17
                        height: 17
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = "#FFFFFFFF"
                            ctx.lineWidth = 1.35
                            ctx.lineCap = "round"
                            ctx.beginPath()
                            ctx.moveTo(8.5, 2.3)
                            ctx.lineTo(8.5, 7.4)
                            ctx.moveTo(5.1, 5.2)
                            ctx.bezierCurveTo(2.7, 7.2, 2.8, 11.1, 5.4, 13.2)
                            ctx.bezierCurveTo(7.5, 14.9, 10.7, 14.9, 12.8, 13.2)
                            ctx.bezierCurveTo(15.4, 11.1, 15.5, 7.2, 13.1, 5.2)
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: sddm.powerOff()
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
            width: Math.min(520, root.width - 48)
            height: Math.min(620, root.height - 96)
            radius: 6
            anchors.centerIn: parent
            color: "#F607080B"
            border.width: 1
            border.color: "#22FFFFFF"
            clip: true

            Column {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    width: parent.width
                    height: 38
                    color: "#FF0B0C10"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Vertex Appearance"
                        color: "#C8FFFFFF"
                        font.family: root.selectedFont
                        font.pixelSize: 13
                        font.weight: Font.Normal
                    }

                    Rectangle {
                        id: closeButton
                        property bool hovered: false
                        width: 30
                        height: 30
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 15
                        color: hovered ? "#38A0A6B2" : "transparent"

                        Canvas {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.strokeStyle = "#DDFFFFFF"
                                ctx.lineWidth = 0.9
                                ctx.lineCap = "round"
                                ctx.beginPath()
                                ctx.moveTo(4.2, 4.2)
                                ctx.lineTo(11.8, 11.8)
                                ctx.moveTo(11.8, 4.2)
                                ctx.lineTo(4.2, 11.8)
                                ctx.stroke()
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: closeButton.hovered = true
                            onExited: closeButton.hovered = false
                            onClicked: root.customizeVisible = false
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: "#12FFFFFF"
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - 38

                    Column {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        Rectangle {
                            width: parent.width
                            height: 166
                            radius: 6
                            clip: true
                            color: "#111319"
                            border.width: 1
                            border.color: "#12FFFFFF"

                            Image {
                                anchors.fill: parent
                                source: root.backgroundSource
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "#44000000"
                            }

                            Column {
                                anchors.top: parent.top
                                anchors.topMargin: 18
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 1

                                Text {
                                    id: customPreviewDate
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dateText.text
                                    color: "#BFC7CBD4"
                                    font.family: root.selectedFont
                                    font.pixelSize: 8
                                    font.weight: Font.Light
                                }

                                Text {
                                    id: customPreviewTime
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: timeText.text
                                    color: "#B8FFFFFF"
                                    font.family: root.selectedFont
                                    font.pixelSize: 38
                                    font.weight: Font.Light
                                    lineHeight: 0.9
                                }
                            }

                            Rectangle {
                                width: 72
                                height: 3
                                radius: 2
                                color: "#44FFFFFF"
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 14
                            }
                        }

                        Text {
                            text: "TIME TRANSPARENCY"
                            color: "#88FFFFFF"
                            font.family: root.selectedFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
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
                            color: "#88FFFFFF"
                            font.family: root.selectedFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }

                        Row {
                            spacing: 8
                            Repeater {
                                model: ["Alpine", "Night", "Canyon", "Forest"]
                                delegate: Rectangle {
                                    width: 76
                                    height: 30
                                    radius: 6
                                    color: "#12FFFFFF"
                                    border.width: 1
                                    border.color: "#12FFFFFF"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: "#CCFFFFFF"
                                        font.family: root.selectedFont
                                        font.pixelSize: 11
                                        font.weight: Font.Normal
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.backgroundSource = config.background
                                    }
                                }
                            }
                        }

                        Text {
                            text: "CLOCK FONTS"
                            color: "#88FFFFFF"
                            font.family: root.selectedFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }

                        Row {
                            spacing: 8
                            Repeater {
                                model: ["SF Pro", "Vertex", "Manrope"]
                                delegate: Rectangle {
                                    width: 82
                                    height: 30
                                    radius: 6
                                    color: "#12FFFFFF"
                                    border.width: 1
                                    border.color: "#12FFFFFF"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: "#CCFFFFFF"
                                        font.family: root.selectedFont
                                        font.pixelSize: 11
                                        font.weight: Font.Normal
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (modelData === "SF Pro") {
                                                root.selectedFont = config.font
                                            } else if (modelData === "Vertex") {
                                                root.selectedFont = "Space Grotesk"
                                            } else {
                                                root.selectedFont = "Manrope"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
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
