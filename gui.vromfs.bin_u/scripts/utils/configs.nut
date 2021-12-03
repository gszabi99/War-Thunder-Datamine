local ConfigBase = require("configBase.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local configs = {
  PRICE = {
    getImpl = ::get_price_blk
    isActual = ::is_price_actual
    requestUpdate = ::req_price_from_server
    cbName = "PriceUpdated"
    onConfigUpdate = @() ::g_discount.updateDiscountData()
  }

  ENTITLEMENTS_PRICE = {
    getImpl = ::get_entitlements_price_blk
    isActual = ::is_entitlements_price_actual
    requestUpdate = ::req_entitlements_price_from_server
    cbName = "EntitlementsPriceUpdated"
    onConfigUpdate = @() ::g_discount.updateDiscountData()
  }

  GUI = {
    getImpl = function() {
      local blk = ::DataBlock()
      try {
        blk.load("config/gui.blk")
      }
      catch (e) {
      }
      return blk
    }
    needScriptedCache = true
  }

  AVATARS = {
    getImpl = function() {
      local blk = ::DataBlock()
      try {
        blk.load("config/avatars.blk")
      }
      catch (e) {
      }
      return blk
    }
    needScriptedCache = true
  }
}
  .map(@(cData, id) ConfigBase(cData.__merge({ id })))

addListenersWithoutEnv({
  AuthorizeComplete = @(p) configs.each(@(cfg) cfg.invalidateCache())
},
  ::g_listener_priority.CONFIG_VALIDATION)

return configs