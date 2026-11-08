.pragma library

var MODES = ["hour", "day", "custom"]
var END_BEHAVIORS = ["loop", "hold"]
var EDGES = ["inner", "outer"]
var DIRECTIONS_H = ["right", "left"]
var DIRECTIONS_V = ["down", "up"]
var PIP_STYLES = ["circle", "triangle", "diamond", "tick", "glow", "none"]
var PIP_SIZES = { small: 6, medium: 9, large: 13 }

var COLORS = [
  { id: "theme", value: null },
  { id: "red", value: "#ff4e45" },
  { id: "orange", value: "#ff9f43" },
  { id: "yellow", value: "#f9d44a" },
  { id: "green", value: "#5fd38d" },
  { id: "cyan", value: "#4fd1e8" },
  { id: "blue", value: "#5b9dff" },
  { id: "purple", value: "#a98bff" },
  { id: "pink", value: "#ff7ac6" },
  { id: "white", value: "#f2f2f2" }
]

var DEFAULTS = {
  enabled: true,
  mode: "hour",
  startTime: "08:00",
  durationMin: 480,
  endBehavior: "loop",
  color: "theme",
  trackOpacity: 0.25,
  lineHeight: 2,
  edge: "inner",
  directionH: "right",
  directionV: "down",
  pipStyle: "circle",
  pipSize: "medium",
  loopAnimation: true,
  rainbow: false
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

function oneOf(value, allowed, fallback) {
  return allowed.indexOf(value) !== -1 ? value : fallback
}

function colorIds() {
  var out = []
  for (var i = 0; i < COLORS.length; i++) out.push(COLORS[i].id)
  return out
}

function colorValue(id) {
  for (var i = 0; i < COLORS.length; i++) if (COLORS[i].id === id) return COLORS[i].value
  return null
}

// Minutes after midnight for "HH:MM", or -1 when malformed.
function parseClock(text) {
  var m = String(text || "").match(/^\s*(\d{1,2}):(\d{2})\s*$/)
  if (!m) return -1
  var h = parseInt(m[1], 10), min = parseInt(m[2], 10)
  if (h > 23 || min > 59) return -1
  return h * 60 + min
}

function formatClock(minutes) {
  var h = Math.floor(minutes / 60) % 24, m = minutes % 60
  return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
}

// Validated settings with every field present.
function normalize(raw) {
  var s = raw || {}
  var start = parseClock(s.startTime)
  return {
    enabled: s.enabled !== false,
    mode: oneOf(s.mode, MODES, DEFAULTS.mode),
    startTime: start < 0 ? DEFAULTS.startTime : formatClock(start),
    durationMin: Math.round(clamp(Number(s.durationMin) || DEFAULTS.durationMin, 1, 1440)),
    endBehavior: oneOf(s.endBehavior, END_BEHAVIORS, DEFAULTS.endBehavior),
    color: oneOf(s.color, colorIds(), DEFAULTS.color),
    trackOpacity: clamp(isFinite(Number(s.trackOpacity)) && s.trackOpacity !== null ? Number(s.trackOpacity) : DEFAULTS.trackOpacity, 0, 1),
    edge: oneOf(s.edge, EDGES, DEFAULTS.edge),
    directionH: oneOf(s.directionH, DIRECTIONS_H, DEFAULTS.directionH),
    directionV: oneOf(s.directionV, DIRECTIONS_V, DEFAULTS.directionV),
    lineHeight: Math.round(clamp(Number(s.lineHeight) || DEFAULTS.lineHeight, 1, 8)),
    pipStyle: oneOf(s.pipStyle, PIP_STYLES, DEFAULTS.pipStyle),
    pipSize: PIP_SIZES.hasOwnProperty(s.pipSize) ? s.pipSize : DEFAULTS.pipSize,
    loopAnimation: s.loopAnimation !== false,
    rainbow: s.rainbow === true
  }
}

// Span boundaries come from local Date fields, not fixed offsets, so a DST
// change shortens or lengthens the hour/day it lands in instead of shifting it.
function span(nowMs, cfg) {
  var now = new Date(nowMs)
  var y = now.getFullYear(), mo = now.getMonth(), d = now.getDate()
  var start, end

  if (cfg.mode === "day") {
    start = new Date(y, mo, d).getTime()
    end = new Date(y, mo, d + 1).getTime()
  } else if (cfg.mode === "custom") {
    var startMin = parseClock(cfg.startTime)
    if (startMin < 0) startMin = parseClock(DEFAULTS.startTime)
    var durMs = cfg.durationMin * 60000
    var anchor = new Date(y, mo, d, 0, startMin).getTime()
    if (cfg.endBehavior === "hold") {
      // A block that started yesterday may still be running after midnight.
      var prev = new Date(y, mo, d - 1, 0, startMin).getTime()
      if (nowMs < anchor && nowMs < prev + durMs) anchor = prev
      start = anchor
      end = anchor + durMs
    } else {
      var k = Math.floor((nowMs - anchor) / durMs)
      start = anchor + k * durMs
      end = start + durMs
    }
  } else {
    start = new Date(y, mo, d, now.getHours()).getTime()
    end = new Date(y, mo, d, now.getHours() + 1).getTime()
  }

  var length = Math.max(1, end - start)
  var fraction = clamp((nowMs - start) / length, 0, 1)
  return {
    start: start,
    end: end,
    durationMs: length,
    fraction: fraction,
    remainingMs: Math.max(0, end - Math.max(nowMs, start))
  }
}
