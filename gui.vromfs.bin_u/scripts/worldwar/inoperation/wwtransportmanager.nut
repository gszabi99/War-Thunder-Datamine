local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local cachedLoadedTransport = null
local function getLoadedTransport() {
  if (cachedLoadedTransport != null)
    return cachedLoadedTransport?.loadedTransport ?? {}

  local blk = ::DataBlock()
  ::ww_get_loaded_transport(blk)
  cachedLoadedTransport = blk
  return cachedLoadedTransport?.loadedTransport ?? {}
}

local clearCacheLoadedTransport = @() cachedLoadedTransport = null

local function isEmptyTransport(armyName) {
  return !(armyName in getLoadedTransport())
}

local function isFullLoadedTransport(armyName) {
  return armyName in getLoadedTransport()
}

subscriptions.addListenersWithoutEnv({
  WWLoadOperation = @(p) clearCacheLoadedTransport()
})

local function getTransportedArmiesData(formation)
{
  local armies = []
  local loadedTransport = getLoadedTransport()
  local transportedArmies = loadedTransport?[formation.name].armies ?? formation?.loadedArmies
  local totalUnitsNum = 0
  if(transportedArmies != null)
    for(local i=0; i< transportedArmies.blockCount(); i++)
    {
      local armyBlk = transportedArmies.getBlock(i)
      local army  = ::WwArmy(armyBlk.getBlockName(), armyBlk)
      armies.append(army)
      totalUnitsNum += army.getUnits().len()
    }

  return {armies = armies, totalUnitsNum = totalUnitsNum}
}

return {
  getLoadedTransport = getLoadedTransport
  getTransportedArmiesData = getTransportedArmiesData
  isEmptyTransport = isEmptyTransport
  isFullLoadedTransport = isFullLoadedTransport
}