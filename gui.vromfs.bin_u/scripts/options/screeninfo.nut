from "%scripts/dagui_library.nut" import *

let { round } = require("math")

function isTripleHead(sw = null, sh = null) {
  sw = sw ?? screen_width()
  sh = sh ?? screen_height()
  return sw >= sh * 3 * 5 / 4
}

function isUltraWide(sw = null, sh = null) {
  sw = sw ?? screen_width()
  sh = sh ?? screen_height()
  let ratio = 1.0 * sw / sh
  return !isTripleHead(sw, sh) && ratio >= 2.5
}

function getHudWidthLimit() {
  let sw = screen_width()
  let sh = screen_height()
  return isTripleHead(sw, sh) ? (1.0 / 3)
    : isUltraWide(sw, sh) ? (1.0 * sh * 16 / 9 / sw)
    : 1.0
}

function getMenuWidthLimit() {
  return isTripleHead() ? (1.0 / 3) : 1.0
}

function getFinalSafearea(safearea, widthLimit) {
  if (widthLimit < 1.0 && safearea < 1.0 && isTripleHead())
    widthLimit = widthLimit * safearea
  return [ min(safearea, widthLimit), safearea ]
}

function getMainScreenSizePx(sw = null, sh = null) {
  sw = sw ?? screen_width()
  sh = sh ?? screen_height()
  if (isTripleHead(sw, sh))
    sw = sw / 3
  return [ sw, sh ]
}

function getScreenHeightForFonts(sw, sh) {
  let scr = getMainScreenSizePx(sw, sh)
  let height = min(0.75 * max(scr[0], scr[1]), min(scr[1], scr[0]))
  return round(height).tointeger()
}

return {
  isUltraWide = isUltraWide
  getHudWidthLimit = getHudWidthLimit
  getMenuWidthLimit = getMenuWidthLimit
  getFinalSafearea = getFinalSafearea
  getMainScreenSizePx = getMainScreenSizePx
  getScreenHeightForFonts = getScreenHeightForFonts
}
