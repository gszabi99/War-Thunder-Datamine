from "%scripts/dagui_natives.nut" import has_entitlement, get_entitlement_cost_gold
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let { format } = require("string")
let { bundlesShopInfo } = require("%scripts/onlineShop/entitlementsInfo.nut")
let { formatLocalizationArrayToDescription } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { doesLocTextExist } = require("dagor.localize")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { get_warpoints_blk, get_ranks_blk } = require("blkGetters")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { getShopPriceBlk } = require("%scripts/onlineShop/onlineShopState.nut")
let { measureType } = require("%scripts/measureType.nut")
let { steam_is_running } = require("steam")
let { isPC } = require("%sqstd/platform.nut")

let exchangedWarpointsExpireDays = {
  ["Japanese"] = 180
}

let premiumAccountDescriptionArr = [
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_1"
    isBold = false
    color = null
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_2"
    isBold = true
    color = "@userlogColoredText"
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_3"
    isBold = true
    color = "@userlogColoredText"
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_4"
    isBold = true
    color = "@userlogColoredText"
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_5"
    isBold = true
    color = "@userlogColoredText"
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_9"
    isBold = false
    color = "@highlightedTextColor"
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_6"
    isBold = false
    color = "@highlightedTextColor"
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_7"
    isBold = false
    color = "@highlightedTextColor"
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_8"
    isBold = false
    color = "@highlightedTextColor"
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_10"
    isBold = false
    color = "@highlightedTextColor"
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_11"
    isBold = false
    color = "@highlightedTextColor"
    isVisible = @() isPC && hasFeature("PrivacySettings")
  },
  {
    locId = "charServer/entitlement/PremiumAccount/desc/string_12"
    isBold = false
    color = "@highlightedTextColor"
  },
]

let getPremiumAccountDescriptionArr = @() premiumAccountDescriptionArr.filter(
 @(v) v?.isVisible() ?? true)

function getEntitlementConfig(name) {
  if (!name || name == "")
    return null

  let res = { name = name }

  let pblk = getShopPriceBlk()
  if (pblk?[name] == null)
    return null

  foreach (param in ["entitlementGift", "aircraftGift", "unlockGift", "decalGift", "attachableGift", "skinGift", "showEntAsGift"]) {
    if (param in pblk[name])
      res[param] <- pblk[name] % param
  }

  if (res?.showEntAsGift != null) {
    if (pblk[name]?.showEntitlementGift)
      res.entitlementGift.extend(res.showEntAsGift)
    else
      res.entitlementGift = res?.showEntAsGift
  }

  for (local i = 0; i < pblk[name].paramCount(); i++) {
    let paramName = pblk[name].getParamName(i)
    if (!(paramName in res))
      res[paramName] <- pblk[name].getParamValue(i)
  }

  return res
}

function getEntitlementLocId(ent) {
  return ("alias" in ent) ? ent.alias : ("group" in ent) ? ent.group : (ent?.name ?? "unknown")
}

function getEntitlementAmount(ent) {
  if ("httl" in ent)
    return ent.httl.tofloat() / 24.0

  foreach (n in ["ttl", "wpIncome", "goldIncome"])
    if ((n in ent) && ent[n] > 0)
      return ent[n]

  return 1
}

function getEntitlementTimeText(ent) {
  if ("ttl" in ent)
    return "".concat(ent.ttl, loc("measureUnits/days"))
  if ("httl" in ent)
    return "".concat(ent.httl, loc("measureUnits/hours"))
  return ""
}

function getEntitlementFullTimeText(ent) {
  if ("ttl" in ent)
    return loc("measureUnits/full/days", { n = ent.ttl })
  if ("httl" in ent)
    return loc("measureUnits/full/hours", { n = ent.httl })
  return ""
}

function getEntitlementShortName(ent) {
  local name = ""
  if (("useGroupAmount" in ent) && ent.useGroupAmount && ("group" in ent)) {
    name = loc($"charServer/entitlement/{ent.group}")
    let amountStr = decimalFormat(getEntitlementAmount(ent))
    if (name.indexof("%d") != null)
      return name.replace("%d", amountStr)
    return loc($"charServer/entitlement/{ent.group}", { amount = amountStr })
  }
  return loc($"charServer/entitlement/{getEntitlementLocId(ent)}")
}

function getEntitlementName(ent) {
  local name = getEntitlementShortName(ent)
  let timeText = getEntitlementTimeText(ent)
  if (timeText != "")
    name = $"{name} {timeText}"
  return name
}

function getFirstPurchaseAdditionalAmount(ent) {
  if (!has_entitlement(ent.name))
    return getTblValue("goldIncomeFirstBuy", ent, 0)

  return 0
}

function getEntitlementPrice(ent) {
  if (ent?.onlinePurchase ?? false) {
    let info = bundlesShopInfo.get()?[ent.name]
    if (info) {
      let { shop_price = 0, shop_price_curr = "" } = info
      let locId = $"priceText/{shop_price_curr}"
      return doesLocTextExist(locId) ? loc(locId, { price = shop_price }) : $"{shop_price} {utf8ToUpper(shop_price_curr)}"
    }
  }
  else if ("goldCost" in ent)
    return Cost(0, get_entitlement_cost_gold(ent.name)).tostring()
  return ""
}

local bonusPercentText = @(v) "+{0}".subst(measureType.PERCENT_FLOAT.getMeasureUnitsText(v - 1.0))

function getEntitlementPriceFloat(ent) {
  return ent?.goldCost ? ent.goldCost.tofloat() : -1.0
}

function getPricePerEntitlement(ent) {
  let amount = getEntitlementAmount(ent)
  if (amount <= 0)
    return 0.0

  return getEntitlementPriceFloat(ent) / amount
}

function  getEntitlementLocParams() {
  let rBlk = get_ranks_blk()
  let wBlk = get_warpoints_blk()

  let premiumRpMult = rBlk?.xpMultiplier ?? 1.0
  let premiumWpMult = wBlk?.wpMultiplier ?? 1.0
  let premiumBattleTimeWpMult = premiumWpMult * (wBlk?.battleTimePremMul ?? 1.0)
  let premiumOtherModesWpMult = premiumWpMult

  return {
    bonusRpPercent           = bonusPercentText(premiumRpMult)
    bonusWpPercent           = bonusPercentText(premiumWpMult)
    bonusBattleTimeWpPercent = bonusPercentText(premiumBattleTimeWpMult)
    bonusOtherModesWpPercent = bonusPercentText(premiumOtherModesWpMult)
  }
}

let canBuyEntitlement = @(ent)
  (ent?.hideWhenUnbougth ?? false)
    || ent?.chapter == "campaign"
    || ent?.chapter == "license"
    || ent?.chapter == "bonuses"

function getEntitlementBundles() {
  let bundles = {}
  let eblk = getShopPriceBlk()
  let numBlocks = eblk.blockCount()
  for (local i = 0; i < numBlocks; i++) {
    let ib = eblk.getBlock(i)
    let name = ib.getBlockName()
    if (ib?.bundle)
        bundles[name] <- ib.bundle % "item"
  }
  return bundles
}

function isBoughtEntitlement(ent) {
  let bundles = getEntitlementBundles()
  if (ent?.name != null && bundles?[ent.name] != null) {
    let isBought = callee()
    foreach (name in bundles[ent.name])
      if (!this.goods?[name] || !isBought(this.goods[name]))
        return false
    return true
  }
  let realname = ent?.alias ?? ent.name
  return (canBuyEntitlement(ent) && has_entitlement(realname))
}

function getEntitlementDescription(product, _productId) {
  if (product == null)
    return ""

  let paramTbl =  getEntitlementLocParams()

  let entLocId = getEntitlementLocId(product)
  if (["PremiumAccount", "PremiumAccountSubscription"].contains(entLocId)) {
    let locArr = getPremiumAccountDescriptionArr().map(@(d) d.__merge(
      { text = loc(d.locId, paramTbl), isBold = product?.isItem ? false : d.isBold }
    ))

    return formatLocalizationArrayToDescription(locArr)
  }

  let resArr = []
  if (product?.useGroupAmount && ("group" in product))
    paramTbl.amount <- getEntitlementAmount(product).tointeger()

  let locId = $"charServer/entitlement/{entLocId}/desc"
  resArr.append(loc(locId, paramTbl))

  foreach (giftName in product?.entitlementGift ?? []) {
    let config = giftName.slice(0, 4) == "Rate" ? getEntitlementConfig(product.name) : getEntitlementConfig(giftName)
    resArr.append(format(loc("charServer/gift/entitlement"), getEntitlementName(config)))
  }

  foreach (airName in product?.aircraftGift ?? [])
    resArr.append(format(loc("charServer/gift/aircraft"), getUnitName(airName)))

  if (product?.goldIncome && product?.chapter != "eagles")
    resArr.append(format(loc("charServer/gift"), "".concat(product.goldIncome, loc("gold/short/colored"))))

  if ("afterGiftsDesc" in product)
    resArr.append("\n{0}".subst(loc(product.afterGiftsDesc)))

  if (product?.onlinePurchase && !isBoughtEntitlement(product) && steam_is_running())
    resArr.append(loc("charServer/web_purchase"))

  if (product?.chapter == "warpoints") {
    let days = exchangedWarpointsExpireDays?[getLanguageName()] ?? 0
    if (days > 0)
      resArr.append(colorize("warningTextColor",
        loc("charServer/chapter/warpoints/expireWarning", { days = days })))
  }

  return "\n".join(resArr)
}

function getWarpointsGoldCost(amount) {
  local entitlementGoldCost = 0
  local entitlementWpAmount = 0
  let eblk = getShopPriceBlk()
  let numBlocks = eblk.blockCount()
  for (local i = 0; i < numBlocks; i++) {
    let ib = eblk.getBlock(i)
    let { chapter = null, goldCost = 0, wpIncome = 0 } = ib
    if (chapter != "warpoints" || wpIncome == 0 || goldCost == 0)
      continue
    if (amount < wpIncome)
      break

    entitlementWpAmount = wpIncome
    entitlementGoldCost = goldCost
    if (amount == wpIncome)
      break
  }
  if (entitlementWpAmount == 0)
    return Cost()
  if (entitlementWpAmount == amount)
    return Cost(0, entitlementGoldCost)

  return Cost(0, (entitlementGoldCost.tofloat() * amount / entitlementWpAmount).tointeger())
}

return {
  getEntitlementConfig
  getEntitlementLocId
  getEntitlementAmount
  getEntitlementName
  getEntitlementShortName
  getEntitlementTimeText
  getEntitlementFullTimeText
  getEntitlementPrice
  getEntitlementPriceFloat
  getEntitlementDescription
  getFirstPurchaseAdditionalAmount
  getPricePerEntitlement
  isBoughtEntitlement
  getEntitlementLocParams
  canBuyEntitlement
  getPremiumAccountDescriptionArr
  getWarpointsGoldCost
}