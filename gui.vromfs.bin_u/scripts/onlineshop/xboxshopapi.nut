import "%scripts/wndLib/qrWindow.nut" as openQrWindow
import "statsd" as statsd
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/onlineShop/xboxShopData.nut" import xboxProceedItems, canUseIngameShop, requestData, getShopItem
from "%scripts/gdk/purch.nut" import set_xbox_on_purchase_cb
from "%scripts/user/countryUtils.nut" import isPlayerRecommendedEmailRegistration
from "%sqstd/platform.nut" import platformId
from "%scripts/bqQueue/bqQueue.nut" import sendBqEvent
from "%scripts/langUtils/language.nut" import getLanguageName
from "%scripts/queue/queueManager.nut" import checkQueueAndStart
from "dagor.workcycle" import defer
from "%gdkLib/impl/store.nut" import show_marketplace, ProductKind
from "%scripts/dagui_library.nut" import *
from "%scripts/onlineShop/onlineShopConsts.nut" import xboxMediaItemType
from "%globalScripts/loc_helpers.nut" import getVendorLocId
from "%scripts/seen/seenIds.nut" import SEEN

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)
let unitTypes = require("%scripts/unit/unitTypesList.nut")

let sheetsArray = Computed(function() {
  let val = xboxProceedItems.get()
  let res = []
  if (xboxMediaItemType.GameConsumable in val)
    res.append({
      id = "xbox_game_consumation"
      locId = "itemTypes/xboxGameConsumation"
      getSeenId = @() $"##xbox_item_sheet_{xboxMediaItemType.GameConsumable}"
      categoryId = xboxMediaItemType.GameConsumable
      sortParams = [
        { param = "price", asc = false }
        { param = "price", asc = true }
      ]
      sortSubParam = "consumableQuantity"
      contentTypes = ["eagles"]
    })

  if (xboxMediaItemType.GameContent in val)
    res.append({
      id = "xbox_game_content"
      locId = "itemTypes/xboxGameContent"
      getSeenId = @() $"##xbox_item_sheet_{xboxMediaItemType.GameContent}"
      categoryId = xboxMediaItemType.GameContent
      sortParams = [
        { param = "releaseDate", asc = false }
        { param = "releaseDate", asc = true }
        { param = "price", asc = false }
        { param = "price", asc = true }
        { param = "isBought", asc = false }
        { param = "isBought", asc = true }
      ]
      sortSubParam = "name"
      contentTypes = [null, ""]
    })

  unitTypes.types.each(function(unitType) {
    if (!(unitType.typeName in val))
      return

    res.append({
      id = $"xbox_game_content_{unitType.typeName}"
      locId = unitType.getArmyLocId()
      getSeenId = @() $"##xbox_item_sheet_{unitType.typeName}"
      categoryId = unitType.typeName
      sortParams = [
        { param = "releaseDate", asc = false }
        { param = "releaseDate", asc = true }
        { param = "price", asc = false }
        { param = "price", asc = true }
        { param = "isBought", asc = false }
        { param = "isBought", asc = true }
      ]
      sortSubParam = "name"
      contentTypes = [null, ""]
    })
  })
  return res
})

sheetsArray.subscribe(function(sheetsArrayValue) {
  let proceedItems = xboxProceedItems.get()
  foreach (_idx, sh in sheetsArrayValue) {
    let sheet = sh
    seenList.setSubListGetter(sheet.getSeenId(), @()
      (proceedItems?[sheet.categoryId] ?? [])
      .filter(@(it) !it.canBeUnseen())
      .map(@(it) it.getSeenId())
    )
  }
})

let isChapterSuitable = @(chapter) isInArray(chapter, [null, "", "eagles"])
let getEntStoreLocId = @() canUseIngameShop() ? "#topmenu/xboxIngameShop" : $"#{getVendorLocId("msgbox/btn_onlineShop")}"

let openIngameStoreImpl = kwarg(
  function(chapter = null, curItemId = "", afterCloseFunc = null, statsdMetric = "unknown",
    forceExternalShop = false, unitName = "") {
    if (!isChapterSuitable(chapter))
      return false

    if (canUseIngameShop() && !forceExternalShop) {
      requestData(
        false,
        function() {
          let curItem = getShopItem(curItemId)
          local curSheetId = null
          if (curItem?.categoriesList) {
            let unitTypeName = getAircraftByName(unitName).unitType.typeName
            curSheetId = curItem.categoriesList.contains(unitTypeName) ? unitTypeName
              : curItem.categoriesList?[0]

            log($"XBOX SHOP: Found sheet {curSheetId} for unit {unitName}. Item {curItem?.id}, {curItem?.entitlementId}")
          }

          statsd.send_counter("sq.ingame_store.open", 1, { origin = statsdMetric })
          handlersManager.loadHandler(get_gui_handler("XboxShop"), {
            itemsCatalog = xboxProceedItems.get()
            chapter = chapter
            curItem
            curSheetId
            afterCloseFunc
            titleLocId = "topmenu/xboxIngameShop"
            storeLocId = "items/openIn/XboxStore"
            seenEnumId = SEEN.EXT_XBOX_SHOP
            seenList
            sheetsArray = sheetsArray.get()
          })
        })
      return true
    }

    checkQueueAndStart(Callback(function() {
      set_xbox_on_purchase_cb(afterCloseFunc)
      defer(function() {
        local curItem = getShopItem(curItemId)
        if (curItem)
          curItem.showDetails(statsdMetric)
        else {
          let productKind = (chapter == "eagles") ? ProductKind.Consumable : ProductKind.Durable
          show_marketplace(productKind, null)
        }
      })
    }, this), null, "isCanUseOnlineShop")

    return true
  }
)

function openIngameStore(params = {}) {
  if (isChapterSuitable(params?.chapter)
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
  getEntStoreUnseenIcon = @() SEEN.EXT_XBOX_SHOP
  openEntStoreTopMenuFunc = @(_obj, _handler) openIngameStore({ statsdMetric = "topmenu" })
})