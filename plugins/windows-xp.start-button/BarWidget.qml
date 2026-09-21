import QtQuick

// The Windows XP "start" button.
//
// Lunas draws it as a 100x30 green lozenge with a soft highlight across the top,
// the four-pane Windows flag and the word "start" in bold italic. Pressing it
// opens the Start menu; the whole button lightens while hovered, exactly as the
// Luna visual style does.
//
// The root is a plain Item rather than the shell's `BarWidget` base so the
// widget depends on nothing but QtQuick: the bar host injects `bar`,
// `moduleName` and `settings` into any item that declares them, which is the
// whole of the base class's contract that this button uses.
Item {
  id: root

  // Injected by the bar host.
  property QtObject bar: null
  property string moduleName: "windows-xp.start-button"
  property var settings: ({})

  // Per-entry overrides, in the same shape the host's base class exposes.
  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  // The menu plugin this button opens. Overridable per bar entry so a clone of
  // the button can point at a clone of the menu.
  readonly property string menuPlugin: String(root.setting("menuPlugin", "windows-xp.start-menu"))
  readonly property string label: String(root.setting("label", "start"))

  // Windows XP's Start button geometry at 96 DPI.
  readonly property int buttonWidth: 100
  readonly property int buttonHeight: Math.max(22, root.bar ? Math.round(root.bar.barSize) : 30)

  implicitWidth: buttonWidth
  implicitHeight: buttonHeight

  // Single-quote a value for a shell command line. Plugin ids are restricted
  // to [a-z0-9._+-], so quoting is belt and braces rather than load-bearing.
  function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'"
  }

  function toggleMenu() {
    if (!root.bar) return
    if (root.bar.hideTooltip) root.bar.hideTooltip(root)
    root.bar.run("omarchy-shell shell toggle " + root.shellQuote(root.menuPlugin) + " '{}'")
  }

  Item {
    id: button
    anchors.fill: parent

    // Luna's green body: a warm highlight across the top third, the base green
    // through the middle, and a darker rim along the bottom edge.
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 1
      anchors.bottomMargin: 1
      radius: 3
      border.width: 1
      border.color: "#1d4a14"

      gradient: Gradient {
        GradientStop {
          position: 0.00
          color: pointer.pressed ? "#2c6a22" : (hover.hovered ? "#93d46c" : "#7cc055")
        }
        GradientStop {
          position: 0.34
          color: pointer.pressed ? "#275f1d" : (hover.hovered ? "#63b03e" : "#4fa032")
        }
        GradientStop {
          position: 0.56
          color: pointer.pressed ? "#215418" : "#3c8a2e"
        }
        GradientStop {
          position: 1.00
          color: pointer.pressed ? "#17400f" : "#2b7320"
        }
      }

      // The pale inner line Luna paints just inside the border.
      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 2
        color: "transparent"
        border.color: "#c6e8a0"
        border.width: 1
        opacity: pointer.pressed ? 0.25 : 0.6
      }

      Row {
        anchors.centerIn: parent
        spacing: 5

        WindowsFlag {
          anchors.verticalCenter: parent.verticalCenter
          width: 19
          height: 17
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.label
          color: "#ffffff"
          font.family: "Tahoma"
          // 11px is Tahoma 8pt at 96 DPI: the size Windows XP draws "start" at.
          font.pixelSize: 11
          font.bold: true
          font.italic: true
          style: Text.Raised
          styleColor: "#1d4a14"
        }
      }
    }

    HoverHandler { id: hover }

    MouseArea {
      id: pointer
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggleMenu()
    }
  }

  // The four-pane Windows flag, drawn as one skewed mark: the panes get
  // narrower towards the right to suggest the flag flying away from the viewer.
  component WindowsFlag: Item {
    id: flag

    // x, y, width and colour of each pane in the flag's own coordinate space.
    readonly property var panes: [
      { px: 0.00, py: 0.00, pw: 0.46, ph: 0.46, color: "#ef4a3a" },
      { px: 0.54, py: 0.00, pw: 0.46, ph: 0.46, color: "#7cc043" },
      { px: 0.00, py: 0.54, pw: 0.46, ph: 0.46, color: "#4a90e2" },
      { px: 0.54, py: 0.54, pw: 0.46, ph: 0.46, color: "#f5c542" }
    ]

    Repeater {
      model: flag.panes

      delegate: Item {
        required property var modelData
        required property int index

        // Every pane is a parallelogram, which is what gives the mark its
        // perspective without a real 3D transform.
        x: flag.width * (modelData.px + 0.16 * modelData.py)
        y: flag.height * modelData.py
        width: flag.width * (modelData.pw * (1.0 - 0.30 * modelData.py))
        height: flag.height * (modelData.ph * (1.0 - 0.12 * modelData.px)) - 1

        Rectangle {
          anchors.fill: parent
          color: modelData.color
          radius: 1
        }
      }
    }
  }
}
