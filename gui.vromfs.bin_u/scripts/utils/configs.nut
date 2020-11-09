::g_script_reloader.loadOnce("scripts/utils/configBase.nut")

::configs <- {
  list = []
}

::configs_init_tbl <- {
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
    getImpl = function() { return ::DataBlock("config/gui.blk") || ::DataBlock() }
    needScriptedCache = true
  }

  AVATARS = {
    getImpl = function() { return ::DataBlock("config/avatars.blk") || ::DataBlock() }
    needScriptedCache = true
  }
}

foreach(id, cData in ::configs_init_tbl)
{
  cData.id <- id
  local cfg = ::ConfigBase(cData)
  ::configs[id] <- cfg
  ::configs.list.append(cfg)
}
delete configs_init_tbl


configs.onEventAuthorizeComplete <- function onEventAuthorizeComplete(p)
{
  foreach(cfg in list)
    cfg.invalidateCache()
}

::subscribe_handler(::configs, ::g_listener_priority.CONFIG_VALIDATION)