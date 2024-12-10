from "%rGui/globals/ui_library.nut" import *
let { wwGetPlayerSide } = require("worldwar")
let { zoneSideTypeStr } = require("%rGui/wwMap/wwMapTypes.nut")
let { isOperationPaused } = require("%appGlobals/worldWar/wwOperationState.nut")

let isOperationPausedWatch = Watched(false)

let getPlayerSide = @() wwGetPlayerSide()
let getPlayerSideStr = @() zoneSideTypeStr[getPlayerSide()]
let isPlayerSide = @(side) getPlayerSide() == side
let isPlayerSideStr = @(side) zoneSideTypeStr[getPlayerSide()] == side

return {
  isOperationPausedWatch
  getPlayerSide
  getPlayerSideStr
  isPlayerSide
  isPlayerSideStr
  updateOperationState = @() isOperationPausedWatch.set(isOperationPaused())
}