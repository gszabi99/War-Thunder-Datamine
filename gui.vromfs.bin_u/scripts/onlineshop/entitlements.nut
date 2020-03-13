local function getEntitlementConfig(name)
{
  local res = { name = name }

  local pblk = ::DataBlock()
  ::get_shop_prices(pblk)
  if (pblk?[name] != null)
  {
    foreach(param in ["ttl", "httl", "onlinePurchase", "wpIncome", "goldIncome", "goldIncomeFirstBuy",
                      "group", "useGroupAmount", "image", "chapterImage",
                      "aircraftGift", "alias", "chapter", "goldDiscount", "goldCost"])
      if (pblk[name]?[param] != null && !(param in res))
        res[param] <- pblk[name][param]
  }
  return res
}

local function getEntitlementLocId(item)
{
  return ("alias" in item) ? item.alias : ("group" in item) ? item.group : item.name
}

local function getEntitlementAmount(item)
{
  if ("httl" in item)
    return item.httl.tofloat() / 24.0

  foreach(n in ["ttl", "wpIncome", "goldIncome"])
    if ((n in item) && item[n] > 0)
      return item[n]

  return 1
}

local function getEntitlementTimeText(item)
{
  if ("ttl" in item)
    return item.ttl + ::loc("measureUnits/days")
  if ("httl" in item)
    return item.httl + ::loc("measureUnits/hours")
  return ""
}

local function getEntitlementName(item)
{
  local name = ""
  if (("useGroupAmount" in item) && item.useGroupAmount && ("group" in item))
  {
    name = ::loc("charServer/entitlement/" + item.group)
    local amountStr = ::g_language.decimalFormat(getEntitlementAmount(item))
    if(name.indexof("%d") != null)
      name = ::stringReplace(name, "%d", amountStr)
    else
      name = ::loc("charServer/entitlement/" + item.group, {amount = amountStr})
  }
  else
    name = ::loc("charServer/entitlement/" + getEntitlementLocId(item))

  local timeText = getEntitlementTimeText(item)
  if (timeText!="")
    name += " " + timeText
  return name
}

local function getFirstPurchaseAdditionalAmount(item)
{
  if (!::has_entitlement(item.name))
    return ::getTblValue("goldIncomeFirstBuy", item, 0)

  return 0
}

local function getEntitlementPrice(item)
{
  if (("onlinePurchase" in item) && item.onlinePurchase)
  {
    local priceText = ""
    if (::steam_is_running())
      priceText = ::loc("price/steam/" + item.name, "")
    if (priceText == "")
      priceText = ::loc("price/" + item.name, "")

    if (priceText != "")
    {
      local markup = ::steam_is_running() ? 1.0 + getSteamMarkUp()/100.0 : 1.0
      local totalPrice = priceText.tofloat() * markup
      local discount = ::g_discount.getEntitlementDiscount(item.name)
      if (discount)
        totalPrice -= totalPrice * discount * 0.01

      return format(::loc("price/common"),
        item?.chapter == "eagles" ? totalPrice.tostring() : ::g_language.decimalFormat(totalPrice))
    }
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