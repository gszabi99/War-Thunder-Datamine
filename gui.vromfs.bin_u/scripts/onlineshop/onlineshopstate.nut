from "%scripts/dagui_natives.nut" import has_entitlement, get_shop_prices
from "%scripts/dagui_library.nut" import *
let DataBlock = require("DataBlock")
let { get_game_settings_blk } = require("blkGetters")
let { addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { getBundleId } = require("%scripts/onlineShop/onlineBundles.nut")







local shopPriceBlkCache = null
local purchaseDataCache = {}
local searchEntitlementsCache = null

function invalidateShopPriceBlk() {
  shopPriceBlkCache = null
  searchEntitlementsCache = null
  purchaseDataCache.clear()
}

function validateShopPriceBlk() {
  if (shopPriceBlkCache)
    return
  shopPriceBlkCache = DataBlock()
  get_shop_prices(shopPriceBlkCache)
}

function getShopPriceBlk() {
  validateShopPriceBlk()
  return shopPriceBlkCache
}

function searchEntitlementsByUnit(unitName) {
  if (searchEntitlementsCache)
    return searchEntitlementsCache?[unitName] ?? []

  searchEntitlementsCache = {}
  let priceBlk = getShopPriceBlk()
  let numBlocks = priceBlk.blockCount()
  for (local i = 0; i < numBlocks; i++) {
    let ib = priceBlk.getBlock(i)
    let entitlementName = ib.getBlockName()
    if (ib?.hideWhenUnbought && !has_entitlement(entitlementName))
      continue

    foreach (name in ib % "aircraftGift") {
      if (name not in searchEntitlementsCache)
        searchEntitlementsCache[name] <- []

      searchEntitlementsCache[name].append(entitlementName)
    }
  }
  return searchEntitlementsCache?[unitName] ?? []
}

let getGoodsChapter = @(goodsName) getShopPriceBlk()?[goodsName].chapter ?? ""





function getEntitlementsByFeature(name) {
  let entitlements = []
  if (name == null)
    return entitlements
  let feature = get_game_settings_blk()?.features?[name]
  if (feature == null)
    return entitlements
  foreach (condition in (feature % "condition")) {
    if (type(condition) == "string" && (condition in getShopPriceBlk()))
      entitlements.append(condition)
  }
  return entitlements
}













function createPurchaseData(goodsName = "", guid = null, customPurchaseLink = null) {
  let res = {
    canBePurchased = !!(guid || customPurchaseLink)
    guid = guid
    customPurchaseLink = customPurchaseLink
    sourceEntitlement = goodsName
  }
  if (goodsName != "")
      purchaseDataCache[goodsName] <- res
  return res
}

local purchaseDataRecursion = 0
function getPurchaseData(goodsName) {
  if (goodsName in purchaseDataCache)
    return purchaseDataCache[goodsName]

  if (purchaseDataRecursion > 10) {
    let msg = $"OnlineShopModel: getPurchaseData: found recursion for {goodsName}"
    script_net_assert_once("getPurchaseData recursion", msg)
    return createPurchaseData(goodsName)
  }

  let customPurchaseLink = loc($"customPurchaseLink/{goodsName}", "")
  if (customPurchaseLink != "")
    return createPurchaseData(goodsName, null, customPurchaseLink)

  let guid = getBundleId(goodsName)
  if (guid != "")
    return createPurchaseData(goodsName, guid)

  purchaseDataRecursion++
  
  local res = null
  let priceBlk = getShopPriceBlk()
  let numBlocks = priceBlk.blockCount()
  for (local i = 0; i < numBlocks; i++) {
    let blk = priceBlk.getBlock(i)
    if (!isInArray(goodsName, blk % "entitlementGift")
        && !isInArray(goodsName, blk % "fingerprintController"))
      continue

    let entitlement = blk.getBlockName()
    let purchData = getPurchaseData(entitlement)
    if (!purchData.canBePurchased)
      continue

    res = purchData
    purchaseDataCache[goodsName] <- res
    break
  }

  purchaseDataRecursion--
  return res ?? createPurchaseData(goodsName)
}



function getFeaturePurchaseData(feature) {
  local res = null
  foreach (entitlement in getEntitlementsByFeature(feature)) {
    res = getPurchaseData(entitlement)
    if (res.canBePurchased)
      return res
  }
  return res ?? createPurchaseData()
}



function getAllFeaturePurchases(feature) {
  let res = []
  foreach (entitlement in getEntitlementsByFeature(feature)) {
    let purchase = getPurchaseData(entitlement)
    if (purchase.canBePurchased)
      res.append(purchase)
  }
  return res
}

addListenersWithoutEnv({
  ProfileUpdated = @(_) searchEntitlementsCache = null
  EntitlementsPriceUpdated = @(_) invalidateShopPriceBlk()
  SignOut = @(_) invalidateShopPriceBlk()
}, CONFIG_VALIDATION)

return {
  searchEntitlementsByUnit
  getShopPriceBlk
  getGoodsChapter
  getPurchaseData
  getFeaturePurchaseData
  getAllFeaturePurchases
}
