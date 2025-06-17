from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let { playerUnitName, isUnitAlive } = require("%rGui/hudState.nut")
let { isInFlight } = require("%rGui/globalState.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")
let { getAAComplexMenuConfigPath, canEnterAAComplexMenu } = require("guiRadar")
let DataBlock = require("DataBlock")

let onAAComplexMenuRequest = @(evt) isAAComplexMenuActive.set(evt.show)
let hideAAComplexMenu = @() isAAComplexMenuActive.set(false)

eventbus_subscribe("on_aa_complex_menu_request", onAAComplexMenuRequest)

isInFlight.subscribe(@(v) !v ? hideAAComplexMenu() : null)
isUnitAlive.subscribe(@(v) !v ? hideAAComplexMenu() : null)

let aaMenuCfgDefaults = {
  hasTurretView = true

  hasVerticalView = true
  verticalViewMaxAltitude = 12.0

  hasTargetList = true
}
local aaMenuCfg = Watched(clone aaMenuCfgDefaults)

function updateCfg(){
  aaMenuCfg.mutate(function(cfg) {
    let blk = DataBlock()
    let path = getAAComplexMenuConfigPath()
    if (path && blk.tryLoad(path)) {
      let cfgBlk = blk.getBlockByNameEx("antiAirComplexMenu")

      cfg["hasTurretView"] = cfgBlk.getBool("hasTurretView", aaMenuCfgDefaults.hasTurretView)
      cfg["hasVerticalView"] = cfgBlk.getBool("hasVerticalView", aaMenuCfgDefaults.hasVerticalView)
      cfg["verticalViewMaxAltitude"] = cfgBlk.getReal("verticalViewMaxAltitude", aaMenuCfgDefaults.verticalViewMaxAltitude)
      cfg["hasTargetList"] = cfgBlk.getBool("hasTargetList", aaMenuCfgDefaults.hasTargetList)
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