from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { wwGetPlayerSide } = require("worldwar")

::g_ww_map_reinforcement_tab_type <- {
  types = []
  cache = {
    byCode = {}
  }
  template = {
    getHandler = function (_placeObj) { return null }
    needAutoSwitch = @() false
    getTabTextPostfix = function() { return "" }
  }
}


enums.addTypesByGlobalName("g_ww_map_reinforcement_tab_type", {
  UNKNOWN = {
    code = -1
  }


  COMMANDERS = {
    code = 0
    tabId = "commanders_block"
    tabIcon = "worldWar/iconCommander"
    tabText = "worldwar/commanders"
    getHandler = function (placeObj) {
      return handlersManager.loadHandler(
        gui_handlers.WwCommanders,
        { scene = placeObj }
      )
    }
  }


  REINFORCEMENT = {
    code = 1
    tabId = "reinforcements_block"
    tabIcon = "worldWar/iconReinforcement"
    tabText = "worldWar/Reinforcements"
    needAutoSwitch = @() ::g_world_war.getMyReadyReinforcementsArray().len() > 0
    getTabTextPostfix = function() {
      let availReinf = ::g_world_war.getMyReadyReinforcementsArray().len()
      if (availReinf > 0)
        return loc("ui/parentheses/space", { text = availReinf })
      return ""
    }
    getHandler = function (placeObj) {
      return handlersManager.loadHandler(
        gui_handlers.WwReinforcements,
        { scene = placeObj }
      )
    }
  }


  AIRFIELDS = {
    code = 2
    tabId = "airfields_block"
    tabIcon = "worldwar/iconAir"
    tabText = "worldWar/airfieldsList"
    getHandler = function (placeObj) {
      return handlersManager.loadHandler(
        gui_handlers.WwAirfieldsList,
        {
          scene = placeObj
          side = wwGetPlayerSide()
        }
      )
    }
  }


  ARMIES = {
    code = 3
    tabId = "armies_block"
    tabIcon = "worldWar/iconArmy"
    tabText = "worldWar/armies"
    getTabTextPostfix = function() {
      local commonCount = 0
      local surroundedCount = 0
      foreach (armiesData in ::g_operations.getArmiesCache()) {
        commonCount += (armiesData?.common ?? []).len()
        surroundedCount += (armiesData?.surrounded ?? []).len()
      }

      let countText = "".concat(commonCount.tostring(),
        (surroundedCount > 0 ? "".concat("+", colorize("armySurroundedColor", surroundedCount)) : ""))

      return loc("ui/parentheses/space", { text = countText })
    }
    getHandler = function (placeObj) {
      return handlersManager.loadHandler(
        gui_handlers.WwArmiesList,
        {
          scene = placeObj
        }
      )
    }
  }
}, null, "name")


::g_ww_map_reinforcement_tab_type.getTypeByCode <- function getTypeByCode(code) {
  return enums.getCachedType(
    "code",
    code,
    this.cache.byCode,
    this,
    this.UNKNOWN
  )
}
