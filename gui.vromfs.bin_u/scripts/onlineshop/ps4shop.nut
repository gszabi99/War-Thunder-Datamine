require("ingameConsoleStore.nut")
local statsd = require("statsd")
local psnStore = require("sony.store")
local psnSystem = require("sony.sys")

local seenEnumId = SEEN.EXT_PS4_SHOP

local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local seenList = require("scripts/seen/seenList.nut").get(seenEnumId)
local shopData = require("scripts/onlineShop/ps4ShopData.nut")

local persistent = {
  sheetsArray = []
}
::g_script_reloader.registerPersistentData("PS4Shop", persistent, ["sheetsArray"])


local defaultsSheetData = {
  WARTHUNDEREAGLES = {
    sortParams = [
      {param = "releaseDate", asc = false}
      {param = "releaseDate", asc = true}
      {param = "price", asc = false}
      {param = "price", asc = true}
    ]
    sortSubParam = "name"
    contentTypes = ["eagles"]
  }
  def = {
    sortParams = [
      {param = "releaseDate", asc = false}
      {param = "releaseDate", asc = true}
      {param = "price", asc = false}
      {param = "price", asc = true}
      {param = "isBought", asc = false}
      {param = "isBought", asc = true}
    ]
    contentTypes = [null, ""]
  }
}

local fillSheetsArray = function(bcEventParams = {}) {
  if (!shopData.getData().blockCount())
  {
    ::dagor.debug("PS4: Ingame Shop: Don't init sheets. CategoriesData is empty")
    return
  }

  if (!persistent.sheetsArray.len())
  {
    for (local i = 0; i < shopData.getData().blockCount(); i++)
    {
      local block = shopData.getData().getBlock(i)
      local categoryId = block.getBlockName()

      persistent.sheetsArray.append({
        id = $"sheet_{categoryId}"
        locText = block?.name ?? block.displayName ?? ""
        getSeenId = @() $"##ps4_item_sheet_{categoryId}"
        categoryId = categoryId
        sortParams = defaultsSheetData?[categoryId].sortParams ?? defaultsSheetData.def.sortParams
        sortSubParam = "name"
        contentTypes = defaultsSheetData?[categoryId].contentTypes ?? defaultsSheetData.def.contentTypes
      })
    }
  }

  foreach (sh in persistent.sheetsArray)
  {
    local sheet = sh
    seenList.setSubListGetter(sheet.getSeenId(), function()
    {
      local res = []
      local productsList = shopData.getData()?[sheet.categoryId].links ?? ::DataBlock()
      for (local i = 0; i < productsList.blockCount(); i++)
      {
        local blockName = productsList.getBlock(i).getBlockName()
        local item = shopData.getShopItem(blockName)
        if (!item)
          continue

        if (!item.canBeUnseen())
          res.append(item.getSeenId())
      }
      return res
    })
  }

  ::broadcastEvent("PS4ShopSheetsInited", bcEventParams)
}

subscriptions.addListenersWithoutEnv({
  Ps4ShopDataUpdated = fillSheetsArray
})

class ::gui_handlers.Ps4Shop extends ::gui_handlers.IngameConsoleStore
{
  needWaitIcon = true
  isLoadingInProgress = false

  function initScreen()
  {
    if (canDisplayStoreContents())
    {
      psnStore.show_icon(psnStore.IconPosition.CENTER)
      base.initScreen()
      statsd.send_counter("sq.ingame_store.contents", 1, {callsite = "init_screen", status = "ok"})
      return
    }

    statsd.send_counter("sq.ingame_store.contents", 1, {callsite = "init_screen", status = "empty"})
    goBack()
  }

  function loadCurSheetItemsList()
  {
    itemsList = []
    local itemsLinks = shopData.getData().getBlockByName(curSheet.categoryId)?.links ?? ::DataBlock()
    for (local i = 0; i < itemsLinks.blockCount(); i++)
    {
      local itemId = itemsLinks.getBlock(i).getBlockName()
      local block = shopData.getShopItem(itemId)
      if (block)
        itemsList.append(block)
      else
        ::dagor.debug($"PS4: Ingame Shop: Skip missing info of item {itemId}")
    }
  }

  function afterModalDestroy()
  {
    psnStore.hide_icon()
  }

  function canDisplayStoreContents()
  {
    local isStoreEmpty = !isLoadingInProgress && !itemsCatalog.len()
    if (isStoreEmpty)
      psnSystem.show_message(psnSystem.Message.EMPTY_STORE, @(_) null)
    return !isStoreEmpty
  }

  function onEventPS4ShopSheetsInited(p)
  {
    isLoadingInProgress = p?.isLoadingInProgress ?? false
    if (!canDisplayStoreContents())
    {
      statsd.send_counter("sq.ingame_store.contents", 1,
        {callsite = "on_event_shop_sheets_inited", status = "empty"})
      goBack()
      return
    }
    statsd.send_counter("sq.ingame_store.contents", 1,
      {callsite = "on_event_shop_sheets_inited", status = "ok"})

    fillItemsList()
    updateItemInfo()
  }

  function onEventPS4IngameShopUpdate(p)
  {
    curItem = getCurItem()
    local wasBought = curItem?.isBought
    curItem?.updateIsBoughtStatus()
    if (wasBought != curItem?.isBought)
      ::configs.ENTITLEMENTS_PRICE.checkUpdate()

    updateSorting()
    fillItemsList()
    ::g_discount.updateOnlineShopDiscounts()
  }

  function onEventSignOut(p)
  {
    psnStore.hide_icon()
  }
}

local openIngameStore = ::kwarg(
  function (chapter = null, curItemId = "", afterCloseFunc = null, openedFrom = "unknown") {
    if (!::isInArray(chapter, [null, "", "eagles"]))
      return false

    if (shopData.canUseIngameShop())
    {
      statsd.send_counter("sq.ingame_store.open", 1, {origin = openedFrom})
      local item = shopData.getShopItem(curItemId)
      ::handlersManager.loadHandler(::gui_handlers.Ps4Shop, {
        itemsCatalog = shopData.getShopItemsTable()
        isLoadingInProgress = !shopData.isItemsUpdated()
        chapter = chapter
        curSheetId = item?.category
        curItem = item
        afterCloseFunc = afterCloseFunc
        titleLocId = "topmenu/ps4IngameShop"
        storeLocId = "items/purchaseIn/Ps4Store"
        openStoreLocId = "items/openIn/Ps4Store"
        seenEnumId = seenEnumId
        seenList = seenList
        sheetsArray = persistent.sheetsArray
      })
      return true
    }

    ::queues.checkAndStart(function() {
      ::get_gui_scene().performDelayed(::getroottable(),
        function() {
          if (chapter == null || chapter == "")
          {
            local res = ::ps4_open_store("WARTHUNDERAPACKS", false)
            ::update_purchases_return_mainmenu(afterCloseFunc, res)
          }
          else if (chapter == "eagles")
          {
            local res = ::ps4_open_store("WARTHUNDEREAGLES", false)
            ::update_purchases_return_mainmenu(afterCloseFunc, res)
          }
        }
      )
    }, null, "isCanUseOnlineShop")

    return true
  }
)

return shopData.__merge({
  openIngameStore = openIngameStore
  getEntStoreLocId = @() shopData.canUseIngameShop()? "#topmenu/ps4IngameShop" : "#msgbox/btn_onlineShop"
  getEntStoreIcon = @() shopData.canUseIngameShop()? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
  isEntStoreTopMenuItemHidden = @(...) !shopData.canUseIngameShop() || !::isInMenu()
  getEntStoreUnseenIcon = @() SEEN.EXT_PS4_SHOP
  needEntStoreDiscountIcon = true
  openEntStoreTopMenuFunc = @(obj, handler) openIngameStore({statsdMetric = "topmenu"})
})
