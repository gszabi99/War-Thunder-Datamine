from "%scripts/dagui_library.nut" import *
from "dagor.http" import HTTP_SUCCESS
from "json" import parse_json
from "dagor.workcycle" import resetTimeout, clearTimer
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { getBundlesBlockName } = require("%scripts/onlineShop/onlineBundles.nut")
let { requestMultipleItems } = require("%scripts/onlineShop/shopItemInfo.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isPlatformPC } = require("%scripts/clientState/platform.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { eventbus_subscribe } = require("eventbus")
let { getShopPriceBlk } = require("%scripts/onlineShop/onlineShopState.nut")

let logE = log_with_prefix("[ENTITLEMENTS INFO] ")

const MAX_COUNT_IN_REQUEST = 70
const MIN_TIME_BETWEEN_SAME_REQUESTS_SEC = 300
let bundlesShopInfo = Watched({})
let isInRequest = mkWatched(persist, "isInRequest", false)
let fullListData = {}
let listForRequest = {}

function shouldRequestEntitlement(entName) {
  let priceBlk = getShopPriceBlk()
  let entBlk = priceBlk?[entName]
  if (entBlk == null)
    return false

  let chapter = entBlk?.chapter ?? ""
  if (chapter == "eagles" || chapter == "premium")
    return true

  let aircraftGiftList = entBlk % "aircraftGift"
  foreach (unitName in aircraftGiftList) {
    let unit = getAircraftByName(unitName)
    if (unit == null || !unit.isVisibleInShop() || unit.isBought())
      continue
    let canBuy = !!unit.gift && unit.event == null
      && unit.marketplaceItemdefId == null && !unit.isCrossPromo
    if (canBuy)
      return true
  }
  return false
}

function requestBundlesShopInfo() {
  if (isInRequest.get() || listForRequest.len() == 0)
    return
  let guids = listForRequest.keys()
  if (guids.len() > MAX_COUNT_IN_REQUEST)
    guids.resize(MAX_COUNT_IN_REQUEST)
  isInRequest.set(true)
  requestMultipleItems(guids, "requestMultipleItemsCb")
}

function updateBundlesShopInfo() {
  if (!isLoggedIn.get() || !isPlatformPC)
    return

  let bundlesList = GUI.get()?.bundles[getBundlesBlockName()]
  if (bundlesList == null)
    return

  fullListData.clear()
  listForRequest.clear()

  for (local i = 0; i < bundlesList.paramCount(); i++) {
    let entName = bundlesList.getParamName(i)
    if (!shouldRequestEntitlement(entName))
      continue
    let guid = bundlesList.getParamValue(i)
    fullListData[entName] <- guid
    listForRequest[guid] <- entName
  }

  logE($"Update bundles shop info. request items count {fullListData.len()}, full list count {bundlesList.paramCount()}")
  if (listForRequest.len()) {
    clearTimer(requestBundlesShopInfo)
    requestBundlesShopInfo()
  }
  else
    bundlesShopInfo.set({})
}

updateBundlesShopInfo()

function tryRequestDelayed() {
  resetTimeout(MIN_TIME_BETWEEN_SAME_REQUESTS_SEC, requestBundlesShopInfo)
}

function requestMultipleItemsCb(response) {
  isInRequest.set(false)
  if (!isLoggedIn.get())
    return

  let { status = -1, http_code = -1, body = null, context = null } = response
  if (status != HTTP_SUCCESS || http_code < 200 || 300 <= http_code || body == null || context == null) {
    logE($"Error response (http_code = {http_code}, status = {status})")
    tryRequestDelayed()
    return
  }

  local data = null
  try {
    let bodyStr = body.as_string()
    if (bodyStr.len() > 6 && bodyStr.slice(0, 6) == "<html>") { 
      logE("Error: request result is html page instead of data")
      tryRequestDelayed()
      return
    }
    data = parse_json(bodyStr)
  }
  catch(e) {
    logE($"Error: failed getting: {e}")
  }
  let { items = null } = data
  if (data?.status != "OK" || items == null) {
    logE($"Request error: status = {data?.status}, error = {data?.error}, hasItems = {items != null}")
    tryRequestDelayed()
    return
  }

  logE($"Received success result guidsCount = {context.len()}")
  let resList = {}
  foreach (guid in context) {
    if (guid not in listForRequest)
      continue

    let id = listForRequest[guid]
    listForRequest.$rawdelete(guid)
    if (guid in items)
      resList[id] <- items[guid].__merge({ guid })
  }
  if (resList.len() > 0)
    bundlesShopInfo.mutate(@(info) info.__update(resList))

  requestBundlesShopInfo()
}

eventbus_subscribe("requestMultipleItemsCb", requestMultipleItemsCb)

function resetCache() {
  fullListData.clear()
  listForRequest.clear()
  bundlesShopInfo.set({})
  isInRequest.set(false)
  updateBundlesShopInfo()
}

addListenersWithoutEnv({
  SignOut = @(_p) resetCache()
  LoginComplete = @(_p) resetCache()
  PriceUpdated = @(_p) updateBundlesShopInfo()
  EntitlementsPriceUpdated = @(_p) updateBundlesShopInfo()
}, g_listener_priority.CONFIG_VALIDATION)

return {
  bundlesShopInfo
}