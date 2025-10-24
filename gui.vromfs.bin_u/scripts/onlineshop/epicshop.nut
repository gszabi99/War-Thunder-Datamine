from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

require("ingameConsoleStore.nut")
let statsd = require("statsd")

let seenEnumId = SEEN.EXT_EPIC_SHOP

let seenList = require("%scripts/seen/seenList.nut").get(seenEnumId)
let { catalog, canUseIngameShop, getShopItem, requestData, isLoadingInProgress
} = require("%scripts/onlineShop/epicShopData.nut")

let sheetsArray = [
  {
    id = "epic_game_gold"
    locId = "itemTypes/epicGameGold"
    getSeenId = @() "##epic_item_sheet_gold"
    mediaType = "gold"
    sortParams = [
      { param = "price", asc = false }
      { param = "price", asc = true }
    ]
    sortSubParam = "name"
    contentTypes = ["eagles"]
  },
  {
    id = "epic_game_items"
    locId = "itemTypes/epicGameContent"
    getSeenId = @() "##epic_item_sheet_dlc"
    mediaType = "dlc"
    sortParams = [
      { param = "price", asc = false }
      { param = "price", asc = true }
      { param = "isBought", asc = false }
      { param = "isBought", asc = true }
    ]
    sortSubParam = "name"
    contentTypes = [null, ""]
  }
]

foreach (sh in sheetsArray) {
  local sheet = sh
  seenList.setSubListGetter(sheet.getSeenId(), @() (
    catalog.get()?[sheet.mediaType] ?? []).filter(@(item) !item.canBeUnseen()).map(@(item) item.getSeenId())
  )
}


gui_handlers.EpicShop <- class (gui_handlers.IngameConsoleStore) {
  needWaitIcon = true
  isLoadingInProgress = false

  function loadCurSheetItemsList() {
    this.itemsList = this.itemsCatalog?[this.curSheet.mediaType] ?? []
  }

  function onEventEpicShopItemUpdated(_p) {
    this.updateSorting()
    this.fillItemsList()
  }

  function onEventEpicShopDataUpdated(p) {
    this.isLoadingInProgress = p?.isLoadingInProgress ?? false
    this.fillItemsList()
    this.updateItemInfo()
  }
}

let openIngameStore = kwarg(
  function(chapter = null, curItemId = "", afterCloseFunc = null,
    statsdMetric = "unknown", unitName = "") {
    if (!isInArray(chapter, [null, "", "eagles"]))
      return false

    if (canUseIngameShop()) {
      statsd.send_counter("sq.ingame_store.open", 1, { origin = statsdMetric })
      let item = getShopItem(curItemId)
      requestData(@() handlersManager.loadHandler(gui_handlers.EpicShop, {
        itemsCatalog = catalog.get()
        isLoadingInProgress = isLoadingInProgress.get()
        chapter = chapter
        curItem = item
        afterCloseFunc = afterCloseFunc
        titleLocId = ""
        storeLocId = "items/openIn/EpicGameStore"
        seenEnumId = seenEnumId
        seenList = seenList
        sheetsArray = sheetsArray
      }))
      return true
    }

    return false
  }
)

return {
  openIngameStore
  getEntStoreLocId = @() canUseIngameShop() ? "#topmenu/xboxIngameShop" : "#msgbox/btn_onlineShop"
  getEntStoreIcon = @() canUseIngameShop() ? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
  isEntStoreTopMenuItemHidden = @(...) !canUseIngameShop() || !isInMenu.get()
  getEntStoreUnseenIcon = @() seenEnumId
  openEntStoreTopMenuFunc = @(_obj, _handler) openIngameStore({ statsdMetric = "topmenu" })
}
