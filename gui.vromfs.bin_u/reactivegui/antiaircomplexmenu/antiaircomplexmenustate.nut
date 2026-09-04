import "DataBlock" as DataBlock
from "%rGui/hudState.nut" import playerUnitName, isUnitAlive
from "%rGui/globalState.nut" import isInFlight
from "%appGlobals/hud/hudState.nut" import isAAComplexMenuActive
from "eventbus" import eventbus_subscribe
from "guiRadar" import getAAComplexMenuConfigPath, canEnterAAComplexMenu
from "controls" import showAAComplexMenu
from "blkLoad" import tryLoadBlk
from "%rGui/globals/ui_library.nut" import *
from "types" import Bool

let { defaultFilters } = require("%rGui/radarFiltersConfig.nut")

let hideAAComplexMenu = @() showAAComplexMenu(false)

eventbus_subscribe("on_aa_complex_menu_request", @(evt) isAAComplexMenuActive.set(evt.show))

isInFlight.subscribe(@(v) !v ? hideAAComplexMenu() : null)
isUnitAlive.subscribe(@(v) !v ? hideAAComplexMenu() : null)

let aaMenuCfgDefaults = {
  hasTurretView = true

  hasVerticalView = true
  verticalViewMaxAltitude = 12.0

  hasTargetList = true
  targetList = defaultFilters
}
local aaMenuCfg = Watched(clone aaMenuCfgDefaults)

function updateCfg(){
  aaMenuCfg.mutate(function(cfg) {
    let blk = DataBlock()
    let path = getAAComplexMenuConfigPath()
    if (path && tryLoadBlk(blk, path)) {
      let cfgBlk = blk.getBlockByNameEx("antiAirComplexMenu")

      cfg["hasTurretView"] = cfgBlk.getBool("hasTurretView", aaMenuCfgDefaults.hasTurretView)
      cfg["hasVerticalView"] = cfgBlk.getBool("hasVerticalView", aaMenuCfgDefaults.hasVerticalView)
      cfg["verticalViewMaxAltitude"] = cfgBlk.getReal("verticalViewMaxAltitude", aaMenuCfgDefaults.verticalViewMaxAltitude)

      cfg["hasTargetList"] = cfgBlk.getBool("hasTargetList", aaMenuCfgDefaults.hasTargetList)

      let targetList = defaultFilters
      let targetListCfg = cfgBlk.getBlockByNameEx("targetList")
      for (local i = 0; i < targetListCfg.paramCount(); i++) {
        let val = targetListCfg.getParamValue(i)
        if (!(val instanceof Bool))
          continue
        let name = targetListCfg.getParamName(i)
        targetList[name] <- val
      }
      cfg.targetList <- targetList

    }
    else {
      cfg.__update(aaMenuCfgDefaults)
    }
  })
}
updateCfg()

function updateAAMenuVisibility() {
  if (!canEnterAAComplexMenu()) {
    hideAAComplexMenu()
  }
}

playerUnitName.subscribe(function(_){
  updateCfg()
  updateAAMenuVisibility()
})

return {
  aaMenuCfg
}