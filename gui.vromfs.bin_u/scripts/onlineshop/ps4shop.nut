require("ingameConsoleStore.nut")
let statsd = require("statsd")
let psnStore = require("sony.store")
let psnSystem = require("sony.sys")

let seenEnumId = SEEN.EXT_PS4_SHOP

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let seenList = require("%scripts/seen/seenList.nut").get(seenEnumId)
let shopData = require("%scripts/onlineShop/ps4ShopData.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { isPlayerRecommendedEmailRegistration } = require("%scripts/user/playerCountry.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")

let persistent = {
  sheetsArray = []
}
::g_script_reloader.registerPersistentData("PS4Shop", persistent, ["sheetsArray"])


let defaultsSheetData = {
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

let fillSheetsArray = function(bcEventParams = {}) {
  if (!shopData.getData().blockCount())
  {
    ::dagor.debug("PS4: Ingame Shop: Don't init sheets. CategoriesData is empty")
    return
  }

  if (!persistent.sheetsArray.len())
  {
    for (local i = 0; i < shopData.getData().blockCount(); i++)
    {
      let block = shopData.getData().getBlock(i)
      let categoryId = block.getBlockName()

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
    let sheet = sh
    seenList.setSubListGetter(sheet.getSeenId(), function()
    {
      let res = []
      let productsList = shopData.getData().getBlockByName(sheet?.categoryId ?? "")?.links ?? ::DataBlock()
      for (local i = 0; i < productsList.blockCount(); i++)
      {
        let blockName = productsList.getBlock(i).getBlockName()
        let item = shopData.getShopItem(blockName)
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

::gui_handlers.Ps4Shop <- class extends ::gui_handlers.IngameConsoleStore
{
  needWaitIcon = true
  isLoadingInProgress = false

  function initScreen()
  {
    if (canDisplayStoreContents())
    {
      psnStore.show_icon(psnStore.IconPosition.LEFT)
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
    let itemsLinks = shopData.getData().getBlockByName(curSheet?.categoryId ?? "")?.links ?? ::DataBlock()
    for (local i = 0; i < itemsLinks.blockCount(); i++)
    {
      let itemId = itemsLinks.getBlock(i).getBlockName()
      let block = shopData.getShopItem(itemId)
      if (block)
        itemsList.append(block)
      else
        ::dagor.debug($"PS4: Ingame Shop: Skip missing info of item {itemId}")
    }
  }

  function afterModalDestroy() {
    psnStore.hide_icon()
  }

  function onDestroy() {
    psnStore.hide_icon()
  }

  function canDisplayStoreContents()
  {
    let isStoreEmpty = !isLoadingInProgress && !itemsCatalog.len()
    if (isStoreEmpty)
      psnSystem.show_message(psnSystem.Message.EMPTY_STORE, "", {})
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
    let wasBought = curItem?.isBought
    curItem?.updateIsBoughtStatus()
    if (wasBought != curItem?.isBought)
      ENTITLEMENTS_PRICE.checkUpdate()

    updateSorting()
    fillItemsList()
    ::g_discount.updateOnlineShopDiscounts()
  }

  function onEventSignOut(p)
  {
    psnStore.hide_icon()
  }
}

let isChapterSuitable = @(chapter) ::isInArray(chapter, [null, "", "eagles"])
let getEntStoreLocId = @() shopData.canUseIngameShop()? "#topmenu/ps4IngameShop" : "#msgbox/btn_onlineShop"

let openIngameStoreImpl = ::kwarg(
  function (chapter = null, curItemId = "", afterCloseFunc = null, statsdMetric = "unknown", forceExternalShop = false) {
    if (!isChapterSuitable(chapter))
      return false

    let item = curItemId != "" ? shopData.getShopItem(curItemId) : null
    if (shopData.canUseIngameShop() && !forceExternalShop)
    {
      statsd.send_counter("sq.ingame_store.open", 1, {origin = statsdMetric})
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
          if (item)
            item.showDescription(statsdMetric)
          else if (chapter == null || chapter == "") {
            let res = ::ps4_open_store("WARTHUNDERAPACKS", false)
            ::update_purchases_return_mainmenu(afterCloseFunc, res)
          }
          else if (chapter == "eagles") {
            let res = ::ps4_open_store("WARTHUNDEREAGLES", false)
            ::update_purchases_return_mainmenu(afterCloseFunc, res)
          }
        }
      )
    }, null, "isCanUseOnlineShop")

    return true
  }
)

let function openIngameStore(params = {}) {
  if (isChapterSuitable(params?.chapter)
    && ::g_language.getLanguageName() == "Russian"
    && isPlayerRecommendedEmailRegistration()) {
    ::add_big_query_record("ingame_store_qr", targetPlatform)
    openQrWindow({
      headerText = params?.chapter == "eagles" ? ::loc("charServer/chapter/eagles") : ""
      infoText = ::loc("eagles/rechargeUrlNotification")
      baseUrl = "{0}{1}".subst(::loc("url/recharge"), "&partner=QRLogin&partner_val=q37edt1l")
      needUrlWithQrRedirect = true
      needShowUrlLink = false
      buttons = [{
        shortcut = "Y"
        text = ::loc(getEntStoreLocId())
        onClick = "goBack"
      }]
      onEscapeCb = @() openIngameStoreImpl(params)
    })
    return true
  }

  return openIngameStoreImpl(params)
}

return shopData.__merge({
  openIngameStore = openIngameStore
  getEntStoreLocId = getEntStoreLocId
  getEntStoreIcon = @() shopData.canUseIngameShop()? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
  isEntStoreTopMenuItemHidden = @(...) !shopData.canUseIngameShop() || !::isInMenu()
  getEntStoreUnseenIcon = @() SEEN.EXT_PS4_SHOP
  needEntStoreDiscountIcon = true
  openEntStoreTopMenuFunc = @(obj, handler) openIngameStore({statsdMetric = "topmenu"})
})
