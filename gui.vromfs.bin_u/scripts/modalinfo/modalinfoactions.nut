from "%scripts/dagui_library.nut" import *

let { defer } = require("dagor.workcycle")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let guiStartWeaponryPresets = require("%scripts/weaponry/guiStartWeaponryPresets.nut")
let { destroyModalInfo } = require("%scripts/modalInfo/modalInfo.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { eventbus_send} = require("eventbus")


function doAction(obj, curEdiff) {
  let destination = obj.destination
  let unit = obj?.unit ? getAircraftByName(obj.unit) : getShowedUnit()

  if (["protection", "xray"].contains(destination)) {
    broadcastEvent("ChangeDMVieverMode", { page = destination })
    obj.getScene().performDelayed(this, @() unit.doPreview())
  }
  else if (destination == "secondaryWeapon")
    guiStartWeaponryPresets({ unit, curEdiff })

  else if (destination == "analysis") {
    if (get_cur_gui_scene().isInAct())
      defer(@() handlersManager.animatedSwitchScene(@() handlersManager.loadHandler(gui_handlers.ProtectionAnalysis, { unit = unit })))
    else
      handlersManager.animatedSwitchScene(@() handlersManager.loadHandler(gui_handlers.ProtectionAnalysis, { unit = unit }))
  }
  else if (destination == "trajectory") {
    let ammoName = obj?.id ?? ""
    eventbus_send("trajectory_btn_clicked", {
      unit
      ammoName
      applySelectedOptionAfterInit = true
    })
  }
  destroyModalInfo()
}

return {
  doAction
}