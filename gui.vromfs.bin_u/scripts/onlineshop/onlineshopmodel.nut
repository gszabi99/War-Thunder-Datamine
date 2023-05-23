//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let DataBlock = require("DataBlock")
let { ceil } = require("math")
let { get_url_for_purchase } = require("url")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { getShopItem, openIngameStore, canUseIngameShop
} = require("%scripts/onlineShop/entitlementsStore.nut")

let callbackWhenAppWillActive = require("%scripts/clientState/callbackWhenAppWillActive.nut")
let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { havePlayerTag } = require("%scripts/user/userUtils.nut")
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")


/*
 * Search in price.blk:
 * Search param is a name of a unit
 * Return an array of entitlement names
 *
 * API:
 *
 *  showUnitGoods(unitName)
 *    Find goods and open it in store
 *    ---
 *    This function should be moved to onlineShop handler,
 *    but this required refactioring in this handler
 *    ---
 * */

::OnlineShopModel <- {
  priceBlk = null
  purchaseDataCache = {}
  searchEntitlementsCache = null
  entitlemetsUpdaterWeak = null
  callbackReturnFunc = null

  onEventProfileUpdated = @(_) this.searchEntitlementsCache = null
}

/*API methods*/
::OnlineShopModel.showUnitGoods <- function showUnitGoods(unitName, requestOrigin) {
  if (!hasFeature("OnlineShopPacks"))
    return ::showInfoMsgBox(loc("msgbox/notAvailbleYet"))

  let customUrl = loc("url/custom_purchase/unit", { unitName }, "")
  if (customUrl.len())
    return this.openShopUrl(customUrl)

  this.__assyncActionWrap(function () {
      let searchResult = this.searchEntitlementsByUnit(unitName)
      foreach (goodsName in searchResult) {
        let bundleId = getBundleId(goodsName)
        if (bundleId != "") {
          if (isPlatformSony || isPlatformXboxOne) {
            if (getShopItem(bundleId) != null) {
              openIngameStore({ curItemId = bundleId, statsdMetric = requestOrigin, unitName })
              return
            }
          }
          else {
            this.doBrowserPurchase(goodsName)
            return
          }
        }
      }

      if (isPlatformSony || isPlatformXboxOne)
        return openIngameStore({ statsdMetric = requestOrigin })

      return ::gui_modal_onlineShop()
    }.bindenv(::OnlineShopModel))
}
/*end API methods*/

::OnlineShopModel.invalidatePriceBlk <- function invalidatePriceBlk() {
  this.priceBlk = null
  this.searchEntitlementsCache = null
  this.purchaseDataCache.clear()
}

::OnlineShopModel.validatePriceBlk <- function validatePriceBlk() {
  if (this.priceBlk)
    return
  this.priceBlk = DataBlock()
  ::get_shop_prices(this.priceBlk)
}

::OnlineShopModel.getPriceBlk <- function getPriceBlk() {
  this.validatePriceBlk()
  return this.priceBlk
}

//Check is price.blk is fresh and perform an action.
//If prise.blk is rotten, upfate price.blk and then perform action.
::OnlineShopModel.__assyncActionWrap <- function __assyncActionWrap(action) {
  let isActual = ENTITLEMENTS_PRICE.checkUpdate(
    action ? (@() action()).bindenv(this) : null,
    null,
    true,
    false
  )

  if (isActual)
    action()
}

::OnlineShopModel.onEventEntitlementsPriceUpdated <- function onEventEntitlementsPriceUpdated(_p) {
  this.invalidatePriceBlk()
}

::OnlineShopModel.onEventSignOut <- function onEventSignOut(_p) {
  this.invalidatePriceBlk()
}

::OnlineShopModel.getGoodsByName <- function getGoodsByName(goodsName) {
  return getTblValue(goodsName, this.getPriceBlk())
}

::OnlineShopModel.isEntitlement <- function isEntitlement(name) {
  if (type(name) == "string")
    return name in this.getPriceBlk()
  return false
}

::OnlineShopModel.searchEntitlementsByUnit <- function searchEntitlementsByUnit(unitName) {
  if (this.searchEntitlementsCache)
    return this.searchEntitlementsCache?[unitName] ?? []

  this.searchEntitlementsCache = {}
  let priceBlk = this.getPriceBlk()
  let numBlocks = priceBlk.blockCount()
  for (local i = 0; i < numBlocks; i++) {
    let ib = priceBlk.getBlock(i)
    let entitlementName = ib.getBlockName()
    if (ib?.hideWhenUnbought && !::has_entitlement(entitlementName))
      continue

    foreach (name in ib % "aircraftGift") {
      if (name not in this.searchEntitlementsCache)
        this.searchEntitlementsCache[name] <- []

      this.searchEntitlementsCache[name].append(entitlementName)
    }
  }
  return this.searchEntitlementsCache?[unitName] ?? []
}

::OnlineShopModel.getCustomPurchaseLink <- function getCustomPurchaseLink(goodsName) {
  return loc("customPurchaseLink/" + goodsName, "")
}

/*
  search first available entitlemnt to purchase to get current entitlement.by name
  _res - internal parametr - do not use from outside

  return {
    canBePurchased = (bool)
    guid = (string) or null
    customPurchaseLink = (string) or null
    sourceEntitlement =  (string)   - entitlement which need to buy to get requested entitlement
  }
*/
::OnlineShopModel._purchaseDataRecursion <- 0
::OnlineShopModel.getPurchaseData <- function getPurchaseData(goodsName) {
  if (goodsName in this.purchaseDataCache)
    return this.purchaseDataCache[goodsName]

  if (this._purchaseDataRecursion > 10) {
    let msg = "OnlineShopModel: getPurchaseData: found recursion for " + goodsName
    ::script_net_assert_once("getPurchaseData recursion", msg)
    return this.createPurchaseData(goodsName)
  }

  let customPurchaseLink = this.getCustomPurchaseLink(goodsName)
  if (!u.isEmpty(customPurchaseLink))
    return this.createPurchaseData(goodsName, null, customPurchaseLink)

  let guid = getBundleId(goodsName)
  if (!u.isEmpty(guid))
    return this.createPurchaseData(goodsName, guid)

  this._purchaseDataRecursion++
  //search in gifts or fingerPrints
  local res = null
  let priceBlk = this.getPriceBlk()
  let numBlocks = priceBlk.blockCount()
  for (local i = 0; i < numBlocks; i++) {
    let blk = priceBlk.getBlock(i)
    if (!isInArray(goodsName, blk % "entitlementGift")
        && !isInArray(goodsName, blk % "fingerprintController"))
      continue

    let entitlement = blk.getBlockName()
    let purchData = this.getPurchaseData(entitlement)
    if (!purchData.canBePurchased)
      continue

    res = purchData
    this.purchaseDataCache[goodsName] <- res
    break
  }

  this._purchaseDataRecursion--
  return res || this.createPurchaseData(goodsName)
}

::OnlineShopModel.createPurchaseData <- function createPurchaseData(goodsName = "", guid = null, customPurchaseLink = null) {
  let res = {
    canBePurchased = !!(guid || customPurchaseLink)
    guid = guid
    customPurchaseLink = customPurchaseLink
    sourceEntitlement = goodsName
    openBrowser = function () { return ::OnlineShopModel.openBrowserByPurchaseData(this) }
  }
  if (goodsName != "")
      this.purchaseDataCache[goodsName] <- res
  return res
}

/**
 * Returns array of entitlements that
 * unlock feature with provided name.
 */
let function getEntitlementsByFeature(name) {
  let entitlements = []
  if (name == null)
    return entitlements
  let feature = ::get_game_settings_blk()?.features?[name]
  if (feature == null)
    return entitlements
  foreach (condition in (feature % "condition")) {
    if (type(condition) == "string" &&
        ::OnlineShopModel.isEntitlement(condition))
      entitlements.append(condition)
  }
  return entitlements
}

//return purchaseData (look getPurchaseData) of first found entitlement which can be purchased.
// or empty purchase data
::OnlineShopModel.getFeaturePurchaseData <- function getFeaturePurchaseData(feature) {
  local res = null
  foreach (entitlement in getEntitlementsByFeature(feature)) {
    res = this.getPurchaseData(entitlement)
    if (res.canBePurchased)
      return res
  }
  return res || this.createPurchaseData()
}

//return purchaseDatas (look getPurchaseData) of all entitlements which can be purchased.
// or empty array
::OnlineShopModel.getAllFeaturePurchases <- function getAllFeaturePurchases(feature) {
  let res = []
  foreach (entitlement in getEntitlementsByFeature(feature)) {
    let purchase = this.getPurchaseData(entitlement)
    if (purchase.canBePurchased)
      res.append(purchase)
  }
  return res
}

::OnlineShopModel.openBrowserForFirstFoundEntitlement <- function openBrowserForFirstFoundEntitlement(entitlementsList) {
  foreach (entitlement in entitlementsList) {
    let purchase = this.getPurchaseData(entitlement)
    if (purchase.canBePurchased) {
      this.openBrowserByPurchaseData(purchase)
      break
    }
  }
}

::OnlineShopModel.openBrowserByPurchaseData <- function openBrowserByPurchaseData(purchaseData) {
  if (!purchaseData.canBePurchased)
    return false

  if (isPlatformSony || isPlatformXboxOne)
    return openIngameStore()

  if (purchaseData.customPurchaseLink) {
    this.openShopUrl(purchaseData.customPurchaseLink)
    return true
  }
  let customPurchaseUrl = this.getCustomPurchaseUrl(this.getGoodsChapter(purchaseData.sourceEntitlement))
  if (! u.isEmpty(customPurchaseUrl)) {
    this.openShopUrl(customPurchaseUrl)
    return true
  }
  if (purchaseData.guid) {
    this.doBrowserPurchaseByGuid(purchaseData.guid, purchaseData.sourceEntitlement)
    return true
  }
  return false
}

::OnlineShopModel.doBrowserPurchase <- function doBrowserPurchase(goodsName) {
  if (isPlatformSony || isPlatformXboxOne)
    return openIngameStore()
  //just to avoid bugs, when users, who should to purchase goods in regional
  //web shops, accidentally uses ingame online shop
  let customUrl = this.getCustomPurchaseUrl(this.getGoodsChapter(goodsName))
  if (customUrl != "") {
    this.openShopUrl(customUrl)
    return
  }
  this.doBrowserPurchaseByGuid(getBundleId(goodsName))
}

::OnlineShopModel.doBrowserPurchaseByGuid <- function doBrowserPurchaseByGuid(guid, dbgGoodsName = "") {
  let isSteam = ::steam_is_running() &&
                  (havePlayerTag("steam") || hasFeature("AllowSteamAccountLinking")) //temporary use old code pass for steam

  let url = isSteam
    ? format(loc("url/webstore/steam/item"), guid, ::steam_get_app_id(), ::steam_get_my_id())
    : " ".concat("auto_local", "auto_login", get_url_for_purchase(guid))

  if (url == "") {
    ::showInfoMsgBox(loc("browser/purchase_url_not_found"), "errorMessageBox")
    log("get_url_for_purchase have returned empty url for guid/" + dbgGoodsName)
    return
  }

  this.openShopUrl(url)
}

::OnlineShopModel.getGoodsChapter <- function getGoodsChapter(goodsName) {
  let goods = this.getGoodsByName(goodsName)
  return "chapter" in goods ? goods.chapter : ""
}

//Get custom URL for purchase goods from regional stores
//if returns "" uses default store.
//custom URLs are defined for particular languages and almost always are ""
//Consoles are exception. They always uses It's store.
::OnlineShopModel.getCustomPurchaseUrl <- function getCustomPurchaseUrl(chapter) {
  if (isPlatformSony || isPlatformXboxOne)
    return ""

  let circuit = ::get_cur_circuit_name()
  let locParams = {
    userId = ::my_user_id_str
    circuit = circuit
    circuitTencentId = getTblValue("circuitTencentId", ::get_network_block()[circuit], circuit)
  }
  let locIdPrefix = ::is_platform_shield_tv()
    ? "url/custom_purchase_shield_tv"
    : "url/custom_purchase"
  if (chapter == "eagles")
    return loc(locIdPrefix + "/eagles", locParams)
  if (!isInArray(chapter, ["hidden", "premium", "eagles", "warpoints"]))
    return loc(locIdPrefix, locParams)
  return ""
}

::OnlineShopModel.openShopUrl <- function openShopUrl(baseUrl, isAlreadyAuthenticated = false) {
  if (needShowGuestEmailRegistration()) {
    showGuestEmailRegistration()
    return
  }

  openUrl(baseUrl, false, isAlreadyAuthenticated, "shop_window")
  this.startEntitlementsUpdater()
}

//return true when custom Url found
::OnlineShopModel.checkAndOpenCustomPurchaseUrl <- function checkAndOpenCustomPurchaseUrl(chapter, needMsgBox = false) {
  let customUrl = this.getCustomPurchaseUrl(chapter)
  if (customUrl == "")
    return false

  if (hasFeature("ManuallyUpdateBalance")) {
    this.openUpdateBalanceMenu(customUrl)
    return true
  }

  if (!needMsgBox)
    this.openShopUrl(customUrl)
  else
    ::scene_msg_box("onlineShop_buy_" + chapter, null,
      loc("charServer/web_recharge"),
      [["ok", @() ::OnlineShopModel.openShopUrl(customUrl) ],
       ["cancel", function() {} ]
      ],
      "ok",
      { cancel_fn = function() {} }
    )

  return true
}

::OnlineShopModel.openUpdateBalanceMenu <- function openUpdateBalanceMenu(customUrl) {
  let menu = [
    {
      text = loc("charServer/btn/web_recharge")
      action = (@(customUrl) function() { this.openShopUrl(customUrl) })(customUrl)
    }
    {
      text = ""
      action = ::update_entitlements_limited
      onUpdateButton = function(_p) {
        local refreshText = loc("charServer/btn/refresh_balance")
        let updateTimeout = ::get_update_entitlements_timeout_msec()
        let enable = updateTimeout <= 0
        if (!enable)
          refreshText += loc("ui/parentheses/space", { text = ceil(0.001 * updateTimeout) })
        return {
          text = refreshText
          enable = enable
          stopUpdate = enable
        }
      }
    }
  ]
  ::gui_right_click_menu(menu, this)
}

::OnlineShopModel.startEntitlementsUpdater <- function startEntitlementsUpdater() {
  callbackWhenAppWillActive(function() {
      if (::is_online_available())
        ::g_tasker.addTask(::update_entitlements_limited(),
          {
            showProgressBox = true
            progressBoxText = loc("charServer/checking")
          })
    }
  )
}

::OnlineShopModel.launchOnlineShop <- function launchOnlineShop(owner = null, chapter = null, afterCloseFunc = null, launchedFrom = "unknown") {
  if (!::isInMenu())
    return afterCloseFunc && afterCloseFunc()

  if (openIngameStore({ chapter = chapter, afterCloseFunc = afterCloseFunc, statsdMetric = launchedFrom }))
    return

  ::gui_modal_onlineShop(owner, chapter, afterCloseFunc)
}

//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //

::update_purchases_return_mainmenu <- function update_purchases_return_mainmenu(afterCloseFunc = null, openStoreResult = -1) {
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
    let progressBox = ::scene_msg_box("char_connecting", null, loc("charServer/checking"), null, null)
    ::add_bg_task_cb(taskId, function() {
      ::destroyMsgBox(progressBox)
      ::gui_start_mainmenu_reload()
      if (afterCloseFunc)
        afterCloseFunc()
    })
  }
  else if (afterCloseFunc)
    afterCloseFunc()
}

::gui_modal_onlineShop <- function gui_modal_onlineShop(owner = null, chapter = null, afterCloseFunc = null) {
  if (::OnlineShopModel.checkAndOpenCustomPurchaseUrl(chapter, true))
    return

  if (isInArray(chapter, [null, ""])) {
    local webStoreUrl = loc("url/webstore", "")
    if (::steam_is_running() && (havePlayerTag("steam") || hasFeature("AllowSteamAccountLinking")))
      webStoreUrl = format(loc("url/webstore/steam"), ::steam_get_my_id())

    if (webStoreUrl != "")
      return ::OnlineShopModel.openShopUrl(webStoreUrl)
  }

  let useRowVisual = chapter != null && isInArray(chapter, ["premium", "eagles", "warpoints"])
  let hClass = useRowVisual ? ::gui_handlers.OnlineShopRowHandler : ::gui_handlers.OnlineShopHandler
  let prevShopHandler = ::handlersManager.findHandlerClassInScene(hClass)
  if (prevShopHandler) {
    if (!afterCloseFunc) {
      afterCloseFunc = prevShopHandler.afterCloseFunc
      prevShopHandler.afterCloseFunc = null
    }
    if (prevShopHandler.scene.getModalCounter() != 0)
      ::handlersManager.destroyModal(prevShopHandler)
  }

  ::gui_start_modal_wnd(hClass, { owner = owner, afterCloseFunc = afterCloseFunc, chapter = chapter })
}

subscribe_handler(::OnlineShopModel, ::g_listener_priority.CONFIG_VALIDATION)

let function openOnlineShopFromPromo(handler, params) {
  let shopType = params?[0]
  if (shopType == ONLINE_SHOP_TYPES.BUNDLE
    || (shopType == ONLINE_SHOP_TYPES.EAGLES && canUseIngameShop())) {
    let bundleId = getBundleId(params?[1])
    if (bundleId != "") {
      if (isPlatformSony || isPlatformXboxOne)
        openIngameStore({
          curItemId = bundleId,
          statsdMetric = "promo",
          forceExternalShop = params?[2] == "forceExternalBrowser"
        })
      else
        ::OnlineShopModel.doBrowserPurchaseByGuid(bundleId, params?[1])
      return
    }
  }
  else
    handler.startOnlineShop(shopType, null, "promo")
}

addPromoAction("online_shop", @(handler, params, _obj) openOnlineShopFromPromo(handler, params))
