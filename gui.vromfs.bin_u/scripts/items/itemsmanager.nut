from "%scripts/dagui_natives.nut" import get_user_logs_count, get_current_personal_discount_count, get_user_log_blk_body, item_get_type_id_by_type_name, get_item_data_by_uid, periodic_task_register_ex, get_current_personal_discount_uid, get_items_blk, get_items_cache, get_cyber_cafe_level, periodic_task_unregister
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab, itemType
from "%scripts/mainConsts.nut" import LOST_DELAYED_ACTION_MSEC, SEEN

let { get_mission_time } = require("mission")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { get_cyber_cafe_max_level } = require("%appGlobals/ranks_common_shared.nut")
let { search, isEmpty, isDataBlock } = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_time_msec } = require("dagor.time")
let DataBlock  = require("DataBlock")
let ItemGenerators = require("%scripts/items/itemsClasses/itemGenerators.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let itemTransfer = require("%scripts/items/itemsTransfer.nut")
let stdMath = require("%sqstd/math.nut")
let { setShouldCheckAutoConsume, checkAutoConsume } = require("%scripts/items/autoConsumeItems.nut")
let { buyableSmokesList } = require("%scripts/unlocks/unlockSmoke.nut")
let { boosterEffectType } = require("%scripts/items/boosterEffect.nut")
let seenList = require("%scripts/seen/seenList.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { PRICE } = require("%scripts/utils/configs.nut")
let inventoryItemTypeByTag = require("%scripts/items/inventoryItemTypeByTag.nut")
let { floor } = require("math")
let { deferOnce } = require("dagor.workcycle")
let { get_price_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { items_classes } = require("%scripts/items/itemsClasses/itemsClasses.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")

let seenInventory = seenList.get(SEEN.INVENTORY)
let seenItems = seenList.get(SEEN.ITEMS_SHOP)

const OUT_OF_DATE_DAYS_ITEMS_SHOP = 28
const OUT_OF_DATE_DAYS_INVENTORY = 0
const FAKE_ITEM_CYBER_CAFE_BOOSTER_UID = -1

let itemsShopListVersion = Watched(0)
let inventoryListVersion = Watched(0)
let itemsList = []
let inventory = []
let inventoryItemById = {}
let shopItemById = {}
let itemsListInternal = []
let itemsListExternal = []
let itemsByItemdefId = {}
let rawInventoryItemAmountsByItemdefId = {}
let itemTypeClasses = {}

let itemTypeFeatures = {
  [itemType.WAGER] = "Wagers",
  [itemType.ORDER] = "Orders",
}

let itemTypeByBlkType = {
  [EIT_BOOSTER]             = itemType.BOOSTER,
  [EIT_TOURNAMENT_TICKET]   = itemType.TICKET,
  [EIT_WAGER]               = itemType.WAGER,
  [EIT_PERSONAL_DISCOUNTS]  = itemType.DISCOUNT,
  [EIT_ORDER]               = itemType.ORDER,
  [EIT_UNIVERSAL_SPARE]     = itemType.UNIVERSAL_SPARE,
  [EIT_MOD_OVERDRIVE]       = itemType.MOD_OVERDRIVE,
  [EIT_MOD_UPGRADE]         = itemType.MOD_UPGRADE,
}

local shopVisibleSeenIds = null
local inventoryVisibleSeenIds = null
local reqUpdateList = true
local reqUpdateItemDefsList = true
local needInventoryUpdate = true
local isInventoryInternalUpdated = false
local isInventoryFullUpdate = false
local extInventoryUpdateTime = 0
local ignoreItemLimits = false
local fakeItemsList = null
local genericItemsForCyberCafeLevel = -1
local refreshBoostersTask = -1
local boostersTaskUpdateFlightTime = -1

// debug
local dbgTrophiesListInternal = []
local dbgUpdateInternalItemsCount = 0

let getInternalItemsDebugInfo = @() {
  dbgTrophiesListInternal
  dbgLoadedTrophiesCount = dbgTrophiesListInternal.len()
  itemsListInternal
  dbgLoadedItemsInternalCount = itemsListInternal.len()
  dbgUpdateInternalItemsCount
}

function initItemsClasses() {
  foreach (itemClass in items_classes) {
    let iType = itemClass.iType
    if (stdMath.number_of_set_bits(iType) != 1)
      assert(false, $"Incorrect item class iType {iType} must be a power of 2")
    if (iType in itemTypeClasses)
      assert(false, $"duplicate iType in item classes {iType}")
    else
      itemTypeClasses[iType] <- itemClass
  }
}
initItemsClasses() //init classes right after scripts load.


function getInventoryItemType(blkType) {
  if (type(blkType) == "string") {
    if (blkType in inventoryItemTypeByTag)
      return inventoryItemTypeByTag[blkType]

    blkType = item_get_type_id_by_type_name(blkType)
  }
  return itemTypeByBlkType?[blkType] ?? itemType.UNKNOWN
}

function createItem(item_type, blk, inventoryBlk = null, slotData = null) {
  let iClass = itemTypeClasses?[item_type] ?? BaseItem
  return iClass(blk, inventoryBlk, slotData)
}

let shopSmokeItems = Computed(@() buyableSmokesList.value
  .map(@(blk) createItem(itemType.SMOKE, blk)))

function fillFakeItemsList() {
  let curLevel = get_cyber_cafe_level()
  if (curLevel == genericItemsForCyberCafeLevel)
    return

  genericItemsForCyberCafeLevel = curLevel
  fakeItemsList = DataBlock()

  for (local i = 0; i <= get_cyber_cafe_max_level(); ++i) {
    let level = i || curLevel //we do not need level0 booster, but need booster of current level.
    let table = {
      type = itemType.FAKE_BOOSTER
      iconStyle = "cybercafebonus"
      locId = "item/FakeBoosterForNetCafeLevel"
      rateBoosterParams = {
        xpRate = floor(100.0 * ::get_cyber_cafe_bonus_by_effect_type(boosterEffectType.RP, level) + 0.5)
        wpRate = floor(100.0 * ::get_cyber_cafe_bonus_by_effect_type(boosterEffectType.WP, level) + 0.5)
      }
    }
    fakeItemsList[$"FakeBoosterForNetCafeLevel{i || ""}"] <- ::build_blk_from_container(table)
  }

  for (local i = 2; i <= g_squad_manager.getMaxSquadSize(); ++i) {
    let table = {
      type = itemType.FAKE_BOOSTER
      rateBoosterParams = {
        xpRate = floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(boosterEffectType.RP, i) + 0.5)
        wpRate = floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(boosterEffectType.WP, i) + 0.5)
      }
    }
    fakeItemsList[$"FakeBoosterForSquadFromSameCafe{i}"] <- ::build_blk_from_container(table)
  }

  let trophyFromInventory = {
    type = itemType.TROPHY
    locId = "inventory/consumeItem"
    iconStyle = "gold_iron_box"
  }
  fakeItemsList["trophyFromInventory"] <- ::build_blk_from_container(trophyFromInventory)
}

function checkItemDefsUpdate() {
  if (!reqUpdateItemDefsList)
    return false
  reqUpdateItemDefsList = false

  itemsListExternal.clear()
  // Collecting itemdefs as shop items
  foreach (itemDefDesc in inventoryClient.getItemdefs()) {
    local item = itemsByItemdefId?[itemDefDesc?.itemdefid]
    if (!item) {
      let defType = itemDefDesc?.type

      if (isInArray(defType, ["playtimegenerator", "generator", "bundle", "delayedexchange"])
          || !isEmpty(itemDefDesc?.exchange) || itemDefDesc?.tags?.hasAdditionalRecipes)
        ItemGenerators.add(itemDefDesc)

      if (!isInArray(defType, [ "item", "delayedexchange" ]))
        continue

      let iType = getInventoryItemType(itemDefDesc?.tags.type ?? "")
      if (iType == itemType.UNKNOWN)
        continue

      item = createItem(iType, itemDefDesc)
      itemsByItemdefId[item.id] <- item
    }

    if (item.isCanBuy())
      itemsListExternal.append(item)
  }
  return true
}

function checkShopItemsUpdate() {
  if (!reqUpdateList)
    return false

  reqUpdateList = false
  PRICE.checkUpdate()
  itemsListInternal.clear()
  dbgTrophiesListInternal.clear()
  ++dbgUpdateInternalItemsCount

  let pBlk = get_price_blk()
  let trophyBlk = pBlk?.trophy
  if (trophyBlk)
    for (local i = 0; i < trophyBlk.blockCount(); ++i) {
      let blk = trophyBlk.getBlock(i)
      if (blk?.shouldNotBeDisplayedOnClient)
        continue

      let item = createItem(itemType.TROPHY, blk)
      itemsListInternal.append(item)
      dbgTrophiesListInternal.append(item)
    }

  let itemsBlk = get_items_blk()
  ignoreItemLimits = !!itemsBlk?.ignoreItemLimits
  for (local i = 0; i < itemsBlk.blockCount(); ++i) {
    let blk = itemsBlk.getBlock(i)
    let iType = getInventoryItemType(blk?.type)
    if (iType == itemType.UNKNOWN) {
      log($"Error: unknown item type in items blk = {blk?.type ?? "NULL"}")
      continue
    }
    let item = createItem(iType, blk)
    itemsListInternal.append(item)
  }

  fillFakeItemsList()
  if (fakeItemsList)
    for (local i = 0; i < fakeItemsList.blockCount(); ++i) {
      let blk = fakeItemsList.getBlock(i)
      let item = createItem(blk?.type, blk)
      itemsListInternal.append(item)
    }

  itemsListInternal.extend(shopSmokeItems.get())
  return true
}

function checkUpdateList() {
  local hasChanges = checkShopItemsUpdate()
  if (checkItemDefsUpdate())
    hasChanges = true

  if (!hasChanges)
    return

  let duplicatesId = []
  shopItemById.clear()
  itemsList.clear()
  itemsList.extend(itemsListInternal)
  itemsList.extend(itemsListExternal)

  foreach (item in itemsList)
    if (item.id in shopItemById)
      duplicatesId.append(item.id)
    else
      shopItemById[item.id] <- item

  if (duplicatesId.len())
    assert(false, $"Items shop: found duplicate items id = \n{", ".join(duplicatesId, true)}")
}

function requestItemsByItemdefIds(itemdefIdsList) {
  inventoryClient.requestItemdefsByIds(itemdefIdsList)
}

let isItemdefId = @(id) type(id) == "integer"

// fixme remove redundant parameter
function findItemById(id, _typeMask = itemType.ALL) {
  checkUpdateList()
  let item = shopItemById?[id] ?? itemsByItemdefId?[id]
  if (!item && isItemdefId(id))
    requestItemsByItemdefIds([id])
  return item
}

function collectUserlogItemdefs() {
  let res = []
  for (local i = 0; i < get_user_logs_count(); ++i) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
    let itemDefId = blk?.body.itemDefId
    if (itemDefId)
      res.append(itemDefId)
  }
  requestItemsByItemdefIds(res)
}

function checkInventoryUpdate() {
  if (!needInventoryUpdate)
    return
  needInventoryUpdate = false

  inventory.clear()
  inventoryItemById.clear()

  let itemsBlk = get_items_blk()
  let itemsCache = get_items_cache()
  foreach (slot in itemsCache) {
    if (!slot.uids.len())
      continue

    let invItemBlk = DataBlock()
    get_item_data_by_uid(invItemBlk, slot.uids[0])
    if (getTblValue("expiredTime", invItemBlk, 0) < 0)
      continue

    let iType = getInventoryItemType(invItemBlk?.type)
    if (iType == itemType.UNKNOWN)
      continue

    let blk = itemsBlk?[slot.id]
    if (!blk) {
      if (is_dev_version())
        log($"Error: found removed item: {slot.id}")
      continue //skip removed items
    }

    let item = createItem(iType, blk, invItemBlk, slot)
    inventory.append(item)
    inventoryItemById[item.id] <- item
    if (item.shouldAutoConsume && !item.isActive())
      setShouldCheckAutoConsume(true)
  }

  fillFakeItemsList()
  if (fakeItemsList && get_cyber_cafe_level()) {
    let id = "FakeBoosterForNetCafeLevel"
    let blk = fakeItemsList.getBlockByName(id)
    if (blk) {
      let item = createItem(blk?.type, blk, DataBlock(), { uids = [FAKE_ITEM_CYBER_CAFE_BOOSTER_UID] })
      inventory.append(item)
      inventoryItemById[item.id] <- item
    }
  }

  // gather transfer items list
  let transferAmounts = {}
  foreach (data in itemTransfer.getSendingList())
    transferAmounts[data.itemDefId] <- (transferAmounts?[data.itemDefId] ?? 0) + 1

  // Collecting external inventory items
  rawInventoryItemAmountsByItemdefId.clear()
  let extInventoryItems = []
  foreach (itemDesc in inventoryClient.getItems()) {
    let itemDefDesc = itemDesc.itemdef
    let itemDefId = itemDesc.itemdefid
    if (itemDefId in rawInventoryItemAmountsByItemdefId)
      rawInventoryItemAmountsByItemdefId[itemDefId] += itemDesc.quantity
    else
      rawInventoryItemAmountsByItemdefId[itemDefId] <- itemDesc.quantity

    if (!itemDefDesc.len()) //item not fully updated, or itemDesc no more exist.
      continue

    let iType = getInventoryItemType(itemDefDesc?.tags?.type ?? "")
    if (iType == itemType.UNKNOWN) {
      logerr($"Inventory: Unknown itemdef.tags.type in item {itemDefDesc?.itemdefid ?? "NULL"}")
      continue
    }

    local isCreate = true
    foreach (existingItem in extInventoryItems)
      if (existingItem.tryAddItem(itemDefDesc, itemDesc)) {
        isCreate = false
        break
      }
    if (isCreate) {
      let item = createItem(iType, itemDefDesc, itemDesc)
      if (item.id in transferAmounts)
        item.transferAmount += transferAmounts.$rawdelete(item.id)
      if (item.shouldAutoConsume)
        setShouldCheckAutoConsume(true)
      extInventoryItems.append(item)
      inventoryItemById[item.id] <- item
    }
  }

  //add items in transfer
  let itemdefsToRequest = []
  foreach (itemdefid, amount in transferAmounts) {
    let itemdef = inventoryClient.getItemdefs()?[itemdefid]
    if (!itemdef) {
      itemdefsToRequest.append(itemdefid)
      continue
    }
    let iType = getInventoryItemType(itemdef?.tags?.type ?? "")
    if (iType == itemType.UNKNOWN) {
      if (isInArray(itemdef?.type, [ "item", "delayedexchange" ]))
        logerr($"Inventory: Transfer: Unknown itemdef.tags.type in item {itemdefid}")
      continue
    }
    let item = createItem(iType, itemdef, {})
    item.transferAmount += amount
    extInventoryItems.append(item)
    inventoryItemById[item.id] <- item
  }

  if (itemdefsToRequest.len())
    inventoryClient.requestItemdefsByIds(itemdefsToRequest)

  inventory.extend(extInventoryItems)
  extInventoryUpdateTime = get_time_msec()
}

function getItemsFromList(list, typeMask, filterFunc = null, itemMaskProperty = "iType") {
  if (typeMask == itemType.ALL && !filterFunc)
    return list

  let res = []
  foreach (item in list)
    if (((item?[itemMaskProperty] ?? item.iType) & typeMask)
        && (!filterFunc || filterFunc(item)))
      res.append(item)
  return res
}

function getInventoryList(typeMask = itemType.ALL, filterFunc = null) {
  checkInventoryUpdate()
  checkAutoConsume()
  return getItemsFromList(inventory, typeMask, filterFunc)
}

function findItemByUid(uid, filterType = itemType.ALL) {
  let itemsArray = getInventoryList(filterType)
  let res = search(itemsArray, @(item) isInArray(uid, item.uids))
  return res
}

function getBestItemSpecialOfferByUnit(unit) {
  let res = []
  for (local i = 0; i < get_current_personal_discount_count(); ++i) {
    let uid = get_current_personal_discount_uid(i)
    let item = findItemByUid(uid, itemType.DISCOUNT)
    if (item == null || !(item?.isSpecialOffer ?? false) || !item.isActive())
      continue

    let locParams = item.getSpecialOfferLocParams()
    let itemUnit = locParams?.unit
    if (itemUnit == unit)
      res.append({
        item = item
        discountValue = locParams.discountValue
        discountMax = locParams.discountMax
        discountMin = locParams.discountMin
      })
  }

  if (res.len() == 0)
    return null

  res.sort(@(a, b) b.discountValue <=> a.discountValue
    || b.discountMax <=> a.discountMax
    || b.discountMin <=> a.discountMin)
  return res[0].item
}

function isItemVisible(item, shopTab) {
  return shopTab == itemsTab.SHOP ? item.isCanBuy() && (!item.isDevItem || hasFeature("devItemShop"))
      && !item.isHiddenItem() && !item.isVisibleInWorkshopOnly() && !item.isHideInShop
    : shopTab == itemsTab.INVENTORY ? !item.isHiddenItem() && !item.isVisibleInWorkshopOnly()
      && (!item.shouldAutoConsume || item.canOpenForGold())
    : false
}

// Returns a mask for items, showing only the available features.
function checkItemsMaskFeatures(itemsMask) {
  foreach (iType, feature in itemTypeFeatures)
    if ((itemsMask & iType) && !hasFeature(feature))
      itemsMask -= iType
  return itemsMask
}

function getItemsList(typeMask = itemType.ALL, filterFunc = null) {
  checkUpdateList()
  return getItemsFromList(itemsList, typeMask, filterFunc)
}

function getShopList(typeMask = itemType.INVENTORY_ALL, filterFunc = null) {
  checkUpdateList()
  return getItemsFromList(itemsList, typeMask, filterFunc, "shopFilterMask")
}

function getItemOrRecipeBundleById(id) {
  local item = findItemById(id)
  if (item || !ItemGenerators.get(id))
    return item

  let itemDefDesc = inventoryClient.getItemdefs()?[id]
  if (!itemDefDesc)
    return item

  item = createItem(itemType.RECIPES_BUNDLE, itemDefDesc)
  // This item is not visible in the inventory or shop,
  // so there's no need for a special event regarding its creation.
  // However, we need to be able to find it by ID to work with it correctly later.
  itemsByItemdefId[item.id] <- item
  return item
}

function getInventoryItemById(id) {
  checkInventoryUpdate()
  return inventoryItemById?[id]
}

function getInventoryListByShopMask(typeMask, filterFunc = null) {
  checkInventoryUpdate()
  checkAutoConsume()
  return getItemsFromList(inventory, typeMask, filterFunc, "shopFilterMask")
}

let getInventoryItemByCraftedFrom = @(uid) search(getInventoryList(),
  @(item) item.isCraftResult() && item.craftedFrom == uid)

function removeRefreshBoostersTask() {
  if (refreshBoostersTask >= 0)
    periodic_task_unregister(refreshBoostersTask)
  refreshBoostersTask = -1
}

function onBoosterExpiredInFlight(_dt = 0) {
  removeRefreshBoostersTask()
  if (isInFlight())
    ::update_gamercards()
}

//just update gamercards atm.
function registerBoosterUpdateTimer(boostersList) {
  if (!isInFlight())
    return

  let curFlightTime = get_mission_time()
  local nextExpireTime = -1
  foreach (booster in boostersList) {
    let expireTime = booster.getExpireFlightTime()
    if (expireTime <= curFlightTime)
      continue
    if (nextExpireTime < 0 || expireTime < nextExpireTime)
      nextExpireTime = expireTime
  }

  if (nextExpireTime < 0)
    return

  let nextUpdateTime = nextExpireTime.tointeger() + 1
  if (refreshBoostersTask >= 0 && nextUpdateTime >= boostersTaskUpdateFlightTime)
    return

  removeRefreshBoostersTask()

  boostersTaskUpdateFlightTime = nextUpdateTime
  refreshBoostersTask = periodic_task_register_ex({},
    onBoosterExpiredInFlight,
    boostersTaskUpdateFlightTime - curFlightTime,
    EPTF_IN_FLIGHT,
    EPTT_BEST_EFFORT,
    false //flight time
  )
}

let refreshExtInventory = @() inventoryClient.refreshItems()

function isItemsManagerEnabled() {
  let checkNewbie = !isMeNewbie()
    || seenInventory.hasSeen()
    || inventory.len() > 0
  return hasFeature("Items") && checkNewbie
}

function getItemsSortComparator(itemsSeenList = null) {
  return function(item1, item2) { //warning disable: -return-different-types
    if (!item1 || !item2)
      return item2 <=> item1
    return item2.isActive() <=> item1.isActive()
      || (itemsSeenList && itemsSeenList.isNew(item2.getSeenId()) <=> itemsSeenList.isNew(item1.getSeenId()))
      || item2.hasExpireTimer() <=> item1.hasExpireTimer()
      || (item1.hasExpireTimer() && (item1.expiredTimeSec <=> item2.expiredTimeSec))
      || item1.iType <=> item2.iType
      || item2.getRarity() <=> item1.getRarity()
      || item1.id <=> item2.id
      || item1.tradeableTimestamp <=> item2.tradeableTimestamp
  }
}

function getRawInventoryItemAmount(itemdefid) {
  return rawInventoryItemAmountsByItemdefId?[itemdefid] ?? 0
}

// promo
function consumeItemFromPromo(handler, params) {
  let itemId = params?[0]
  if (itemId == null)
    return

  let item = getInventoryItemById(to_integer_safe(itemId, itemId, false))
  if (!(item?.canConsume() ?? false))
    return

  item?.consume(@(...) null, { needConsumeImpl = params?[1] == "needConsumeImpl" })
  handler.goBack()
}

function canConsumeItemFromPromo(params) {
  let itemId = params?[0]
  if (itemId == null)
    return false
  let item = getInventoryItemById(to_integer_safe(itemId, itemId, false))
  return item?.canConsume() ?? false
}

addPromoAction("consume_item",
  @(handler, params, _obj) consumeItemFromPromo(handler, params),
  @(params) canConsumeItemFromPromo(params))


function markInventoryUpdate() {
  if (needInventoryUpdate)
    return

  needInventoryUpdate = true
  inventoryVisibleSeenIds = null
  if (!isInventoryFullUpdate && isInventoryInternalUpdated && !inventoryClient.isWaitForInventory()) {
    isInventoryFullUpdate = true
    seenInventory.setDaysToUnseen(OUT_OF_DATE_DAYS_INVENTORY)
  }
  seenInventory.onListChanged()
  broadcastEvent("InventoryUpdate")
  inventoryListVersion(inventoryListVersion.value + 1)
}

function getShopVisibleSeenIds() {
  if (!shopVisibleSeenIds)
    shopVisibleSeenIds = getShopList(checkItemsMaskFeatures(itemType.INVENTORY_ALL),
      @(it) isItemVisible(it, itemsTab.SHOP)).map(@(it) it.getSeenId())
  return shopVisibleSeenIds
}

// seen
let seenIdCanBeNew = {}
function canSeenIdBeNew(seenId) {
  if (!(seenId in seenIdCanBeNew) || seenIdCanBeNew[seenId] == null) {
    let id = to_integer_safe(seenId, seenId, false) //ext inventory items id needs to be convert to int
    let item = findItemById(id)
    let itemCanBeNew = item && !(getAircraftByName(item.getTopPrize()?.unit)?.isBought() ?? false)
    seenIdCanBeNew[seenId] <- itemCanBeNew
    return itemCanBeNew
  }
  return seenIdCanBeNew[seenId]
}

function getInventoryVisibleSeenIds() {
  if (!inventoryVisibleSeenIds) {
    let invItemsList = getInventoryListByShopMask(checkItemsMaskFeatures(itemType.INVENTORY_ALL))
    inventoryVisibleSeenIds = invItemsList.filter(
      @(it) isItemVisible(it, itemsTab.INVENTORY)).map(@(it) it.getSeenId())
  }

  return inventoryVisibleSeenIds
}

function canGetDecoratorFromTrophy(decorator) {
  if (!decorator || decorator.isUnlocked())
    return false
  let visibleTypeMask = checkItemsMaskFeatures(itemType.TROPHY)
  let filterFunc = @(item) !item.isDevItem && isItemVisible(item, itemsTab.SHOP)
  return getShopList(visibleTypeMask, filterFunc)
    .findindex(@(item) item.getContent().findindex(@(prize) prize?.resource == decorator.id) != null) != null
}

let clearSeenCashe = @() seenIdCanBeNew.clear()
let invalidateShopVisibleSeenIds = @() shopVisibleSeenIds = null

seenItems.setListGetter(@() getShopVisibleSeenIds())
seenItems.setCanBeNewFunc(canSeenIdBeNew)
seenInventory.setListGetter(@() getInventoryVisibleSeenIds())

let makeSeenCompatibility = @(savePath) function() {
  let res = {}
  let blk = loadLocalByAccount(savePath)
  if (!isDataBlock(blk))
    return res

  for (local i = 0; i < blk.paramCount(); ++i)
    res[blk.getParamName(i)] <- blk.getParamValue(i)
  saveLocalByAccount(savePath, null)
  return res
}

seenItems.setCompatibilityLoadData(makeSeenCompatibility("seen_shop_items"))
seenInventory.setCompatibilityLoadData(makeSeenCompatibility("seen_inventory_items"))


function markItemsDefsListUpdate() {
  reqUpdateItemDefsList = true
  shopVisibleSeenIds = null
  clearSeenCashe()
  seenItems.onListChanged()
  broadcastEvent("ItemsShopUpdate")
  itemsShopListVersion(itemsShopListVersion.value + 1)
}

local lastItemDefsUpdatedelayedCall = 0
function markItemsDefsListUpdateDelayed() {
  if (reqUpdateItemDefsList)
    return
  if (lastItemDefsUpdatedelayedCall
      && lastItemDefsUpdatedelayedCall + LOST_DELAYED_ACTION_MSEC > get_time_msec())
    return

  lastItemDefsUpdatedelayedCall = get_time_msec()
  handlersManager.doDelayed(function() {
    lastItemDefsUpdatedelayedCall = 0
    markItemsDefsListUpdate()
  })
}

local lastInventoryUpdateDelayedCall = 0
function markInventoryUpdateDelayed() {
  if (needInventoryUpdate)
    return
  if (lastInventoryUpdateDelayedCall
      && lastInventoryUpdateDelayedCall < get_time_msec() + LOST_DELAYED_ACTION_MSEC)
    return

  lastInventoryUpdateDelayedCall = get_time_msec()
  ::g_delayed_actions.add(function() {
    if (!::g_login.isProfileReceived())
      return
    lastInventoryUpdateDelayedCall = 0
    markInventoryUpdate()
  }, 200)
}

function markItemsListUpdate() {
  reqUpdateList = true
  shopVisibleSeenIds = null
  seenItems.setDaysToUnseen(OUT_OF_DATE_DAYS_ITEMS_SHOP)
  clearSeenCashe()
  seenItems.onListChanged()
  broadcastEvent("ItemsShopUpdate")
  itemsShopListVersion(itemsShopListVersion.value + 1)
}
shopSmokeItems.subscribe(@(_) markItemsListUpdate())

addListenersWithoutEnv({
  PriceUpdated = @(_) markItemsListUpdate()
  ItemDefChanged = @(_) markItemsDefsListUpdate()
  TourRegistrationComplete = @(_) markInventoryUpdate()
  ExtInventoryChanged = @(_) markInventoryUpdateDelayed()
  SendingItemsChanged = @(_) markInventoryUpdateDelayed()
  ExtPricesChanged = @(_) markItemsDefsListUpdateDelayed()
  GameLocalizationChanged = @(_) inventoryClient.forceRefreshItemDefs(
    @() itemsByItemdefId.clear())

  function ProfileUpdated(_) {
    foreach (index, itemCanBeNew in seenIdCanBeNew)
      if (itemCanBeNew == true)
        seenIdCanBeNew[index] = null
  }
  function LoadingStateChange(_) {
    if (!isInFlight())
      removeRefreshBoostersTask()
  }
  function LoginComplete(_) {
    setShouldCheckAutoConsume(true)
    reqUpdateList = true
  }
  function SignOut(_) {
    isInventoryFullUpdate = false
    isInventoryInternalUpdated = false
  }
  function EntitlementsUpdatedFromOnlineShop(_) {
    let curLevel = get_cyber_cafe_level()
    if (genericItemsForCyberCafeLevel != curLevel) {
      markItemsListUpdate()
      markInventoryUpdate()
    }
  }
})

// event from native code:
function onItemsLoaded() {
  isInventoryInternalUpdated = true
  markInventoryUpdate()
}
::on_items_loaded <- @() deferOnce(onItemsLoaded)


::ItemsManager <- {
  // circ reft and some other issues with the export
  getExtInventoryUpdateTime = @() extInventoryUpdateTime
  needIgnoreItemLimits = @() ignoreItemLimits
  isInventoryFullUpdated = @() isInventoryFullUpdate
  isItemdefId
  requestItemsByItemdefIds
  collectUserlogItemdefs
  getInventoryItemType
  markInventoryUpdate
  markInventoryUpdateDelayed
  findItemById
  findItemByUid
  getItemsList
  getShopList
  getItemOrRecipeBundleById
  getInventoryList
  isItemsManagerEnabled
  getRawInventoryItemAmount
  getItemsSortComparator
  refreshExtInventory
  registerBoosterUpdateTimer
  getInventoryListByShopMask
  getInventoryItemById
  getInventoryItemByCraftedFrom
  canGetDecoratorFromTrophy
}

return {
  itemsShopListVersion
  inventoryListVersion
  shopSmokeItems
  getBestItemSpecialOfferByUnit
  invalidateShopVisibleSeenIds
  isItemVisible
  isItemdefId
  findItemByUid
  findItemById
  checkItemsMaskFeatures
  getShopList
  getInventoryList
  getInventoryItemById
  isItemsManagerEnabled
  getInternalItemsDebugInfo
  canGetDecoratorFromTrophy
}
