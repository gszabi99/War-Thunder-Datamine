from "%rGui/globals/ui_library.nut" import *
let { wwGetCurrActionType } = require("worldwar")
let { actionType } = require("%rGui/wwMap/wwMapTypes.nut")
let { selectedArmy } = require("%rGui/wwMap/wwArmyStates.nut")

let transportReadyToUnload = Watched(null)
let transportReadyToLoad = Watched(null)

let isTransport = @(armyData) armyData?.specs.transportInfo.type != "TT_NONE"

function getLoadedArmyType(armyData, loadedTransport) {
  let lt = loadedTransport?.loadedTransport
  if (lt == null)
    return "UT_NONE"

  let armies = lt.getBlockByName(armyData.name)
  if (armies == null)
    return "UT_NONE"

  let army = armies.armies.getBlock(0)
  let armyType = army.specs.unitType
  if (army.iconOverride == "infantry" && armyType == "UT_GROUND")
    return "UT_INFANTRY";
  return armyType
}

function getLoadedArmyName(armyData, loadedTransport) {
  let lt = loadedTransport?.loadedTransport
  if (lt == null)
    return ""

  let armies = lt.getBlockByName(armyData.name)
  if (armies == null)
    return ""

  return armies.armies.getBlock(0).getBlockName()
}

function getLoadedArmy(armyData, loadedTransport) {
  let lt = loadedTransport?.loadedTransport
  if (lt == null)
    return ""

  let armies = lt.getBlockByName(armyData.name)
  if (armies == null)
    return ""

  return armies.armies.getBlock(0)
}

function updateTransportAction() {
  let currActionType = wwGetCurrActionType()
  if (currActionType == actionType.AUT_TransportUnload) {
    transportReadyToUnload.set(selectedArmy.get())
    transportReadyToLoad.set(null)
  }
  else if (currActionType == actionType.AUT_TransportLoad) {
    transportReadyToLoad.set(selectedArmy.get())
    transportReadyToUnload.set(null)
  }
  else {
    transportReadyToUnload.set(null)
    transportReadyToLoad.set(null)
  }
}

return {
  isTransport
  getLoadedArmyType
  getLoadedArmyName
  getLoadedArmy
  updateTransportAction
  transportReadyToUnload
  transportReadyToLoad
}