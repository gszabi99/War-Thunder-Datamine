from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/items/listPopupWnd/itemsListWndBase.nut" import ItemsListWndBase
from "%scripts/unit/unitInfo.nut" import getUnitName
from "%scripts/items/itemsManagerModule.nut" import getUniversalSparesForUnit
from "%scripts/clientState/localProfileDeprecated.nut" import loadLocalByAccount, saveLocalByAccount
from "%scripts/respawn/respawnDailyFreeSpare.nut" import createDailyFreeSpareItem
from "guiRespawn" import getNumFreeSparesPerDay
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

const NEED_SKIP_SPARE_ACTIVATION_CONFIRM_SAVE_ID = "needSkipSpareActivationConfirm"

let RespawnSpareWnd = class (ItemsListWndBase) {
  sceneTplName = "%gui/respawn/respawnSpareWnd.tpl"

  unit = null
  onOkCb = null

  function initScreen() {
    base.initScreen()

    let needSkipConfirm = loadLocalByAccount(NEED_SKIP_SPARE_ACTIVATION_CONFIRM_SAVE_ID, false)
    this.scene.findObject("noConfirmActivation").setValue(needSkipConfirm)

    let firstNotLockedIdx = this.itemsList.findindex(@(item) !item?.isItemLocked()) ?? 0
    this.scene.findObject("items_list").setValue(firstNotLockedIdx)
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

register_gui_handler("RespawnSpareWnd", RespawnSpareWnd)

function openRespawnSpareWnd(unit, onOkCb, alignObj, showDailySparesOnly) {
  if (unit == null)
    return

  let itemsList = []

  if (getNumFreeSparesPerDay() > 0) 
    itemsList.append(createDailyFreeSpareItem())

  if (!showDailySparesOnly)
    itemsList.extend(getUniversalSparesForUnit(unit))

  if (itemsList.len() == 0)
    return

  handlersManager.loadHandler(RespawnSpareWnd, {
    unit
    itemsList
    alignObj
    align = ALIGN.TOP
    onOkCb
    showAmount = false
  })
}

return freeze({
  openRespawnSpareWnd
})