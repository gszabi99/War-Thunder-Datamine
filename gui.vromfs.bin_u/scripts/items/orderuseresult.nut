from "%scripts/dagui_library.nut" import *

let { enumsAddTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")

let g_order_use_result_cache = {
  byCode = {}
}

let order_use_results = {
  OK = {
    code = ORDER_USE_RESULT_OK
    name = "ok"
  }

  BAD_MODE = {
    code = ORDER_USE_RESULT_BAD_MODE
    name = "bad_mode"
  }

  BAD_PLAYER = {
    code = ORDER_USE_RESULT_BAD_PLAYER
    name = "bad_player"
  }

  NO_ITEM = {
    code = ORDER_USE_RESULT_NO_ITEM
    name = "no_item"
  }

  ORDER_RUNNING = {
    code = ORDER_USE_RESULT_ORDER_RUNNING
    name = "order_running"
  }

  COOLDOWN = {
    code = ORDER_USE_RESULT_COOLDOWN
    name = "cooldown"
  }

  BAD_ITEM_CONFIG = {
    code = ORDER_USE_RESULT_BAD_ITEM_CONFIG
    name = "bad_item_config"
  }

  MAX_USES = {
    code = ORDER_USE_RESULT_MAX_USES
    name = "max_uses"
  }

  ALREADY_USED = {
    code = ORDER_USE_RESULT_ALREADY_USED
    name = "already_used"
  }

  MODE_SPECIFIC_ERROR = {
    code = ORDER_USE_RESULT_MODE_SPECIFIC_ERROR
    name = "mode_specific_error"
  }

  UNKNOWN = {
    code = -1
    name = "unknown"
  }

  RESTRICTED_MISSION = {
    code = -2
    name = "restricted_mission"
  }
}

let g_order_use_result = {
  types = []

  function _createResultMessage(addErrorHeader) {
    return (this == order_use_results.OK || !addErrorHeader)
      ? loc($"orderUseResult/result/{this.name}")
      : "".concat(loc("orderUseResult/error"), "\n", loc($"orderUseResult/result/{this.name}"))
  }

  function getOrderUseResultByCode(useResultCode) {
    return enumsGetCachedType("code", useResultCode, g_order_use_result_cache.byCode,
      this, this.UNKNOWN)
  }
}

g_order_use_result.template <- {
  /**
   * Creates text message to show in order
   * activation window, order tooltip, etc.
   */
  createResultMessage = g_order_use_result._createResultMessage
}


enumsAddTypes(g_order_use_result, order_use_results)

return {g_order_use_result}
