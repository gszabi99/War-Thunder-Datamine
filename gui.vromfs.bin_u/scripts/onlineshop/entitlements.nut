let { bundlesShopInfo } = require("%scripts/onlineShop/entitlementsInfo.nut")

let function getEntitlementConfig(name)
{
  if (!name || name == "")
    return null

  let res = { name = name }

  let pblk = ::OnlineShopModel.getPriceBlk()
  if (pblk?[name] == null)
    return null

  foreach(param in ["entitlementGift", "aircraftGift", "unlockGift", "decalGift", "attachableGift", "skinGift", "showEntAsGift"])
  {
    if (param in pblk[name])
      res[param] <- pblk[name] % param
  }

  if (res?.showEntAsGift != null)
  {
    if (pblk[name]?.showEntitlementGift)
      res.entitlementGift.extend(res.showEntAsGift)
    else
      res.entitlementGift = res?.showEntAsGift
  }

  for (local i = 0; i < pblk[name].paramCount(); i++)
  {
    let paramName = pblk[name].getParamName(i)
    if (!(paramName in res))
      res[paramName] <- pblk[name].getParamValue(i)
  }

  return res
}

let function getEntitlementLocId(item)
{
  return ("alias" in item) ? item.alias : ("group" in item) ? item.group : (item?.name ?? "unknown")
}

let function getEntitlementAmount(item)
{
  if ("httl" in item)
    return item.httl.tofloat() / 24.0

  foreach(n in ["ttl", "wpIncome", "goldIncome"])
    if ((n in item) && item[n] > 0)
      return item[n]

  return 1
}

let function getEntitlementTimeText(item)
{
  if ("ttl" in item)
    return item.ttl + ::loc("measureUnits/days")
  if ("httl" in item)
    return item.httl + ::loc("measureUnits/hours")
  return ""
}

let function getEntitlementName(item)
{
  local name = ""
  if (("useGroupAmount" in item) && item.useGroupAmount && ("group" in item))
  {
    name = ::loc("charServer/entitlement/" + item.group)
    let amountStr = ::g_language.decimalFormat(getEntitlementAmount(item))
    if(name.indexof("%d") != null)
      name = ::stringReplace(name, "%d", amountStr)
    else
      name = ::loc("charServer/entitlement/" + item.group, {amount = amountStr})
  }
  else
    name = ::loc("charServer/entitlement/" + getEntitlementLocId(item))

  let timeText = getEntitlementTimeText(item)
  if (timeText!="")
    name += " " + timeText
  return name
}

let function getFirstPurchaseAdditionalAmount(item)
{
  if (!::has_entitlement(item.name))
    return ::getTblValue("goldIncomeFirstBuy", item, 0)

  return 0
}

let function getEntitlementPrice(item)
{
  if (item?.onlinePurchase ?? false) {
    let info = bundlesShopInfo.value?[item.name]
    if (info)
      return ::loc($"priceText/{info?.shop_price_curr}", { price = info?.shop_price ?? 0 }, "")

    let priceText = ::loc("price/" + item.name, "")
    if (priceText == "")
      return ""

    let markup = ::steam_is_running() ? 1.0 + getSteamMarkUp()/100.0 : 1.0
    local totalPrice = priceText.tofloat() * markup
    let discount = ::g_discount.getEntitlementDiscount(item.name)
    if (discount)
      totalPrice -= totalPrice * discount * 0.01

    return format(::loc("price/common"),
      item?.chapter == "eagles" ? totalPrice.tostring() : ::g_language.decimalFormat(totalPrice))
  }
  else if ("goldCost" in item)
    return ::Cost(0, ::get_entitlement_cost_gold(item.name)).tostring()
  return ""
}

return {
  getEntitlementConfig = getEntitlementConfig
  getEntitlementLocId = getEntitlementLocId
  getEntitlementAmount = getEntitlementAmount
  getEntitlementName = getEntitlementName
  getFirstPurchaseAdditionalAmount = getFirstPurchaseAdditionalAmount
  getEntitlementTimeText = getEntitlementTimeText
  getEntitlementPrice = getEntitlementPrice
}