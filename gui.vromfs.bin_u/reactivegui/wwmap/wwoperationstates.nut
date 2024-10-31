from "%rGui/globals/ui_library.nut" import *
let { wwIsOperationPaused, wwGetPlayerSide } = require("worldwar")
let { zoneSideTypeStr } = require("%rGui/wwMap/wwMapTypes.nut")

let isOperationPaused = Watched(false)

let getPlayerSide = @() wwGetPlayerSide()
let getPlayerSideStr = @() zoneSideTypeStr[getPlayerSide()]
let isPlayerSide = @(side) getPlayerSide() == side
let isPlayerSideStr = @(side) zoneSideTypeStr[getPlayerSide()] == side

return {
  isOperationPaused
  getPlayerSide
  getPlayerSideStr
  isPlayerSide
  isPlayerSideStr
  updateOperationState = @() isOperationPaused.set(wwIsOperationPaused())
}