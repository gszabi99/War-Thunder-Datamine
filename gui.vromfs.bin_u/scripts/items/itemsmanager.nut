let ItemGenerators = require("%scripts/items/itemsClasses/itemGenerators.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let itemTransfer = require("%scripts/items/itemsTransfer.nut")
let stdMath = require("%sqstd/math.nut")
let { setShouldCheckAutoConsume, checkAutoConsume } = require("%scripts/items/autoConsumeItems.nut")
let { buyableSmokesList } = require("%scripts/unlocks/unlockSmoke.nut")
let { boosterEffectType }= require("%scripts/items/boosterEffect.nut")
let seenList = require("%scripts/seen/seenList.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { PRICE } = require("%scripts/utils/configs.nut")

// Independent Modules
require("%scripts/items/roulette/bhvRoulette.nut")

let seenInventory = seenList.get(SEEN.INVENTORY)
let seenItems = seenList.get(SEEN.ITEMS_SHOP)
let OUT_OF_DATE_DAYS_ITEMS_SHOP = 28
let OUT_OF_DATE_DAYS_INVENTORY = 0

/*
  ::ItemsManager API:

  getItemsList(typeMask = itemType.ALL)     - get items list by type mask
  fillItemDescr(item, holderObj, handler)   - update item description in object.
  findItemById(id, typeMask = itemType.ALL) - search item by id

  getInventoryList(typeMask = itemType.ALL) - get items list by type mask
*/

::FAKE_ITEM_CYBER_CAFE_BOOSTER_UID <- -1

//events from native code:
::on_items_loaded <- @() ::ItemsManager.onItemsLoaded()

let itemsShopListVersion = ::Watched(0)
let inventoryListVersion = ::Watched(0)

foreach (fn in [
                 "discountItemSortMethod.nut"
                 "trophyMultiAward.nut"
                 "itemLimits.nut"
                 "listPopupWnd/itemsListWndBase.nut"
                 "listPopupWnd/universalSpareApplyWnd.nut"
                 "listPopupWnd/modUpgradeApplyWnd.nut"
                 "roulette/itemsRoulette.nut"
               ])
  ::g_script_reloader.loadOnce("%scripts/items/" + fn)

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
                 "itemSmoke.nut"

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
                 "itemWarpoints.nut"
                 "itemUnlock.nut"
                 "itemBattlePass.nut"
                 "itemRentedUnit.nut"
                 "itemUnitCouponMod.nut"
                 "itemProfileIcon.nut"
               ])
  ::g_script_reloader.loadOnce("%scripts/items/itemsClasses/" + fn)


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

  isInventoryInternalUpdated = false
  isInventoryFullUpdated = false

  extInventoryUpdateTime = 0

  ignoreItemLimits = false
  fakeItemsList = null
  genericItemsForCyberCafeLevel = -1

  refreshBoostersTask = -1
  boostersTaskUpdateFlightTime = -1
  smokeItems = ::Computed(@()
    buyableSmokesList.value.map(@(blk) ::ItemsManager.createItem(itemType.SMOKE, blk)))


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
    let res = []
    for (local i = 0; i < ::get_current_personal_discount_count(); i++) {
      let uid = ::get_current_personal_discount_uid(i)
      let item = ::ItemsManager.findItemByUid(uid, itemType.DISCOUNT)
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

  function onEventPriceUpdated(p) {
    markItemsListUpdate()
  }

  function canGetDecoratorFromTrophy(decorator) {
    if (!decorator || decorator.isUnlocked())
      return false
    let visibleTypeMask = checkItemsMaskFeatures(itemType.TROPHY)
    let filterFunc = @(item) !item.isDevItem && isItemVisible(item, itemsTab.SHOP)
    return getShopList(visibleTypeMask, filterFunc)
      .findindex(@(item) item.getContent().findindex(@(prize) prize?.resource == decorator.id) != null) != null
  }

  function invalidateShopVisibleSeenIds() {
    shopVisibleSeenIds = null
  }
}

::ItemsManager.fillFakeItemsList <- function fillFakeItemsList()
{
  let curLevel = ::get_cyber_cafe_level()
  if (curLevel == genericItemsForCyberCafeLevel)
    return

  genericItemsForCyberCafeLevel = curLevel

  fakeItemsList = ::DataBlock()

  for (local i = 0; i <= ::cyber_cafe_max_level; i++)
  {
    let level = i || curLevel //we do not need level0 booster, but need booster of current level.
    let table = {
      type = itemType.FAKE_BOOSTER
      iconStyle = "cybercafebonus"
      locId = "item/FakeBoosterForNetCafeLevel"
      rateBoosterParams = {
        xpRate = ::floor(100.0 * ::get_cyber_cafe_bonus_by_effect_type(boosterEffectType.RP, level) + 0.5)
        wpRate = ::floor(100.0 * ::get_cyber_cafe_bonus_by_effect_type(boosterEffectType.WP, level) + 0.5)
      }
    }
    fakeItemsList["FakeBoosterForNetCafeLevel" + (i || "")] <- ::build_blk_from_container(table)
  }

  for (local i = 2; i <= ::g_squad_manager.getMaxSquadSize(); i++)
  {
    let table = {
      type = itemType.FAKE_BOOSTER
      rateBoosterParams = {
        xpRate = ::floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(boosterEffectType.RP, i) + 0.5)
        wpRate = ::floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(boosterEffectType.WP, i) + 0.5)
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
::ItemsManager._checkUpdateList <- function _checkUpdateList()
{
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

  foreach(item in itemsList)
    if (item.id in shopItemById)
      duplicatesId.append(item.id)
    else
      shopItemById[item.id] <- item

  if (duplicatesId.len())
    ::dagor.assertf(false, "Items shop: found duplicate items id = \n" + ::g_string.implode(duplicatesId, ", "))
}

::ItemsManager.checkShopItemsUpdate <- function checkShopItemsUpdate()
{
  if (!_reqUpdateList)
    return false
  _reqUpdateList = false
  PRICE.checkUpdate()
  itemsListInternal.clear()
  dbgTrophiesListInternal.clear()
  dbgUpdateInternalItemsCount++

  let pBlk = ::get_price_blk()
  let trophyBlk = pBlk?.trophy
  if (trophyBlk)
    for (local i = 0; i < trophyBlk.blockCount(); i++)
    {
      let blk = trophyBlk.getBlock(i)
      let item = createItem(itemType.TROPHY, blk)
      itemsListInternal.append(item)
      dbgTrophiesListInternal.append(item)
    }
  dbgLoadedTrophiesCount = dbgTrophiesListInternal.len()

  let itemsBlk = ::get_items_blk()
  ignoreItemLimits = !!itemsBlk?.ignoreItemLimits
  for(local i = 0; i < itemsBlk.blockCount(); i++)
  {
    let blk = itemsBlk.getBlock(i)
    let iType = getInventoryItemType(blk?.type)
    if (iType == itemType.UNKNOWN)
    {
      ::dagor.debug("Error: unknown item type in items blk = " + (blk?.type ?? "NULL"))
      continue
    }
    let item = createItem(iType, blk)
    itemsListInternal.append(item)
  }

  ::ItemsManager.fillFakeItemsList()
  if (fakeItemsList)
    for (local i = 0; i < fakeItemsList.blockCount(); i++)
    {
      let blk = fakeItemsList.getBlock(i)
      let item = createItem(blk?.type, blk)
      itemsListInternal.append(item)
    }

  dbgLoadedItemsInternalCount = itemsListInternal.len()

  itemsListInternal.extend(smokeItems.value)

  return true
}

::ItemsManager.checkItemDefsUpdate <- function checkItemDefsUpdate()
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
      let defType = itemDefDesc?.type

      if (::isInArray(defType, [ "playtimegenerator", "generator", "bundle", "delayedexchange" ])
        || !::u.isEmpty(itemDefDesc?.exchange) || itemDefDesc?.tags?.hasAdditionalRecipes)
          ItemGenerators.add(itemDefDesc)

      if (!::isInArray(defType, [ "item", "delayedexchange" ]))
        continue
      let iType = getInventoryItemType(itemDefDesc?.tags?.type ?? "")
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

::ItemsManager.onEventEntitlementsUpdatedFromOnlineShop <- function onEventEntitlementsUpdatedFromOnlineShop(params)
{
  let curLevel = ::get_cyber_cafe_level()
  if (genericItemsForCyberCafeLevel != curLevel)
  {
    markItemsListUpdate()
    markInventoryUpdate()
  }
}

::ItemsManager.initItemsClasses <- function initItemsClasses()
{
  foreach(name, itemClass in ::items_classes)
  {
    let iType = itemClass.iType
    if (stdMath.number_of_set_bits(iType) != 1)
      ::dagor.assertf(false, "Incorrect item class iType " + iType + " must be a power of 2")
    if (iType in itemTypeClasses)
      ::dagor.assertf(false, "duplicate iType in item classes " + iType)
    else
      itemTypeClasses[iType] <- itemClass
  }
}
::ItemsManager.initItemsClasses() //init classes right after scripts load.

::ItemsManager.createItem <- function createItem(itemType, blk, inventoryBlk = null, slotData = null)
{
  let iClass = (itemType in itemTypeClasses)? itemTypeClasses[itemType] : ::BaseItem
  return iClass(blk, inventoryBlk, slotData)
}

::ItemsManager.getItemClass <- function getItemClass(itemType)
{
  return (itemType in itemTypeClasses)? itemTypeClasses[itemType] : ::BaseItem
}

::ItemsManager.getItemsList <- function getItemsList(typeMask = itemType.ALL, filterFunc = null)
{
  _checkUpdateList()
  return _getItemsFromList(itemsList, typeMask, filterFunc)
}

::ItemsManager.getShopList <- function getShopList(typeMask = itemType.INVENTORY_ALL, filterFunc = null)
{
  _checkUpdateList()
  return _getItemsFromList(itemsList, typeMask, filterFunc, "shopFilterMask")
}

::ItemsManager.isItemVisible <- function isItemVisible(item, shopTab)
{
  return shopTab == itemsTab.SHOP ? item.isCanBuy() && (!item.isDevItem || ::has_feature("devItemShop"))
      && !item.isHiddenItem() && !item.isVisibleInWorkshopOnly() && !item.isHideInShop
    : shopTab == itemsTab.INVENTORY ? !item.isHiddenItem() && !item.isVisibleInWorkshopOnly()
    : false
}

::ItemsManager.getShopVisibleSeenIds <- function getShopVisibleSeenIds()
{
  if (!shopVisibleSeenIds)
    shopVisibleSeenIds = getShopList(checkItemsMaskFeatures(itemType.INVENTORY_ALL),
      @(it) ::ItemsManager.isItemVisible(it, itemsTab.SHOP)).map(@(it) it.getSeenId())
  return shopVisibleSeenIds
}

::ItemsManager.findItemById <- function findItemById(id, typeMask = itemType.ALL)
{
  _checkUpdateList()
  let item = shopItemById?[id] ?? itemsByItemdefId?[id]
  if (!item && isItemdefId(id))
    requestItemsByItemdefIds([id])
  return item
}

::ItemsManager.isItemdefId <- function isItemdefId(id)
{
  return typeof id == "integer"
}

::ItemsManager.requestItemsByItemdefIds <- function requestItemsByItemdefIds(itemdefIdsList)
{
  inventoryClient.requestItemdefsByIds(itemdefIdsList)
}

::ItemsManager.getItemOrRecipeBundleById <- function getItemOrRecipeBundleById(id)
{
  local item = findItemById(id)
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

::ItemsManager.markItemsListUpdate <- function markItemsListUpdate()
{
  _reqUpdateList = true
  shopVisibleSeenIds = null
  seenItems.setDaysToUnseen(OUT_OF_DATE_DAYS_ITEMS_SHOP)
  seenItems.onListChanged()
  ::broadcastEvent("ItemsShopUpdate")
  itemsShopListVersion(itemsShopListVersion.value + 1)
}

::ItemsManager.smokeItems.subscribe(@(p) ::ItemsManager.markItemsListUpdate())

::ItemsManager.markItemsDefsListUpdate <- function markItemsDefsListUpdate()
{
  _reqUpdateItemDefsList = true
  shopVisibleSeenIds = null
  seenItems.onListChanged()
  ::broadcastEvent("ItemsShopUpdate")
  itemsShopListVersion(itemsShopListVersion.value + 1)
}

local lastItemDefsUpdatedelayedCall = 0
::ItemsManager.markItemsDefsListUpdateDelayed <- function markItemsDefsListUpdateDelayed()
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

::ItemsManager.onEventItemDefChanged <- function onEventItemDefChanged(p)
{
  markItemsDefsListUpdateDelayed()
}

::ItemsManager.onEventExtPricesChanged <- @(p) markItemsDefsListUpdateDelayed()


/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------INVENTORY ITEMS-----------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////
::ItemsManager.getInventoryItemType <- function getInventoryItemType(blkType)
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
      case "warpoints":           return itemType.WARPOINTS
      case "unlock":              return itemType.UNLOCK
      case "battlePass":          return itemType.BATTLE_PASS
      case "rented_unit":         return itemType.RENTED_UNIT
      case "unit_coupon_mod":     return itemType.UNIT_COUPON_MOD
      case "profile_icon":        return itemType.PROFILE_ICON
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

::ItemsManager._checkInventoryUpdate <- function _checkInventoryUpdate()
{
  if (!_needInventoryUpdate)
    return
  _needInventoryUpdate = false

  inventory = []

  let itemsBlk = ::get_items_blk()

  let itemsCache = ::get_items_cache()
  foreach(slot in itemsCache)
  {
    if (!slot.uids.len())
      continue

    let invItemBlk = ::DataBlock()
    ::get_item_data_by_uid(invItemBlk, slot.uids[0])
    if (::getTblValue("expiredTime", invItemBlk, 0) < 0)
      continue

    let iType = getInventoryItemType(invItemBlk?.type)
    if (iType == itemType.UNKNOWN)
    {
      //debugTableData(invItemBlk)
      //::dagor.assertf(false, "Inventory: unknown item type = " + invItemBlk?.type)
      continue
    }

    let blk = itemsBlk?[slot.id]
    if (!blk)
    {
      if (::is_dev_version)
        dagor.debug("Error: found removed item: " + slot.id)
      continue //skip removed items
    }

    let item = createItem(iType, blk, invItemBlk, slot)
    inventory.append(item)
    if (item.shouldAutoConsume && !item.isActive())
      setShouldCheckAutoConsume(true)
  }

  ::ItemsManager.fillFakeItemsList()
  if (fakeItemsList && ::get_cyber_cafe_level())
  {
    let id = "FakeBoosterForNetCafeLevel"
    let blk = fakeItemsList.getBlockByName(id)
    if (blk)
    {
      let item = createItem(blk?.type, blk, ::DataBlock(), {uids = [::FAKE_ITEM_CYBER_CAFE_BOOSTER_UID]})
      inventory.append(item)
    }
  }

  //gather transfer items list
  let transferAmounts = {}
  foreach(data in itemTransfer.getSendingList())
    transferAmounts[data.itemDefId] <- (transferAmounts?[data.itemDefId] ?? 0) + 1

  // Collecting external inventory items
  rawInventoryItemAmountsByItemdefId = {}
  let extInventoryItems = []
  foreach (itemDesc in inventoryClient.getItems())
  {
    let itemDefDesc = itemDesc.itemdef
    let itemDefId = itemDesc.itemdefid
    if (itemDefId in rawInventoryItemAmountsByItemdefId)
      rawInventoryItemAmountsByItemdefId[itemDefId] += itemDesc.quantity
    else
      rawInventoryItemAmountsByItemdefId[itemDefId] <- itemDesc.quantity

    if (!itemDefDesc.len()) //item not full updated, or itemDesc no more exist.
      continue
    let iType = getInventoryItemType(itemDefDesc?.tags?.type ?? "")
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
      let item = createItem(iType, itemDefDesc, itemDesc)
      if (item.id in transferAmounts)
        item.transferAmount += delete transferAmounts[item.id]
      if (item.shouldAutoConsume)
        setShouldCheckAutoConsume(true)
      extInventoryItems.append(item)
    }
  }

  //add items in transfer
  let itemdefsToRequest = []
  foreach(itemdefid, amount in transferAmounts)
  {
    let itemdef = inventoryClient.getItemdefs()?[itemdefid]
    if (!itemdef)
    {
      itemdefsToRequest.append(itemdefid)
      continue
    }
    let iType = getInventoryItemType(itemdef?.tags?.type ?? "")
    if (iType == itemType.UNKNOWN)
    {
      if (::isInArray(itemdef?.type, [ "item", "delayedexchange" ]))
        ::dagor.logerr("Inventory: Transfer: Unknown itemdef.tags.type in item " + itemdefid)
      continue
    }
    let item = createItem(iType, itemdef, {})
    item.transferAmount += amount
    extInventoryItems.append(item)
  }

  if (itemdefsToRequest.len())
    inventoryClient.requestItemdefsByIds(itemdefsToRequest)

  inventory.extend(extInventoryItems)
  extInventoryUpdateTime = ::dagor.getCurTime()
}

::ItemsManager.getInventoryList <- function getInventoryList(typeMask = itemType.ALL, filterFunc = null)
{
  _checkInventoryUpdate()
  checkAutoConsume()
  return _getItemsFromList(inventory, typeMask, filterFunc)
}

::ItemsManager.getInventoryListByShopMask <- function getInventoryListByShopMask(typeMask, filterFunc = null)
{
  _checkInventoryUpdate()
  checkAutoConsume()
  return _getItemsFromList(inventory, typeMask, filterFunc, "shopFilterMask")
}

::ItemsManager.getInventoryVisibleSeenIds <- function getInventoryVisibleSeenIds()
{
  if (!inventoryVisibleSeenIds)
  {
    let itemsList = getInventoryListByShopMask(checkItemsMaskFeatures(itemType.INVENTORY_ALL))
    inventoryVisibleSeenIds = itemsList.filter(
      @(it) ::ItemsManager.isItemVisible(it, itemsTab.INVENTORY)).map(@(it) it.getSeenId())
  }

  return inventoryVisibleSeenIds
}

::ItemsManager.getInventoryItemById <- @(id) ::u.search(getInventoryList(), @(item) item.id == id)

::ItemsManager.getInventoryItemByCraftedFrom <- @(uid) ::u.search(getInventoryList(),
  @(item) item.isCraftResult() && item.craftedFrom == uid)

::ItemsManager.markInventoryUpdate <- function markInventoryUpdate()
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
  inventoryListVersion(inventoryListVersion.value + 1)
}

local lastInventoryUpdateDelayedCall = 0
::ItemsManager.markInventoryUpdateDelayed <- function markInventoryUpdateDelayed()
{
  if (_needInventoryUpdate)
    return
  if (lastInventoryUpdateDelayedCall
      && lastInventoryUpdateDelayedCall < ::dagor.getCurTime() + LOST_DELAYED_ACTION_MSEC)
    return

  lastInventoryUpdateDelayedCall = ::dagor.getCurTime()
  ::g_delayed_actions.add(function() {
    if (!::g_login.isProfileReceived())
      return
    lastInventoryUpdateDelayedCall = 0
    markInventoryUpdate()
  }.bindenv(this), 200)
}

::ItemsManager.onItemsLoaded <- function onItemsLoaded()
{
  isInventoryInternalUpdated = true
  markInventoryUpdate()
}

::ItemsManager.onEventLoginComplete <- function onEventLoginComplete(p) {
  setShouldCheckAutoConsume(true)
  _reqUpdateList = true
}

::ItemsManager.onEventSignOut <- function onEventSignOut(p)
{
  isInventoryFullUpdated = false
  isInventoryInternalUpdated = false
}


/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------ITEM UTILS----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

::ItemsManager.checkItemsMaskFeatures <- function checkItemsMaskFeatures(itemsMask) //return itemss mask only of available features
{
  foreach(iType, feature in itemTypeFeatures)
    if ((itemsMask & iType) && !::has_feature(feature))
      itemsMask -= iType
  return itemsMask
}

::ItemsManager._getItemsFromList <- function _getItemsFromList(list, typeMask, filterFunc = null, itemMaskProperty = "iType")
{
  if (typeMask == itemType.ALL && !filterFunc)
    return list

  let res = []
  foreach(item in list)
    if (((item?[itemMaskProperty] ?? item.iType) & typeMask)
        && (!filterFunc || filterFunc(item)))
      res.append(item)
  return res
}

//just update gamercards atm.
::ItemsManager.registerBoosterUpdateTimer <- function registerBoosterUpdateTimer(boostersList)
{
  if (!::is_in_flight())
    return

  let curFlightTime = ::get_usefull_total_time()
  local nextExpireTime = -1
  foreach(booster in boostersList)
  {
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
  refreshBoostersTask = ::periodic_task_register_ex(this,
                                                    _onBoosterExpiredInFlight,
                                                    boostersTaskUpdateFlightTime - curFlightTime,
                                                    ::EPTF_IN_FLIGHT,
                                                    ::EPTT_BEST_EFFORT,
                                                    false //flight time
                                                   )
}

::ItemsManager._onBoosterExpiredInFlight <- function _onBoosterExpiredInFlight(dt = 0)
{
  removeRefreshBoostersTask()
  if (::is_in_flight())
    ::update_gamercards()
}

::ItemsManager.removeRefreshBoostersTask <- function removeRefreshBoostersTask()
{
  if (refreshBoostersTask >= 0)
    ::periodic_task_unregister(refreshBoostersTask)
  refreshBoostersTask = -1
}

::ItemsManager.refreshExtInventory <- function refreshExtInventory()
{
  inventoryClient.refreshItems()
}

::ItemsManager.onEventExtInventoryChanged    <- @(p) markInventoryUpdateDelayed()
::ItemsManager.onEventSendingItemsChanged    <- @(p) markInventoryUpdateDelayed()

::ItemsManager.onEventLoadingStateChange <- function onEventLoadingStateChange(p)
{
  if (!::is_in_flight())
    removeRefreshBoostersTask()
}

::ItemsManager.onEventGameLocalizationChanged <- function onEventGameLocalizationChanged(p)
{
  inventoryClient.forceRefreshItemDefs((@() itemsByItemdefId = {}).bindenv(this))
}

::ItemsManager.findItemByUid <- function findItemByUid(uid, filterType = itemType.ALL)
{
  let itemsArray = ::ItemsManager.getInventoryList(filterType)
  let res = u.search(itemsArray, @(item) ::isInArray(uid, item.uids) )
  return res
}

::ItemsManager.collectUserlogItemdefs <- function collectUserlogItemdefs()
{
  for(local i = 0; i < ::get_user_logs_count(); i++)
  {
    let blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    let itemDefId = blk?.body?.itemDefId
    if (itemDefId)
      ::ItemsManager.findItemById(itemDefId) // Requests itemdef, if it is not found.
  }
}

::ItemsManager.isEnabled <- function isEnabled()
{
  let checkNewbie = !::my_stats.isMeNewbie()
    || seenInventory.hasSeen()
    || inventory.len() > 0
  return ::has_feature("Items") && checkNewbie
}

::ItemsManager.getItemsSortComparator <- function getItemsSortComparator(itemsSeenList = null)
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

::ItemsManager.getRawInventoryItemAmount <- function getRawInventoryItemAmount(itemdefid)
{
  return rawInventoryItemAmountsByItemdefId?[itemdefid] ?? 0
}

::subscribe_handler(::ItemsManager, ::g_listener_priority.DEFAULT_HANDLER)


/////////////////////////////////////////////////////////////////////////////////////////////
//-----------------------------  PROMO ACTIONS---------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

let function consumeItemFromPromo(handler, params) {
  let itemId = params?[0]
  if (itemId == null)
    return
  let item = ::ItemsManager.getInventoryItemById(::to_integer_safe(itemId, itemId, false))
  if (!(item?.canConsume() ?? false))
    return

  item?.consume(@(...) null, { needConsumeImpl = params?[1] == "needConsumeImpl" })
  handler.goBack()
}

let function canConsumeItemFromPromo(params) {
  let itemId = params?[0]
  if (itemId == null)
    return false
  let item = ::ItemsManager.getInventoryItemById(::to_integer_safe(itemId, itemId, false))
  return item?.canConsume() ?? false
}

addPromoAction("consume_item", @(handler, params, obj) consumeItemFromPromo(handler, params),
  @(params) canConsumeItemFromPromo(params))

/////////////////////////////////////////////////////////////////////////////////////////////
//--------------------------------SEEN ITEMS-----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

seenItems.setListGetter(@() ::ItemsManager.getShopVisibleSeenIds())
seenInventory.setListGetter(@() ::ItemsManager.getInventoryVisibleSeenIds())

let makeSeenCompatibility = @(savePath) function()
  {
    let res = {}
    let blk = ::loadLocalByAccount(savePath)
    if (!::u.isDataBlock(blk))
      return res

    for (local i = 0; i < blk.paramCount(); i++)
      res[blk.getParamName(i)] <- blk.getParamValue(i)
    ::saveLocalByAccount(savePath, null)
    return res
  }

seenItems.setCompatibilityLoadData(makeSeenCompatibility("seen_shop_items"))
seenInventory.setCompatibilityLoadData(makeSeenCompatibility("seen_inventory_items"))

return {
  itemsShopListVersion
  inventoryListVersion
}
