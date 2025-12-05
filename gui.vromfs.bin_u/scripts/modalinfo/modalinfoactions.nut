from "%scripts/dagui_library.nut" import *

let { defer } = require("dagor.workcycle")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let guiStartWeaponryPresets = require("%scripts/weaponry/guiStartWeaponryPresets.nut")
let { destroyModalInfo } = require("%scripts/modalInfo/modalInfo.nut")


function doAction(obj, curEdiff) {
  let destination = obj.destination
  let unit = getAircraftByName(obj.unit)

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
  destroyModalInfo()
}

return {
  doAction
}