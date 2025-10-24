from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { ItemsListWndBase } = require("%scripts/items/listPopupWnd/itemsListWndBase.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getUniversalSparesForUnit } = require("%scripts/items/itemsManagerModule.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getNumFreeSparesPerDay } = require("guiRespawn")
let { createDailyFreeSpareItem } = require("%scripts/respawn/respawnDailyFreeSpare.nut")

const NEED_SKIP_SPARE_ACTIVATION_CONFIRM_SAVE_ID = "needSkipSpareActivationConfirm"

let RespawnSpareWnd = class (ItemsListWndBase) {
  sceneTplName = "%gui/respawn/respawnSpareWnd.tpl"

  unit = null
  onOkCb = null

  function initScreen() {
    base.initScreen()

    let needSkipConfirm = loadLocalByAccount(NEED_SKIP_SPARE_ACTIVATION_CONFIRM_SAVE_ID, false)
    this.scene.findObject("noConfirmActivation").setValue(needSkipConfirm)
  }

  function onActivate() {
    let needSkipConfirm = loadLocalByAccount(NEED_SKIP_SPARE_ACTIVATION_CONFIRM_SAVE_ID, false)
    if (needSkipConfirm) {
      this.onOkCb(this.curItem)
      this.goBack()
      return
    }

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

  onNoConfirmActivationChange =
    @(obj) saveLocalByAccount(NEED_SKIP_SPARE_ACTIVATION_CONFIRM_SAVE_ID, obj.getValue())

  onAmountInc = @() null
  onAmountDec = @() null
  onAmountChange = @() null
}

gui_handlers.RespawnSpareWnd <- RespawnSpareWnd

function openRespawnSpareWnd(unit, onOkCb, alignObj, align = ALIGN.TOP) {
  if (unit == null)
    return

  let itemsList = []

  if (getNumFreeSparesPerDay() > 0) 
    itemsList.append(createDailyFreeSpareItem())

  itemsList.extend(getUniversalSparesForUnit(unit))

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