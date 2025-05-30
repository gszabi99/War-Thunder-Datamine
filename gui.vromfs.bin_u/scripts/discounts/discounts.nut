from "%scripts/dagui_natives.nut" import ps4_get_region, has_entitlement, get_entitlements_price_blk, get_entitlement_gold_discount
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { deferOnce, setTimeout, clearTimer } = require("dagor.workcycle")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getTimestampFromStringUtc } = require("%scripts/time.nut")
let { targetPlatform, isPlatformPC, isPlatformPS4 } = require("%scripts/clientState/platform.nut")

let { canUseIngameShop, haveDiscount, getShopItemsTable, needEntStoreDiscountIcon
} = require("%scripts/onlineShop/entitlementsShopData.nut")

let { getEntitlementId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getEntitlementConfig } = require("%scripts/onlineShop/entitlements.nut")
let { discountUnitsBundles } = require("%scripts/onlineShop/discountBundles.nut")

let { eachBlock } = require("%sqstd/datablock.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_charserver_time_sec } = require("chard")
let { get_price_blk } = require("blkGetters")
let { isUnitGift } = require("%scripts/unit/unitShopInfo.nut")
let { isCountryAvailable } = require("%scripts/firstChoice/firstChoice.nut")
let { getDiscountByPath } = require("%scripts/discounts/discountUtils.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { discountsList, consoleEntitlementUnits, getEntitlementUnitDiscount,
  getUnitDiscountByName, canBeVisibleDiscountOnUnit
} = require("%scripts/discounts/discountsState.nut")

const UPDATE_DISCOUNT_DATA_TIMER_ID = "update_discount_data"
const TOP_MENU_ONLINE_SHOP_ID = "online_shop"

let platformMapForDiscountFromGuiBlk = {
  pc = isPlatformPC
  ps4_scee = isPlatformPS4 && ps4_get_region() == SCE_REGION_SCEE
  ps4_scea = isPlatformPS4 && ps4_get_region() == SCE_REGION_SCEA
  ps4_scej = isPlatformPS4 && ps4_get_region() == SCE_REGION_SCEJ
}

function clearDiscountsList() {
  discountsList.clear()
  discountsList.__update({
    [TOP_MENU_ONLINE_SHOP_ID] = false,
    changeExp = false,
    topmenu_research = false,
    entitlements = {},
    entitlementUnits = {},
    airList = {},
  })
}

function pushDiscountsUpdateEvent() {
  updateGamercards()
  broadcastEvent("DiscountsDataUpdated")
}

function checkEntitlement(entName, entlBlock, giftUnits) {
  let discountItemList = ["premium", "warpoints", "eagles", "campaign", "bonuses"]
  local chapter = entlBlock?.chapter
  if (!isInArray(chapter, discountItemList))
    return

  local discount = get_entitlement_gold_discount(entName)
  let singleDiscount = entlBlock?.singleDiscount && !has_entitlement(entName)
                            ? entlBlock.singleDiscount
                            : 0

  discount = max(discount, singleDiscount)
  if (discount == 0)
    return

  discountsList.entitlements[entName] <- discount

  if (chapter == "campaign" || chapter == "bonuses") {
    if (canUseIngameShop())
      chapter = TOP_MENU_ONLINE_SHOP_ID
  }

  local chapterVal = true
  if (chapter == TOP_MENU_ONLINE_SHOP_ID)
    chapterVal = canUseIngameShop() || isPlatformPC
  discountsList[chapter] <- chapterVal

  if (entlBlock?.aircraftGift)
    foreach (unitName in entlBlock % "aircraftGift")
      if (unitName in giftUnits)
        discountsList.entitlementUnits[unitName] <- discount
}

function updateGiftUnitsDiscountFromGuiBlk(giftUnits) { 
  let discountsBlk = GUI.get()?.entitlement_units_discount
  if (discountsBlk == null)
    return null

  local minUpdateDiscountsTimeSec = null
  for (local i = 0; i < discountsBlk.blockCount(); i++) {
    let discountConfigBlk = discountsBlk.getBlock(i)
    let platforms = (discountConfigBlk?.platform ?? "pc").split(";")
    local isSuitableForCurrentPlatform = false
    foreach (platform in platforms) {
      if (targetPlatform != platform && !(platformMapForDiscountFromGuiBlk?[platform] ?? false))
        continue

      isSuitableForCurrentPlatform = true
      break
    }

    if (!isSuitableForCurrentPlatform)
      continue

    let startTime = getTimestampFromStringUtc(discountConfigBlk.beginDate)
    let endTime = getTimestampFromStringUtc(discountConfigBlk.endDate)
    let currentTime = get_charserver_time_sec()
    if (currentTime >= endTime)
      continue

    if (currentTime < startTime) {
      let updateTimeSec = startTime - currentTime
      minUpdateDiscountsTimeSec = min(minUpdateDiscountsTimeSec ?? updateTimeSec, updateTimeSec)
      continue
    }

    let updateTimeSec = endTime - currentTime
    minUpdateDiscountsTimeSec = min(minUpdateDiscountsTimeSec ?? updateTimeSec, updateTimeSec)
    foreach (unitName, discount in discountConfigBlk)
      if (unitName in giftUnits)
        discountsList.entitlementUnits[unitName] <- discount
  }
  return minUpdateDiscountsTimeSec
}

function updateDiscountData(isSilentUpdate = false) {
  clearDiscountsList()

  let pBlk = get_price_blk()

  let chPath = ["exp_to_gold_rate"]
  chPath.append(shopCountriesList)
  discountsList.changeExp = getDiscountByPath(chPath, pBlk) > 0

  let giftUnits = {}

  foreach (air in getAllUnits())
    if (isCountryAvailable(air.shopCountry)
        && !air.isBought()
        && air.isVisibleInShop()) {
      if (isUnitGift(air)) {
        if (isPlatformPC)
          giftUnits[air.name] <- 0
        continue
      }

      let path = ["aircrafts", air.name]
      let discount = getDiscountByPath(path, pBlk)
      if (discount > 0)
        discountsList.airList[air.name] <- discount
    }

  eachBlock(get_entitlements_price_blk(), @(b, n) checkEntitlement(n, b, giftUnits))

  clearTimer(UPDATE_DISCOUNT_DATA_TIMER_ID)
  let minUpdateDiscountsTimeSec = updateGiftUnitsDiscountFromGuiBlk(giftUnits)  
  if (minUpdateDiscountsTimeSec != null)
    setTimeout(minUpdateDiscountsTimeSec, updateDiscountData, UPDATE_DISCOUNT_DATA_TIMER_ID)

  if (canUseIngameShop() && needEntStoreDiscountIcon)
    discountsList[TOP_MENU_ONLINE_SHOP_ID] = haveDiscount()

  discountsList.entitlementUnits.__update(
    consoleEntitlementUnits, discountUnitsBundles.get())

  local isShopDiscountVisible = false
  foreach (airName, discount in discountsList.airList)
    if (discount > 0 && canBeVisibleDiscountOnUnit(getAircraftByName(airName))) {
      isShopDiscountVisible = true
      break
    }
  if (!isShopDiscountVisible)
    foreach (airName, discount in discountsList.entitlementUnits)
      if (discount > 0 && canBeVisibleDiscountOnUnit(getAircraftByName(airName))) {
        isShopDiscountVisible = true
        break
      }
  discountsList.topmenu_research = isShopDiscountVisible

  if (!isSilentUpdate)
    pushDiscountsUpdateEvent()
}

function updateOnlineShopDiscounts() {
  consoleEntitlementUnits.clear()

  if (!needEntStoreDiscountIcon)
    return

  let isDiscountAvailable = haveDiscount()
  discountsList[TOP_MENU_ONLINE_SHOP_ID] = isDiscountAvailable

  if (isDiscountAvailable)
    foreach (_label, item in getShopItemsTable()) {
      if (item.haveDiscount()) {
        let entId = getEntitlementId(item.id)
        let config = getEntitlementConfig(entId)
        let unitsList = config?.aircraftGift ?? []
        foreach (unitName in unitsList)
          consoleEntitlementUnits[unitName] <- item.getDiscountPercent()
      }
    }

  updateDiscountData()
}

clearDiscountsList()

discountUnitsBundles.subscribe(@(_) updateDiscountData())

addListenersWithoutEnv({
  XboxShopDataUpdated         = @(_) updateOnlineShopDiscounts()
  Ps4ShopDataUpdated          = @(_) updateOnlineShopDiscounts()
  EpicShopDataUpdated         = @(_) updateOnlineShopDiscounts()
  EpicShopItemUpdated         = @(_) updateOnlineShopDiscounts()
  PriceUpdated                = @(_) updateDiscountData()
  EntitlementsPriceUpdated    = @(_) updateDiscountData()

  function UnitBought(p) {
    let unitName = getTblValue("unitName", p)
    if (!unitName)
      return

    if (getUnitDiscountByName(unitName) == 0 && getEntitlementUnitDiscount(unitName) == 0)
      return

    updateDiscountData()
    
    deferOnce(pushDiscountsUpdateEvent)
  }
}, g_listener_priority.CONFIG_VALIDATION)

return {
  updateDiscountData
  updateOnlineShopDiscounts
}
