import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Windows XP Start menu, drawn from xp-menu.json.
//
// The surface the Start button opens. It reproduces the Windows XP Start menu
// layout: the blue header with the account name, the white left column (pinned
// items, the search box, the separator, the fixed places and All Programs), the
// pale blue right column of system places, and the blue footer with Log Off and
// Turn Off Computer.
//
// Fly-out submenus are separate layer-shell surfaces anchored to the row that
// opened them, which is how Windows XP folds them out.
//
// Summoned with:
//   omarchy-shell shell summon windows-xp.start-menu
Item {
  id: root

  // Injected by the omarchy-shell host.
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property bool opened: false

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string userName: Quickshell.env("USER") || "User"
  readonly property string definitionPath: home + "/.config/omarchy/plugins/windows-xp.start-menu/xp-menu.json"

  property var definition: ({})

  readonly property var pinned: definition.pinned || []
  readonly property var below: definition.below || []
  readonly property var rightColumn: definition.right || []
  readonly property var footer: definition.footer || []
  readonly property var powerButtons: definition.powerDialog && definition.powerDialog.buttons
    ? definition.powerDialog.buttons : []
  readonly property string powerTitle: definition.powerDialog && definition.powerDialog.title
    ? definition.powerDialog.title : "Turn off computer"

  // ------------------------------------------------------------- metrics
  // Windows XP Start menu metrics at 96 DPI.
  readonly property int menuWidth: 396
  readonly property int leftWidth: 200
  readonly property int rightWidth: 196
  readonly property int headerHeight: 54
  readonly property int footerHeight: 38
  readonly property int rowHeight: 22
  readonly property int submenuWidth: 234
  readonly property int maxBodyHeight: 520
  // The search row: XP-era menus have none, so it is only present when the
  // shell handed us an application library to search.
  readonly property int searchHeight: 24

  readonly property string menuFont: "Tahoma"
  readonly property color headerTop: "#1868d8"
  readonly property color headerBottom: "#3f8cf3"
  readonly property color footerTop: "#3f8cf3"
  readonly property color footerBottom: "#1868d8"
  readonly property color panelBlue: "#d3e5fa"
  readonly property color panelBorder: "#0b3d91"
  readonly property color rowHover: "#316ac5"
  readonly property color textDark: "#000000"
  readonly property color linkBlue: "#003399"

  // --------------------------------------------------------------- state
  property bool powerOpen: false
  property string submenuId: ""
  property var submenuRows: []
  property real submenuAnchorY: 0
  property string query: ""

  readonly property bool searching: query.length > 0

  // The card is exactly as tall as its content: the body takes the taller
  // column's natural height, so no row is ever clipped. `measuredBodyHeight`
  // is a reading of the laid-out columns, not an input to them, which is what
  // keeps the two from feeding each other.
  property int measuredBodyHeight: 0
  readonly property int bodyHeight: measuredBodyHeight > 0 ? measuredBodyHeight : 140
  readonly property int menuHeight: headerHeight + footerHeight + bodyHeight + 2

  // ------------------------------------------------- plugin lifecycle
  // The shell calls open() when the plugin is summoned and close() when it is
  // hidden, so the plugin marks itself open through the same pair.
  function open(payloadJson) {
    openMenu()
    return "ok"
  }

  function close() {
    hideMenu()
  }

  // ------------------------------------------------------------- actions
  function toggle() {
    if (opened) hideMenu()
    else openMenu()
  }

  function openMenu() {
    submenuId = ""
    submenuRows = []
    query = ""
    opened = true
  }

  function hideMenu() {
    opened = false
    submenuId = ""
    submenuRows = []
  }

  function runAction(action) {
    var command = String(action || "")
    if (!command) return
    hideMenu()
    Quickshell.execDetached(["bash", "-lc", command])
  }

  // Every Start menu row routes through here: submenus fold out, `target` rows
  // borrow another row's submenu, the power row swaps in the dialog, and
  // everything else runs its command.
  function handleRow(rowData, sceneY) {
    if (!rowData || !rowData.id) {
      submenuId = ""
      submenuRows = []
      return
    }
    if (rowData.menu) {
      submenuId = String(rowData.id)
      submenuRows = rowData.menu
      submenuAnchorY = Number(sceneY)
      return
    }
    if (rowData.target) {
      var rows = rowsForTarget(rowData.target)
      if (rows.length > 0) {
        submenuId = String(rowData.target)
        submenuRows = rows
        submenuAnchorY = Number(sceneY)
        return
      }
    }
    submenuId = ""
    submenuRows = []
    if (rowData.dialog === "power") {
      hideMenu()
      powerOpen = true
      return
    }
    if (rowData.action) runAction(rowData.action)
  }

  function openFooter(rowData) {
    handleRow(rowData, headerHeight + bodyHeight - rowHeight)
  }

  // A `target` row links to the matching submenu declared elsewhere in the
  // definition (the right column's Control Panel points at the left column's).
  function rowsForTarget(target) {
    var id = String(target || "")
    for (var i = 0; i < below.length; i++)
      if (String(below[i].id) === id) return below[i].menu || []
    for (var j = 0; j < rightColumn.length; j++)
      if (String(rightColumn[j].id) === id) return rightColumn[j].menu || []
    return []
  }

  // ------------------------------------------------------ application rows
  function appLibrary() {
    return shell && shell.appLibrary ? shell.appLibrary : null
  }

  readonly property var appRows: {
    var api = appLibrary()
    if (!api) return []
    var rows = api.sortedEntries("")
    var out = []
    for (var i = 0; i < rows.length; i++) {
      var entry = rows[i].entry
      if (!entry) continue
      out.push({
        appId: String(entry.id || ""),
        appLabel: api.entryName(entry),
        appIcon: api.iconSource(entry.icon)
      })
    }
    return out
  }

  readonly property var filteredApps: {
    var needle = String(query || "").trim().toLowerCase()
    if (needle === "") return []
    var out = []
    for (var i = 0; i < appRows.length; i++) {
      if (String(appRows[i].appLabel).toLowerCase().indexOf(needle) !== -1) out.push(appRows[i])
      if (out.length >= 10) break
    }
    return out
  }

  function launchApp(appId) {
    var api = appLibrary()
    if (!api || !appId) return
    hideMenu()
    api.launch(appId, "")
  }

  // The menu sits on the taskbar, so its bottom inset is the taskbar height.
  function barHeight() {
    var barApi = shell && shell.bar ? shell.bar : null
    if (!barApi) return 30
    var size = Number(barApi.barSize || 0)
    if (!(size > 0)) return 30
    var position = String(barApi.position || "top")
    if (position === "left" || position === "right") return 0
    return size
  }

  onOpenedChanged: {
    if (opened) {
      definitionFile.reload()
      Qt.callLater(function() { searchField.forceActiveFocus() })
    }
  }

  // The definition file is JSONC so it can carry the same explanatory comments
  // the Omarchy menu extensions do. JSON.parse cannot read those, so whole-line
  // comments are removed and trailing commas tolerated first.
  function stripJsonc(raw) {
    return String(raw || "")
      .replace(/^\s*\/\/[^\n]*/gm, "")
      .replace(/,(\s*[}\]])/g, "$1")
  }

  FileView {
    id: definitionFile
    path: root.definitionPath
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        root.definition = JSON.parse(root.stripJsonc(text()))
      } catch (e) {
        console.warn("windows-xp.start-menu: cannot parse " + root.definitionPath + ": " + e)
        root.definition = ({})
      }
    }
    onLoadFailed: {
      console.warn("windows-xp.start-menu: cannot read " + root.definitionPath)
      root.definition = ({})
    }
  }

  // ------------------------------------------------------- the Start menu
  PanelWindow {
    id: menuWindow

    visible: root.opened
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    anchors { bottom: true; left: true }
    margins { bottom: root.barHeight(); left: 0 }
    implicitWidth: root.menuWidth
    implicitHeight: root.menuHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-start-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
      anchors.fill: parent
      color: "#ffffff"
      border.color: root.panelBorder
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0

        // ------------------------------------------------------- header
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.headerHeight

          gradient: Gradient {
            GradientStop { position: 0.0; color: root.headerBottom }
            GradientStop { position: 1.0; color: root.headerTop }
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            // XP shows the account picture on a white plate with a navy
            // hairline. With no picture configured we draw the initial.
            Rectangle {
              Layout.alignment: Qt.AlignVCenter
              width: 42
              height: 42
              color: "#ffffff"
              border.color: root.panelBorder
              border.width: 2

              Text {
                anchors.centerIn: parent
                text: String(root.userName).charAt(0).toUpperCase()
                color: root.headerTop
                font.family: root.menuFont
                font.pixelSize: 22
                font.bold: true
              }
            }

            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              text: root.userName
              color: "#ffffff"
              font.family: root.menuFont
              font.pixelSize: 15
              font.bold: true
              elide: Text.ElideRight
              style: Text.Raised
              styleColor: root.panelBorder
            }
          }
        }

        // --------------------------------------------------------- body
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 0

          // ------------------------------------------- left white column
          Rectangle {
            Layout.preferredWidth: root.leftWidth
            Layout.fillHeight: true
            color: "#ffffff"

            Column {
              id: leftFlow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: 4
              spacing: 0

              Repeater {
                model: root.searching ? [] : root.pinned

                delegate: StartRow {
                  required property var modelData
                  width: leftFlow.width
                  row: modelData
                  onActivated: function(rowData, sceneY) { root.handleRow(rowData, sceneY) }
                }
              }

              // The search field occupies a row of the flow; the visible input
              // is drawn by `searchField` in the window above, which is
              // positioned to land exactly on this spacer.
              Item {
                width: parent.width
                height: root.searchHeight
              }

              Repeater {
                model: root.filteredApps

                delegate: AppRow {
                  required property var modelData
                  width: leftFlow.width
                  appId: modelData.appId
                  appLabel: modelData.appLabel
                  appIcon: modelData.appIcon
                  onActivated: function(appId) { root.launchApp(appId) }
                }
              }

              // The separator XP draws above the fixed places.
              Item {
                width: parent.width
                height: root.searching ? 0 : 9

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: 6
                  anchors.right: parent.right
                  anchors.rightMargin: 6
                  height: 1
                  color: "#c8c8c8"
                }
              }

              Repeater {
                model: root.searching ? [] : root.below

                delegate: StartRow {
                  required property var modelData
                  width: leftFlow.width
                  row: modelData
                  onActivated: function(rowData, sceneY) { root.handleRow(rowData, sceneY) }
                }
              }
            }
          }

          // ---------------------------------------- right blue column
          Rectangle {
            Layout.preferredWidth: root.rightWidth
            Layout.fillHeight: true
            color: root.panelBlue

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: 1
              color: "#8fb4e8"
            }

            Column {
              id: rightFlow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: 4
              spacing: 0

              Repeater {
                model: root.rightColumn

                delegate: StartRow {
                  required property var modelData
                  width: rightFlow.width
                  row: modelData
                  linkStyle: true
                  onActivated: function(rowData, sceneY) { root.handleRow(rowData, sceneY) }
                }
              }
            }
          }
        }

        // ------------------------------------------------------- footer
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: root.footerHeight

          gradient: Gradient {
            GradientStop { position: 0.0; color: root.footerTop }
            GradientStop { position: 1.0; color: root.footerBottom }
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Repeater {
              model: root.footer

              delegate: Item {
                required property var modelData
                width: footerContent.implicitWidth
                height: root.footerHeight

                Row {
                  id: footerContent
                  anchors.centerIn: parent
                  spacing: 6

                  XpIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 20
                    name: String(modelData.icon || "")
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(modelData.label || "")
                    color: footerHover.hovered ? "#ffd800" : "#ffffff"
                    font.family: root.menuFont
                    font.pixelSize: 11
                    font.bold: true
                    style: Text.Raised
                    styleColor: root.panelBorder
                  }
                }

                HoverHandler { id: footerHover }
                MouseArea {
                  anchors.fill: parent
                  onClicked: root.openFooter(modelData)
                }
              }
            }
          }
        }
      }
    }

    // The search box XP-style menus put above the separator. The window owns
    // the input item so focus and Escape work regardless of the row state.
    Item {
      id: searchPlate
      // One row below the pinned items, inside the card's own padding.
      x: 6
      y: 1 + root.headerHeight + 4 + root.pinned.length * root.rowHeight + 1
      width: root.leftWidth - 12
      height: root.searchHeight - 4
      visible: height > 0

      Rectangle {
        anchors.fill: parent
        color: "#ffffff"
        border.color: "#7f9db9"
        border.width: 1

        TextInput {
          id: searchField
          anchors.fill: parent
          anchors.leftMargin: 4
          anchors.rightMargin: 4
          verticalAlignment: TextInput.AlignVCenter
          color: root.textDark
          font.family: root.menuFont
          font.pixelSize: 11
          selectByMouse: true
          clip: true
          onTextChanged: root.query = text
          onAccepted: if (root.filteredApps.length > 0) root.launchApp(root.filteredApps[0].appId)
          Keys.onEscapePressed: root.hideMenu()
        }

        Text {
          anchors.fill: parent
          anchors.leftMargin: 5
          verticalAlignment: Text.AlignVCenter
          visible: searchField.text.length === 0
          text: "Search programs"
          color: "#808080"
          font.family: root.menuFont
          // No italic: Tahoma ships no italic face, so asking for one would
          // silently render upright anyway.
          font.pixelSize: 11
        }
      }
    }
  }

  // --------------------------------------------------- click-away layer
  // Windows XP closes the Start menu when you click the desktop. This is a
  // transparent surface covering everything except the menu itself, so a click
  // outside dismisses it. It is deliberately the lowest of the overlay windows
  // the menu owns, which keeps it behind the menu and the fly-outs.
  PanelWindow {
    id: dismissLayer

    visible: root.opened
    screen: menuWindow.screen
    anchors { top: true; left: true; right: true; bottom: true }
    margins {
      bottom: root.menuHeight + root.barHeight()
      // Leave room for a fly-out that folds out to the right of the menu.
      left: root.menuWidth
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-start-menu-dismiss"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
      anchors.fill: parent
      onClicked: root.hideMenu()
    }
  }

  // ------------------------------------------------------ submenu flyout
  PanelWindow {
    id: submenuWindow

    visible: root.opened && root.submenuRows.length > 0
    screen: menuWindow.screen
    anchors { bottom: true; left: true }
    margins {
      bottom: root.barHeight() + Math.max(0, root.menuHeight - root.submenuAnchorY - root.rowHeight)
      left: root.menuWidth - 2
    }
    implicitWidth: root.submenuWidth
    implicitHeight: Math.min(root.submenuRows.length * root.rowHeight + 8, 460)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-start-menu-sub"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: "#ffffff"
      border.color: root.panelBorder
      border.width: 1

      Column {
        id: submenuFlow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 4
        spacing: 0

        Repeater {
          model: root.submenuRows

          delegate: StartRow {
            required property var modelData
            width: submenuFlow.width
            row: modelData
            nested: true
            // A nested row with its own menu pushes a new level; one without
            // acts immediately. Both keep the existing anchor so the fly-out
            // never jumps vertically.
            onActivated: function(rowData, sceneY) { root.handleRow(rowData, root.submenuAnchorY) }
          }
        }
      }
    }
  }

  // ------------------------------------------------------- power dialog
  PanelWindow {
    id: powerWindow

    visible: root.powerOpen
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    // A layershell surface cannot be anchored to its own centre the way a
    // regular item can, so the window keeps its natural size and the dialog
    // card inside it is what the compositor centres.
    implicitWidth: 320
    implicitHeight: 168
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-turn-off-computer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    PowerDialog {
      anchors.fill: parent
      title: root.powerTitle
      buttons: root.powerButtons

      onChosen: function(action) {
        root.powerOpen = false
        if (String(action) !== "") Quickshell.execDetached(["bash", "-lc", String(action)])
      }
    }
  }

  // The card grows to fit whichever column ends up taller, capped so a long
  // application list cannot swallow the screen. The columns' implicit heights
  // are read after layout, and the body is what those readings produce.
  function measure() {
    var left = leftFlow ? leftFlow.implicitHeight : 0
    var right = rightFlow ? rightFlow.implicitHeight : 0
    measuredBodyHeight = Math.max(left, right, 140)
  }

  Connections {
    target: leftFlow
    function onImplicitHeightChanged() { root.measure() }
  }

  Connections {
    target: rightFlow
    function onImplicitHeightChanged() { root.measure() }
  }

  Component.onCompleted: measure()
}
