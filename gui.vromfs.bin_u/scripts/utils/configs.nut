::g_script_reloader.loadOnce("scripts/utils/configBase.nut")

::configs <- {
  list = []
}

local configs_init_tbl = {
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

foreach(id, cData in configs_init_tbl)
{
  cData.id <- id
  local cfg = ::ConfigBase(cData)
  ::configs[id] <- cfg
  ::configs.list.append(cfg)
}



configs.onEventAuthorizeComplete <- function onEventAuthorizeComplete(p)
{
  foreach(cfg in list)
    cfg.invalidateCache()
}

::subscribe_handler(::configs, ::g_listener_priority.CONFIG_VALIDATION)