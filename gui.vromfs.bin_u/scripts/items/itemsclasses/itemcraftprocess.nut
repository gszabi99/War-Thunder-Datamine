from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let ItemExternal = require("%scripts/items/itemsClasses/itemExternal.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

::items_classes.CraftProcess <- class extends ItemExternal {
  static iType = itemType.CRAFT_PROCESS
  static defaultLocId = "craft_part"
  static typeIcon = "#ui/gameuiskin#item_type_craftpart.svg"

  static itemExpiredLocId = "items/craft_process/finished"
  static descReceipesListWithCurQuantities = false

  isDisassemble       = @() itemDef?.tags?.isDisassemble == true
  canConsume          = @() false
  canAssemble         = @() false
  canConvertToWarbonds= @() false
  hasLink             = @() false

  getMainActionData   = @(...) null
  doMainAction        = @(...) false
  getAltActionName    = @(...) ""
  doAltAction         = @(...) false

  shouldShowAmount    = @(count) count >= 0
  getDescRecipeListHeader = @(...) loc("items/craft_process/using") // there is always 1 recipe
  getMarketablePropDesc = @() ""

  function cancelCrafting(cb = null, params = null)
  {
    if (uids.len() > 0)
    {
      let parentItem = params?.parentItem
      let item = this
      let text = loc(getLocIdsList().msgBoxConfirm,
        { itemName = colorize("activeTextColor", parentItem ? parentItem.getName() : getName()) })
      ::scene_msg_box("craft_canceled", null, text, [
        [ "yes", @() inventoryClient.cancelDelayedExchange(item.uids[0],
                     @(resultItems) item.onCancelComplete(resultItems, params),
                     @(errorId) item.showCantCancelCraftMsgBox()) ],
        [ "no" ]
      ], "yes", { cancel_fn = function() {} })
      return true
    }

    showCantCancelCraftMsgBox()
    return true
  }

  showCantCancelCraftMsgBox = @() ::scene_msg_box("cant_cancel_craft",
    null,
    colorize("badTextColor", loc(getCantUseLocId())),
    [["ok", @() ::ItemsManager.refreshExtInventory()]],
    "ok")

  function onCancelComplete(resultItems, params)
  {
    ::ItemsManager.markInventoryUpdateDelayed()

    let resultItemsShowOpening  = ::u.filter(resultItems, ::trophyReward.isShowItemInTrophyReward)
    let trophyId = id
    if (resultItemsShowOpening.len())
    {
      let openTrophyWndConfigs = ::u.map(resultItemsShowOpening, @(extItem) {
        id = trophyId
        item = extItem?.itemdef?.itemdefid
        count = extItem?.quantity ?? 0
      })
      ::gui_start_open_trophy({ [trophyId] = openTrophyWndConfigs,
        rewardTitle = loc(getLocIdsList().cancelTitle),
        rewardListLocId = getItemsListLocId(),
        isHidePrizeActionBtn = params?.isHidePrizeActionBtn ?? false
      })
    }
  }

  getLocIdsListImpl = @() base.getLocIdsListImpl().__update({
    msgBoxCantUse = "msgBox/cancelCraftProcess/cant"
      + (isDisassemble() ? "/disassemble" : "")
    msgBoxConfirm = "msgBox/cancelCraftProcess/confirm"
      + (isDisassemble() ? "/disassemble" : "")
    cancelTitle   = "mainmenu/craftCanceled/title"
      + (isDisassemble() ? "/disassemble" : "")
  })
}
