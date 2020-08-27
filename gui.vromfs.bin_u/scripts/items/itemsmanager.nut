local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local itemTransfer = require("scripts/items/itemsTransfer.nut")
local stdMath = require("std/math.nut")
local { openUrl } = require("scripts/onlineShop/url.nut")

local seenList = require("scripts/seen/seenList.nut")
local seenInventory = seenList.get(SEEN.INVENTORY)
local seenItems = seenList.get(SEEN.ITEMS_SHOP)
local OUT_OF_DATE_DAYS_ITEMS_SHOP = 28
local OUT_OF_DATE_DAYS_INVENTORY = 0

/*
  ::ItemsManager API:

  getItemsList(typeMask = itemType.ALL)     - get items list by type mask
  fillItemDescr(item, holderObj, handler)   - update item description in object.
  findItemById(id, typeMask = itemType.ALL) - search item by id

  getInventoryList(typeMask = itemType.ALL) - get items list by type mask
*/

class BoosterEffectType
{
  static RP = {
    name = "xpRate"
    currencyMark = ::loc("currency/researchPoints/sign/colored")
    abbreviation = "xp"
    checkBooster = function(booster)
    {
      return ::getTblValue("xpRate", booster, 0) != 0
    }
    getValue = function(booster)
    {
      return ::getTblValue("xpRate", booster, 0)
    }
    getText = function(value, colored = false, showEmpty = true)
    {
      if (value == 0 && !showEmpty)
        return ""
      return ::Cost().setRp(value).toStringWithParams({isColored = colored})
    }
  }
  static WP = {
    name = "wpRate"
    currencyMark = ::loc("warpoints/short/colored")
    abbreviation = "wp"
    checkBooster = function(booster)
    {
      return ::getTblValue("wpRate", booster, 0) != 0
    }
    getValue = function(booster)
    {
      return ::getTblValue("wpRate", booster, 0)
    }
    getText = function(value, colored = false, showEmpty = true)
    {
      if (value == 0 && !showEmpty)
        return ""
      return ::Cost(value).toStringWithParams({isWpAlwaysShown = true, isColored = colored})
    }
  }
}

::FAKE_ITEM_CYBER_CAFE_BOOSTER_UID <- -1

//events from native code:
::on_items_loaded <- @() ::ItemsManager.onItemsLoaded()

foreach (fn in [
                 "discountItemSortMethod.nut"
                 "trophyMultiAward.nut"
                 "itemLimits.nut"
                 "listPopupWnd/itemsListWndBase.nut"
                 "listPopupWnd/universalSpareApplyWnd.nut"
                 "listPopupWnd/modUpgradeApplyWnd.nut"
                 "roulette/itemsRoulette.nut"
               ])
  ::g_script_reloader.loadOnce("scripts/items/" + fn)

foreach (fn in [
                 "itemsBase.nut"
                 "itemTrophy.nut"
                 "itemBooster.nut"
                 "itemTicket.nut"
                 "itemWager.nut"
                 "itemDiscount.nut"
                 "itemOrder.nut"
                 "itemUniversalSpare.nut"
                 "itemModOverdrive.nut"
                 "itemModUpgrade.nut"

                 //external inventory items
                 "itemVehicle.nut"
                 "itemSkin.nut"
                 "itemDecal.nut"
                 "itemAttachable.nut"
                 "itemKey.nut"
                 "itemChest.nut"
                 "itemWarbonds.nut"
                 "itemInternalItem.nut"
                 "itemCraftPart.nut"
                 "itemCraftProcess.nut"
                 "itemRecipesBundle.nut"
                 "itemEntitlement.nut"
               ])
  ::g_script_reloader.loadOnce("scripts/items/itemsClasses/" + fn)

::ItemsManager <- {
  itemsList = []
  inventory = []
  shopItemById = {}

  itemsListInternal = []
  itemsListExternal = []
  itemsByItemdefId = {}

  rawInventoryItemAmountsByItemdefId = {}

  itemTypeClasses = {} //itemtype = itemclass

  //lists cache for optimization
  shopVisibleSeenIds = null
  inventoryVisibleSeenIds = null

  itemTypeFeatures = {
    [itemType.WAGER] = "Wagers",
    [itemType.ORDER] = "Orders"
  }

  _reqUpdateList = true
  _reqUpdateItemDefsList = true
  _needInventoryUpdate = true

  shouldCheckAutoConsume = false

  isInventoryInternalUpdated = false
  isInventoryFullUpdated = false

  extInventoryUpdateTime = 0

  ignoreItemLimits = false
  fakeItemsList = null
  genericItemsForCyberCafeLevel = -1

  refreshBoostersTask = -1
  boostersTaskUpdateFlightTime = -1

  //!!!BEGIN added only for debug
  dbgTrophiesListInternal = []
  dbgLoadedTrophiesCount = 0
  dbgLoadedItemsInternalCount = 0
  dbgUpdateInternalItemsCount = 0

  getInternalItemsDebugInfo = @() {
    dbgTrophiesListInternal = dbgTrophiesListInternal
    dbgLoadedTrophiesCount = dbgLoadedTrophiesCount
    itemsListInternal = itemsListInternal
    dbgLoadedItemsInternalCount = dbgLoadedItemsInternalCount
    dbgUpdateInternalItemsCount = dbgUpdateInternalItemsCount
  }
  //!!!END added only for debug

  function getBestSpecialOfferItemByUnit(unit) {
    local res = []
    for (local i = 0; i < ::get_current_personal_discount_count(); i++) {
      local uid = ::get_current_personal_discount_uid(i)
      local item = ::ItemsManager.findItemByUid(uid, itemType.DISCOUNT)
      if (item == null || !(item?.isSpecialOffer ?? false) || !item.isActive())
        continue

      local locParams = item.getSpecialOfferLocParams()
      local itemUnit = locParams?.unit
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
}

ItemsManager.fillFakeItemsList <- function fillFakeItemsList()
{
  local curLevel = ::get_cyber_cafe_level()
  if (curLevel == genericItemsForCyberCafeLevel)
    return

  genericItemsForCyberCafeLevel = curLevel

  fakeItemsList = ::DataBlock()

  for (local i = 0; i <= ::cyber_cafe_max_level; i++)
  {
    local level = i || curLevel //we do not need level0 booster, but need booster of current level.
    local table = {
      type = itemType.FAKE_BOOSTER
      iconStyle = "cybercafebonus"
      locId = "item/FakeBoosterForNetCafeLevel"
      rateBoosterParams = {
        xpRate = ::floor(100.0 * ::get_cyber_cafe_bonus_by_effect_type(BoosterEffectType.RP, level) + 0.5)
        wpRate = ::floor(100.0 * ::get_cyber_cafe_bonus_by_effect_type(BoosterEffectType.WP, level) + 0.5)
      }
    }
    fakeItemsList["FakeBoosterForNetCafeLevel" + (i || "")] <- ::build_blk_from_container(table)
  }

  for (local i = 2; i <= ::g_squad_manager.getMaxSquadSize(); i++)
  {
    local table = {
      type = itemType.FAKE_BOOSTER
      rateBoosterParams = {
        xpRate = ::floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(BoosterEffectType.RP, i) + 0.5)
        wpRate = ::floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(BoosterEffectType.WP, i) + 0.5)
      }
    }
    fakeItemsList["FakeBoosterForSquadFromSameCafe" + i] <- ::build_blk_from_container(table)
  }

  local trophyFromInventory = {
    type = itemType.TROPHY
    locId = "inventory/consumeItem"
    iconStyle = "gold_iron_box"
  }
  fakeItemsList["trophyFromInventory"] <- ::build_blk_from_container(trophyFromInventory)
}

/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------SHOP ITEMS----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////
ItemsManager._checkUpdateList <- function _checkUpdateList()
{
  local hasChanges = checkShopItemsUpdate()
  if (checkItemDefsUpdate())
    hasChanges = true

  if (!hasChanges)
    return

  local duplicatesId = []
  shopItemById.clear()
  itemsList.clear()
  itemsList.extend(itemsListInternal)
  itemsList.extend(itemsListExternal)

  foreach(item in itemsList)
    if (item.id in shopItemById)
      duplicatesId.append(item.id)
    else
      shopItemById[item.id] <- item

  if (duplicatesId.len())
    ::dagor.assertf(false, "Items shop: found duplicate items id = \n" + ::g_string.implode(duplicatesId, ", "))
}

ItemsManager.checkShopItemsUpdate <- function checkShopItemsUpdate()
{
  if (!_reqUpdateList)
    return false
  _reqUpdateList = false
  itemsListInternal.clear()
  dbgTrophiesListInternal.clear()
  dbgUpdateInternalItemsCount++

  local pBlk = ::get_price_blk()
  local trophyBlk = pBlk?.trophy
  if (trophyBlk)
    for (local i = 0; i < trophyBlk.blockCount(); i++)
    {
      local blk = trophyBlk.getBlock(i)
      local item = createItem(itemType.TROPHY, blk)
      itemsListInternal.append(item)
      dbgTrophiesListInternal.append(item)
    }
  dbgLoadedTrophiesCount = dbgTrophiesListInternal.len()

  local itemsBlk = ::get_items_blk()
  ignoreItemLimits = !!itemsBlk?.ignoreItemLimits
  for(local i = 0; i < itemsBlk.blockCount(); i++)
  {
    local blk = itemsBlk.getBlock(i)
    local iType = getInventoryItemType(blk?.type)
    if (iType == itemType.UNKNOWN)
    {
      ::dagor.debug("Error: unknown item type in items blk = " + (blk?.type ?? "NULL"))
      continue
    }
    local item = createItem(iType, blk)
    itemsListInternal.append(item)
  }

  ::ItemsManager.fillFakeItemsList()
  if (fakeItemsList)
    for (local i = 0; i < fakeItemsList.blockCount(); i++)
    {
      local blk = fakeItemsList.getBlock(i)
      local item = createItem(blk?.type, blk)
      itemsListInternal.append(item)
    }

  dbgLoadedItemsInternalCount = itemsListInternal.len()
  return true
}

ItemsManager.checkItemDefsUpdate <- function checkItemDefsUpdate()
{
  if (!_reqUpdateItemDefsList)
    return false
  _reqUpdateItemDefsList = false

  itemsListExternal.clear()
  // Collecting itemdefs as shop items
  foreach (itemDefDesc in inventoryClient.getItemdefs())
  {
    local item = itemsByItemdefId?[itemDefDesc?.itemdefid]
    if (!item)
    {
      local defType = itemDefDesc?.type

      if (::isInArray(defType, [ "playtimegenerator", "generator", "bundle", "delayedexchange" ])
        || !::u.isEmpty(itemDefDesc?.exchange) || itemDefDesc?.tags?.hasAdditionalRecipes)
          ItemGenerators.add(itemDefDesc)

      if (!::isInArray(defType, [ "item", "delayedexchange" ]))
        continue
      local iType = getInventoryItemType(itemDefDesc?.tags?.type ?? "")
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

ItemsManager.onEventEntitlementsUpdatedFromOnlineShop <- function onEventEntitlementsUpdatedFromOnlineShop(params)
{
  local curLevel = ::get_cyber_cafe_level()
  if (genericItemsForCyberCafeLevel != curLevel)
  {
    markItemsListUpdate()
    markInventoryUpdate()
  }
}

ItemsManager.initItemsClasses <- function initItemsClasses()
{
  foreach(name, itemClass in ::items_classes)
  {
    local iType = itemClass.iType
    if (stdMath.number_of_set_bits(iType) != 1)
      ::dagor.assertf(false, "Incorrect item class iType " + iType + " must be a power of 2")
    if (iType in itemTypeClasses)
      ::dagor.assertf(false, "duplicate iType in item classes " + iType)
    else
      itemTypeClasses[iType] <- itemClass
  }
}
::ItemsManager.initItemsClasses() //init classes right after scripts load.

ItemsManager.createItem <- function createItem(itemType, blk, inventoryBlk = null, slotData = null)
{
  local iClass = (itemType in itemTypeClasses)? itemTypeClasses[itemType] : ::BaseItem
  return iClass(blk, inventoryBlk, slotData)
}

ItemsManager.getItemClass <- function getItemClass(itemType)
{
  return (itemType in itemTypeClasses)? itemTypeClasses[itemType] : ::BaseItem
}

ItemsManager.getItemsList <- function getItemsList(typeMask = itemType.ALL, filterFunc = null)
{
  _checkUpdateList()
  return _getItemsFromList(itemsList, typeMask, filterFunc)
}

ItemsManager.getShopList <- function getShopList(typeMask = itemType.INVENTORY_ALL, filterFunc = null)
{
  _checkUpdateList()
  return _getItemsFromList(itemsList, typeMask, filterFunc, "shopFilterMask")
}

ItemsManager.getShopVisibleSeenIds <- function getShopVisibleSeenIds()
{
  if (!shopVisibleSeenIds)
    shopVisibleSeenIds = getShopList(checkItemsMaskFeatures(itemType.INVENTORY_ALL),
      @(it) it.isCanBuy() && !it.isHiddenItem() && !it.isVisibleInWorkshopOnly()).map(@(it) it.getSeenId())
  return shopVisibleSeenIds
}

ItemsManager.findItemById <- function findItemById(id, typeMask = itemType.ALL)
{
  _checkUpdateList()
  local item = shopItemById?[id] ?? itemsByItemdefId?[id]
  if (!item && isItemdefId(id))
    requestItemsByItemdefIds([id])
  return item
}

ItemsManager.isItemdefId <- function isItemdefId(id)
{
  return typeof id == "integer"
}

ItemsManager.requestItemsByItemdefIds <- function requestItemsByItemdefIds(itemdefIdsList)
{
  inventoryClient.requestItemdefsByIds(itemdefIdsList)
}

ItemsManager.getItemOrRecipeBundleById <- function getItemOrRecipeBundleById(id)
{
  local item = findItemById(id)
  if (item || !ItemGenerators.get(id))
    return item

  local itemDefDesc = inventoryClient.getItemdefs()?[id]
  if (!itemDefDesc)
    return item

  item = createItem(itemType.RECIPES_BUNDLE, itemDefDesc)
  //this item is not visible in inventory or shop, so no need special event about it creation
  //but we need to be able find it by id to correct work with it later.
  itemsByItemdefId[item.id] <- item
  return item
}

ItemsManager.isMarketplaceEnabled <- function isMarketplaceEnabled()
{
  return ::has_feature("Marketplace") && ::has_feature("AllowExternalLink") &&
    inventoryClient.getMarketplaceBaseUrl() != null
}

ItemsManager.goToMarketplace <- function goToMarketplace()
{
  if (isMarketplaceEnabled())
    openUrl(inventoryClient.getMarketplaceBaseUrl(), false, false, "marketplace")
}

ItemsManager.markItemsListUpdate <- function markItemsListUpdate()
{
  _reqUpdateList = true
  shopVisibleSeenIds = null
  seenItems.setDaysToUnseen(OUT_OF_DATE_DAYS_ITEMS_SHOP)
  seenItems.onListChanged()
  ::broadcastEvent("ItemsShopUpdate")
}

ItemsManager.markItemsDefsListUpdate <- function markItemsDefsListUpdate()
{
  _reqUpdateItemDefsList = true
  shopVisibleSeenIds = null
  seenItems.onListChanged()
  ::broadcastEvent("ItemsShopUpdate")
}

local lastItemDefsUpdatedelayedCall = 0
ItemsManager.markItemsDefsListUpdateDelayed <- function markItemsDefsListUpdateDelayed()
{
  if (_reqUpdateItemDefsList)
    return
  if (lastItemDefsUpdatedelayedCall
      && lastItemDefsUpdatedelayedCall < ::dagor.getCurTime() + LOST_DELAYED_ACTION_MSEC)
    return

  lastItemDefsUpdatedelayedCall = ::dagor.getCurTime()
  ::handlersManager.doDelayed(function() {
    lastItemDefsUpdatedelayedCall = 0
    markItemsDefsListUpdate()
  }.bindenv(this))
}

ItemsManager.onEventItemDefChanged <- function onEventItemDefChanged(p)
{
  markItemsDefsListUpdateDelayed()
}

::ItemsManager.onEventExtPricesChanged <- @(p) markItemsDefsListUpdateDelayed()


/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------INVENTORY ITEMS-----------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////
ItemsManager.getInventoryItemType <- function getInventoryItemType(blkType)
{
  if (typeof(blkType) == "string") {
    switch (blkType)
    {
      case "skin":                return itemType.SKIN
      case "decal":               return itemType.DECAL
      case "attachable":          return itemType.ATTACHABLE
      case "key":                 return itemType.KEY
      case "chest":               return itemType.CHEST
      case "aircraft":
      case "tank":
      case "helicopter":
      case "ship":                return itemType.VEHICLE
      case "warbonds":            return itemType.WARBONDS
      case "craft_part":          return itemType.CRAFT_PART
      case "craft_process":       return itemType.CRAFT_PROCESS
      case "internal_item":       return itemType.INTERNAL_ITEM
      case "entitlement":         return itemType.ENTITLEMENT
    }

    blkType = ::item_get_type_id_by_type_name(blkType)
  }

  switch (blkType)
  {
    case ::EIT_BOOSTER:           return itemType.BOOSTER
    case ::EIT_TOURNAMENT_TICKET: return itemType.TICKET
    case ::EIT_WAGER:             return itemType.WAGER
    case ::EIT_PERSONAL_DISCOUNTS:return itemType.DISCOUNT
    case ::EIT_ORDER:             return itemType.ORDER
    case ::EIT_UNIVERSAL_SPARE:   return itemType.UNIVERSAL_SPARE
    case ::EIT_MOD_OVERDRIVE:     return itemType.MOD_OVERDRIVE
    case ::EIT_MOD_UPGRADE:       return itemType.MOD_UPGRADE
  }
  return itemType.UNKNOWN
}

ItemsManager._checkInventoryUpdate <- function _checkInventoryUpdate()
{
  if (!_needInventoryUpdate)
    return
  _needInventoryUpdate = false

  inventory = []

  local itemsBlk = ::get_items_blk()

  local itemsCache = ::get_items_cache()
  foreach(slot in itemsCache)
  {
    if (!slot.uids.len())
      continue

    local invItemBlk = ::DataBlock()
    ::get_item_data_by_uid(invItemBlk, slot.uids[0])
    if (::getTblValue("expiredTime", invItemBlk, 0) < 0)
      continue

    local iType = getInventoryItemType(invItemBlk?.type)
    if (iType == itemType.UNKNOWN)
    {
      //debugTableData(invItemBlk)
      //::dagor.assertf(false, "Inventory: unknown item type = " + invItemBlk?.type)
      continue
    }

    local blk = itemsBlk?[slot.id]
    if (!blk)
    {
      if (::is_dev_version)
        dagor.debug("Error: found removed item: " + slot.id)
      continue //skip removed items
    }

    local item = createItem(iType, blk, invItemBlk, slot)
    inventory.append(item)
    if (item.shouldAutoConsume && !item.isActive())
      shouldCheckAutoConsume = true
  }

  ::ItemsManager.fillFakeItemsList()
  if (fakeItemsList && ::get_cyber_cafe_level())
  {
    local id = "FakeBoosterForNetCafeLevel"
    local blk = fakeItemsList.getBlockByName(id)
    if (blk)
    {
      local item = createItem(blk?.type, blk, ::DataBlock(), {uids = [::FAKE_ITEM_CYBER_CAFE_BOOSTER_UID]})
      inventory.append(item)
    }
  }

  //gather transfer items list
  local transferAmounts = {}
  foreach(data in itemTransfer.getSendingList())
    transferAmounts[data.itemDefId] <- (transferAmounts?[data.itemDefId] ?? 0) + 1

  // Collecting external inventory items
  rawInventoryItemAmountsByItemdefId = {}
  local extInventoryItems = []
  foreach (itemDesc in inventoryClient.getItems())
  {
    local itemDefDesc = itemDesc.itemdef
    local itemDefId = itemDesc.itemdefid
    if (itemDefId in rawInventoryItemAmountsByItemdefId)
      rawInventoryItemAmountsByItemdefId[itemDefId] += itemDesc.quantity
    else
      rawInventoryItemAmountsByItemdefId[itemDefId] <- itemDesc.quantity

    if (!itemDefDesc.len()) //item not full updated, or itemDesc no more exist.
      continue
    local iType = getInventoryItemType(itemDefDesc?.tags?.type ?? "")
    if (iType == itemType.UNKNOWN)
    {
      ::dagor.logerr("Inventory: Unknown itemdef.tags.type in item " + (itemDefDesc?.itemdefid ?? "NULL"))
      continue
    }

    local isCreate = true
    foreach (existingItem in extInventoryItems)
      if (existingItem.tryAddItem(itemDefDesc, itemDesc))
      {
        isCreate = false
        break
      }
    if (isCreate)
    {
      local item = createItem(iType, itemDefDesc, itemDesc)
      if (item.id in transferAmounts)
        item.transferAmount += delete transferAmounts[item.id]
      if (item.shouldAutoConsume)
        shouldCheckAutoConsume = true
      extInventoryItems.append(item)
    }
  }

  //add items in transfer
  local itemdefsToRequest = []
  foreach(itemdefid, amount in transferAmounts)
  {
    local itemdef = inventoryClient.getItemdefs()?[itemdefid]
    if (!itemdef)
    {
      itemdefsToRequest.append(itemdefid)
      continue
    }
    local iType = getInventoryItemType(itemdef?.tags?.type ?? "")
    if (iType == itemType.UNKNOWN)
    {
      if (::isInArray(itemdef?.type, [ "item", "delayedexchange" ]))
        ::dagor.logerr("Inventory: Transfer: Unknown itemdef.tags.type in item " + itemdefid)
      continue
    }
    local item = createItem(iType, itemdef, {})
    item.transferAmount += amount
    extInventoryItems.append(item)
  }

  if (itemdefsToRequest.len())
    inventoryClient.requestItemdefsByIds(itemdefsToRequest)

  inventory.extend(extInventoryItems)
  extInventoryUpdateTime = ::dagor.getCurTime()
}

ItemsManager.checkAutoConsume <- function checkAutoConsume()
{
  if (!shouldCheckAutoConsume)
    return
  shouldCheckAutoConsume = false
  autoConsumeItems()
}

ItemsManager.getInventoryList <- function getInventoryList(typeMask = itemType.ALL, filterFunc = null)
{
  _checkInventoryUpdate()
  checkAutoConsume()
  return _getItemsFromList(inventory, typeMask, filterFunc)
}

ItemsManager.getInventoryListByShopMask <- function getInventoryListByShopMask(typeMask, filterFunc = null)
{
  _checkInventoryUpdate()
  checkAutoConsume()
  return _getItemsFromList(inventory, typeMask, filterFunc, "shopFilterMask")
}

ItemsManager.getInventoryVisibleSeenIds <- function getInventoryVisibleSeenIds()
{
  if (!inventoryVisibleSeenIds)
  {
    local itemsList = getInventoryListByShopMask(checkItemsMaskFeatures(itemType.INVENTORY_ALL))
    inventoryVisibleSeenIds = itemsList.filter(
      @(it) !it.isHiddenItem() && !it.isVisibleInWorkshopOnly()).map(@(it) it.getSeenId())
  }

  return inventoryVisibleSeenIds
}

ItemsManager.getInventoryItemById <- @(id) ::u.search(getInventoryList(), @(item) item.id == id)

ItemsManager.getInventoryItemByCraftedFrom <- @(uid) ::u.search(getInventoryList(),
  @(item) item.isCraftResult() && item.craftedFrom == uid)

ItemsManager.markInventoryUpdate <- function markInventoryUpdate()
{
  if (_needInventoryUpdate)
    return

  _needInventoryUpdate = true
  inventoryVisibleSeenIds = null
  if (!isInventoryFullUpdated && isInventoryInternalUpdated && !inventoryClient.isWaitForInventory())
  {
    isInventoryFullUpdated = true
    seenInventory.setDaysToUnseen(OUT_OF_DATE_DAYS_INVENTORY)
  }
  seenInventory.onListChanged()
  ::broadcastEvent("InventoryUpdate")
}

local lastInventoryUpdateDelayedCall = 0
ItemsManager.markInventoryUpdateDelayed <- function markInventoryUpdateDelayed()
{
  if (_needInventoryUpdate)
    return
  if (lastInventoryUpdateDelayedCall
      && lastInventoryUpdateDelayedCall < ::dagor.getCurTime() + LOST_DELAYED_ACTION_MSEC)
    return

  lastInventoryUpdateDelayedCall = ::dagor.getCurTime()
  ::handlersManager.doDelayed(function() {
    lastInventoryUpdateDelayedCall = 0
    markInventoryUpdate()
  }.bindenv(this))
}

ItemsManager.onItemsLoaded <- function onItemsLoaded()
{
  isInventoryInternalUpdated = true
  markInventoryUpdate()
}

local isAutoConsumeInProgress = false
ItemsManager.autoConsumeItems <- function autoConsumeItems()
{
  if (isAutoConsumeInProgress)
    return

  local onConsumeFinish = function(...) {
    isAutoConsumeInProgress = false
    autoConsumeItems()
  }.bindenv(this)

  foreach(item in getInventoryList())
    if (item.shouldAutoConsume && item.consume(onConsumeFinish, {}))
    {
      isAutoConsumeInProgress = true
      break
    }
}

ItemsManager.onEventLoginComplete <- function onEventLoginComplete(p) {
  shouldCheckAutoConsume = true
  _reqUpdateList = true
}

ItemsManager.onEventSignOut <- function onEventSignOut(p)
{
  isInventoryFullUpdated = false
  isInventoryInternalUpdated = false
}


/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------ITEM UTILS----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

ItemsManager.checkItemsMaskFeatures <- function checkItemsMaskFeatures(itemsMask) //return itemss mask only of available features
{
  foreach(iType, feature in itemTypeFeatures)
    if ((itemsMask & iType) && !::has_feature(feature))
      itemsMask -= iType
  return itemsMask
}

ItemsManager._getItemsFromList <- function _getItemsFromList(list, typeMask, filterFunc = null, itemMaskProperty = "iType")
{
  if (typeMask == itemType.ALL && !filterFunc)
    return list

  local res = []
  foreach(item in list)
    if (((item?[itemMaskProperty] ?? item.iType) & typeMask)
        && (!filterFunc || filterFunc(item)))
      res.append(item)
  return res
}

ItemsManager.fillItemDescr <- function fillItemDescr(item, holderObj, handler = null, shopDesc = false, preferMarkup = false, params = null)
{
  handler = handler || ::get_cur_base_gui_handler()

  item = item?.getSubstitutionItem() ?? item
  local obj = holderObj.findObject("item_name")
  if (::checkObj(obj))
    obj.setValue(item? item.getDescriptionTitle() : "")

  local addDescObj = holderObj.findObject("item_desc_under_title")
  if (::checkObj(addDescObj))
    addDescObj.setValue(item?.getDescriptionUnderTitle?() ?? "")

  local helpObj = holderObj.findObject("item_type_help")
  if (::checkObj(helpObj))
  {
    local helpText = item && item?.getItemTypeDescription? item.getItemTypeDescription() : ""
    helpObj.tooltip = helpText
    helpObj.show(shopDesc && helpText != "")
  }

  local isDescTextBeforeDescDiv = !item || item?.isDescTextBeforeDescDiv || false
  obj = holderObj.findObject(isDescTextBeforeDescDiv ? "item_desc" : "item_desc_under_div")
  if (::checkObj(obj))
  {
    local desc = ""
    if (item)
    {
      if (item?.getShortItemTypeDescription)
        desc = item.getShortItemTypeDescription()
      local descText = preferMarkup ? item.getLongDescription() : item.getDescription()
      if (descText.len() > 0)
        desc += (desc.len() ? "\n\n" : "") + descText
      local itemLimitsDesc = item?.getLimitsDescription ? item.getLimitsDescription() : ""
      if (itemLimitsDesc.len() > 0)
        desc += (desc.len() ? "\n" : "") + itemLimitsDesc
    }
    local descModifyFunc = ::getTblValue("descModifyFunc", params)
    if (descModifyFunc)
      desc = descModifyFunc(desc)

    local warbondId = ::getTblValue("wbId", params)
    if (warbondId)
    {
      local warbond = ::g_warbonds.findWarbond(warbondId, ::getTblValue("wbListId", params))
      local award = warbond? warbond.getAwardById(item.id) : null
      if (award)
        desc = award.addAmountTextToDesc(desc)
    }

    obj.setValue(desc)
  }

  obj = holderObj.findObject("item_desc_div")
  if (::checkObj(obj))
  {
    local longdescMarkup = (preferMarkup && item && item?.getLongDescriptionMarkup) ? item.getLongDescriptionMarkup({ shopDesc = shopDesc }) : ""
    obj.show(longdescMarkup != "")
    if (longdescMarkup != "")
      obj.getScene().replaceContentFromText(obj, longdescMarkup, longdescMarkup.len(), handler)
  }

  obj = holderObj.findObject(isDescTextBeforeDescDiv ? "item_desc_under_div" : "item_desc")
  if (::checkObj(obj))
    obj.setValue("")

  ::ItemsManager.fillItemTableInfo(item, holderObj)

  obj = holderObj.findObject("item_icon")
  obj.show(item != null)
  if (item)
  {
    local iconSetParams = {
      bigPicture = item?.allowBigPicture || false
      addItemName = !shopDesc
    }
    item.setIcon(obj, iconSetParams)
  }
  obj.scrollToView()

  if (item && item?.getDescTimers)
    foreach(timerData in item.getDescTimers())
    {
      if (!timerData.needTimer.call(item))
        continue

      local timerObj = holderObj.findObject(timerData.id)
      local tData = timerData
      if (::check_obj(timerObj))
        SecondsUpdater(timerObj, function(tObj, params)
        {
          tObj.setValue(tData.getText.call(item))
          return !tData.needTimer.call(item)
        })
    }
}

ItemsManager.fillItemTableInfo <- function fillItemTableInfo(item, holderObj)
{
  if (!::checkObj(holderObj))
    return

  ::ItemsManager.fillItemTable(item, holderObj)

  local obj = holderObj.findObject("item_desc_above_table")
  if (::checkObj(obj))
    obj.setValue(item && item?.getDescriptionAboveTable ? item.getDescriptionAboveTable() : "")

  obj = holderObj.findObject("item_desc_under_table")
  if (::checkObj(obj))
    obj.setValue(item && item?.getDescriptionUnderTable ? item.getDescriptionUnderTable() : "")
}

ItemsManager.fillItemTable <- function fillItemTable(item, holderObj)
{
  local containerObj = holderObj.findObject("item_table_container")
  if (!::checkObj(containerObj))
    return

  local tableData = item && item?.getTableData ? item.getTableData() : null
  local show = tableData != null
  containerObj.show(show)

  if (show)
    holderObj.getScene().replaceContentFromText(containerObj, tableData, tableData.len(), this)
}

ItemsManager.getActiveBoostersArray <- function getActiveBoostersArray(effectType = null)
{
  local res = []
  local total = ::get_current_booster_count(INVALID_USER_ID)
  local bonusType = effectType ? effectType.name : null
  for (local i = 0; i < total; i++)
  {
    local uid = ::get_current_booster_uid(INVALID_USER_ID, i)
    local item = ::ItemsManager.findItemByUid(uid, itemType.BOOSTER)
    if (!item || (bonusType && item[bonusType] == 0) || !item.isActive(true))
      continue

    res.append(item)
  }

  if (res.len())
    registerBoosterUpdateTimer(res)

  return res
}

//just update gamercards atm.
ItemsManager.registerBoosterUpdateTimer <- function registerBoosterUpdateTimer(boostersList)
{
  if (!::is_in_flight())
    return

  local curFlightTime = ::get_usefull_total_time()
  local nextExpireTime = -1
  foreach(booster in boostersList)
  {
    local expireTime = booster.getExpireFlightTime()
    if (expireTime <= curFlightTime)
      continue
    if (nextExpireTime < 0 || expireTime < nextExpireTime)
      nextExpireTime = expireTime
  }

  if (nextExpireTime < 0)
    return

  local nextUpdateTime = nextExpireTime.tointeger() + 1
  if (refreshBoostersTask >= 0 && nextUpdateTime >= boostersTaskUpdateFlightTime)
    return

  removeRefreshBoostersTask()

  boostersTaskUpdateFlightTime = nextUpdateTime
  refreshBoostersTask = ::periodic_task_register_ex(this,
                                                    _onBoosterExpiredInFlight,
                                                    boostersTaskUpdateFlightTime - curFlightTime,
                                                    ::EPTF_IN_FLIGHT,
                                                    ::EPTT_BEST_EFFORT,
                                                    false //flight time
                                                   )
}

ItemsManager._onBoosterExpiredInFlight <- function _onBoosterExpiredInFlight(dt = 0)
{
  removeRefreshBoostersTask()
  if (::is_in_flight())
    ::update_gamercards()
}

ItemsManager.removeRefreshBoostersTask <- function removeRefreshBoostersTask()
{
  if (refreshBoostersTask >= 0)
    ::periodic_task_unregister(refreshBoostersTask)
  refreshBoostersTask = -1
}

ItemsManager.refreshExtInventory <- function refreshExtInventory()
{
  inventoryClient.refreshItems()
}

ItemsManager.forceRefreshExtInventory <- function forceRefreshExtInventory()
{
  itemsByItemdefId = {}
  inventoryClient.forceRefreshItemDefs()
}

ItemsManager.onEventExtInventoryChanged    <- @(p) markInventoryUpdateDelayed()
ItemsManager.onEventSendingItemsChanged    <- @(p) markInventoryUpdateDelayed()

ItemsManager.onEventLoadingStateChange <- function onEventLoadingStateChange(p)
{
  if (!::is_in_flight())
    removeRefreshBoostersTask()
}

ItemsManager.onEventGameLocalizationChanged <- function onEventGameLocalizationChanged(p)
{
  forceRefreshExtInventory()
}

/**
 * Returns structure table of boosters.
 * This structure looks like this:
 * {
 *   <sort_order> = {
 *     publick = [array of public boosters]
 *     personal = [array of personal boosters]
 *   }
 *  maxSortOrder = <maximum sort_order>
 * }
 * Public and personal arrays of boosters sorted by effect type
 */
ItemsManager.sortBoosters <- function sortBoosters(boosters, effectType)
{
  local res = {
    maxSortOrder = 0
  }
  foreach(booster in boosters)
  {
    res.maxSortOrder = ::max(::getTblValue("maxSortOrder", res, 0), booster.sortOrder)
    if (!::getTblValue(booster.sortOrder, res))
      res[booster.sortOrder] <- {
        personal = [],
        public = [],
      }

    if (booster.personal)
      res[booster.sortOrder].personal.append(booster)
    else
      res[booster.sortOrder].public.append(booster)
  }

  for (local i = 0; i <= res.maxSortOrder; i++)
    if (i in res && res[i].len())
      foreach (arr in res[i])
        ::ItemsManager.sortByParam(arr, effectType.name)
  return res
}

/**
 * Summs effects of passed boosters and returns table in format:
 * {
 *   <BoosterEffectType.name> = <value in percent>
 * }
 */
ItemsManager.getBoostersEffects <- function getBoostersEffects(boosters)
{
  local result = {}
  foreach (effectType in ::BoosterEffectType)
  {
    result[effectType.name] <- 0
    local sortedBoosters = ::ItemsManager.sortBoosters(boosters, effectType)
    for (local i = 0; i <= sortedBoosters.maxSortOrder; i++)
    {
      if (!(i in sortedBoosters))
        continue
      result[effectType.name] += ::calc_public_boost(::ItemsManager.getBoostersEffectsArray(sortedBoosters[i].public, effectType))
                              + ::calc_personal_boost(::ItemsManager.getBoostersEffectsArray(sortedBoosters[i].personal, effectType))
    }
  }
  return result
}

ItemsManager.getBoostersEffectsArray <- function getBoostersEffectsArray(itemsArray, effectType)
{
  local res = []
  foreach(item in itemsArray)
    res.append(item[effectType.name])
  return res
}

ItemsManager.getActiveBoostersDescription <- function getActiveBoostersDescription(boostersArray, effectType, selectedItem = null)
{
  if (!boostersArray || boostersArray.len() == 0)
    return ""

  local getColoredNumByType = (@(effectType) function(num) {
    return ::colorize("activeTextColor", "+" + num.tointeger() + "%") + effectType.currencyMark
  })(effectType)

  local separateBoosters = []

  local itemsArray = []
  foreach(booster in boostersArray)
  {
    if (booster.showBoosterInSeparateList)
      separateBoosters.append(booster.getName() + ::loc("ui/colon") + booster.getEffectDesc(true, effectType))
    else
      itemsArray.append(booster)
  }
  if (separateBoosters.len())
    separateBoosters.append("\n")

  local sortedItemsTable = ::ItemsManager.sortBoosters(itemsArray, effectType)
  local detailedDescription = []
  for (local i = 0; i <= sortedItemsTable.maxSortOrder; i++)
  {
    local arraysList = ::getTblValue(i, sortedItemsTable)
    if (!arraysList || arraysList.len() == 0)
      continue

    local personalTotal = arraysList.personal.len() == 0
                          ? 0
                          : ::calc_personal_boost(::ItemsManager.getBoostersEffectsArray(arraysList.personal, effectType))

    local publicTotal = arraysList.public.len() == 0
                        ? 0
                        : ::calc_public_boost(::ItemsManager.getBoostersEffectsArray(arraysList.public, effectType))

    local isBothBoosterTypesAvailable = personalTotal != 0 && publicTotal != 0

    local header = ""
    local detailedArray = []
    local insertedSubHeader = false

    foreach(j, arrayName in ["personal", "public"])
    {
      local arr = arraysList[arrayName]
      if (arr.len() == 0)
        continue

      local personal = arr[0].personal
      local boostNum = personal? personalTotal : publicTotal

      header = ::loc("mainmenu/boosterType/common")
      if (arr[0].eventConditions)
        header = ::UnlockConditions.getConditionsText(arr[0].eventConditions, null, null, { inlineText = true })

      local subHeader = "* " + ::loc("mainmenu/booster/" + arrayName)
      if (isBothBoosterTypesAvailable)
      {
        subHeader += ::loc("ui/colon")
        subHeader += getColoredNumByType(boostNum)
      }

      detailedArray.append(subHeader)

      local effectsArray = []
      foreach(idx, item in arr)
      {
        local effOld = personal? ::calc_personal_boost(effectsArray) : ::calc_public_boost(effectsArray)
        effectsArray.append(item[effectType.name])
        local effNew = personal? ::calc_personal_boost(effectsArray) : ::calc_public_boost(effectsArray)

        local string = arr.len() == 1? "" : (idx+1) + ") "
        string += item.getEffectDesc(false) + ::loc("ui/comma")
        string += ::loc("items/booster/giveRealBonus", {realBonus = getColoredNumByType(::format("%.02f", effNew - effOld).tofloat())})
        string += (idx == arr.len()-1? ::loc("ui/dot") : ::loc("ui/semicolon"))

        if (selectedItem != null && selectedItem.id == item.id)
          string = ::colorize("userlogColoredText", string)

        detailedArray.append(string)
      }

      if (!insertedSubHeader)
      {
        local totalBonus = publicTotal + personalTotal
        header += ::loc("ui/colon") + getColoredNumByType(totalBonus)
        detailedArray.insert(0, header)
        insertedSubHeader = true
      }
    }
    detailedDescription.append(::g_string.implode(detailedArray, "\n"))
  }

  local description = ::loc("mainmenu/boostersTooltip", effectType) + ::loc("ui/colon") + "\n"
  return description + ::g_string.implode(separateBoosters, "\n") + ::g_string.implode(detailedDescription, "\n\n")
}

ItemsManager.hasActiveBoosters <- function hasActiveBoosters(effectType, personal)
{
  local items = ::ItemsManager.getInventoryList(itemType.BOOSTER, (@(effectType, personal) function (item) {
    return item.isActive(true) && effectType.checkBooster(item) && item.personal == personal
  })(effectType, personal))
  return items.len() != 0
}

ItemsManager.sortEffectsArray <- function sortEffectsArray(a, b)
{
  if (a != b)
    return a > b? -1 : 1
  return 0
}

ItemsManager.sortByParam <- function sortByParam(arr, param)
{
  local sortByBonus = (@(param) function(a, b) {
    if (a[param] != b[param])
      return a[param] > b[param]? -1 : 1
    return 0
  })(param)

  arr.sort(sortByBonus)
  return arr
}

ItemsManager.findItemByUid <- function findItemByUid(uid, filterType = itemType.ALL)
{
  local itemsArray = ::ItemsManager.getInventoryList(filterType)
  local res = u.search(itemsArray, @(item) ::isInArray(uid, item.uids) )
  return res
}

ItemsManager.collectUserlogItemdefs <- function collectUserlogItemdefs()
{
  for(local i = 0; i < ::get_user_logs_count(); i++)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    local itemDefId = blk?.body?.itemDefId
    if (itemDefId)
      ::ItemsManager.findItemById(itemDefId) // Requests itemdef, if it is not found.
  }
}

ItemsManager.isEnabled <- function isEnabled()
{
  local checkNewbie = !::my_stats.isMeNewbie()
    || seenInventory.hasSeen()
    || inventory.len() > 0
  return ::has_feature("Items") && checkNewbie && ::isInMenu()
}

ItemsManager.canPreviewItems <- function canPreviewItems()
{
  local can = ::isInMenu() && !::checkIsInQueue()
      && !(::g_squad_manager.isSquadMember() && ::g_squad_manager.isMeReady())
      && !::SessionLobby.hasSessionInLobby()
  if (!can)
    ::g_popups.add("", ::loc("mainmenu/itemPreviewForbidden"))
  return can
}

ItemsManager.getItemsSortComparator <- function getItemsSortComparator(itemsSeenList = null)
{
  return function(item1, item2)
  {
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

ItemsManager.getRawInventoryItemAmount <- function getRawInventoryItemAmount(itemdefid)
{
  return rawInventoryItemAmountsByItemdefId?[itemdefid] ?? 0
}

::subscribe_handler(::ItemsManager, ::g_listener_priority.DEFAULT_HANDLER)


/////////////////////////////////////////////////////////////////////////////////////////////
//--------------------------------SEEN ITEMS-----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

seenItems.setListGetter(@() ::ItemsManager.getShopVisibleSeenIds())
seenInventory.setListGetter(@() ::ItemsManager.getInventoryVisibleSeenIds())

local makeSeenCompatibility = @(savePath) function()
  {
    local res = {}
    local blk = ::loadLocalByAccount(savePath)
    if (!::u.isDataBlock(blk))
      return res

    for (local i = 0; i < blk.paramCount(); i++)
      res[blk.getParamName(i)] <- blk.getParamValue(i)
    ::saveLocalByAccount(savePath, null)
    return res
  }

seenItems.setCompatibilityLoadData(makeSeenCompatibility("seen_shop_items"))
seenInventory.setCompatibilityLoadData(makeSeenCompatibility("seen_inventory_items"))
