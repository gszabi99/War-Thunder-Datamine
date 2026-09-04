from "%appGlobals/worldWar/wwOperationState.nut" import isOperationPaused
from "worldwar" import wwGetPlayerSide
from "%rGui/globals/ui_library.nut" import *

let { zoneSideTypeStr } = require("%rGui/wwMap/wwMapTypes.nut")

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