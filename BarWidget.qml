import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "sebasgl23.snake"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property real openPanelIndicatorWidth: button.implicitWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "sebasgl23.snake"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  Component {
    id: snakeGlyph

    Item {
      Rectangle {
        x: parent.width * 0.13
        y: parent.height * 0.56
        width: parent.width * 0.32
        height: parent.height * 0.22
        radius: Style.cornerRadius > 0 ? height * 0.22 : 0
        color: button.foreground
      }

      Rectangle {
        x: parent.width * 0.35
        y: parent.height * 0.35
        width: parent.width * 0.24
        height: parent.height * 0.43
        radius: Style.cornerRadius > 0 ? width * 0.22 : 0
        color: button.foreground
      }

      Rectangle {
        x: parent.width * 0.54
        y: parent.height * 0.22
        width: parent.width * 0.33
        height: parent.height * 0.25
        radius: Style.cornerRadius > 0 ? height * 0.22 : 0
        color: button.foreground

        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Math.max(1, parent.height * 0.18)
          width: Math.max(1, parent.height * 0.13)
          height: width
          radius: width / 2
          color: Color.background
        }
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.opened
    iconComponent: snakeGlyph
    tooltipText: "Snake"
    onPressed: root.togglePanel()
  }
}
