from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { enumsAddTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { wwGetPlayerSide } = require("worldwar")

let g_ww_map_info_type = {
  types = []
  cache = {
    byIndex = {}
  }
  template = {
    getMainBlockHandler = function(_placeObj, _side = SIDE_NONE) { return null }
  }
}

g_ww_map_info_type.getTypeByIndex <- function getTypeByIndex(index) {
  return enumsGetCachedType("index", index, g_ww_map_info_type.cache.byIndex, g_ww_map_info_type, g_ww_map_info_type.UNKNOWN)
}

enumsAddTypes(g_ww_map_info_type, {
  UNKNOWN = {
    index = -1
  }

  OBJECTIVE = {
    index = 0
    getMainBlockHandler = function(placeObj, side = null, handlerParams = null) {
      return handlersManager.loadHandler(gui_handlers.wwObjective, {
        scene = placeObj,
        side = side || wwGetPlayerSide()
        restrictShownObjectives = true
      }.__update(handlerParams))
    }
  }

  LOG = {
    index = 1
    getMainBlockHandler = function(placeObj, side = null, handlerParams = null) {
      return handlersManager.loadHandler(gui_handlers.WwOperationLog, {
        scene = placeObj,
        side = side || wwGetPlayerSide()
      }.__update(handlerParams))
    }
  }
}, null, "name")

return {
  g_ww_map_info_type
}