from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { eventbus_send } = require("eventbus")
let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")
let { refreshExtInventory, markInventoryUpdateDelayed } = require("%scripts/items/itemsManager.nut")
let { isShowItemInTrophyReward } = require("%scripts/items/trophyReward.nut")

let CraftProcess = class (ItemExternal) {
  static iType = itemType.CRAFT_PROCESS
  static name = "CraftProcess"
  static defaultLocId = "craft_part"
  static typeIcon = "#ui/gameuiskin#item_type_craftpart.svg"

  static itemExpiredLocId = "items/craft_process/finished"
  static descReceipesListWithCurQuantities = false

  isDisassemble       = @() this.itemDef?.tags.isDisassemble == true
  canConsume          = @() false
  canAssemble         = @() false
  canConvertToWarbonds = @() false
  hasLink             = @() false

  getMainActionData   = @(...) null
  doMainAction        = @(...) false
  getAltActionName    = @(...) ""
  doAltAction         = @(...) false

  shouldShowAmount    = @(count) count >= 0
  getDescRecipeListHeader = @(...) loc("items/craft_process/using") 
  getMarketablePropDesc = @() ""

  function cancelCrafting(_cb = null, params = null) {
    if (this.uids.len() > 0) {
      let parentItem = params?.parentItem
      let item = this
      let text = loc(this.getLocIdsList().msgBoxConfirm,
        { itemName = colorize("activeTextColor", parentItem ? parentItem.getName() : this.getName()) })
      scene_msg_box("craft_canceled", null, text, [
        [ "yes", @() inventoryClient.cancelDelayedExchange(item.uids[0],
                     @(resultItems) item.onCancelComplete(resultItems, params),
                     @(_errorId) item.showCantCancelCraftMsgBox()) ],
        [ "no" ]
      ], "yes", { cancel_fn = function() {} })
      return true
    }

    this.showCantCancelCraftMsgBox()
    return true
  }

  showCantCancelCraftMsgBox = @() scene_msg_box("cant_cancel_craft",
    null,
    colorize("badTextColor", loc(this.getCantUseLocId())),
    [["ok", @() refreshExtInventory()]],
    "ok")

  function onCancelComplete(resultItems, params) {
    markInventoryUpdateDelayed()

    let resultItemsShowOpening  = resultItems.filter(isShowItemInTrophyReward)
    let trophyId = this.id
    if (resultItemsShowOpening.len()) {
      let openTrophyWndConfigs = resultItemsShowOpening.map(@(extItem) {
        id = trophyId
        item = extItem?.itemdef.itemdefid
        count = extItem?.quantity ?? 0
      })
      eventbus_send("guiStartOpenTrophy", {
        [trophyId.tostring()] = openTrophyWndConfigs,
        rewardTitle = loc(this.getLocIdsList().cancelTitle),
        rewardListLocId = this.getItemsListLocId(),
        isHidePrizeActionBtn = params?.isHidePrizeActionBtn ?? false
      })
    }
  }

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    msgBoxCantUse = "".concat("msgBox/cancelCraftProcess/cant",
      (this.isDisassemble() ? "/disassemble" : ""))
    msgBoxConfirm = "".concat("msgBox/cancelCraftProcess/confirm",
      (this.isDisassemble() ? "/disassemble" : ""))
    cancelTitle   = "".concat("mainmenu/craftCanceled/title",
      (this.isDisassemble() ? "/disassemble" : ""))
  })
}

registerItemClass(CraftProcess)
