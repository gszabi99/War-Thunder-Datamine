from "%scripts/dagui_natives.nut" import is_online_available, get_cur_circuit_name
from "%scripts/dagui_library.nut" import *
from "%scripts/onlineShop/onlineShopConsts.nut" import ONLINE_SHOP_TYPES

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { isInMenu, handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let { ceil } = require("math")
let { get_url_for_purchase } = require("url")
let { isPlatformSony, isPlatformXboxOne, isPlatformShieldTv } = require("%scripts/clientState/platform.nut")
let { getShopItem, canUseIngameShop } = require("%scripts/onlineShop/entitlementsShopData.nut")
let { openIngameStore } = require("%scripts/onlineShop/entitlementsShop.nut")
let callbackWhenAppWillActive = require("%scripts/clientState/callbackWhenAppWillActive.nut")
let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { getCurCircuitUrl } = require("%appGlobals/urlCustom.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")
let { get_network_block } = require("blkGetters")
let { userIdStr, havePlayerTag } = require("%scripts/user/profileStates.nut")
let { addTask } = require("%scripts/tasker.nut")
let { searchEntitlementsByUnit, getGoodsChapter, getPurchaseData } = require("%scripts/onlineShop/onlineShopState.nut")
let { steam_is_running, steam_get_my_id, steam_get_app_id } = require("steam")

function startEntitlementsUpdater() {
  callbackWhenAppWillActive(function() {
      if (is_online_available())
        addTask(::update_entitlements_limited(),
          {
            showProgressBox = true
            progressBoxText = loc("charServer/checking")
          })
    }
  )
}

//Get custom URL for purchase goods from regional stores
//if returns "" uses default store.
//custom URLs are defined for particular languages and almost always are ""
//Consoles are exception. They always uses It's store.
function getCustomPurchaseUrl(chapter) {
  if (isPlatformSony || isPlatformXboxOne)
    return ""

  let circuit = get_cur_circuit_name()
  let locParams = {
    userId = userIdStr.value
    circuit = circuit
    circuitTencentId = getTblValue("circuitTencentId", get_network_block()[circuit], circuit)
  }
  let locIdPrefix = isPlatformShieldTv()
    ? "url/custom_purchase_shield_tv"
    : "url/custom_purchase"
  if (chapter == "eagles")
    return loc($"{locIdPrefix}/eagles", locParams)
  if (!isInArray(chapter, ["hidden", "premium", "eagles", "warpoints"]))
    return loc(locIdPrefix, locParams)
  return ""
}

function openShopUrl(baseUrl, isAlreadyAuthenticated = false) {
  if (needShowGuestEmailRegistration()) {
    showGuestEmailRegistration()
    return
  }

  openUrl(baseUrl, false, isAlreadyAuthenticated, "shop_window")
  startEntitlementsUpdater()
}

function openUpdateBalanceMenu(customUrl) {
  let menu = [
    {
      text = loc("charServer/btn/web_recharge")
      action =  @() openShopUrl(customUrl)
    }
    {
      text = ""
      action = ::update_entitlements_limited
      onUpdateButton = function(_p) {
        local refreshText = loc("charServer/btn/refresh_balance")
        let updateTimeout = ::get_update_entitlements_timeout_msec()
        let enable = updateTimeout <= 0
        if (!enable)
          refreshText = "".concat(refreshText, loc("ui/parentheses/space", { text = ceil(0.001 * updateTimeout) }))
        return {
          text = refreshText
          enable = enable
          stopUpdate = enable
        }
      }
    }
  ]
  ::gui_right_click_menu(menu, null)
}

//return true when custom Url found
function checkAndOpenCustomPurchaseUrl(chapter) {
  let customUrl = getCustomPurchaseUrl(chapter)
  if (customUrl == "")
    return false

  if (hasFeature("ManuallyUpdateBalance")) {
    openUpdateBalanceMenu(customUrl)
    return true
  }

  scene_msg_box($"onlineShop_buy_{chapter}", null,
    loc("charServer/web_recharge"),
    [["ok", @() openShopUrl(customUrl) ],
     ["cancel", @() null ]
    ],
    "ok",
    { cancel_fn = @() null }
  )

  return true
}

//Check is price.blk is fresh and perform an action.
//If prise.blk is rotten, upfate price.blk and then perform action.
function assyncActionWrap(action) {
  let isActual = ENTITLEMENTS_PRICE.checkUpdate(
    action,
    null,
    true,
    false
  )

  if (isActual)
    action()
}

function doBrowserPurchaseByGuid(guid, dbgGoodsName = "") {
  let isSteam = steam_is_running()
    && (havePlayerTag("steam") || hasFeature("AllowSteamAccountLinking")) //temporary use old code pass for steam

  let url = isSteam
    ? format(loc("url/webstore/steam/item"), guid, steam_get_app_id(), steam_get_my_id().tostring())
    : " ".concat("auto_local", "auto_login", get_url_for_purchase(guid))

  if (url == "") {
    showInfoMsgBox(loc("browser/purchase_url_not_found"), "errorMessageBox")
    log($"get_url_for_purchase have returned empty url for guid/{dbgGoodsName}")
    return
  }

  openShopUrl(url)
}

function doBrowserPurchase(goodsName) {
  if (isPlatformSony || isPlatformXboxOne)
    return openIngameStore()
  //just to avoid bugs, when users, who should to purchase goods in regional
  //web shops, accidentally uses ingame online shop
  let customUrl = getCustomPurchaseUrl(getGoodsChapter(goodsName))
  if (customUrl != "") {
    openShopUrl(customUrl)
    return
  }
  doBrowserPurchaseByGuid(getBundleId(goodsName))
}

function openModalOnlineShop(owner = null, chapter = null, afterCloseFunc = null) {
  if (checkAndOpenCustomPurchaseUrl(chapter))
    return

  if (isInArray(chapter, [null, ""])) {
    local webStoreUrl = getCurCircuitUrl("webstoreURL", loc("url/webstore", ""))
    if (steam_is_running() && (havePlayerTag("steam") || hasFeature("AllowSteamAccountLinking")))
      webStoreUrl = format(loc("url/webstore/steam"), steam_get_my_id().tostring())

    if (webStoreUrl != "")
      return openShopUrl(webStoreUrl)
  }

  let useRowVisual = chapter != null && isInArray(chapter, ["premium", "eagles", "warpoints"])
  let hClass = useRowVisual ? gui_handlers.OnlineShopRowHandler : gui_handlers.OnlineShopHandler
  let prevShopHandler = handlersManager.findHandlerClassInScene(hClass)
  if (prevShopHandler) {
    if (!afterCloseFunc) {
      afterCloseFunc = prevShopHandler.afterCloseFunc
      prevShopHandler.afterCloseFunc = null
    }
    if (prevShopHandler.scene.getModalCounter() != 0)
      handlersManager.destroyModal(prevShopHandler)
  }

  loadHandler(hClass, { owner = owner, afterCloseFunc = afterCloseFunc, chapter = chapter })
}

/*
 * API:
 *
 *  showUnitGoods(unitName)
 *    Find goods and open it in store
*/
function showUnitGoods(unitName, requestOrigin) {
  if (!hasFeature("OnlineShopPacks"))
    return showInfoMsgBox(loc("msgbox/notAvailbleYet"))

  let customUrl = loc("url/custom_purchase/unit", { unitName }, "")
  if (customUrl.len())
    return openShopUrl(customUrl)

  assyncActionWrap(function () {
    let searchResult = searchEntitlementsByUnit(unitName)
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
          doBrowserPurchase(goodsName)
          return
        }
      }
    }

    if (isPlatformSony || isPlatformXboxOne)
      return openIngameStore({ statsdMetric = requestOrigin })

    return openModalOnlineShop()
  })
}
/*end API methods*/

function openBrowserByPurchaseData(purchaseData) {
  if (!purchaseData.canBePurchased)
    return false

  if (isPlatformSony || isPlatformXboxOne)
    return openIngameStore()

  if (purchaseData.customPurchaseLink) {
    openShopUrl(purchaseData.customPurchaseLink)
    return true
  }
  let customPurchaseUrl = getCustomPurchaseUrl(getGoodsChapter(purchaseData.sourceEntitlement))
  if (customPurchaseUrl != "") {
    openShopUrl(customPurchaseUrl)
    return true
  }
  if (purchaseData.guid) {
    doBrowserPurchaseByGuid(purchaseData.guid, purchaseData.sourceEntitlement)
    return true
  }
  return false
}

function openBrowserForFirstFoundEntitlement(entitlementsList) {
  foreach (entitlement in entitlementsList) {
    let purchase = getPurchaseData(entitlement)
    if (purchase.canBePurchased) {
      openBrowserByPurchaseData(purchase)
      break
    }
  }
}

function launchOnlineShop(owner = null, chapter = null, afterCloseFunc = null, launchedFrom = "unknown") {
  if (!isInMenu())
    return afterCloseFunc?()

  if (openIngameStore({ chapter = chapter, afterCloseFunc = afterCloseFunc, statsdMetric = launchedFrom }))
    return

  openModalOnlineShop(owner, chapter, afterCloseFunc)
}

::launchOnlineShop <- launchOnlineShop //!!!FIX ME: Need remove use this function in baseGuiHandlerWT.nut
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //

function openOnlineShopFromPromo(handler, params) {
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
        doBrowserPurchaseByGuid(bundleId, params?[1])
      return
    }
  }
  else
    handler.startOnlineShop(shopType, null, "promo")
}

addPromoAction("online_shop", @(handler, params, _obj) openOnlineShopFromPromo(handler, params))

return {
  showUnitGoods
  doBrowserPurchase
  openBrowserForFirstFoundEntitlement
  openBrowserByPurchaseData
  launchOnlineShop
}