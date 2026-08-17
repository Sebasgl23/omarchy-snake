.pragma library

var STATUS_READY = "ready"
var STATUS_PLAYING = "playing"
var STATUS_PAUSED = "paused"
var STATUS_GAME_OVER = "game-over"
var STATUS_WON = "won"

var START_TICK_MS = 150
var MIN_TICK_MS = 70
var TICK_STEP_MS = 5

function point(x, y) {
  return { x: x, y: y }
}

function copyPoint(value) {
  return point(value.x, value.y)
}

function copyBody(body) {
  var result = []
  for (var i = 0; i < body.length; i++) result.push(copyPoint(body[i]))
  return result
}

function randomIndex(length, randomFn) {
  if (length <= 0) return -1
  var value = randomFn ? Number(randomFn()) : Math.random()
  if (!isFinite(value)) value = 0
  value = Math.max(0, Math.min(0.999999999, value))
  return Math.floor(value * length)
}

function samePoint(a, b) {
  return a && b && a.x === b.x && a.y === b.y
}

function contains(body, candidate) {
  for (var i = 0; i < body.length; i++) {
    if (samePoint(body[i], candidate)) return true
  }
  return false
}

function spawnFood(width, height, body, randomFn) {
  var free = []
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var candidate = point(x, y)
      if (!contains(body, candidate)) free.push(candidate)
    }
  }
  var index = randomIndex(free.length, randomFn)
  return index < 0 ? null : free[index]
}

function create(width, height, randomFn) {
  var boardWidth = Math.max(4, Math.floor(Number(width) || 20))
  var boardHeight = Math.max(4, Math.floor(Number(height) || 20))
  var centerX = Math.floor(boardWidth / 2)
  var centerY = Math.floor(boardHeight / 2)
  var body = [
    point(centerX, centerY),
    point(centerX - 1, centerY),
    point(centerX - 2, centerY)
  ]

  return {
    width: boardWidth,
    height: boardHeight,
    body: body,
    food: spawnFood(boardWidth, boardHeight, body, randomFn),
    direction: point(1, 0),
    pendingDirection: null,
    score: 0,
    tickMs: START_TICK_MS,
    status: STATUS_READY
  }
}

function withStatus(state, status) {
  return {
    width: state.width,
    height: state.height,
    body: copyBody(state.body),
    food: state.food ? copyPoint(state.food) : null,
    direction: copyPoint(state.direction),
    pendingDirection: state.pendingDirection ? copyPoint(state.pendingDirection) : null,
    score: state.score,
    tickMs: state.tickMs,
    status: status
  }
}

function togglePause(state) {
  if (state.status === STATUS_PLAYING) return withStatus(state, STATUS_PAUSED)
  if (state.status === STATUS_PAUSED || state.status === STATUS_READY)
    return withStatus(state, STATUS_PLAYING)
  return state
}

function pause(state) {
  return state.status === STATUS_PLAYING ? withStatus(state, STATUS_PAUSED) : state
}

function isUnitDirection(dx, dy) {
  return Math.abs(dx) + Math.abs(dy) === 1
}

function queueDirection(state, dx, dy) {
  var nextX = Math.floor(Number(dx) || 0)
  var nextY = Math.floor(Number(dy) || 0)
  if (!isUnitDirection(nextX, nextY)) return state
  if (state.status === STATUS_GAME_OVER || state.status === STATUS_WON) return state
  if (state.pendingDirection) return state
  if (state.direction.x + nextX === 0 && state.direction.y + nextY === 0) return state

  var next = withStatus(state, state.status === STATUS_READY ? STATUS_PLAYING : state.status)
  next.pendingDirection = point(nextX, nextY)
  return next
}

function outside(state, candidate) {
  return candidate.x < 0 || candidate.y < 0
    || candidate.x >= state.width || candidate.y >= state.height
}

function step(state, randomFn) {
  if (state.status !== STATUS_PLAYING) return state

  var direction = state.pendingDirection || state.direction
  var head = state.body[0]
  var nextHead = point(head.x + direction.x, head.y + direction.y)
  var eating = samePoint(nextHead, state.food)
  var collisionBody = eating ? state.body : state.body.slice(0, state.body.length - 1)

  if (outside(state, nextHead) || contains(collisionBody, nextHead)) {
    var dead = withStatus(state, STATUS_GAME_OVER)
    dead.direction = copyPoint(direction)
    dead.pendingDirection = null
    return dead
  }

  var nextBody = [nextHead].concat(copyBody(state.body))
  if (!eating) nextBody.pop()

  var nextScore = state.score + (eating ? 1 : 0)
  var nextFood = eating
    ? spawnFood(state.width, state.height, nextBody, randomFn)
    : copyPoint(state.food)

  return {
    width: state.width,
    height: state.height,
    body: nextBody,
    food: nextFood,
    direction: copyPoint(direction),
    pendingDirection: null,
    score: nextScore,
    tickMs: eating ? Math.max(MIN_TICK_MS, state.tickMs - TICK_STEP_MS) : state.tickMs,
    status: eating && !nextFood ? STATUS_WON : STATUS_PLAYING
  }
}

function cellKind(state, index) {
  var x = index % state.width
  var y = Math.floor(index / state.width)
  if (state.food && state.food.x === x && state.food.y === y) return "food"
  for (var i = 0; i < state.body.length; i++) {
    if (state.body[i].x === x && state.body[i].y === y) return i === 0 ? "head" : "body"
  }
  return "empty"
}
