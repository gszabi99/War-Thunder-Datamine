//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")


let BaseItemModClass = require("%scripts/items/itemsClasses/itemModBase.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")

::items_classes.ModOverdrive <- class extends BaseItemModClass {
  static iType = itemType.MOD_OVERDRIVE
  static defaultLocId = "modOverdrive"
  static defaultIcon = "#ui/gameuiskin#overdrive_upgrade_bg"
  static typeIcon = "#ui/gameuiskin#item_type_overdrive.svg"

  canBuy = true
  allowBigPicture = false
  isActiveOverdrive = false

  constructor(blk, invBlk = null, slotData = null) {
    base.constructor(blk, invBlk, slotData)

    this.isActiveOverdrive = slotData?.isActive ?? false
  }

  getConditionsBlk = @(configBlk) configBlk?.modOverdriveParams
  canActivate = @() this.isInventoryItem && !this.isActive()
  isActive = @(...) this.isActiveOverdrive

  getIconMainLayer = @() LayersIcon.findLayerCfg("mod_overdrive")

  function getMainActionData(isShort = false, params = {}) {
    if (this.amount && this.canActivate())
      return {
        btnName = loc("item/activate")
      }

    return base.getMainActionData(isShort, params)
  }

  function doMainAction(cb, handler, params = null) {
    if (this.canActivate())
      return this.activate(cb, handler)
    return base.doMainAction(cb, handler, params)
  }

  function activate(cb, _handler = null) {
    let uid = this.uids?[0]
    if (uid == null)
      return false

    let item = this
    let successCb = function() {
      if (cb)
        cb({ success = true, item = item })
      broadcastEvent("OverdriveActivated")
    }

    let blk = DataBlock()
    blk.uid = uid
    let taskId = ::char_send_blk("cln_activate_mod_overdrive_item", blk)
    return ::g_tasker.addTask(
      taskId,
      {
        showProgressBox = true
        progressBoxDelayedButtons = 30
      },
      successCb
    )
  }
}