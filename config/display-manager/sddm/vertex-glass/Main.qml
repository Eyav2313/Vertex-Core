import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0E1117"

    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        opacity: 0.92
    }

    Rectangle {
        anchors.fill: parent
        color: "#66080B10"
    }

    Rectangle {
        id: loginPanel
        width: Math.min(parent.width * 0.86, 420)
        height: 430
        radius: 20
        color: "#B0181C25"
        border.color: "#55FFFFFF"
        border.width: 1
        anchors.centerIn: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 34
            spacing: 18

            Text {
                text: "Vertex OS"
                color: "#F5F7FA"
                font.pixelSize: 32
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Secure session"
                color: "#AAB2C0"
                font.pixelSize: 14
                Layout.alignment: Qt.AlignHCenter
            }

            ComboBox {
                id: userBox
                model: userModel
                textRole: "name"
                Layout.fillWidth: true
                Layout.topMargin: 18
            }

            PasswordBox {
                id: passwordBox
                placeholderText: "Password"
                Layout.fillWidth: true
                focus: true
                onAccepted: sddm.login(userBox.currentText, passwordBox.text, sessionBox.currentIndex)
            }

            ComboBox {
                id: sessionBox
                model: sessionModel
                textRole: "name"
                Layout.fillWidth: true
            }

            Button {
                text: "Sign in"
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                onClicked: sddm.login(userBox.currentText, passwordBox.text, sessionBox.currentIndex)
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Button {
                    text: "Sleep"
                    onClicked: sddm.suspend()
                }

                Button {
                    text: "Restart"
                    onClicked: sddm.reboot()
                }

                Button {
                    text: "Power"
                    onClicked: sddm.powerOff()
                }
            }
        }
    }
}
