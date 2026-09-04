from "%rGui/wwMap/wwMapUtils.nut" import sendToDagui
from "worldwar" import wwGetCurrActionType
from "%rGui/globals/ui_library.nut" import *

let { actionType } = require("%rGui/wwMap/wwMapTypes.nut")

let haveActiveAction = @() wwGetCurrActionType() != actionType.AUT_None

let doAction = @(pos) sendToDagui("ww.doAction", { action = wwGetCurrActionType(), pos })

let moveArmy = @(targetArmyName, pos, append) sendToDagui("ww.moveArmy", { targetArmyName, pos, append })

let sendAircraft = @(airField, armyTargetName, pos) sendToDagui("ww.sendAircraft", { airfieldIdx = airField.airfieldIdx, armyTargetName, pos })

let isTransportLoad = @() wwGetCurrActionType() == actionType.AUT_TransportLoad

let isTransportUnload = @() wwGetCurrActionType() == actionType.AUT_TransportUnload

let isArtilleryFire = @() wwGetCurrActionType() == actionType.AUT_ArtilleryFire



return {
  haveActiveAction
  isArtilleryFire
  isTransportLoad
  isTransportUnload
  doAction
  moveArmy
  sendAircraft
}