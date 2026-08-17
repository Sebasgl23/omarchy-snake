import QtQuick
import QtTest
import "../GameModel.js" as Game

TestCase {
  name: "GameModel"

  function zeroRandom() { return 0 }
  function highRandom() { return 0.999999 }

  function stateWith(values) {
    var state = Game.create(values.width || 8, values.height || 8, zeroRandom)
    for (var key in values) state[key] = values[key]
    return state
  }

  function test_create() {
    var state = Game.create(20, 20, zeroRandom)
    compare(state.width, 20)
    compare(state.height, 20)
    compare(state.body.length, 3)
    compare(state.status, Game.STATUS_READY)
    verify(state.food !== null)
    verify(!Game.contains(state.body, state.food))
  }

  function test_directionStartsAndRejectsReverse() {
    var state = Game.create(8, 8, zeroRandom)
    var reversed = Game.queueDirection(state, -1, 0)
    compare(reversed.status, Game.STATUS_READY)
    verify(reversed.pendingDirection === null)

    var started = Game.queueDirection(state, 0, -1)
    compare(started.status, Game.STATUS_PLAYING)
    compare(started.pendingDirection.x, 0)
    compare(started.pendingDirection.y, -1)

    var ignored = Game.queueDirection(started, -1, 0)
    compare(ignored.pendingDirection.x, 0)
    compare(ignored.pendingDirection.y, -1)
  }

  function test_stepMovesWithoutGrowing() {
    var state = stateWith({
      status: Game.STATUS_PLAYING,
      food: { x: 0, y: 0 }
    })
    var next = Game.step(state, zeroRandom)
    compare(next.body.length, state.body.length)
    compare(next.body[0].x, state.body[0].x + 1)
    compare(next.score, 0)
  }

  function test_eatingGrowsScoresAndSpeedsUp() {
    var state = stateWith({ status: Game.STATUS_PLAYING })
    state.food = { x: state.body[0].x + 1, y: state.body[0].y }
    var next = Game.step(state, highRandom)
    compare(next.body.length, state.body.length + 1)
    compare(next.score, 1)
    compare(next.tickMs, Game.START_TICK_MS - Game.TICK_STEP_MS)
    verify(!Game.contains(next.body, next.food))
  }

  function test_wallCollision() {
    var state = stateWith({
      status: Game.STATUS_PLAYING,
      body: [{ x: 7, y: 3 }, { x: 6, y: 3 }, { x: 5, y: 3 }],
      direction: { x: 1, y: 0 }
    })
    compare(Game.step(state, zeroRandom).status, Game.STATUS_GAME_OVER)
  }

  function test_bodyCollision() {
    var state = stateWith({
      status: Game.STATUS_PLAYING,
      body: [
        { x: 3, y: 3 }, { x: 3, y: 2 }, { x: 2, y: 2 },
        { x: 2, y: 3 }, { x: 2, y: 4 }, { x: 3, y: 4 }
      ],
      direction: { x: -1, y: 0 },
      food: { x: 7, y: 7 }
    })
    compare(Game.step(state, zeroRandom).status, Game.STATUS_GAME_OVER)
  }

  function test_tailCellIsSafeWhenNotEating() {
    var state = stateWith({
      status: Game.STATUS_PLAYING,
      body: [{ x: 2, y: 2 }, { x: 2, y: 3 }, { x: 1, y: 3 }, { x: 1, y: 2 }],
      direction: { x: -1, y: 0 },
      food: { x: 7, y: 7 }
    })
    compare(Game.step(state, zeroRandom).status, Game.STATUS_PLAYING)
  }

  function test_pauseAndResume() {
    var state = Game.create(8, 8, zeroRandom)
    state = Game.togglePause(state)
    compare(state.status, Game.STATUS_PLAYING)
    state = Game.pause(state)
    compare(state.status, Game.STATUS_PAUSED)
    state = Game.togglePause(state)
    compare(state.status, Game.STATUS_PLAYING)
  }

  function test_speedHasFloor() {
    var state = stateWith({ status: Game.STATUS_PLAYING, tickMs: Game.MIN_TICK_MS })
    state.food = { x: state.body[0].x + 1, y: state.body[0].y }
    compare(Game.step(state, highRandom).tickMs, Game.MIN_TICK_MS)
  }

  function test_fullBoardWins() {
    var state = stateWith({
      width: 4,
      height: 4,
      status: Game.STATUS_PLAYING,
      body: [
        { x: 2, y: 0 }, { x: 1, y: 0 }, { x: 0, y: 0 },
        { x: 0, y: 1 }, { x: 1, y: 1 }, { x: 2, y: 1 }, { x: 3, y: 1 },
        { x: 3, y: 2 }, { x: 2, y: 2 }, { x: 1, y: 2 }, { x: 0, y: 2 },
        { x: 0, y: 3 }, { x: 1, y: 3 }, { x: 2, y: 3 }, { x: 3, y: 3 }
      ],
      direction: { x: 1, y: 0 },
      food: { x: 3, y: 0 }
    })
    var next = Game.step(state, zeroRandom)
    compare(next.status, Game.STATUS_WON)
    compare(next.body.length, 16)
    verify(next.food === null)
  }
}
