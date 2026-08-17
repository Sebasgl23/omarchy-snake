import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "GameModel.js" as Game

Panel {
  id: root
  moduleName: "sebasgl23.snake"
  ipcTarget: "sebasgl23.snake"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int boardColumns: 20
  readonly property int boardRows: 20
  property var game: Game.create(boardColumns, boardRows, Math.random)
  property int sessionBest: 0
  readonly property int storedBest: Math.max(0, Number(setting("bestScore", 0)) || 0)
  readonly property int bestScore: Math.max(storedBest, sessionBest)

  function open() {
    root.controller.show()
  }

  function close() {
    root.game = Game.pause(root.game)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function restart() {
    root.game = Game.create(boardColumns, boardRows, Math.random)
  }

  function togglePause() {
    root.game = Game.togglePause(root.game)
  }

  function steer(dx, dy) {
    root.game = Game.queueDirection(root.game, dx, dy)
  }

  function persistBest(score) {
    var value = Math.max(0, Math.floor(Number(score) || 0))
    if (value <= root.bestScore) return

    root.sessionBest = value
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.bestScore = value

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function stateLabel() {
    if (game.status === Game.STATUS_READY) return "READY"
    if (game.status === Game.STATUS_PAUSED) return "PAUSED"
    if (game.status === Game.STATUS_GAME_OVER) return "GAME OVER"
    if (game.status === Game.STATUS_WON) return "BOARD CLEARED"
    return ""
  }

  onGameChanged: persistBest(game.score)

  Timer {
    interval: root.game.tickMs
    running: root.opened && root.game.status === Game.STATUS_PLAYING
    repeat: true
    onTriggered: root.game = Game.step(root.game, Math.random)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(372))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.steer(dx, dy) }
      onActivateRequested: {
        if (root.game.status === Game.STATUS_GAME_OVER || root.game.status === Game.STATUS_WON)
          root.restart()
        else
          root.togglePause()
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        var key = text.toLowerCase()
        if (key === "w") root.steer(0, -1)
        else if (key === "a") root.steer(-1, 0)
        else if (key === "s") root.steer(0, 1)
        else if (key === "d") root.steer(1, 0)
        else if (key === "p") root.togglePause()
        else if (key === "r") root.restart()
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(12)

        Item {
          width: parent.width
          height: Math.max(scoreRow.implicitHeight, actionRow.implicitHeight)

          Row {
            id: scoreRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(22)

            Column {
              spacing: Style.space(2)

              Text {
                text: "SCORE"
                color: Color.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                text: root.game.score
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
            }

            Column {
              spacing: Style.space(2)

              Text {
                text: "BEST"
                color: Color.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Text {
                text: root.bestScore
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
            }
          }

          Row {
            id: actionRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Button {
              width: Style.space(34)
              height: Style.space(34)
              iconText: root.game.status === Game.STATUS_PLAYING ? "󰏤" : "󰐊"
              iconSize: Style.font.icon
              tooltipText: root.game.status === Game.STATUS_PLAYING ? "Pause" : "Play"
              foreground: root.foreground
              onClicked: root.togglePause()
            }

            Button {
              width: Style.space(34)
              height: Style.space(34)
              iconText: "󰑐"
              iconSize: Style.font.icon
              tooltipText: "Restart"
              foreground: root.foreground
              onClicked: root.restart()
            }
          }
        }

        Item {
          id: boardFrame
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.min(parent.width, Style.space(332))
          height: width

          readonly property int cellSize: Math.floor(width / root.boardColumns)
          readonly property int boardSize: cellSize * root.boardColumns

          BorderSurface {
            anchors.centerIn: parent
            width: boardFrame.boardSize
            height: boardFrame.boardSize
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
            borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))
            radius: Style.cornerRadius

            Grid {
              anchors.fill: parent
              columns: root.boardColumns

              Repeater {
                model: root.boardColumns * root.boardRows

                Item {
                  required property int index
                  width: boardFrame.cellSize
                  height: boardFrame.cellSize
                  readonly property string kind: Game.cellKind(root.game, index)

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.max(1, Math.floor(boardFrame.cellSize * 0.08))
                    visible: parent.kind !== "empty"
                    radius: Style.cornerRadius > 0 ? Math.max(1, width * 0.18) : 0
                    color: parent.kind === "food" ? Color.urgent
                      : parent.kind === "head" ? Color.accent
                      : root.foreground
                    opacity: parent.kind === "body" ? 0.72 : 1
                  }
                }
              }
            }

            Rectangle {
              anchors.centerIn: parent
              visible: root.game.status !== Game.STATUS_PLAYING
              width: stateText.implicitWidth + Style.space(28)
              height: stateText.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: Color.popups.background
              border.width: Math.max(1, Style.normalBorderWidth)
              border.color: Color.popups.border

              Text {
                id: stateText
                anchors.centerIn: parent
                text: root.stateLabel()
                color: root.game.status === Game.STATUS_GAME_OVER ? Color.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                keyCatcher.forceActiveFocus()
                if (root.game.status === Game.STATUS_GAME_OVER || root.game.status === Game.STATUS_WON)
                  root.restart()
                else
                  root.togglePause()
              }
            }
          }
        }
      }
    }
  }
}
