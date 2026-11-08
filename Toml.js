.pragma library

// Line-level edits to ~/.config/omarchy/shell.toml that leave every other
// section, comment, and key exactly as it was.

function sectionRange(lines, section) {
  var start = -1
  for (var i = 0; i < lines.length; i++) {
    var m = lines[i].match(/^\s*\[([A-Za-z0-9_-]+)\]\s*(#.*)?$/)
    if (!m) continue
    if (start >= 0) return { start: start, end: i }
    if (m[1] === section) start = i
  }
  return start >= 0 ? { start: start, end: lines.length } : null
}

function keyPattern(key) {
  return new RegExp("^\\s*" + key.replace(/[-]/g, "\\-") + "\\s*=")
}

function readNumber(text, section, key) {
  var lines = String(text || "").split("\n")
  var r = sectionRange(lines, section)
  if (!r) return null
  var pat = keyPattern(key)
  for (var i = r.start + 1; i < r.end; i++) {
    if (!pat.test(lines[i])) continue
    var m = lines[i].match(/=\s*(-?\d+(?:\.\d+)?)/)
    return m ? Number(m[1]) : null
  }
  return null
}

// value === null removes the key, and the section header too once it holds
// no other keys.
function setNumber(text, section, key, value) {
  var lines = String(text || "").split("\n")
  if (lines.length && lines[lines.length - 1] === "") lines.pop()
  var r = sectionRange(lines, section)
  var pat = keyPattern(key)
  var newLine = key + " = " + value

  if (!r) {
    if (value === null) return lines.join("\n") + (lines.length ? "\n" : "")
    if (lines.length && lines[lines.length - 1].trim() !== "") lines.push("")
    lines.push("[" + section + "]", newLine)
    return lines.join("\n") + "\n"
  }

  var at = -1
  for (var i = r.start + 1; i < r.end; i++) if (pat.test(lines[i])) { at = i; break }

  if (value !== null) {
    if (at >= 0) lines[at] = newLine
    else lines.splice(r.start + 1, 0, newLine)
  } else if (at >= 0) {
    lines.splice(at, 1)
    r.end--
    var others = false
    for (var j = r.start + 1; j < r.end; j++) {
      var t = lines[j].trim()
      if (t !== "" && t.charAt(0) !== "#") { others = true; break }
    }
    if (!others) {
      lines.splice(r.start, r.end - r.start)
      while (lines.length && lines[lines.length - 1].trim() === "") lines.pop()
    }
  }
  return lines.length ? lines.join("\n") + "\n" : ""
}
