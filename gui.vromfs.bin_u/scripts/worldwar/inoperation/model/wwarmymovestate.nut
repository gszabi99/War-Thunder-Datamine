//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")

::g_ww_army_move_state <- {
  types = []
  cache = {
    byName = {}
  }
}

::g_ww_army_move_state.template <- {
  isMove = false
  name = ""
}

enums.addTypesByGlobalName("g_ww_army_move_state", {
  ES_UNKNOWN = {
    isMove = false
  }
  ES_WAIT_FOR_PATH = {
    isMove = false
  }
  ES_WRONG_PATH = {
    isMove = false
  }
  ES_PATH_PASSED = {
    isMove = false
  }
  ES_MOVING_BY_PATH = {
    isMove = true
  }
  ES_STOPED = {
    isMove = false
  }
}, null, "name")

::g_ww_army_move_state.getMoveParamsByName <- function getMoveParamsByName(name) {
  return enums.getCachedType("name", name, ::g_ww_army_move_state.cache.byName, this, this.ES_UNKNOWN)
}
