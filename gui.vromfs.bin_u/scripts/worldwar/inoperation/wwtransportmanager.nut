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

return {
  getLoadedTransport
  isEmptyTransport
  isFullLoadedTransport
}