import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/u.nut" import isEqual
from "%rGui/wwMap/wwBattlesStates.nut" import updateBattlesStates
from "%rGui/wwMap/wwArmyStates.nut" import updateArmiesState
from "%rGui/wwMap/wwArtilleryStrikeStates.nut" import updateArtilleryStrikeStates, updateArtilleryAction
from "%rGui/wwMap/wwTransportUtils.nut" import updateTransportAction
from "%rGui/wwMap/wwAirfieldsStates.nut" import updateAirfieldsStates
from "%rGui/wwMap/wwOperationStates.nut" import updateOperationState
from "worldwar" import wwGetZonesState, wwGetSectorSprites, wwGetLoadedTransport
from "dagor.workcycle" import setInterval, clearTimer
from "%rGui/globals/ui_library.nut" import *


let zonesSides = Watched([])
let zonesConnectedToRear = Watched([])
let zonesHighlightedFlag = Watched([])
let sectorSprites = Watched([])
let loadedTransport = Watched(null)

let cursorPosition = Watched(null)
let isShiftPressed = Watched(false)

function updateZonesState() {
  let { zSides = [], zConnectedToRear = [], zHighlightFlag = [] } = wwGetZonesState()
  if (!isEqual(zSides, zonesSides.get()))
    zonesSides.set(zSides)

  if (!isEqual(zConnectedToRear, zonesConnectedToRear.get()))
    zonesConnectedToRear.set(zConnectedToRear)

  if (!isEqual(zHighlightFlag, zonesHighlightedFlag.get()))
    zonesHighlightedFlag.set(zHighlightFlag)
}

function updateSectorSprites() {
  let ss = wwGetSectorSprites()
  if (!isEqual(ss, sectorSprites.get()))
    sectorSprites.set(ss)
}

function updateLoadedTransport() {
  let lt = DataBlock()
  wwGetLoadedTransport(lt)
  let loadedTransportCount = lt?.loadedTransport.blockCount() ?? 0
  let storedLoadedTransportCount = loadedTransport.get()?.loadedTransport.blockCount() ?? 0
  if (loadedTransportCount != storedLoadedTransportCount)
    loadedTransport.set(lt)
}

function updateWatches() {
  updateZonesState()
  updateSectorSprites()
  updateArmiesState()
  updateLoadedTransport()
  updateBattlesStates()
  updateArtilleryStrikeStates()
  updateArtilleryAction()
  updateTransportAction()
  updateAirfieldsStates()
  updateOperationState()
}

return {
  zonesSides
  zonesConnectedToRear
  zonesHighlightedFlag
  sectorSprites
  loadedTransport
  startUpdates = @() setInterval(0.1, updateWatches)
  stopUpdates = @() clearTimer(updateWatches)
  cursorPosition
  isShiftPressed
}
