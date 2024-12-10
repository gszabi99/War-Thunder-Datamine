from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")

let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isUnitFeatureLocked } = require("%scripts/unit/unitStatus.nut")

function checkFeatureLock(unit, lockAction) {
  if (!isUnitFeatureLocked(unit))
    return true
  let params = {
    purchaseAvailable = hasFeature("OnlineShopPacks")
    featureLockAction = lockAction
    unit = unit
  }

  loadHandler(gui_handlers.VehicleRequireFeatureWindow, params)
  return false
}

return {
  checkFeatureLock
}