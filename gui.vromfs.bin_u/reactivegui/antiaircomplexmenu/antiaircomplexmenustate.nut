from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let { playerUnitName, isUnitAlive } = require("%rGui/hudState.nut")
let { isInFlight } = require("%rGui/globalState.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")
let { getAAComplexMenuConfigPath, canEnterAAComplexMenu } = require("guiRadar")
let { showAAComplexMenu } = require("controls")
let { defaultFilters } = require("%rGui/radarFiltersConfig.nut")
let DataBlock = require("DataBlock")
let { tryLoadBlk } = require("blkLoad")

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
        if (!type(val) == "bool"){
          continue
        }
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