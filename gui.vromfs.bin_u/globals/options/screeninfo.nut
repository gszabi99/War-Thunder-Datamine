from "math" import round, min, max



let { screen_width = @() 1920, screen_height = @() 1080 } = require_optional("daguiScene")
let { sw = @(_) screen_width(), sh = @(_) screen_height() } = require_optional("daRg")

let getScreenWidth = @() sw(100)
let getScreenHeight = @() sh(100)

function isTripleHead(swValue = null, shValue = null) {
  swValue = swValue ?? getScreenWidth()
  shValue = shValue ?? getScreenHeight()
  return swValue >= shValue * 3 * 5 / 4
}

function isUltraWide(swValue = null, shValue = null) {
  swValue = swValue ?? getScreenWidth()
  shValue = shValue ?? getScreenHeight()
  let ratio = 1.0 * swValue / shValue
  return !isTripleHead(swValue, shValue) && ratio >= 2.5
}

function getHudWidthLimit() {
  let swValue = getScreenWidth()
  let shValue = getScreenHeight()
  return isTripleHead(swValue, shValue) ? (1.0 / 3)
    : isUltraWide(swValue, shValue) ? (1.0 * shValue * 16 / 9 / swValue)
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

function getMainScreenSizePx(swValue = null, shValue = null) {
  swValue = swValue ?? getScreenWidth()
  shValue = shValue ?? getScreenHeight()
  if (isTripleHead(swValue, shValue))
    swValue = swValue / 3
  return [ swValue, shValue ]
}

function getScreenHeightForFonts(swValue, shValue) {
  let scr = getMainScreenSizePx(swValue, shValue)
  let height = min(0.75 * max(scr[0], scr[1]), min(scr[1], scr[0]))
  return round(height).tointeger()
}

return freeze({
  isUltraWide = isUltraWide
  getHudWidthLimit = getHudWidthLimit
  getMenuWidthLimit = getMenuWidthLimit
  getFinalSafearea = getFinalSafearea
  getMainScreenSizePx = getMainScreenSizePx
  getScreenHeightForFonts = getScreenHeightForFonts
  getScreenWidth
  getScreenHeight
})
