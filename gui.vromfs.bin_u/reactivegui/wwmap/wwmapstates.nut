from "%rGui/globals/ui_library.nut" import *
let DataBlock = require("DataBlock")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { wwGetZonesState, wwGetSectorSprites, wwGetLoadedTransport } = require("worldwar")
let { updateBattlesStates } = require("%rGui/wwMap/wwBattlesStates.nut")
let { updateArmiesState } = require("%rGui/wwMap/wwArmyStates.nut")
let { updateArtilleryStrikeStates, updateArtilleryAction } = require("%rGui/wwMap/wwArtilleryStrikeStates.nut")
let { updateTransportAction } = require("%rGui/wwMap/wwTransportUtils.nut")
let { updateAirfieldsStates } = require("%rGui/wwMap/wwAirfieldsStates.nut")
let { updateOperationState } = require("%rGui/wwMap/wwOperationStates.nut")
let { setInterval, clearTimer } = require("dagor.workcycle")

//watches
let zonesSides = Watched([])
let zonesConnectedToRear = Watched([])
let zonesHighlightedFlag = Watched([])
let sectorSprites = Watched([])
let loadedTransport = Watched(null)

let cursorPosition = Watched(null)

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
  let storedLoadedTransportCount = loadedTransport?.get().loadedTransport.blockCount() ?? 0
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
}
