let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { getShopItem, openIngameStore, canUseIngameShop } = require("%scripts/onlineShop/entitlementsStore.nut")

let callbackWhenAppWillActive = require("%scripts/clientState/callbackWhenAppWillActive.nut")
let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { havePlayerTag } = require("%scripts/user/userUtils.nut")
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

  onEventProfileUpdated = @(_) searchEntitlementsCache = null
}

/*API methods*/
OnlineShopModel.showUnitGoods <- function showUnitGoods(unitName, requestOrigin)
{
  if (!::has_feature("OnlineShopPacks"))
    return ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))

  let customUrl = ::loc("url/custom_purchase/unit", { unitName }, "")
  if (customUrl.len())
    return openShopUrl(customUrl)

  __assyncActionWrap(function ()
    {
      let searchResult = searchEntitlementsByUnit(unitName)
      foreach (goodsName in searchResult)
      {
        let bundleId = getBundleId(goodsName)
        if (bundleId != "")
        {
          if (isPlatformSony || isPlatformXboxOne)
          {
            if (getShopItem(bundleId) != null)
            {
              openIngameStore({ curItemId = bundleId, openedFrom = requestOrigin })
              return
            }
          }
          else
          {
            doBrowserPurchase(goodsName)
            return
          }
        }
      }

      if (isPlatformSony || isPlatformXboxOne)
        return openIngameStore({ openedFrom = requestOrigin })

      return ::gui_modal_onlineShop()
    }.bindenv(OnlineShopModel))
}
/*end API methods*/

OnlineShopModel.invalidatePriceBlk <- function invalidatePriceBlk()
{
  priceBlk = null
  searchEntitlementsCache = null
  purchaseDataCache.clear()
}

OnlineShopModel.validatePriceBlk <- function validatePriceBlk()
{
  if (priceBlk)
    return
  priceBlk = ::DataBlock()
  ::get_shop_prices(priceBlk)
}

OnlineShopModel.getPriceBlk <- function getPriceBlk()
{
  validatePriceBlk()
  return priceBlk
}

//Check is price.blk is fresh and perform an action.
//If prise.blk is rotten, upfate price.blk and then perform action.
OnlineShopModel.__assyncActionWrap <- function __assyncActionWrap(action)
{
  let isActual = ENTITLEMENTS_PRICE.checkUpdate(
    action ? (@() action()).bindenv(this) : null,
    null,
    true,
    false
  )

  if (isActual)
    action()
}

OnlineShopModel.onEventEntitlementsPriceUpdated <- function onEventEntitlementsPriceUpdated(p)
{
  invalidatePriceBlk()
}

OnlineShopModel.onEventSignOut <- function onEventSignOut(p)
{
  invalidatePriceBlk()
}

OnlineShopModel.getGoodsByName <- function getGoodsByName(goodsName)
{
  return ::getTblValue(goodsName, getPriceBlk())
}

OnlineShopModel.isEntitlement <- function isEntitlement(name)
{
  if (typeof name == "string")
    return name in getPriceBlk()
  return false
}

OnlineShopModel.searchEntitlementsByUnit <- function searchEntitlementsByUnit(unitName)
{
  if (searchEntitlementsCache)
    return searchEntitlementsCache?[unitName] ?? []

  searchEntitlementsCache = {}
  let priceBlk = getPriceBlk()
  let numBlocks = priceBlk.blockCount()
  for (local i = 0; i < numBlocks; i++)
  {
    let ib = priceBlk.getBlock(i)
    let entitlementName = ib.getBlockName()
    if (ib?.hideWhenUnbought && !::has_entitlement(entitlementName))
      continue

    foreach (name in ib % "aircraftGift")
    {
      if (name not in searchEntitlementsCache)
        searchEntitlementsCache[name] <- []

      searchEntitlementsCache[name].append(entitlementName)
    }
  }
  return searchEntitlementsCache?[unitName] ?? []
}

OnlineShopModel.getCustomPurchaseLink <- function getCustomPurchaseLink(goodsName)
{
  return ::loc("customPurchaseLink/" + goodsName, "")
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
OnlineShopModel._purchaseDataRecursion <- 0
OnlineShopModel.getPurchaseData <- function getPurchaseData(goodsName)
{
  if (goodsName in purchaseDataCache)
    return purchaseDataCache[goodsName]

  if (_purchaseDataRecursion > 10)
  {
    let msg = "OnlineShopModel: getPurchaseData: found recursion for " + goodsName
    ::script_net_assert_once("getPurchaseData recursion", msg)
    return createPurchaseData(goodsName)
  }

  let customPurchaseLink = getCustomPurchaseLink(goodsName)
  if (!::u.isEmpty(customPurchaseLink))
    return createPurchaseData(goodsName, null, customPurchaseLink)

  let guid = getBundleId(goodsName)
  if (!::u.isEmpty(guid))
    return createPurchaseData(goodsName, guid)

  _purchaseDataRecursion++
  //search in gifts or fingerPrints
  local res = null
  let priceBlk = getPriceBlk()
  let numBlocks = priceBlk.blockCount()
  for (local i = 0; i < numBlocks; i++)
  {
    let blk = priceBlk.getBlock(i)
    if (!::isInArray(goodsName, blk % "entitlementGift")
        && !::isInArray(goodsName, blk % "fingerprintController"))
      continue

    let entitlement = blk.getBlockName()
    let purchData = getPurchaseData(entitlement)
    if (!purchData.canBePurchased)
      continue

    res = purchData
    purchaseDataCache[goodsName] <- res
    break
  }

  _purchaseDataRecursion--
  return res || createPurchaseData(goodsName)
}

OnlineShopModel.createPurchaseData <- function createPurchaseData(goodsName = "", guid = null, customPurchaseLink = null)
{
  let res = {
    canBePurchased = !!(guid || customPurchaseLink)
    guid = guid
    customPurchaseLink = customPurchaseLink
    sourceEntitlement = goodsName
    openBrowser = function () { return ::OnlineShopModel.openBrowserByPurchaseData(this) }
  }
  if (goodsName != "")
      purchaseDataCache[goodsName] <- res
  return res
}

/**
 * Returns array of entitlements that
 * unlock feature with provided name.
 */
let function getEntitlementsByFeature(name)
{
  let entitlements = []
  if (name == null)
    return entitlements
  let feature = ::get_game_settings_blk()?.features?[name]
  if (feature == null)
    return entitlements
  foreach(condition in (feature % "condition"))
  {
    if (typeof(condition) == "string" &&
        ::OnlineShopModel.isEntitlement(condition))
      entitlements.append(condition)
  }
  return entitlements
}

//return purchaseData (look getPurchaseData) of first found entitlement which can be purchased.
// or empty purchase data
OnlineShopModel.getFeaturePurchaseData <- function getFeaturePurchaseData(feature)
{
  local res = null
  foreach(entitlement in getEntitlementsByFeature(feature))
  {
    res = getPurchaseData(entitlement)
    if (res.canBePurchased)
      return res
  }
  return res || createPurchaseData()
}

//return purchaseDatas (look getPurchaseData) of all entitlements which can be purchased.
// or empty array
OnlineShopModel.getAllFeaturePurchases <- function getAllFeaturePurchases(feature)
{
  let res = []
  foreach(entitlement in getEntitlementsByFeature(feature))
  {
    let purchase = getPurchaseData(entitlement)
    if (purchase.canBePurchased)
      res.append(purchase)
  }
  return res
}

OnlineShopModel.openBrowserForFirstFoundEntitlement <- function openBrowserForFirstFoundEntitlement(entitlementsList)
{
  foreach(entitlement in entitlementsList)
  {
    let purchase = getPurchaseData(entitlement)
    if (purchase.canBePurchased)
    {
      openBrowserByPurchaseData(purchase)
      break
    }
  }
}

OnlineShopModel.openBrowserByPurchaseData <- function openBrowserByPurchaseData(purchaseData)
{
  if (!purchaseData.canBePurchased)
    return false

  if (isPlatformSony || isPlatformXboxOne)
    return openIngameStore()

  if (purchaseData.customPurchaseLink)
  {
    openShopUrl(purchaseData.customPurchaseLink)
    return true
  }
  let customPurchaseUrl = getCustomPurchaseUrl(getGoodsChapter(purchaseData.sourceEntitlement))
  if ( ! ::u.isEmpty(customPurchaseUrl))
  {
    openShopUrl(customPurchaseUrl)
    return true
  }
  if (purchaseData.guid)
  {
    doBrowserPurchaseByGuid(purchaseData.guid, purchaseData.sourceEntitlement)
    return true
  }
  return false
}

OnlineShopModel.doBrowserPurchase <- function doBrowserPurchase(goodsName)
{
  if (isPlatformSony || isPlatformXboxOne)
    return openIngameStore()
  //just to avoid bugs, when users, who should to purchase goods in regional
  //web shops, accidentally uses ingame online shop
  let customUrl = getCustomPurchaseUrl(getGoodsChapter(goodsName))
  if (customUrl != "")
  {
    openShopUrl(customUrl)
    return
  }
  doBrowserPurchaseByGuid(getBundleId(goodsName))
}

OnlineShopModel.doBrowserPurchaseByGuid <- function doBrowserPurchaseByGuid(guid, dbgGoodsName = "")
{
  let isSteam = ::steam_is_running() &&
                  (havePlayerTag("steam") || ::has_feature("AllowSteamAccountLinking")) //temporary use old code pass for steam

  // COMPATIBILITY: native pre-auth blocks login in embedded-to-external browser case, but we want this
  //                fixed on production without version bump.
  let useScriptBasedAutoLogin = "get_url_for_purchase" in getroottable()
  let url = isSteam
            ? ::format(::loc("url/webstore/steam/item"), guid, ::steam_get_app_id(), ::steam_get_my_id())
            : (useScriptBasedAutoLogin
              ? $"auto_local auto_login {::get_url_for_purchase(guid)}"
              : ::get_authenticated_url_for_purchase(guid))

  if (url == "")
  {
    ::showInfoMsgBox(::loc("browser/purchase_url_not_found"), "errorMessageBox")
    dagor.debug("get_url_for_purchase have returned empty url for guid/" + dbgGoodsName)
    return
  }

  openShopUrl(url, !useScriptBasedAutoLogin && !isSteam)
}

OnlineShopModel.getGoodsChapter <- function getGoodsChapter(goodsName)
{
  let goods = getGoodsByName(goodsName)
  return "chapter" in goods ? goods.chapter : ""
}

//Get custom URL for purchase goods from regional stores
//if returns "" uses default store.
//custom URLs are defined for particular languages and almost always are ""
//Consoles are exception. They always uses It's store.
OnlineShopModel.getCustomPurchaseUrl <- function getCustomPurchaseUrl(chapter)
{
  if (isPlatformSony || isPlatformXboxOne)
    return ""

  let circuit = ::get_cur_circuit_name()
  let locParams = {
    userId = ::my_user_id_str
    circuit = circuit
    circuitTencentId = ::getTblValue("circuitTencentId", ::get_network_block()[circuit], circuit)
  }
  let locIdPrefix = ::is_platform_shield_tv()
    ? "url/custom_purchase_shield_tv"
    : "url/custom_purchase"
  if (chapter == "eagles")
    return ::loc(locIdPrefix + "/eagles", locParams)
  if (!::isInArray(chapter, ["hidden", "premium", "eagles", "warpoints"]))
    return ::loc(locIdPrefix, locParams)
  return ""
}

OnlineShopModel.openShopUrl <- function openShopUrl(baseUrl, isAlreadyAuthenticated = false)
{
  openUrl(baseUrl, false, isAlreadyAuthenticated, "shop_window")
  startEntitlementsUpdater()
}

//return true when custom Url found
OnlineShopModel.checkAndOpenCustomPurchaseUrl <- function checkAndOpenCustomPurchaseUrl(chapter, needMsgBox = false)
{
  let customUrl = getCustomPurchaseUrl(chapter)
  if (customUrl == "")
    return false

  if (::has_feature("ManuallyUpdateBalance"))
  {
    openUpdateBalanceMenu(customUrl)
    return true
  }

  if (!needMsgBox)
    openShopUrl(customUrl)
  else
    ::scene_msg_box("onlineShop_buy_" + chapter, null,
      ::loc("charServer/web_recharge"),
      [["ok", (@(customUrl) function() { ::OnlineShopModel.openShopUrl(customUrl) })(customUrl) ],
       ["cancel", function() {} ]
      ],
      "ok",
      { cancel_fn = function() {}}
    )

  return true
}

OnlineShopModel.openUpdateBalanceMenu <- function openUpdateBalanceMenu(customUrl)
{
  let menu = [
    {
      text = ::loc("charServer/btn/web_recharge")
      action = (@(customUrl) function() { openShopUrl(customUrl) })(customUrl)
    }
    {
      text = ""
      action = ::update_entitlements_limited
      onUpdateButton = function(p)
      {
        local refreshText = ::loc("charServer/btn/refresh_balance")
        let updateTimeout = ::get_update_entitlements_timeout_msec()
        let enable = updateTimeout <= 0
        if (!enable)
          refreshText += ::loc("ui/parentheses/space", { text = ::ceil(0.001 * updateTimeout) })
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

OnlineShopModel.startEntitlementsUpdater <- function startEntitlementsUpdater()
{
  callbackWhenAppWillActive(function()
    {
      if (::is_online_available())
        ::g_tasker.addTask(::update_entitlements_limited(),
          {
            showProgressBox = true
            progressBoxText = ::loc("charServer/checking")
          })
    }
  )
}

OnlineShopModel.launchOnlineShop <- function launchOnlineShop(owner=null, chapter=null, afterCloseFunc=null, launchedFrom = "unknown")
{
  if (!::isInMenu())
    return afterCloseFunc && afterCloseFunc()

  if (openIngameStore({chapter = chapter, afterCloseFunc = afterCloseFunc, openedFrom = launchedFrom}))
    return

  ::gui_modal_onlineShop(owner, chapter, afterCloseFunc)
}

//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //

::update_purchases_return_mainmenu <- function update_purchases_return_mainmenu(afterCloseFunc = null, openStoreResult = -1)
{
  //TODO: separate afterCloseFunc on Success and Error.
  if (openStoreResult < 0)
  {
    //openStoreResult = -1 doesn't mean that we must not perform afterCloseFunc
    if (afterCloseFunc)
      afterCloseFunc()
    return
  }

  let taskId = ::update_entitlements_limited(true)
  //taskId = -1 doesn't mean that we must not perform afterCloseFunc
  if (taskId >= 0)
  {
    let progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/checking"), null, null)
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

::gui_modal_onlineShop <- function gui_modal_onlineShop(owner=null, chapter=null, afterCloseFunc=null)
{
  if (::OnlineShopModel.checkAndOpenCustomPurchaseUrl(chapter, true))
    return

  if (::isInArray(chapter, [null, ""]))
  {
    local webStoreUrl = ::loc("url/webstore", "")
    if (::steam_is_running() && (havePlayerTag("steam") || ::has_feature("AllowSteamAccountLinking")))
      webStoreUrl = ::format(::loc("url/webstore/steam"), ::steam_get_my_id())

    if (webStoreUrl != "")
      return ::OnlineShopModel.openShopUrl(webStoreUrl)
  }

  let useRowVisual = chapter != null && ::isInArray(chapter, ["premium", "eagles", "warpoints"])
  let hClass = useRowVisual? ::gui_handlers.OnlineShopRowHandler : ::gui_handlers.OnlineShopHandler
  let prevShopHandler = ::handlersManager.findHandlerClassInScene(hClass)
  if (prevShopHandler)
  {
    if (!afterCloseFunc)
    {
      afterCloseFunc = prevShopHandler.afterCloseFunc
      prevShopHandler.afterCloseFunc = null
    }
    if (prevShopHandler.scene.getModalCounter() != 0)
      ::handlersManager.destroyModal(prevShopHandler)
  }

  ::gui_start_modal_wnd(hClass, { owner = owner, afterCloseFunc = afterCloseFunc, chapter = chapter })
}

::subscribe_handler(::OnlineShopModel, ::g_listener_priority.CONFIG_VALIDATION)

let function openOnlineShopFromPromo(handler, params) {
  let shopType = params?[0]
  if (shopType == ONLINE_SHOP_TYPES.BUNDLE
    || (shopType == ONLINE_SHOP_TYPES.EAGLES && canUseIngameShop()))
  {
    let bundleId = getBundleId(params?[1])
    if (bundleId != "")
    {
      if (isPlatformSony || isPlatformXboxOne)
        openIngameStore({ curItemId = bundleId, openedFrom = "promo" })
      else
        ::OnlineShopModel.doBrowserPurchaseByGuid(bundleId, params?[1])
      return
    }
  }
  else
    handler.startOnlineShop(shopType, null, "promo")
}

addPromoAction("online_shop", @(handler, params, obj) openOnlineShopFromPromo(handler, params))
