import QtQuick

// Windows XP's "Turn off computer" dialog: the three round icon buttons with
// Stand By, Turn Off and Restart under them.
Item {
  id: dialog

  property string title: "Turn off computer"
  property var buttons: []

  signal chosen(string action)

  Rectangle {
    anchors.fill: parent
    color: "#ece9d8"
    border.color: "#0b3d91"
    border.width: 1

    // Title bar with the XP blue gradient and the close button.
    Rectangle {
      id: titleBar
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 26

      gradient: Gradient {
        GradientStop { position: 0.0; color: "#0054e3" }
        GradientStop { position: 1.0; color: "#3f8cf3" }
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: dialog.title
        color: "#ffffff"
        font.family: "Tahoma"
        font.pixelSize: 11
        font.bold: true
        style: Text.Raised
        styleColor: "#0b3d91"
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 18
        color: closeHover.hovered ? "#e8a33d" : "#d0483a"
        border.color: "#ffffff"
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "✕"
          color: "#ffffff"
          font.pixelSize: 11
          font.bold: true
        }

        HoverHandler { id: closeHover }
        MouseArea {
          anchors.fill: parent
          onClicked: dialog.chosen("")
        }
      }
    }

    Column {
      anchors.top: titleBar.bottom
      anchors.topMargin: 12
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: 10

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "What do you want the computer to do?"
        color: "#000000"
        font.family: "Tahoma"
        font.pixelSize: 11
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Repeater {
          model: dialog.buttons

          delegate: Column {
            required property var modelData
            width: 84
            spacing: 4

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              width: 54
              height: 54
              radius: 4
              color: buttonHover.hovered ? "#fff3c8" : "#ece9d8"
              border.color: buttonHover.hovered ? "#e8a33d" : "#adb2b2"
              border.width: 1

              XpIcon {
                anchors.centerIn: parent
                size: 40
                name: String(modelData.icon || "power-off")
              }
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: String(modelData.label || "")
              color: "#000000"
              font.family: "Tahoma"
              font.pixelSize: 11
            }

            HoverHandler { id: buttonHover }
            MouseArea {
              anchors.fill: parent
              onClicked: dialog.chosen(String(modelData.action || ""))
            }
          }
        }
      }
    }
  }
}
