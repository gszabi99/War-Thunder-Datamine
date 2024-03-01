from "%scripts/dagui_natives.nut" import ps4_open_store
from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
require("ingameConsoleStore.nut")
let DataBlock = require("DataBlock")
let statsd = require("statsd")
let psnStore = require("sony.store")
let psnSystem = require("sony.sys")

let seenEnumId = SEEN.EXT_PS4_SHOP

let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let seenList = require("%scripts/seen/seenList.nut").get(seenEnumId)
let { canUseIngameShop, getShopData, getShopItem, getShopItemsTable, isItemsUpdated
} = require("%scripts/onlineShop/ps4ShopData.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { isPlayerRecommendedEmailRegistration } = require("%scripts/user/playerCountry.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")
let { showPcStorePromo } = require("%scripts/user/pcStorePromo.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { gui_start_mainmenu_reload } = require("%scripts/mainmenu/guiStartMainmenu.nut")
let { addBgTaskCb } = require("%scripts/tasker.nut")

let persistent = {
  sheetsArray = []
}
registerPersistentData("PS4Shop", persistent, ["sheetsArray"])


let defaultsSheetData = {
  WARTHUNDEREAGLES = {
    sortParams = [
      { param = "releaseDate", asc = false }
      { param = "releaseDate", asc = true }
      { param = "price", asc = false }
      { param = "price", asc = true }
    ]
    sortSubParam = "name"
    contentTypes = ["eagles"]
  }
  def = {
    sortParams = [
      { param = "releaseDate", asc = false }
      { param = "releaseDate", asc = true }
      { param = "price", asc = false }
      { param = "price", asc = true }
      { param = "isBought", asc = false }
      { param = "isBought", asc = true }
    ]
    contentTypes = [null, ""]
  }
}

let fillSheetsArray = function(bcEventParams = {}) {
  if (!getShopData().blockCount()) {
    log("PS4: Ingame Shop: Don't init sheets. CategoriesData is empty")
    return
  }

  if (!persistent.sheetsArray.len()) {
    for (local i = 0; i < getShopData().blockCount(); i++) {
      let block = getShopData().getBlock(i)
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

  foreach (sh in persistent.sheetsArray) {
    let sheet = sh
    seenList.setSubListGetter(sheet.getSeenId(), function() {
      let res = []
      let productsList = getShopData().getBlockByName(sheet?.categoryId ?? "")?.links ?? DataBlock()
      for (local i = 0; i < productsList.blockCount(); i++) {
        let blockName = productsList.getBlock(i).getBlockName()
        let item = getShopItem(blockName)
        if (!item)
          continue

        if (!item.canBeUnseen())
          res.append(item.getSeenId())
      }
      return res
    })
  }

  broadcastEvent("PS4ShopSheetsInited", bcEventParams)
}

subscriptions.addListenersWithoutEnv({
  Ps4ShopDataUpdated = fillSheetsArray
})

gui_handlers.Ps4Shop <- class (gui_handlers.IngameConsoleStore) {
  needWaitIcon = true
  isLoadingInProgress = false

  function initScreen() {
    if (this.canDisplayStoreContents()) {
      psnStore.show_icon(psnStore.IconPosition.LEFT)
      base.initScreen()
      statsd.send_counter("sq.ingame_store.contents", 1, { callsite = "init_screen", status = "ok" })
      return
    }

    statsd.send_counter("sq.ingame_store.contents", 1, { callsite = "init_screen", status = "empty" })
    this.goBack()
  }

  function loadCurSheetItemsList() {
    this.itemsList = []
    let itemsLinks = getShopData().getBlockByName(this.curSheet?.categoryId ?? "")?.links ?? DataBlock()
    for (local i = 0; i < itemsLinks.blockCount(); i++) {
      let itemId = itemsLinks.getBlock(i).getBlockName()
      let block = getShopItem(itemId)
      if (block)
        this.itemsList.append(block)
      else
        log($"PS4: Ingame Shop: Skip missing info of item {itemId}")
    }
  }

  function afterModalDestroy() {
    psnStore.hide_icon()
  }

  function onDestroy() {
    psnStore.hide_icon()
  }

  function canDisplayStoreContents() {
    let isStoreEmpty = !this.isLoadingInProgress && !this.itemsCatalog.len()
    if (isStoreEmpty)
      psnSystem.show_message(psnSystem.Message.EMPTY_STORE, "", {})
    return !isStoreEmpty
  }

  function onEventPS4ShopSheetsInited(p) {
    this.isLoadingInProgress = p?.isLoadingInProgress ?? false
    if (!this.canDisplayStoreContents()) {
      statsd.send_counter("sq.ingame_store.contents", 1,
        { callsite = "on_event_shop_sheets_inited", status = "empty" })
      this.goBack()
      return
    }
    statsd.send_counter("sq.ingame_store.contents", 1,
      { callsite = "on_event_shop_sheets_inited", status = "ok" })

    this.fillItemsList()
    this.updateItemInfo()
  }

  function onEventPS4IngameShopUpdate(_p) {
    this.curItem = this.getCurItem()
    let wasBought = this.curItem?.isBought
    this.curItem?.updateIsBoughtStatus()
    if (wasBought != this.curItem?.isBought)
      ENTITLEMENTS_PRICE.checkUpdate()

    this.updateSorting()
    this.fillItemsList()
    ::g_discount.updateOnlineShopDiscounts()

    if (isPlayerRecommendedEmailRegistration())
      showPcStorePromo()
  }

  function onEventSignOut(_p) {
    psnStore.hide_icon()
  }
}

function updatePurchasesReturnMainmenu(afterCloseFunc = null, openStoreResult = -1) {
  //TODO: separate afterCloseFunc on Success and Error.
  if (openStoreResult < 0) {
    //openStoreResult = -1 doesn't mean that we must not perform afterCloseFunc
    if (afterCloseFunc)
      afterCloseFunc()
    return
  }

  let taskId = ::update_entitlements_limited(true)
  //taskId = -1 doesn't mean that we must not perform afterCloseFunc
  if (taskId >= 0) {
    let progressBox = scene_msg_box("char_connecting", null, loc("charServer/checking"), null, null)
    addBgTaskCb(taskId, function() {
      destroyMsgBox(progressBox)
      gui_start_mainmenu_reload()
      if (afterCloseFunc)
        afterCloseFunc()
    })
  }
  else if (afterCloseFunc)
    afterCloseFunc()
}

let isChapterSuitable = @(chapter) isInArray(chapter, [null, "", "eagles"])
let getEntStoreLocId = @() canUseIngameShop() ? "#topmenu/ps4IngameShop" : "#msgbox/btn_onlineShop"

let openIngameStoreImpl = kwarg(
  function(chapter = null, curItemId = "", afterCloseFunc = null, statsdMetric = "unknown",
    forceExternalShop = false, unitName = "") {//-declared-never-used -unused-func-param
    if (!isChapterSuitable(chapter))
      return false

    let item = curItemId != "" ? getShopItem(curItemId) : null
    if (canUseIngameShop() && !forceExternalShop) {
      statsd.send_counter("sq.ingame_store.open", 1, { origin = statsdMetric })
      handlersManager.loadHandler(gui_handlers.Ps4Shop, {
        itemsCatalog = getShopItemsTable()
        isLoadingInProgress = !isItemsUpdated()
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
      get_gui_scene().performDelayed(getroottable(),
        function() {
          if (item)
            item.showDescription(statsdMetric)
          else if (chapter == null || chapter == "") {
            let res = ps4_open_store("WARTHUNDERAPACKS", false)
            updatePurchasesReturnMainmenu(afterCloseFunc, res)
          }
          else if (chapter == "eagles") {
            let res = ps4_open_store("WARTHUNDEREAGLES", false)
            updatePurchasesReturnMainmenu(afterCloseFunc, res)
          }
        }
      )
    }, null, "isCanUseOnlineShop")

    return true
  }
)

function openIngameStore(params = {}) {
  if (hasFeature("PSNAllowShowQRCodeStore")
    && isChapterSuitable(params?.chapter)
    && getLanguageName() == "Russian"
    && isPlayerRecommendedEmailRegistration()) {
    sendBqEvent("CLIENT_POPUP_1", "ingame_store_qr", { targetPlatform })
    openQrWindow({
      headerText = params?.chapter == "eagles" ? loc("charServer/chapter/eagles") : ""
      infoText = loc("eagles/rechargeUrlNotification")
      qrCodesData = [
        {url = "{0}{1}".subst(loc("url/recharge"), "&partner=QRLogin&partner_val=q37edt1l")}
      ]
      needUrlWithQrRedirect = true
      needShowUrlLink = false
      buttons = [{
        shortcut = "Y"
        text = loc(getEntStoreLocId())
        onClick = "goBack"
      }]
      onEscapeCb = @() openIngameStoreImpl(params)
    })
    return true
  }

  return openIngameStoreImpl(params)
}

return {
  openIngameStore
  getEntStoreLocId
  getEntStoreIcon = @() canUseIngameShop() ? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
  isEntStoreTopMenuItemHidden = @(...) !canUseIngameShop() || !isInMenu()
  getEntStoreUnseenIcon = @() SEEN.EXT_PS4_SHOP
  openEntStoreTopMenuFunc = @(_obj, _handler) openIngameStore({ statsdMetric = "topmenu" })
}
