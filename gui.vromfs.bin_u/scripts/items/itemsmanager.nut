//-file:plus-string
from "%scripts/dagui_natives.nut" import get_user_logs_count, get_current_personal_discount_count, get_user_log_blk_body, item_get_type_id_by_type_name, get_item_data_by_uid, periodic_task_register_ex, get_current_personal_discount_uid, get_items_blk, get_items_cache, get_usefull_total_time, get_cyber_cafe_level, periodic_task_unregister
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab, itemType
from "%scripts/mainConsts.nut" import LOST_DELAYED_ACTION_MSEC, SEEN

let { get_cyber_cafe_max_level } = require("%appGlobals/ranks_common_shared.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfile.nut")
let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { subscribe_handler, broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
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

// Independent Modules
require("%scripts/items/roulette/bhvRoulette.nut")

let seenInventory = seenList.get(SEEN.INVENTORY)
let seenItems = seenList.get(SEEN.ITEMS_SHOP)
let OUT_OF_DATE_DAYS_ITEMS_SHOP = 28
let OUT_OF_DATE_DAYS_INVENTORY = 0

/*
  ItemsManager API:

  getItemsList(typeMask = itemType.ALL)     - get items list by type mask
  fillItemDescr(item, holderObj, handler)   - update item description in object.
  findItemById(id, typeMask = itemType.ALL) - search item by id

  getInventoryList(typeMask = itemType.ALL) - get items list by type mask
*/

local FAKE_ITEM_CYBER_CAFE_BOOSTER_UID = -1

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

let itemTypeClasses = {} //itemtype = itemclass

  //lists cache for optimization
local shopVisibleSeenIds = null
local inventoryVisibleSeenIds = null

let itemTypeFeatures = {
  [itemType.WAGER] = "Wagers",
  [itemType.ORDER] = "Orders"
}

local _reqUpdateList = true
local _reqUpdateItemDefsList = true
local _needInventoryUpdate = true

local isInventoryInternalUpdated = false
local isInventoryFullUpdate = false

local extInventoryUpdateTime = 0

local ignoreItemLimits = false
local fakeItemsList = null
local genericItemsForCyberCafeLevel = -1

local refreshBoostersTask = -1
local boostersTaskUpdateFlightTime = -1

foreach (fn in [
                 "discountItemSortMethod.nut"
                 "trophyMultiAward.nut"
                 "itemLimits.nut"
                 "listPopupWnd/itemsListWndBase.nut"
                 "listPopupWnd/universalSpareApplyWnd.nut"
                 "listPopupWnd/modUpgradeApplyWnd.nut"
                 "roulette/itemsRoulette.nut"
               ])
  loadOnce($"%scripts/items/{fn}")


local ItemsManager

let seenIdCanBeNew = {}
let function canSeenIdBeNew(seenId) {
  if (!(seenId in seenIdCanBeNew) || seenIdCanBeNew[seenId] == null) {
    let id = to_integer_safe(seenId, seenId, false) //ext inventory items id need to convert to integer.
    let item = ItemsManager.findItemById(id)
    let itemCanBeNew = item && !(getAircraftByName(item.getTopPrize()?.unit)?.isBought() ?? false)
    seenIdCanBeNew[seenId] <- itemCanBeNew
    return itemCanBeNew
  }
  return seenIdCanBeNew[seenId]
}


let function clearSeenCashe() {
  seenIdCanBeNew.clear()
}

let function clearCasheForCanBeNewItems() {
  foreach( index, itemCanBeNew in seenIdCanBeNew) {
    if (itemCanBeNew == true)
      seenIdCanBeNew[index] = null
  }
}

//!!!BEGIN added only for debug
local dbgTrophiesListInternal = []
local dbgUpdateInternalItemsCount = 0

let getInternalItemsDebugInfo = @() {
  dbgTrophiesListInternal
  dbgLoadedTrophiesCount = dbgTrophiesListInternal.len()
  itemsListInternal
  dbgLoadedItemsInternalCount = itemsListInternal.len()
  dbgUpdateInternalItemsCount
}
//!!!END added only for debug

function initItemsClasses() {
  foreach (itemClass in items_classes) {
    let iType = itemClass.iType
    if (stdMath.number_of_set_bits(iType) != 1)
      assert(false, "Incorrect item class iType " + iType + " must be a power of 2")
    if (iType in itemTypeClasses)
      assert(false, "duplicate iType in item classes " + iType)
    else
      itemTypeClasses[iType] <- itemClass
  }
}
initItemsClasses() //init classes right after scripts load.

function createItem(item_type, blk, inventoryBlk = null, slotData = null) {
  let iClass = itemTypeClasses?[item_type] ?? BaseItem
  return iClass(blk, inventoryBlk, slotData)
}

ItemsManager = {
  smokeItems = Computed(@()
    buyableSmokesList.value.map(@(blk) createItem(itemType.SMOKE, blk)))

  getExtInventoryUpdateTime = @() extInventoryUpdateTime
  needIgnoreItemLimits = @() ignoreItemLimits
  isInventoryFullUpdated = @() isInventoryFullUpdate
  getInternalItemsDebugInfo

  function getBestSpecialOfferItemByUnit(unit) {
    let res = []
    for (local i = 0; i < get_current_personal_discount_count(); i++) {
      let uid = get_current_personal_discount_uid(i)
      let item = ItemsManager.findItemByUid(uid, itemType.DISCOUNT)
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

  function onEventPriceUpdated(_p) {
    this.markItemsListUpdate()
  }

  function canGetDecoratorFromTrophy(decorator) {
    if (!decorator || decorator.isUnlocked())
      return false
    let visibleTypeMask = this.checkItemsMaskFeatures(itemType.TROPHY)
    let filterFunc = @(item) !item.isDevItem && this.isItemVisible(item, itemsTab.SHOP)
    return this.getShopList(visibleTypeMask, filterFunc)
      .findindex(@(item) item.getContent().findindex(@(prize) prize?.resource == decorator.id) != null) != null
  }

  function invalidateShopVisibleSeenIds() {
    shopVisibleSeenIds = null
  }

  function getInventoryItemById(id) {
    this._checkInventoryUpdate()
    return inventoryItemById?[id]
  }
}

ItemsManager.fillFakeItemsList <- function fillFakeItemsList() {
  let curLevel = get_cyber_cafe_level()
  if (curLevel == genericItemsForCyberCafeLevel)
    return

  genericItemsForCyberCafeLevel = curLevel

  fakeItemsList = DataBlock()

  for (local i = 0; i <= get_cyber_cafe_max_level(); i++) {
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
    fakeItemsList["FakeBoosterForNetCafeLevel" + (i || "")] <- ::build_blk_from_container(table)
  }

  for (local i = 2; i <= ::g_squad_manager.getMaxSquadSize(); i++) {
    let table = {
      type = itemType.FAKE_BOOSTER
      rateBoosterParams = {
        xpRate = floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(boosterEffectType.RP, i) + 0.5)
        wpRate = floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(boosterEffectType.WP, i) + 0.5)
      }
    }
    fakeItemsList["FakeBoosterForSquadFromSameCafe" + i] <- ::build_blk_from_container(table)
  }

  let trophyFromInventory = {
    type = itemType.TROPHY
    locId = "inventory/consumeItem"
    iconStyle = "gold_iron_box"
  }
  fakeItemsList["trophyFromInventory"] <- ::build_blk_from_container(trophyFromInventory)
}

/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------SHOP ITEMS----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////
ItemsManager._checkUpdateList <- function _checkUpdateList() {
  local hasChanges = this.checkShopItemsUpdate()
  if (this.checkItemDefsUpdate())
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
    assert(false, "Items shop: found duplicate items id = \n" + ", ".join(duplicatesId, true))
}

ItemsManager.checkShopItemsUpdate <- function checkShopItemsUpdate() {
  if (!_reqUpdateList)
    return false
  _reqUpdateList = false
  PRICE.checkUpdate()
  itemsListInternal.clear()
  dbgTrophiesListInternal.clear()
  dbgUpdateInternalItemsCount++

  let pBlk = get_price_blk()
  let trophyBlk = pBlk?.trophy
  if (trophyBlk)
    for (local i = 0; i < trophyBlk.blockCount(); i++) {
      let blk = trophyBlk.getBlock(i)
      if (blk?.shouldNotBeDisplayedOnClient)
        continue
      let item = createItem(itemType.TROPHY, blk)
      itemsListInternal.append(item)
      dbgTrophiesListInternal.append(item)
    }

  let itemsBlk = get_items_blk()
  ignoreItemLimits = !!itemsBlk?.ignoreItemLimits
  for (local i = 0; i < itemsBlk.blockCount(); i++) {
    let blk = itemsBlk.getBlock(i)
    let iType = this.getInventoryItemType(blk?.type)
    if (iType == itemType.UNKNOWN) {
      log("Error: unknown item type in items blk = " + (blk?.type ?? "NULL"))
      continue
    }
    let item = createItem(iType, blk)
    itemsListInternal.append(item)
  }

  ItemsManager.fillFakeItemsList()
  if (fakeItemsList)
    for (local i = 0; i < fakeItemsList.blockCount(); i++) {
      let blk = fakeItemsList.getBlock(i)
      let item = createItem(blk?.type, blk)
      itemsListInternal.append(item)
    }

  itemsListInternal.extend(this.smokeItems.value)

  return true
}

ItemsManager.checkItemDefsUpdate <- function checkItemDefsUpdate() {
  if (!_reqUpdateItemDefsList)
    return false
  _reqUpdateItemDefsList = false

  itemsListExternal.clear()
  // Collecting itemdefs as shop items
  foreach (itemDefDesc in inventoryClient.getItemdefs()) {
    local item = itemsByItemdefId?[itemDefDesc?.itemdefid]
    if (!item) {
      let defType = itemDefDesc?.type

      if (isInArray(defType, [ "playtimegenerator", "generator", "bundle", "delayedexchange" ])
        || !u.isEmpty(itemDefDesc?.exchange) || itemDefDesc?.tags?.hasAdditionalRecipes)
          ItemGenerators.add(itemDefDesc)

      if (!isInArray(defType, [ "item", "delayedexchange" ]))
        continue
      let iType = this.getInventoryItemType(itemDefDesc?.tags?.type ?? "")
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

ItemsManager.onEventEntitlementsUpdatedFromOnlineShop <- function onEventEntitlementsUpdatedFromOnlineShop(_params) {
  let curLevel = get_cyber_cafe_level()
  if (genericItemsForCyberCafeLevel != curLevel) {
    this.markItemsListUpdate()
    this.markInventoryUpdate()
  }
}

ItemsManager.getItemClass <- function getItemClass(item_type) {
  return (item_type in itemTypeClasses) ? itemTypeClasses[item_type] : BaseItem
}

ItemsManager.getItemsList <- function getItemsList(typeMask = itemType.ALL, filterFunc = null) {
  this._checkUpdateList()
  return this._getItemsFromList(itemsList, typeMask, filterFunc)
}

ItemsManager.getShopList <- function getShopList(typeMask = itemType.INVENTORY_ALL, filterFunc = null) {
  this._checkUpdateList()
  return this._getItemsFromList(itemsList, typeMask, filterFunc, "shopFilterMask")
}

ItemsManager.isItemVisible <- function isItemVisible(item, shopTab) {
  return shopTab == itemsTab.SHOP ? item.isCanBuy() && (!item.isDevItem || hasFeature("devItemShop"))
      && !item.isHiddenItem() && !item.isVisibleInWorkshopOnly() && !item.isHideInShop
    : shopTab == itemsTab.INVENTORY ? !item.isHiddenItem() && !item.isVisibleInWorkshopOnly()
    : false
}

ItemsManager.getShopVisibleSeenIds <- function getShopVisibleSeenIds() {
  if (!shopVisibleSeenIds)
    shopVisibleSeenIds = this.getShopList(this.checkItemsMaskFeatures(itemType.INVENTORY_ALL),
      @(it) ItemsManager.isItemVisible(it, itemsTab.SHOP)).map(@(it) it.getSeenId())
  return shopVisibleSeenIds
}

ItemsManager.findItemById <- function findItemById(id, _typeMask = itemType.ALL) {
  this._checkUpdateList()
  let item = shopItemById?[id] ?? itemsByItemdefId?[id]
  if (!item && this.isItemdefId(id))
    this.requestItemsByItemdefIds([id])
  return item
}

ItemsManager.isItemdefId <- function isItemdefId(id) {
  return type(id) == "integer"
}

ItemsManager.requestItemsByItemdefIds <- function requestItemsByItemdefIds(itemdefIdsList) {
  inventoryClient.requestItemdefsByIds(itemdefIdsList)
}

ItemsManager.getItemOrRecipeBundleById <- function getItemOrRecipeBundleById(id) {
  local item = this.findItemById(id)
  if (item || !ItemGenerators.get(id))
    return item

  let itemDefDesc = inventoryClient.getItemdefs()?[id]
  if (!itemDefDesc)
    return item

  item = createItem(itemType.RECIPES_BUNDLE, itemDefDesc)
  //this item is not visible in inventory or shop, so no need special event about it creation
  //but we need to be able find it by id to correct work with it later.
  itemsByItemdefId[item.id] <- item
  return item
}

ItemsManager.markItemsListUpdate <- function markItemsListUpdate() {
  _reqUpdateList = true
  shopVisibleSeenIds = null
  seenItems.setDaysToUnseen(OUT_OF_DATE_DAYS_ITEMS_SHOP)
  clearSeenCashe()
  seenItems.onListChanged()
  broadcastEvent("ItemsShopUpdate")
  itemsShopListVersion(itemsShopListVersion.value + 1)
}

ItemsManager.smokeItems.subscribe(@(_p) ItemsManager.markItemsListUpdate())

ItemsManager.markItemsDefsListUpdate <- function markItemsDefsListUpdate() {
  _reqUpdateItemDefsList = true
  shopVisibleSeenIds = null
  clearSeenCashe()
  seenItems.onListChanged()
  broadcastEvent("ItemsShopUpdate")
  itemsShopListVersion(itemsShopListVersion.value + 1)
}

local lastItemDefsUpdatedelayedCall = 0
ItemsManager.markItemsDefsListUpdateDelayed <- function markItemsDefsListUpdateDelayed() {
  if (_reqUpdateItemDefsList)
    return
  if (lastItemDefsUpdatedelayedCall
      && lastItemDefsUpdatedelayedCall + LOST_DELAYED_ACTION_MSEC > get_time_msec())
    return

  lastItemDefsUpdatedelayedCall = get_time_msec()
  handlersManager.doDelayed(function() {
    lastItemDefsUpdatedelayedCall = 0
    this.markItemsDefsListUpdate()
  }.bindenv(this))
}

ItemsManager.onEventItemDefChanged <- function onEventItemDefChanged(_p) {
  this.markItemsDefsListUpdate()
}

ItemsManager.onEventExtPricesChanged <- @(_p) this.markItemsDefsListUpdateDelayed()


/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------INVENTORY ITEMS-----------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////
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

ItemsManager.getInventoryItemType <- function getInventoryItemType(blkType) {
  if (type(blkType) == "string") {
    if (blkType in inventoryItemTypeByTag)
      return inventoryItemTypeByTag[blkType]

    blkType = item_get_type_id_by_type_name(blkType)
  }

  return itemTypeByBlkType?[blkType] ?? itemType.UNKNOWN
}

ItemsManager._checkInventoryUpdate <- function _checkInventoryUpdate() {
  if (!_needInventoryUpdate)
    return
  _needInventoryUpdate = false

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

    let iType = this.getInventoryItemType(invItemBlk?.type)
    if (iType == itemType.UNKNOWN) {
      //debugTableData(invItemBlk)
      //assert(false, "Inventory: unknown item type = " + invItemBlk?.type)
      continue
    }

    let blk = itemsBlk?[slot.id]
    if (!blk) {
      if (::is_dev_version)
        log("Error: found removed item: " + slot.id)
      continue //skip removed items
    }

    let item = createItem(iType, blk, invItemBlk, slot)
    inventory.append(item)
    inventoryItemById[item.id] <- item
    if (item.shouldAutoConsume && !item.isActive())
      setShouldCheckAutoConsume(true)
  }

  ItemsManager.fillFakeItemsList()
  if (fakeItemsList && get_cyber_cafe_level()) {
    let id = "FakeBoosterForNetCafeLevel"
    let blk = fakeItemsList.getBlockByName(id)
    if (blk) {
      let item = createItem(blk?.type, blk, DataBlock(), { uids = [FAKE_ITEM_CYBER_CAFE_BOOSTER_UID] })
      inventory.append(item)
      inventoryItemById[item.id] <- item
    }
  }

  //gather transfer items list
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

    if (!itemDefDesc.len()) //item not full updated, or itemDesc no more exist.
      continue
    let iType = this.getInventoryItemType(itemDefDesc?.tags?.type ?? "")
    if (iType == itemType.UNKNOWN) {
      logerr("Inventory: Unknown itemdef.tags.type in item " + (itemDefDesc?.itemdefid ?? "NULL"))
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
    let iType = this.getInventoryItemType(itemdef?.tags?.type ?? "")
    if (iType == itemType.UNKNOWN) {
      if (isInArray(itemdef?.type, [ "item", "delayedexchange" ]))
        logerr("Inventory: Transfer: Unknown itemdef.tags.type in item " + itemdefid)
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

ItemsManager.getInventoryList <- function getInventoryList(typeMask = itemType.ALL, filterFunc = null) {
  this._checkInventoryUpdate()
  checkAutoConsume()
  return this._getItemsFromList(inventory, typeMask, filterFunc)
}

ItemsManager.getInventoryListByShopMask <- function getInventoryListByShopMask(typeMask, filterFunc = null) {
  this._checkInventoryUpdate()
  checkAutoConsume()
  return this._getItemsFromList(inventory, typeMask, filterFunc, "shopFilterMask")
}

ItemsManager.getInventoryVisibleSeenIds <- function getInventoryVisibleSeenIds() {
  if (!inventoryVisibleSeenIds) {
    let invItemsList = this.getInventoryListByShopMask(this.checkItemsMaskFeatures(itemType.INVENTORY_ALL))
    inventoryVisibleSeenIds = invItemsList.filter(
      @(it) ItemsManager.isItemVisible(it, itemsTab.INVENTORY)).map(@(it) it.getSeenId())
  }

  return inventoryVisibleSeenIds
}

ItemsManager.getInventoryItemByCraftedFrom <- @(uid) u.search(this.getInventoryList(),
  @(item) item.isCraftResult() && item.craftedFrom == uid)

ItemsManager.markInventoryUpdate <- function markInventoryUpdate() {
  if (_needInventoryUpdate)
    return

  _needInventoryUpdate = true
  inventoryVisibleSeenIds = null
  if (!isInventoryFullUpdate && isInventoryInternalUpdated && !inventoryClient.isWaitForInventory()) {
    isInventoryFullUpdate = true
    seenInventory.setDaysToUnseen(OUT_OF_DATE_DAYS_INVENTORY)
  }
  seenInventory.onListChanged()
  broadcastEvent("InventoryUpdate")
  inventoryListVersion(inventoryListVersion.value + 1)
}

local lastInventoryUpdateDelayedCall = 0
ItemsManager.markInventoryUpdateDelayed <- function markInventoryUpdateDelayed() {
  if (_needInventoryUpdate)
    return
  if (lastInventoryUpdateDelayedCall
      && lastInventoryUpdateDelayedCall < get_time_msec() + LOST_DELAYED_ACTION_MSEC)
    return

  lastInventoryUpdateDelayedCall = get_time_msec()
  ::g_delayed_actions.add(function() {
    if (!::g_login.isProfileReceived())
      return
    lastInventoryUpdateDelayedCall = 0
    this.markInventoryUpdate()
  }.bindenv(this), 200)
}

ItemsManager.onEventLoginComplete <- function onEventLoginComplete(_p) {
  setShouldCheckAutoConsume(true)
  _reqUpdateList = true
}

ItemsManager.onEventSignOut <- function onEventSignOut(_p) {
  isInventoryFullUpdate = false
  isInventoryInternalUpdated = false
}


/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------ITEM UTILS----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

ItemsManager.checkItemsMaskFeatures <- function checkItemsMaskFeatures(itemsMask) { //return itemss mask only of available features
  foreach (iType, feature in itemTypeFeatures)
    if ((itemsMask & iType) && !hasFeature(feature))
      itemsMask -= iType
  return itemsMask
}

ItemsManager._getItemsFromList <- function _getItemsFromList(list, typeMask, filterFunc = null, itemMaskProperty = "iType") {
  if (typeMask == itemType.ALL && !filterFunc)
    return list

  let res = []
  foreach (item in list)
    if (((item?[itemMaskProperty] ?? item.iType) & typeMask)
        && (!filterFunc || filterFunc(item)))
      res.append(item)
  return res
}

//just update gamercards atm.
ItemsManager.registerBoosterUpdateTimer <- function registerBoosterUpdateTimer(boostersList) {
  if (!isInFlight())
    return

  let curFlightTime = get_usefull_total_time()
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

  this.removeRefreshBoostersTask()

  boostersTaskUpdateFlightTime = nextUpdateTime
  refreshBoostersTask = periodic_task_register_ex(this,
                                                    this._onBoosterExpiredInFlight,
                                                    boostersTaskUpdateFlightTime - curFlightTime,
                                                    EPTF_IN_FLIGHT,
                                                    EPTT_BEST_EFFORT,
                                                    false //flight time
                                                   )
}

ItemsManager._onBoosterExpiredInFlight <- function _onBoosterExpiredInFlight(_dt = 0) {
  this.removeRefreshBoostersTask()
  if (isInFlight())
    ::update_gamercards()
}

ItemsManager.removeRefreshBoostersTask <- function removeRefreshBoostersTask() {
  if (refreshBoostersTask >= 0)
    periodic_task_unregister(refreshBoostersTask)
  refreshBoostersTask = -1
}

ItemsManager.refreshExtInventory <- function refreshExtInventory() {
  inventoryClient.refreshItems()
}

ItemsManager.onEventExtInventoryChanged        <- @(_p) this.markInventoryUpdateDelayed()
ItemsManager.onEventSendingItemsChanged        <- @(_p) this.markInventoryUpdateDelayed()
ItemsManager.onEventTourRegistrationComplete   <- @(_p) this.markInventoryUpdate()

ItemsManager.onEventLoadingStateChange <- function onEventLoadingStateChange(_p) {
  if (!isInFlight())
    this.removeRefreshBoostersTask()
}

ItemsManager.onEventGameLocalizationChanged <- function onEventGameLocalizationChanged(_p) {
  inventoryClient.forceRefreshItemDefs(@() itemsByItemdefId.clear())
}

ItemsManager.findItemByUid <- function findItemByUid(uid, filterType = itemType.ALL) {
  let itemsArray = ItemsManager.getInventoryList(filterType)
  let res = u.search(itemsArray, @(item) isInArray(uid, item.uids))
  return res
}

ItemsManager.collectUserlogItemdefs <- function collectUserlogItemdefs() {
  let res = []
  for (local i = 0; i < get_user_logs_count(); i++) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
    let itemDefId = blk?.body.itemDefId
    if (itemDefId)
      res.append(itemDefId)
  }
  this.requestItemsByItemdefIds(res)
}

ItemsManager.isEnabled <- function isEnabled() {
  let checkNewbie = !isMeNewbie()
    || seenInventory.hasSeen()
    || inventory.len() > 0
  return hasFeature("Items") && checkNewbie
}

ItemsManager.getItemsSortComparator <- function getItemsSortComparator(itemsSeenList = null) {
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

ItemsManager.getRawInventoryItemAmount <- function getRawInventoryItemAmount(itemdefid) {
  return rawInventoryItemAmountsByItemdefId?[itemdefid] ?? 0
}

subscribe_handler(ItemsManager, ::g_listener_priority.DEFAULT_HANDLER)


/////////////////////////////////////////////////////////////////////////////////////////////
//-----------------------------  PROMO ACTIONS---------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

let function consumeItemFromPromo(handler, params) {
  let itemId = params?[0]
  if (itemId == null)
    return
  let item = ItemsManager.getInventoryItemById(to_integer_safe(itemId, itemId, false))
  if (!(item?.canConsume() ?? false))
    return

  item?.consume(@(...) null, { needConsumeImpl = params?[1] == "needConsumeImpl" })
  handler.goBack()
}

let function canConsumeItemFromPromo(params) {
  let itemId = params?[0]
  if (itemId == null)
    return false
  let item = ItemsManager.getInventoryItemById(to_integer_safe(itemId, itemId, false))
  return item?.canConsume() ?? false
}

addPromoAction("consume_item", @(handler, params, _obj) consumeItemFromPromo(handler, params),
  @(params) canConsumeItemFromPromo(params))

//events from native code:
function onItemsLoaded() {
  isInventoryInternalUpdated = true
  ItemsManager.markInventoryUpdate()
}
::on_items_loaded <- @() deferOnce(onItemsLoaded)

/////////////////////////////////////////////////////////////////////////////////////////////
//--------------------------------SEEN ITEMS-----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

addListenersWithoutEnv({
  ProfileUpdated = @(_p) clearCasheForCanBeNewItems()
})


seenItems.setListGetter(@() ItemsManager.getShopVisibleSeenIds())
seenItems.setCanBeNewFunc(canSeenIdBeNew)
seenInventory.setListGetter(@() ItemsManager.getInventoryVisibleSeenIds())

let makeSeenCompatibility = @(savePath) function() {
    let res = {}
    let blk = loadLocalByAccount(savePath)
    if (!u.isDataBlock(blk))
      return res

    for (local i = 0; i < blk.paramCount(); i++)
      res[blk.getParamName(i)] <- blk.getParamValue(i)
    saveLocalByAccount(savePath, null)
    return res
  }

seenItems.setCompatibilityLoadData(makeSeenCompatibility("seen_shop_items"))
seenInventory.setCompatibilityLoadData(makeSeenCompatibility("seen_inventory_items"))

::ItemsManager <- freeze(ItemsManager)

return {
  itemsShopListVersion
  inventoryListVersion
  clearSeenCashe
}
