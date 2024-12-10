from "%rGui/globals/ui_library.nut" import *

let { send } = require("eventbus")
let { getSettings } = require("%appGlobals/worldWar/wwSettings.nut")
let { zoneSideType } = require("%rGui/wwMap/wwMapTypes.nut")
let { getPlayerSide } = require("%rGui/wwMap/wwOperationStates.nut")
let mapColorsCache = {}

function convertColor4(color) {
  let opacity = color.a * 255
  return Color(color.r * opacity, color.g * opacity, color.b * opacity, opacity)
}

function getMapColor(param) {
  if (mapColorsCache?[param] == null)
    mapColorsCache[param] <- convertColor4(getSettings(param))
  return mapColorsCache[param]
}

function selectColorBySide(zoneSide, allyColorKey, enemyColorKey) {
  local playerSide = getPlayerSide()
  playerSide = playerSide == zoneSideType.SIDE_NONE ? zoneSideType.SIDE_1 : playerSide
  let colorKey = (playerSide == zoneSide) ? allyColorKey : enemyColorKey
  return getMapColor(colorKey)
}

function sendToDagui(eventId, params = {}) {
  send("WWMapEvent", { eventId, data = params })
}

return {
  convertColor4
  getMapColor
  selectColorBySide
  sendToDagui
}