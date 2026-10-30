import "%scripts/g_listener_priority.nut" as g_listener_priority
from "%scripts/unit/unitsData.nut" import getAllUnits
from "%scripts/time.nut" import getTimestampFromStringUtc
from "%sqstd/platform.nut" import platformId, isPC, isPS4
from "%scripts/onlineShop/entitlementsShopData.nut" import canUseIngameShop, haveDiscount, getShopItemsTable, needEntStoreDiscountIcon
from "%scripts/onlineShop/onlineBundles.nut" import getEntitlementId
from "%scripts/onlineShop/entitlements.nut" import getEntitlementConfig
from "%scripts/onlineShop/discountBundles.nut" import discountUnitsBundles
from "%scripts/unit/unitShopInfo.nut" import isUnitGift
from "%scripts/unit/unitStatus.nut" import canBuyNotResearched, isUnitResearched
from "%scripts/firstChoice/firstChoice.nut" import isCountryAvailable
from "%scripts/discounts/discountUtils.nut" import getDiscountByPath
from "%scripts/gamercard/gamercard.nut" import updateGamercards
from "%scripts/discounts/discountsState.nut" import getEntitlementUnitDiscount, getUnitDiscountByName, canBeVisibleDiscountOnUnit
from "%scripts/items/itemsManagerModule.nut" import getInventoryList
from "%scripts/tasker.nut" import addTask
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "dagor.workcycle" import deferOnce, setTimeout, clearTimer
from "%sqstd/datablock.nut" import eachBlock
from "chard" import get_charserver_time_sec
from "blkGetters" import get_price_blk
from "%scripts/dagui_natives.nut" import ps4_get_region, has_entitlement, get_entitlements_price_blk, get_entitlement_gold_discount, save_online_single_job
from "%scripts/dagui_library.nut" import *
from "%globalScripts/sceRegionConsts.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
from "%appGlobals/login/loginState.nut" import isLoggedIn

let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { discountsList, consoleEntitlementUnits } = require("%scripts/discounts/discountsState.nut")

const UPDATE_DISCOUNT_DATA_TIMER_ID = "update_discount_data"
const TOP_MENU_ONLINE_SHOP_ID = "online_shop"

let prevDiscountUnitsBundles = {}
let platformMapForDiscountFromGuiBlk = {
  pc = isPC
  ps4_scee = isPS4 && ps4_get_region() == SCE_REGION_SCEE
  ps4_scea = isPS4 && ps4_get_region() == SCE_REGION_SCEA
  ps4_scej = isPS4 && ps4_get_region() == SCE_REGION_SCEJ
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
    skippedUnitsList = {},
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
    chapterVal = canUseIngameShop() || isPC
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
      if (platformId != platform && !(platformMapForDiscountFromGuiBlk?[platform] ?? false))
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

function isShopDiscountVisible() {
  local isVisible = false
  foreach (airName, discount in discountsList.airList)
    if (discount > 0 && canBeVisibleDiscountOnUnit(getAircraftByName(airName))) {
      isVisible = true
      break
    }
  if (!isVisible)
    foreach (airName, discount in discountsList.entitlementUnits)
      if (discount > 0 && canBeVisibleDiscountOnUnit(getAircraftByName(airName))) {
        isVisible = true
        break
      }
  return isVisible
}

function convertUnitsBundlesData(unitsBundles) {
  return unitsBundles.reduce(function(res, v, key) {
    res[key] <- v.discount
    return res
  }, {})
}

local updateDiscountData = null

function updateProfileToUpdatePersonalDiscounts() {
  let taskId = save_online_single_job(0)
  if (taskId != -1)
    addTask(taskId, null, updateDiscountData)
  else
    updateDiscountData()
}

function collectDiscountItems() {
  let discounts = getInventoryList(itemType.DISCOUNT, @(item) item.isActive())
  if (discounts.len() == 0)
    return

  let closestExpireTime = discounts.reduce(function(res, item) {
    return res == 0 ? item.getExpireDeltaSec() : min(res, item.getExpireDeltaSec())
  }, 0)

  clearTimer(updateProfileToUpdatePersonalDiscounts)
  if(closestExpireTime > 0)
    setTimeout(closestExpireTime + 2, updateProfileToUpdatePersonalDiscounts)
  else
    updateProfileToUpdatePersonalDiscounts()
}

updateDiscountData = function(isSilentUpdate = false) {
  clearDiscountsList()
  let pBlk = get_price_blk()

  let chPath = ["exp_to_gold_rate"]
  chPath.append(shopCountriesList)
  discountsList.changeExp = getDiscountByPath(chPath, pBlk) > 0

  let giftUnits = {}

  foreach (air in getAllUnits()) {
    if (isCountryAvailable(air.shopCountry)
        && !air.isBought()
        && air.isVisibleInShop()) {
      if (isUnitGift(air)) {
        if (isPC)
          giftUnits[air.name] <- 0
        continue
      }
      let path = ["aircrafts", air.name]
      let discount = getDiscountByPath(path, pBlk)
      if (discount == 0)
        continue

      if (!isUnitResearched(air)) {
        discountsList.skippedUnitsList[air.name] <- true
        continue
      }
      discountsList.airList[air.name] <- discount
    }
  }

  eachBlock(get_entitlements_price_blk(), @(b, n) checkEntitlement(n, b, giftUnits))

  clearTimer(UPDATE_DISCOUNT_DATA_TIMER_ID)
  let minUpdateDiscountsTimeSec = updateGiftUnitsDiscountFromGuiBlk(giftUnits)  
  if (minUpdateDiscountsTimeSec != null)
    setTimeout(minUpdateDiscountsTimeSec, updateDiscountData, UPDATE_DISCOUNT_DATA_TIMER_ID)

  if (canUseIngameShop() && needEntStoreDiscountIcon)
    discountsList[TOP_MENU_ONLINE_SHOP_ID] = haveDiscount()

  discountsList.entitlementUnits.__update(
    consoleEntitlementUnits, convertUnitsBundlesData(discountUnitsBundles.get()))

  discountsList.topmenu_research = isShopDiscountVisible()
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

if (isLoggedIn.get())
  deferOnce(@() updateDiscountData())

function updateDiscountUnits(unitsBundles) {
  unitsBundles = convertUnitsBundlesData(unitsBundles)

  foreach (airName, _ in prevDiscountUnitsBundles)
    discountsList.entitlementUnits.rawdelete(airName)

  discountsList.entitlementUnits.__update(unitsBundles)
  discountsList.topmenu_research = isShopDiscountVisible()
  prevDiscountUnitsBundles.replace_with(unitsBundles)
  deferOnce(pushDiscountsUpdateEvent)
}

discountUnitsBundles.subscribe(updateDiscountUnits)

addListenersWithoutEnv({
  XboxShopDataUpdated         = @(_) updateOnlineShopDiscounts()
  Ps4ShopDataUpdated          = @(_) updateOnlineShopDiscounts()
  EpicShopDataUpdated         = @(_) updateOnlineShopDiscounts()
  EpicShopItemUpdated         = @(_) updateOnlineShopDiscounts()
  PriceUpdated                = @(_) updateDiscountData()
  EntitlementsPriceUpdated    = @(_) updateDiscountData()
  InventoryUpdate             = @(_) collectDiscountItems()

  function FlushSquadronExp(p) {
    let { unit } = p
    if (unit == null || canBuyNotResearched(unit))
      return

    updateDiscountData()
    deferOnce(pushDiscountsUpdateEvent)
  }

  function UnitResearch(p) {
    let unit = p?.unit ?? getAircraftByName(p?.unitName ?? "")
    if (unit == null || !unit.isSquadronVehicle() || canBuyNotResearched(unit))
      return

    updateDiscountData()
    deferOnce(pushDiscountsUpdateEvent)
  }

  function UnitBought(p) {
    let unitName = p?.unitName
    if (!unitName)
      return

    if (getUnitDiscountByName(unitName) == 0 && getEntitlementUnitDiscount(unitName) == 0)
      return

    updateDiscountData()
    
    deferOnce(pushDiscountsUpdateEvent)
  }

  function ProfileUpdated(_) {
    foreach (unitName, _ in discountsList.skippedUnitsList) {
      let unit = getAircraftByName(unitName)
      if (unit != null && isUnitResearched(unit) && !unit.isBought()) {
        updateDiscountData(true)
        deferOnce(pushDiscountsUpdateEvent)
        return
      }
    }
  }
}, g_listener_priority.CONFIG_VALIDATION)

return freeze({
  updateDiscountData
  updateOnlineShopDiscounts
})
