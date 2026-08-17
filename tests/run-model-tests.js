const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const source = fs
  .readFileSync(path.join(__dirname, "..", "GameModel.js"), "utf8")
  .replace(/^\.pragma library\s*$/m, "")

const Game = { Math, Number, isFinite }
vm.createContext(Game)
vm.runInContext(source, Game, { filename: "GameModel.js" })

const zero = () => 0
const high = () => 0.999999

function stateWith(values) {
  return Object.assign(Game.create(values.width || 8, values.height || 8, zero), values)
}

function test(name, body) {
  body()
  process.stdout.write(`ok - ${name}\n`)
}

test("creates a valid ready game", () => {
  const state = Game.create(20, 20, zero)
  assert.equal(state.body.length, 3)
  assert.equal(state.status, Game.STATUS_READY)
  assert.equal(Game.contains(state.body, state.food), false)
})

test("starts on a valid turn and rejects reversal", () => {
  const state = Game.create(8, 8, zero)
  assert.equal(Game.queueDirection(state, -1, 0).status, Game.STATUS_READY)
  const started = Game.queueDirection(state, 0, -1)
  assert.equal(started.status, Game.STATUS_PLAYING)
  assert.equal(started.pendingDirection.x, 0)
  assert.equal(started.pendingDirection.y, -1)
  const ignored = Game.queueDirection(started, -1, 0)
  assert.equal(ignored.pendingDirection.x, 0)
  assert.equal(ignored.pendingDirection.y, -1)
})

test("moves without growing", () => {
  const state = stateWith({ status: Game.STATUS_PLAYING, food: { x: 0, y: 0 } })
  const next = Game.step(state, zero)
  assert.equal(next.body.length, state.body.length)
  assert.equal(next.body[0].x, state.body[0].x + 1)
})

test("eating grows, scores and accelerates", () => {
  const state = stateWith({ status: Game.STATUS_PLAYING })
  state.food = { x: state.body[0].x + 1, y: state.body[0].y }
  const next = Game.step(state, high)
  assert.equal(next.body.length, state.body.length + 1)
  assert.equal(next.score, 1)
  assert.equal(next.tickMs, Game.START_TICK_MS - Game.TICK_STEP_MS)
  assert.equal(Game.contains(next.body, next.food), false)
})

test("detects wall and body collisions", () => {
  const wall = stateWith({
    status: Game.STATUS_PLAYING,
    body: [{ x: 7, y: 3 }, { x: 6, y: 3 }, { x: 5, y: 3 }],
    direction: { x: 1, y: 0 }
  })
  assert.equal(Game.step(wall, zero).status, Game.STATUS_GAME_OVER)

  const body = stateWith({
    status: Game.STATUS_PLAYING,
    body: [
      { x: 3, y: 3 }, { x: 3, y: 2 }, { x: 2, y: 2 },
      { x: 2, y: 3 }, { x: 2, y: 4 }, { x: 3, y: 4 }
    ],
    direction: { x: -1, y: 0 },
    food: { x: 7, y: 7 }
  })
  assert.equal(Game.step(body, zero).status, Game.STATUS_GAME_OVER)
})

test("allows moving into the departing tail", () => {
  const state = stateWith({
    status: Game.STATUS_PLAYING,
    body: [{ x: 2, y: 2 }, { x: 2, y: 3 }, { x: 1, y: 3 }, { x: 1, y: 2 }],
    direction: { x: -1, y: 0 },
    food: { x: 7, y: 7 }
  })
  assert.equal(Game.step(state, zero).status, Game.STATUS_PLAYING)
})

test("pauses, resumes and clamps speed", () => {
  let state = Game.togglePause(Game.create(8, 8, zero))
  assert.equal(state.status, Game.STATUS_PLAYING)
  state = Game.pause(state)
  assert.equal(state.status, Game.STATUS_PAUSED)
  assert.equal(Game.togglePause(state).status, Game.STATUS_PLAYING)

  state = stateWith({ status: Game.STATUS_PLAYING, tickMs: Game.MIN_TICK_MS })
  state.food = { x: state.body[0].x + 1, y: state.body[0].y }
  assert.equal(Game.step(state, high).tickMs, Game.MIN_TICK_MS)
})

test("wins after filling the board", () => {
  const state = stateWith({
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
  const next = Game.step(state, zero)
  assert.equal(next.status, Game.STATUS_WON)
  assert.equal(next.body.length, 16)
  assert.equal(next.food, null)
})
