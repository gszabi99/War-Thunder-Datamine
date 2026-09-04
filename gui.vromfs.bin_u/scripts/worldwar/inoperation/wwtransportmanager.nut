import "DataBlock" as DataBlock
from "worldwar" import wwGetLoadedTransport
from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")

local cachedLoadedTransport = null
function getLoadedTransport() {
  if (cachedLoadedTransport != null)
    return cachedLoadedTransport?.loadedTransport ?? {}

  let blk = DataBlock()
  wwGetLoadedTransport(blk)
  cachedLoadedTransport = blk
  return cachedLoadedTransport?.loadedTransport ?? {}
}

let clearCacheLoadedTransport = @() cachedLoadedTransport = null

function isEmptyTransport(armyName) {
  return !(armyName in getLoadedTransport())
}

function isFullLoadedTransport(armyName) {
  return armyName in getLoadedTransport()
}

subscriptions.addListenersWithoutEnv({
  WWLoadOperation = @(_p) clearCacheLoadedTransport()
})

return {
  getLoadedTransport
  isEmptyTransport
  isFullLoadedTransport
  clearCacheLoadedTransport
}
