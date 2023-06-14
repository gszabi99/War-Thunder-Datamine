//checked for plus_string
from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")

local cachedLoadedTransport = null
let function getLoadedTransport() {
  if (cachedLoadedTransport != null)
    return cachedLoadedTransport?.loadedTransport ?? {}

  let blk = DataBlock()
  ::ww_get_loaded_transport(blk)
  cachedLoadedTransport = blk
  return cachedLoadedTransport?.loadedTransport ?? {}
}

let clearCacheLoadedTransport = @() cachedLoadedTransport = null

let function isEmptyTransport(armyName) {
  return !(armyName in getLoadedTransport())
}

let function isFullLoadedTransport(armyName) {
  return armyName in getLoadedTransport()
}

subscriptions.addListenersWithoutEnv({
  WWLoadOperation = @(_p) clearCacheLoadedTransport()
})

let function getTransportedArmiesData(formation) {
  let armies = []
  let loadedTransport = getLoadedTransport()
  let transportedArmies = loadedTransport?[formation.name].armies ?? formation?.loadedArmies
  local totalUnitsNum = 0
  if (transportedArmies != null)
    for (local i = 0; i < transportedArmies.blockCount(); i++) {
      let armyBlk = transportedArmies.getBlock(i)
      let army  = ::WwArmy(armyBlk.getBlockName(), armyBlk)
      armies.append(army)
      totalUnitsNum += army.getUnits().len()
    }

  return { armies, totalUnitsNum }
}

return {
  getLoadedTransport
  getTransportedArmiesData
  isEmptyTransport
  isFullLoadedTransport
}