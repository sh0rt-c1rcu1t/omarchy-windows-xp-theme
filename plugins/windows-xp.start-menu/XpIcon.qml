import QtQuick

// Classic Windows XP icon set, drawn as inline SVG.
//
// The icons are vector so they stay crisp at any taskbar or menu size, and
// they are inlined as data URIs so the plugin stays a self-contained directory
// with no image files to install alongside it.
//
// Usage:  XpIcon { name: "my-computer"; size: 24 }
//
// The palette is the Windows XP icon palette: the warm yellow folder body
// (#f7d38a -> #e8a33d) with its lighter tab, the blue-green "special" folder
// used by My Pictures / My Music, and the blue monitor glass.
Item {
  id: root

  property string name: "folder"
  property int size: 24

  implicitWidth: size
  implicitHeight: size

  Image {
    anchors.centerIn: parent
    width: root.size
    height: root.size
    source: root.sourceFor(root.name, root.size)
    sourceSize.width: root.size
    sourceSize.height: root.size
    smooth: true
    fillMode: Image.PreserveAspectFit
  }

  // ---------------------------------------------------------------- shapes
  // The folder body, with %1 and %2 standing in for the fill and shade colours.
  function folderBody(fill, shade) {
    return '<path d="M3 8h7l2 2.5h11a1 1 0 0 1 1 1V25a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z" fill="' + fill + '" stroke="#7a5a12" stroke-width="1"/>' +
      '<path d="M3 12h23v13a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1z" fill="' + shade + '" opacity="0.55"/>' +
      '<path d="M4 11h22v3H4z" fill="#ffffff" opacity="0.35"/>'
  }

  function folder(fill, shade, tab) {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<path d="M2 9h8l2 2h18a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V10a1 1 0 0 1 1-1z" fill="' + tab + '" stroke="#6b4f10" stroke-width="1"/>' +
      folderBody(fill, shade) +
      '</svg>'
  }

  function computer() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="2" y="5" width="28" height="20" rx="1.5" fill="#d6d2c2" stroke="#6d6a5c" stroke-width="1"/>' +
      '<rect x="4" y="7" width="24" height="14" fill="#2f6fd0"/>' +
      '<path d="M4 7h24v7H4z" fill="#6fa8e8"/>' +
      '<path d="M6 9h9l3 3H6z" fill="#ffffff" opacity="0.55"/>' +
      '<rect x="9" y="25" width="14" height="2.5" fill="#b9b5a6" stroke="#6d6a5c" stroke-width="0.8"/>' +
      '<rect x="4" y="27" width="24" height="3" rx="1" fill="#d6d2c2" stroke="#6d6a5c" stroke-width="1"/>' +
      '</svg>'
  }

  function drive() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="3" y="9" width="26" height="15" rx="2" fill="#d9d6cc" stroke="#6d6a5c" stroke-width="1"/>' +
      '<rect x="3" y="9" width="26" height="7" rx="2" fill="#eff0ee"/>' +
      '<rect x="20" y="11" width="7" height="3" rx="1" fill="#8f9299"/>' +
      '<circle cx="25.5" cy="20.5" r="1.6" fill="#57b04a" stroke="#2c6b25" stroke-width="0.7"/>' +
      '<rect x="7" y="19" width="10" height="1.6" fill="#b6b3a7"/>' +
      '<rect x="7" y="21.5" width="6" height="1.6" fill="#b6b3a7"/>' +
      '</svg>'
  }

  function removable() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="4" y="10" width="24" height="16" rx="2" fill="#3b5dbf" stroke="#22347a" stroke-width="1"/>' +
      '<rect x="4" y="10" width="24" height="7" rx="2" fill="#6f8ee0"/>' +
      '<rect x="19" y="12" width="7" height="3" rx="1" fill="#0d1c4d"/>' +
      '<rect x="8" y="20" width="16" height="2" fill="#8fa6ec"/>' +
      '<path d="M11 6l6-4 6 4z" fill="#e8b23c" stroke="#7a5a12" stroke-width="0.8"/>' +
      '</svg>'
  }

  function controlPanel() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="3" y="6" width="26" height="21" rx="1.5" fill="#ece9d8" stroke="#5a5747" stroke-width="1"/>' +
      '<path d="M3 6h26v5H3z" fill="#2f6fd0"/>' +
      '<circle cx="4.5" cy="8.5" r="1.3" fill="#ffffff" opacity="0.8"/>' +
      '<rect x="6" y="14" width="20" height="2" fill="#9a9788"/>' +
      '<circle cx="11" cy="15" r="3" fill="#ece9d8" stroke="#5a5747" stroke-width="1.2"/>' +
      '<rect x="6" y="20" width="20" height="2" fill="#9a9788"/>' +
      '<circle cx="21" cy="21" r="3" fill="#ece9d8" stroke="#5a5747" stroke-width="1.2"/>' +
      '</svg>'
  }

  function appearance() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="2" y="4" width="28" height="20" rx="1.5" fill="#ece9d8" stroke="#5a5747" stroke-width="1"/>' +
      '<path d="M2 4h28v6H2z" fill="#0054e3"/>' +
      '<rect x="4" y="12" width="24" height="10" fill="#3f8cf3"/>' +
      '<circle cx="9" cy="17" r="3.4" fill="#e8b23c" stroke="#7a5a12" stroke-width="1"/>' +
      '<circle cx="18" cy="17" r="3.4" fill="#c94f3d" stroke="#7a2a20" stroke-width="1"/>' +
      '<circle cx="27" cy="17" r="3.4" fill="#4a9c3d" stroke="#265c1e" stroke-width="1"/>' +
      '<rect x="11" y="25" width="10" height="2" fill="#b9b5a6"/>' +
      '</svg>'
  }

  function display() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="2" y="4" width="28" height="20" rx="1.5" fill="#d6d2c2" stroke="#6d6a5c" stroke-width="1"/>' +
      '<rect x="4" y="6" width="24" height="16" fill="#3f8cf3"/>' +
      '<path d="M4 6h24v8H4z" fill="#8fc0f5"/>' +
      '<rect x="10" y="25" width="12" height="2" fill="#b9b5a6" stroke="#6d6a5c" stroke-width="0.8"/>' +
      '<rect x="6" y="27" width="20" height="2.5" rx="1" fill="#d6d2c2" stroke="#6d6a5c" stroke-width="0.8"/>' +
      '</svg>'
  }

  function sound() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<path d="M4 12h5l7-6v20l-7-6H4z" fill="#e8e5d8" stroke="#5a5747" stroke-width="1.2"/>' +
      '<path d="M20 9c3 2 3 10 0 12" fill="none" stroke="#2f6fd0" stroke-width="2"/>' +
      '<path d="M24 6c5 4 5 16 0 20" fill="none" stroke="#2f6fd0" stroke-width="2"/>' +
      '</svg>'
  }

  function network() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="12" fill="#8fc0f5" stroke="#1c4f9c" stroke-width="1.2"/>' +
      '<ellipse cx="16" cy="16" rx="5" ry="12" fill="none" stroke="#1c4f9c" stroke-width="1.2"/>' +
      '<path d="M4 16h24M6 10h20M6 22h20" fill="none" stroke="#1c4f9c" stroke-width="1.2"/>' +
      '<path d="M16 4a12 12 0 0 1 0 24z" fill="#c9dff8" opacity="0.7"/>' +
      '</svg>'
  }

  function networkPlaces() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="14" cy="15" r="10" fill="#8fc0f5" stroke="#1c4f9c" stroke-width="1.2"/>' +
      '<ellipse cx="14" cy="15" rx="4" ry="10" fill="none" stroke="#1c4f9c" stroke-width="1.2"/>' +
      '<path d="M4 15h20M6 9.5h16M6 20.5h16" fill="none" stroke="#1c4f9c" stroke-width="1.2"/>' +
      '<rect x="18" y="18" width="11" height="9" rx="1.5" fill="#d9d6cc" stroke="#5a5747" stroke-width="1"/>' +
      '<rect x="20" y="20" width="7" height="5" fill="#3f8cf3"/>' +
      '</svg>'
  }

  function printer() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="7" y="4" width="18" height="8" fill="#ffffff" stroke="#5a5747" stroke-width="1"/>' +
      '<rect x="3" y="11" width="26" height="11" rx="1.5" fill="#d9d6cc" stroke="#5a5747" stroke-width="1"/>' +
      '<rect x="6" y="13" width="5" height="2.5" fill="#9a9788"/>' +
      '<rect x="22" y="13" width="4" height="4" rx="1" fill="#57b04a"/>' +
      '<rect x="7" y="20" width="18" height="8" fill="#ffffff" stroke="#5a5747" stroke-width="1"/>' +
      '<path d="M10 23h12M10 25.5h9" stroke="#9a9788" stroke-width="1.2"/>' +
      '</svg>'
  }

  function keyboard() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="1" y="9" width="30" height="15" rx="2" fill="#d9d6cc" stroke="#5a5747" stroke-width="1"/>' +
      '<g fill="#7d7a6d">' +
      '<rect x="4" y="12" width="3" height="3"/><rect x="8.5" y="12" width="3" height="3"/>' +
      '<rect x="13" y="12" width="3" height="3"/><rect x="17.5" y="12" width="3" height="3"/>' +
      '<rect x="22" y="12" width="3" height="3"/><rect x="26" y="12" width="2.5" height="3"/>' +
      '<rect x="4" y="16.5" width="3" height="3"/><rect x="8.5" y="16.5" width="3" height="3"/>' +
      '<rect x="13" y="16.5" width="3" height="3"/><rect x="17.5" y="16.5" width="3" height="3"/>' +
      '<rect x="22" y="16.5" width="6.5" height="3"/>' +
      '</g>' +
      '<rect x="10" y="21" width="12" height="2.5" fill="#7d7a6d"/>' +
      '</svg>'
  }

  function users() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="12" cy="10" r="5" fill="#e8b23c" stroke="#7a5a12" stroke-width="1.2"/>' +
      '<path d="M3 27c0-5 4-8 9-8s9 3 9 8z" fill="#3f8cf3" stroke="#1c4f9c" stroke-width="1.2"/>' +
      '<circle cx="23" cy="13" r="3.6" fill="#d6a032" stroke="#7a5a12" stroke-width="1"/>' +
      '<path d="M18 27c0-3.6 2.6-6 5.6-6S29 23.4 29 27z" fill="#6fa8e8" stroke="#1c4f9c" stroke-width="1"/>' +
      '</svg>'
  }

  function addRemove() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="3" y="6" width="26" height="21" rx="1.5" fill="#ece9d8" stroke="#5a5747" stroke-width="1"/>' +
      '<path d="M3 6h26v5H3z" fill="#2f6fd0"/>' +
      '<path d="M9 17h6v-6h3v6h6v3h-6v6h-3v-6H9z" fill="#4a9c3d" stroke="#265c1e" stroke-width="0.9"/>' +
      '</svg>'
  }

  function system() {
    return computer()
  }

  function help() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="13" fill="#3f8cf3" stroke="#1c4f9c" stroke-width="1.2"/>' +
      '<circle cx="16" cy="16" r="9" fill="#c9dff8"/>' +
      '<text x="16" y="23" font-family="Tahoma, Verdana, sans-serif" font-size="16" font-weight="bold" text-anchor="middle" fill="#1c4f9c">?</text>' +
      '</svg>'
  }

  function search() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="13" cy="13" r="8" fill="#cfe3f8" stroke="#5a5747" stroke-width="2"/>' +
      '<path d="M19 19l9 9" stroke="#8a6a2a" stroke-width="4" stroke-linecap="round"/>' +
      '<path d="M10 9a5 5 0 0 1 5-2" stroke="#ffffff" stroke-width="1.6" fill="none"/>' +
      '</svg>'
  }

  function run() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="3" y="5" width="26" height="22" rx="1.5" fill="#0d1b2a" stroke="#5a5747" stroke-width="1"/>' +
      '<rect x="3" y="5" width="26" height="4" fill="#3f8cf3"/>' +
      '<text x="6" y="21" font-family="monospace" font-size="11" fill="#d8f0ff">&gt;_</text>' +
      '</svg>'
  }

  function email() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<rect x="2" y="7" width="28" height="18" rx="1.5" fill="#ffffff" stroke="#5a5747" stroke-width="1.2"/>' +
      '<path d="M2 8l14 10L30 8" fill="none" stroke="#5a5747" stroke-width="1.4"/>' +
      '<path d="M2 8h28l-14 10z" fill="#c9dff8"/>' +
      '</svg>'
  }

  function internet() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="12" fill="#3f8cf3" stroke="#1c4f9c" stroke-width="1.2"/>' +
      '<ellipse cx="16" cy="16" rx="5" ry="12" fill="none" stroke="#ffffff" stroke-width="1.3"/>' +
      '<path d="M4 16h24M6.5 10h19M6.5 22h19" stroke="#ffffff" stroke-width="1.3" fill="none"/>' +
      '<path d="M16 4a12 12 0 0 0 0 24z" fill="#ffffff" opacity="0.25"/>' +
      '</svg>'
  }

  function logOff() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="13" fill="#e8b23c" stroke="#8a6a2a" stroke-width="1.2"/>' +
      '<path d="M16 8v9" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>' +
      '<path d="M10.5 11a8 8 0 1 0 11 0" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/>' +
      '</svg>'
  }

  function turnOff() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="13" fill="#d0483a" stroke="#7a2418" stroke-width="1.2"/>' +
      '<path d="M16 8v9" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>' +
      '<path d="M10.5 11a8 8 0 1 0 11 0" fill="none" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/>' +
      '</svg>'
  }

  function powerOff() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="12" fill="#d0483a" stroke="#7a2418" stroke-width="1.2"/>' +
      '<path d="M16 9v8" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>' +
      '<path d="M11 12a7 7 0 1 0 10 0" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>' +
      '</svg>'
  }

  function powerStandby() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="12" fill="#e8b23c" stroke="#8a6a2a" stroke-width="1.2"/>' +
      '<path d="M16 9v8" stroke="#ffffff" stroke-width="3" stroke-linecap="round"/>' +
      '<path d="M11 12a7 7 0 1 0 10 0" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>' +
      '</svg>'
  }

  function powerRestart() {
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
      '<circle cx="16" cy="16" r="12" fill="#4a9c3d" stroke="#265c1e" stroke-width="1.2"/>' +
      '<path d="M22 11l-7 1.4 3.2 2.2a6 6 0 1 0-2.2 9" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>' +
      '<path d="M22.5 8.5l-1 5-5-1z" fill="#ffffff"/>' +
      '</svg>'
  }

  function power() {
    return powerOff()
  }

  function settings() {
    return controlPanel()
  }

  function folderOpen() {
    return folder("#f3d07f", "#c8892a", "#ffe6ad")
  }

  function sourceFor(iconName, px) {
    var svg
    switch (iconName) {
    case "my-documents":
    case "recent":
      svg = folder("#f7d38a", "#e0a33d", "#ffe6ad")
      break
    case "my-pictures":
      svg = folder("#cfd9a8", "#8fa05a", "#e8f0c8")
      break
    case "my-music":
      svg = folder("#c9b6e0", "#8a6fbe", "#e6dcf5")
      break
    case "my-videos":
      svg = folder("#c9b6e0", "#8a6fbe", "#e6dcf5")
      break
    case "shared-folder":
    case "folder":
    case "folder-open":
    case "all-programs":
      svg = folderOpen()
      break
    case "my-computer":
    case "system":
      svg = computer()
      break
    case "hard-drive":
    case "disk":
      svg = drive()
      break
    case "removable":
      svg = removable()
      break
    case "control-panel":
    case "settings":
      svg = controlPanel()
      break
    case "appearance":
      svg = appearance()
      break
    case "display":
      svg = display()
      break
    case "sound":
      svg = sound()
      break
    case "network":
      svg = network()
      break
    case "network-places":
      svg = networkPlaces()
      break
    case "printer":
      svg = printer()
      break
    case "keyboard":
      svg = keyboard()
      break
    case "users":
      svg = users()
      break
    case "add-remove":
      svg = addRemove()
      break
    case "help":
      svg = help()
      break
    case "search":
      svg = search()
      break
    case "run":
      svg = run()
      break
    case "email":
      svg = email()
      break
    case "internet":
      svg = internet()
      break
    case "log-off":
      svg = logOff()
      break
    case "turn-off":
      svg = turnOff()
      break
    case "power-off":
      svg = powerOff()
      break
    case "power-standby":
      svg = powerStandby()
      break
    case "power-restart":
      svg = powerRestart()
      break
    default:
      svg = folderOpen()
      break
    }
    return "data:image/svg+xml;utf8," + encodeURI(svg)
  }
}
