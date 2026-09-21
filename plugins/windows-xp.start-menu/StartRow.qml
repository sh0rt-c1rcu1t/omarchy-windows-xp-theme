import QtQuick

// One row of the Windows XP Start menu.
//
// The row owns its own submenu fly-out: XP folds a submenu out of the row that
// spawned it, so anchoring the fly-out to the row keeps it attached while the
// menu is repositioned.
Item {
  id: rowItem

  required property var row
  // Windows XP Start menu metrics.
  readonly property int rowHeight: 22
  readonly property int rowFontSize: 11
  readonly property color hoverBlue: "#316ac5"
  readonly property color textDark: "#000000"
  readonly property color linkBlue: "#003399"
  readonly property string menuFont: "Tahoma"

  property bool nested: false
  property bool linkStyle: false

  signal activated(var rowData, real sceneY)

  implicitHeight: rowHeight
  height: rowHeight

  readonly property bool hasFlyout: !!(rowItem.row && rowItem.row.menu)
  readonly property bool hovered: rowHover.hovered

  Rectangle {
    anchors.fill: parent
    color: rowItem.hovered ? rowItem.hoverBlue : "transparent"
  }

  XpIcon {
    id: rowIcon
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    size: 16
    name: String(rowItem.row ? rowItem.row.icon : "")
  }

  Text {
    id: rowLabel
    anchors.left: rowIcon.right
    anchors.leftMargin: 6
    anchors.right: rowArrow.visible ? rowArrow.left : parent.right
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: String(rowItem.row ? rowItem.row.label : "")
    color: rowItem.hovered ? "#ffffff" : (rowItem.linkStyle ? rowItem.linkBlue : rowItem.textDark)
    font.family: rowItem.menuFont
    font.pixelSize: rowItem.rowFontSize
    font.bold: rowItem.row ? rowItem.row.bold === true : false
    elide: Text.ElideRight
  }

  Text {
    id: rowArrow
    anchors.right: parent.right
    anchors.rightMargin: 5
    anchors.verticalCenter: parent.verticalCenter
    visible: rowItem.hasFlyout
    text: "▸"
    color: rowItem.hovered ? "#ffffff" : rowItem.textDark
    font.pixelSize: 10
  }

  HoverHandler {
    id: rowHover

    onHoveredChanged: {
      if (!hovered) return
      // Entering a leaf row closes whatever fly-out was open, which is what XP
      // does when the pointer slides off a submenu row.
      if (rowItem.hasFlyout) rowItem.activated(rowItem.row, rowItem.mapToItem(null, 0, 0).y)
      else rowItem.activated(({}), -1)
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: rowItem.activated(rowItem.row, rowItem.mapToItem(null, 0, 0).y)
  }
}
