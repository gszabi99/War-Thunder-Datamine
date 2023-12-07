from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { ItemsListWndBase } = require("%scripts/items/listPopupWnd/itemsListWndBase.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getUniversalSparesForUnit } = require("%scripts/items/itemsManagerModule.nut")

let RespawnSpareWnd = class (ItemsListWndBase) {
  sceneTplName = "%gui/respawn/respawnSpareWnd.tpl"

  unit = null
  onOkCb = null

  function onActivate() {
    let text = loc("msgbox/activateSpareForUnit", {
      spareName = this.curItem.getName(true)
      unitName = getUnitName(this.unit)
    })
    let onOk = Callback(function() {
      this.onOkCb(this.curItem)
      this.goBack()
    }, this)
    scene_msg_box("activate_spare_msg_box", null, text, [["yes", onOk], ["no"]], "yes")
  }

  onAmountInc = @() null
  onAmountDec = @() null
  onAmountChange = @() null
}

gui_handlers.RespawnSpareWnd <- RespawnSpareWnd

function openRespawnSpareWnd(unit, onOkCb, alignObj, align = ALIGN.TOP) {
  if (unit == null)
    return

  let itemsList = getUniversalSparesForUnit(unit)
  if (itemsList.len() == 0)
    return

  handlersManager.loadHandler(RespawnSpareWnd, {
    unit
    itemsList
    alignObj
    align
    onOkCb
    showAmount = false
  })
}

return {
  openRespawnSpareWnd
}