import QtQuick

// One application row, used by the Start menu's search results.
Item {
  id: appItem

  required property string appId
  required property string appLabel
  required property string appIcon

  readonly property int rowHeight: 22

  signal activated(string id)

  implicitHeight: rowHeight
  height: rowHeight

  Rectangle {
    anchors.fill: parent
    color: appHover.hovered ? "#316ac5" : "transparent"
  }

  XpIcon {
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    size: 16
    visible: appItem.appIcon.length === 0
    name: "all-programs"
  }

  Image {
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    width: 16
    height: 16
    source: appItem.appIcon
    visible: appItem.appIcon.length > 0
    sourceSize.width: 16
    sourceSize.height: 16
    smooth: true
  }

  Text {
    anchors.left: parent.left
    anchors.leftMargin: 28
    anchors.right: parent.right
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: appItem.appLabel
    color: appHover.hovered ? "#ffffff" : "#000000"
    font.family: "Tahoma"
    font.pixelSize: 11
    elide: Text.ElideRight
  }

  HoverHandler { id: appHover }
  MouseArea {
    anchors.fill: parent
    onClicked: appItem.activated(appItem.appId)
  }
}
