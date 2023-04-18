//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

require("ingameConsoleStore.nut")
let statsd = require("statsd")

let seenEnumId = SEEN.EXT_EPIC_SHOP

let seenList = require("%scripts/seen/seenList.nut").get(seenEnumId)
let shopData = require("%scripts/onlineShop/epicShopData.nut")

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
    shopData.catalog.value?[sheet.mediaType] ?? []).filter(@(item) !item.canBeUnseen()).map(@(item) item.getSeenId())
  )
}


::gui_handlers.EpicShop <- class extends ::gui_handlers.IngameConsoleStore {
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
    statsdMetric = "unknown", unitName = "") {//-declared-never-used -unused-func-param
    if (!isInArray(chapter, [null, "", "eagles"]))
      return false

    if (shopData.canUseIngameShop()) {
      statsd.send_counter("sq.ingame_store.open", 1, { origin = statsdMetric })
      let item = shopData.getShopItem(curItemId)
      shopData.requestData(@() ::handlersManager.loadHandler(::gui_handlers.EpicShop, {
        itemsCatalog = shopData.catalog.value
        isLoadingInProgress = shopData.isLoadingInProgress.value
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

return shopData.__merge({
  openIngameStore = openIngameStore
  getEntStoreLocId = @() shopData.canUseIngameShop() ? "#topmenu/xboxIngameShop" : "#msgbox/btn_onlineShop"
  getEntStoreIcon = @() shopData.canUseIngameShop() ? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
  isEntStoreTopMenuItemHidden = @(...) !shopData.canUseIngameShop() || !::isInMenu()
  getEntStoreUnseenIcon = @() seenEnumId
  needEntStoreDiscountIcon = true
  openEntStoreTopMenuFunc = @(_obj, _handler) openIngameStore({ statsdMetric = "topmenu" })
})