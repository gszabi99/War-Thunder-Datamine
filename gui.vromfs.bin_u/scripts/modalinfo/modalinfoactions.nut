from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "dagor.workcycle" import defer
from "eventbus" import eventbus_send
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let guiStartWeaponryPresets = require("%scripts/weaponry/guiStartWeaponryPresets.nut")
let { destroyModalInfo } = require("%scripts/modalInfo/modalInfo.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")


function doAction(obj, curEdiff) {
  let destination = obj.destination
  let unitName = obj?.unit ?? ""
  let unit = unitName != "" ? getAircraftByName(unitName) : getShowedUnit()

  if (["protection", "xray"].contains(destination)) {
    if (unit == null)
      return
    broadcastEvent("ChangeDMVieverMode", { page = destination })
    obj.getScene().performDelayed(this, @() unit.doPreview())
  }
  else if (destination == "secondaryWeapon")
    guiStartWeaponryPresets({ unit, curEdiff })

  else if (destination == "analysis") {
    if (get_cur_gui_scene().isInAct())
      defer(@() handlersManager.animatedSwitchScene(@() handlersManager.loadHandler(get_gui_handler("ProtectionAnalysis"), { unit = unit })))
    else
      handlersManager.animatedSwitchScene(@() handlersManager.loadHandler(get_gui_handler("ProtectionAnalysis"), { unit = unit }))
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