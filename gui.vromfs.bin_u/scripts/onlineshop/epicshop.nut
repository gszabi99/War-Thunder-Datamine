require("ingameConsoleStore.nut")
local statsd = require("statsd")

local seenEnumId = SEEN.EXT_EPIC_SHOP

local seenList = require("scripts/seen/seenList.nut").get(seenEnumId)
local shopData = require("scripts/onlineShop/epicShopData.nut")

local sheetsArray = [
  {
    id = "epic_game_gold"
    locId = "itemTypes/epicGameGold"
    getSeenId = @() "##epic_item_sheet_" + mediaType
    mediaType = "gold"
    sortParams = [
      {param = "price", asc = false}
      {param = "price", asc = true}
    ]
    sortSubParam = "name"
    contentTypes = ["eagles"]
  },
  {
    id = "epic_game_items"
    locId = "itemTypes/epicGameContent"
    getSeenId = @() "##epic_item_sheet_" + mediaType
    mediaType = "dlc"
    sortParams = [
      {param = "price", asc = false}
      {param = "price", asc = true}
      {param = "isBought", asc = false}
      {param = "isBought", asc = true}
    ]
    sortSubParam = "name"
    contentTypes = [null, ""]
  }
]

foreach (sh in sheetsArray)
{
  local sheet = sh
  seenList.setSubListGetter(sheet.getSeenId(), @() (
    shopData.catalog.value?[sheet.mediaType] ?? []).filter(@(item) !item.canBeUnseen()).map(@(item) item.getSeenId())
  )
}


class ::gui_handlers.EpicShop extends ::gui_handlers.IngameConsoleStore {
  needWaitIcon = true
  isLoadingInProgress = false

  function loadCurSheetItemsList() {
    itemsList = itemsCatalog?[curSheet.mediaType] ?? []
  }

  function onEventEpicShopItemUpdated(p) {
    updateSorting()
    fillItemsList()
  }

  function onEventEpicShopDataUpdated(p) {
    isLoadingInProgress = p?.isLoadingInProgress ?? false
    fillItemsList()
    updateItemInfo()
  }
}

local openIngameStore = ::kwarg(
  function(chapter = null, curItemId = "", afterCloseFunc = null, openedFrom = "unknown") {
    if (!::isInArray(chapter, [null, "", "eagles"]))
      return false

    if (shopData.canUseIngameShop()) {
      statsd.send_counter("sq.ingame_store.open", 1, {origin = openedFrom})
      local item = shopData.getShopItem(curItemId)
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
  getEntStoreLocId = @() shopData.canUseIngameShop()? "#topmenu/xboxIngameShop" : "#msgbox/btn_onlineShop"
  getEntStoreIcon = @() shopData.canUseIngameShop()? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
  isEntStoreTopMenuItemHidden = @(...) !shopData.canUseIngameShop() || !::isInMenu()
  getEntStoreUnseenIcon = @() seenEnumId
  needEntStoreDiscountIcon = true
  openEntStoreTopMenuFunc = @(obj, handler) openIngameStore({statsdMetric = "topmenu"})
})