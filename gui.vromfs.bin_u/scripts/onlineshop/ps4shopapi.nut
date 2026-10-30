import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
import "%scripts/wndLib/qrWindow.nut" as openQrWindow
import "DataBlock" as DataBlock
import "statsd" as statsd
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/onlineShop/ps4ShopData.nut" import canUseIngameShop, getShopData, getShopItem, getShopItemsTable, isItemsUpdated
from "%scripts/user/countryUtils.nut" import isPlayerRecommendedEmailRegistration
from "%sqstd/platform.nut" import platformId
from "%scripts/bqQueue/bqQueue.nut" import sendBqEvent
from "%scripts/langUtils/language.nut" import getLanguageName
from "%scripts/mainmenu/guiStartMainmenu.nut" import gui_start_mainmenu_reload
from "%scripts/tasker.nut" import addBgTaskCb
from "%scripts/onlineShop/entitlementsUpdate.nut" import updateEntitlementsLimited
from "%scripts/queue/queueManager.nut" import checkQueueAndStart
from "dagor.workcycle" import defer
from "%scripts/dagui_natives.nut" import ps4_open_store
from "%scripts/dagui_library.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let { broadcastEvent } = subscriptions
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let seenEnumId = SEEN.EXT_PS4_SHOP
let seenList = require("%scripts/seen/seenList.nut").get(seenEnumId)

let sheetsArray = []

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

  if (!sheetsArray.len()) {
    for (local i = 0; i < getShopData().blockCount(); i++) {
      let block = getShopData().getBlock(i)
      let categoryId = block.getBlockName()

      sheetsArray.append({
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

  foreach (sh in sheetsArray) {
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

function updatePurchasesReturnMainmenu(afterCloseFunc = null, openStoreResult = -1) {
  
  if (openStoreResult < 0) {
    
    if (afterCloseFunc)
      afterCloseFunc()
    return
  }

  let taskId = updateEntitlementsLimited(true)
  
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
    forceExternalShop = false, unitName = "") {
    if (!isChapterSuitable(chapter))
      return false

    let item = curItemId != "" ? getShopItem(curItemId) : null
    if (canUseIngameShop() && !forceExternalShop) {
      statsd.send_counter("sq.ingame_store.open", 1, { origin = statsdMetric })
      handlersManager.loadHandler(get_gui_handler("Ps4Shop"), {
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
        sheetsArray = sheetsArray
      })
      return true
    }

    checkQueueAndStart(function() {
      defer(function() {
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
      })
    }, null, "isCanUseOnlineShop")

    return true
  }
)

function openIngameStore(params = {}) {
  if (hasFeature("PSNAllowShowQRCodeStore")
    && isChapterSuitable(params?.chapter)
    && getLanguageName() == "Russian"
    && isPlayerRecommendedEmailRegistration()) {
    sendBqEvent("CLIENT_POPUP_1", "ingame_store_qr", { targetPlatform = platformId })
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

return freeze({
  openIngameStore
  getEntStoreLocId
  getEntStoreIcon = @() canUseIngameShop() ? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
  isEntStoreTopMenuItemHidden = @(...) !canUseIngameShop() || !isInMenu.get()
  getEntStoreUnseenIcon = @() SEEN.EXT_PS4_SHOP
  openEntStoreTopMenuFunc = @(_obj, _handler) openIngameStore({ statsdMetric = "topmenu" })
})