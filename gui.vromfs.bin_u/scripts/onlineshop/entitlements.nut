//-file:plus-string
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
  }
]

let function getEntitlementConfig(name) {
  if (!name || name == "")
    return null

  let res = { name = name }

  let pblk = ::OnlineShopModel.getPriceBlk()
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

let function getEntitlementLocId(ent) {
  return ("alias" in ent) ? ent.alias : ("group" in ent) ? ent.group : (ent?.name ?? "unknown")
}

let function getEntitlementAmount(ent) {
  if ("httl" in ent)
    return ent.httl.tofloat() / 24.0

  foreach (n in ["ttl", "wpIncome", "goldIncome"])
    if ((n in ent) && ent[n] > 0)
      return ent[n]

  return 1
}

let function getEntitlementTimeText(ent) { // -return-different-types
  if ("ttl" in ent)
    return ent.ttl + loc("measureUnits/days")
  if ("httl" in ent)
    return ent.httl + loc("measureUnits/hours")
  return ""
}

let function getEntitlementName(ent) {
  local name = ""
  if (("useGroupAmount" in ent) && ent.useGroupAmount && ("group" in ent)) {
    name = loc("charServer/entitlement/" + ent.group)
    let amountStr = decimalFormat(getEntitlementAmount(ent))
    if (name.indexof("%d") != null)
      name = ::stringReplace(name, "%d", amountStr)
    else
      name = loc("charServer/entitlement/" + ent.group, { amount = amountStr })
  }
  else
    name = loc("charServer/entitlement/" + getEntitlementLocId(ent))

  let timeText = getEntitlementTimeText(ent)
  if (timeText != "")
    name += " " + timeText
  return name
}

let function getFirstPurchaseAdditionalAmount(ent) {
  if (!::has_entitlement(ent.name))
    return getTblValue("goldIncomeFirstBuy", ent, 0)

  return 0
}

let function getEntitlementPrice(ent) {
  if (ent?.onlinePurchase ?? false) {
    let info = bundlesShopInfo.value?[ent.name]
    if (info) {
      let { shop_price = 0, shop_price_curr = "" } = info
      let locId = $"priceText/{shop_price_curr}"
      return doesLocTextExist(locId) ? loc(locId, { price = shop_price }) : $"{shop_price} {utf8ToUpper(shop_price_curr)}"
    }

    let priceText = loc("price/" + ent.name, "")
    if (priceText == "")
      return ""

    let markup = ::steam_is_running() ? 1.0 + ::getSteamMarkUp() / 100.0 : 1.0
    local totalPrice = priceText.tofloat() * markup
    let discount = ::g_discount.getEntitlementDiscount(ent.name)
    if (discount)
      totalPrice -= totalPrice * discount * 0.01

    return format(loc("price/common"),
      ent?.chapter == "eagles" ? totalPrice.tostring() : decimalFormat(totalPrice))
  }
  else if ("goldCost" in ent)
    return Cost(0, ::get_entitlement_cost_gold(ent.name)).tostring()
  return ""
}

local bonusPercentText = @(v) "+{0}".subst(::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(v - 1.0))

let function getEntitlementPriceFloat(ent) {
  local cost = -1.0
  if (ent?.onlinePurchase) {
    local costText = ""
    if (::steam_is_running())
      costText = loc($"price/steam/{ent.name}", "")
    if (costText == "")
      costText = loc($"price/{ent.name}", "")

    if (costText != "")
      cost = costText.tofloat()
  }
  else if (ent?.goldCost)
    cost = ent.goldCost.tofloat()

  return cost
}

let function getPricePerEntitlement(ent) {
  let amount = getEntitlementAmount(ent)
  if (amount <= 0)
    return 0.0

  return getEntitlementPriceFloat(ent) / amount
}

let function  getEntitlementLocParams() {
  let rBlk = get_ranks_blk()
  let wBlk = get_warpoints_blk()

  let premiumRpMult = rBlk?.xpMultiplier || 1.0
  let premiumWpMult = wBlk?.wpMultiplier || 1.0
  let premiumBattleTimeWpMult = premiumWpMult * (wBlk?.battleTimePremMul || 1.0)
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

let function getEntitlementBundles() {
  let bundles = {}
  let eblk = ::OnlineShopModel.getPriceBlk()
  let numBlocks = eblk.blockCount()
  for (local i = 0; i < numBlocks; i++) {
    let ib = eblk.getBlock(i)
    let name = ib.getBlockName()
    if (ib?.bundle)
        bundles[name] <- ib.bundle % "item"
  }
  return bundles
}

let function isBoughtEntitlement(ent) {
  let bundles = getEntitlementBundles()
  if (ent?.name != null && bundles?[ent.name] != null) {
    let isBought = callee()
    foreach (name in bundles[ent.name])
      if (!this.goods?[name] || !isBought(this.goods[name]))
        return false
    return true
  }
  let realname = ent?.alias ?? ent.name
  return (canBuyEntitlement(ent) && ::has_entitlement(realname))
}

let function getEntitlementDescription(product, _productId) {
  if (product == null)
    return ""

  let paramTbl =  getEntitlementLocParams()

  let entLocId = getEntitlementLocId(product)
  if (entLocId == "PremiumAccount") {
    let locArr = premiumAccountDescriptionArr.map(@(d) d.__merge({ text = loc(d.locId, paramTbl) }))

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

  if (product?.onlinePurchase && !isBoughtEntitlement(product) && ::steam_is_running())
    resArr.append(loc("charServer/web_purchase"))

  if (product?.chapter == "warpoints") {
    let days = exchangedWarpointsExpireDays?[::g_language.getLanguageName()] ?? 0
    if (days > 0)
      resArr.append(colorize("warningTextColor",
        loc("charServer/chapter/warpoints/expireWarning", { days = days })))
  }

  return "\n".join(resArr)
}

return {
  getEntitlementConfig
  getEntitlementLocId
  getEntitlementAmount
  getEntitlementName
  getEntitlementTimeText
  getEntitlementPrice
  getEntitlementPriceFloat
  getEntitlementDescription
  getFirstPurchaseAdditionalAmount
  getPricePerEntitlement
  isBoughtEntitlement
  getEntitlementLocParams
  canBuyEntitlement
  premiumAccountDescriptionArr
}