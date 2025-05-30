from "%scripts/dagui_natives.nut" import get_item_data_by_uid, get_items_blk, get_items_cache, get_cyber_cafe_level
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *

let { itemType } = require("%scripts/items/itemsConsts.nut")
let { get_cyber_cafe_max_level } = require("%appGlobals/ranks_common_shared.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { get_time_msec } = require("dagor.time")
let { floor } = require("math")
let DataBlock  = require("DataBlock")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { fillBlock } = require("%sqstd/datablock.nut")
let { addItemGenerator } = require("%scripts/items/itemGeneratorsManager.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let itemTransfer = require("%scripts/items/itemsTransfer.nut")
let { setShouldCheckAutoConsume } = require("%scripts/items/autoConsumeItems.nut")
let { PRICE } = require("%scripts/utils/configs.nut")
let { get_price_blk } = require("blkGetters")
let { boosterEffectType } = require("%scripts/items/boosterEffectTypes.nut")
let { itemsListInternal,
  itemsList, inventory, inventoryItemById, shopItemById, itemsListExternal, itemsByItemdefId,
  rawInventoryItemAmountsByItemdefId, getInventoryItemType, setExtInventoryUpdateTime
} = require("%scripts/items/itemsManagerState.nut")
let { dbgTrophiesListInternal, incDbgUpdateInternalItemsCount
} = require("%scripts/items/itemsManagerDbgState.nut")
let { shopSmokeItems, createItem } = require("%scripts/items/itemsTypeClasses.nut")
let { getCyberCafeBonusByEffectType, getSquadBonusForSameCyberCafe } = require("%scripts/items/bonusEffectsGetters.nut")

const FAKE_ITEM_CYBER_CAFE_BOOSTER_UID = -1

local fakeItemsList = null
local genericItemsForCyberCafeLevel = -1

local ignoreItemLimits = false

local reqUpdateList = true
local reqUpdateItemDefsList = true
local needInventoryUpdate = true

function fillFakeItemsList() {
  let curLevel = get_cyber_cafe_level()
  if (curLevel == genericItemsForCyberCafeLevel)
    return

  genericItemsForCyberCafeLevel = curLevel
  fakeItemsList = DataBlock()

  for (local i = 0; i <= get_cyber_cafe_max_level(); ++i) {
    let level = i || curLevel 
    let table = {
      type = itemType.FAKE_BOOSTER
      iconStyle = "cybercafebonus"
      locId = "item/FakeBoosterForNetCafeLevel"
      rateBoosterParams = {
        xpRate = floor(100.0 * getCyberCafeBonusByEffectType(boosterEffectType.RP, level) + 0.5)
        wpRate = floor(100.0 * getCyberCafeBonusByEffectType(boosterEffectType.WP, level) + 0.5)
      }
    }
    fillBlock($"FakeBoosterForNetCafeLevel{i || ""}", fakeItemsList, table)
  }

  for (local i = 2; i <= g_squad_manager.getMaxSquadSize(); ++i) {
    let table = {
      type = itemType.FAKE_BOOSTER
      rateBoosterParams = {
        xpRate = floor(100.0 * getSquadBonusForSameCyberCafe(boosterEffectType.RP, i) + 0.5)
        wpRate = floor(100.0 * getSquadBonusForSameCyberCafe(boosterEffectType.WP, i) + 0.5)
      }
    }
    fillBlock($"FakeBoosterForSquadFromSameCafe{i}", fakeItemsList, table)
  }

  let trophyFromInventory = {
    type = itemType.TROPHY
    locId = "inventory/consumeItem"
    iconStyle = "gold_iron_box"
  }
  fillBlock("trophyFromInventory", fakeItemsList, trophyFromInventory)
}

function checkItemDefsUpdate() {
  if (!reqUpdateItemDefsList)
    return false
  reqUpdateItemDefsList = false

  itemsListExternal.clear()
  
  foreach (itemDefDesc in inventoryClient.getItemdefs()) {
    local item = itemsByItemdefId?[itemDefDesc?.itemdefid]
    if (!item) {
      let defType = itemDefDesc?.type

      if (isInArray(defType, ["playtimegenerator", "generator", "bundle", "delayedexchange"])
          || !isEmpty(itemDefDesc?.exchange) || itemDefDesc?.tags.hasAdditionalRecipes)
        addItemGenerator(itemDefDesc)

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
  incDbgUpdateInternalItemsCount()

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
    
    if ((invItemBlk?.expiredTime ?? 0) < 0)
      continue

    let iType = getInventoryItemType(invItemBlk?.type)
    if (iType == itemType.UNKNOWN)
      continue

    let blk = itemsBlk?[slot.id]
    if (!blk) {
      if (is_dev_version())
        log($"Error: found removed item: {slot.id}")
      continue 
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

  
  let transferAmounts = {}
  foreach (data in itemTransfer.getSendingList())
    transferAmounts[data.itemDefId] <- (transferAmounts?[data.itemDefId] ?? 0) + 1

  
  rawInventoryItemAmountsByItemdefId.clear()
  let extInventoryItems = []
  foreach (itemDesc in inventoryClient.getItems()) {
    let itemDefDesc = itemDesc.itemdef
    let itemDefId = itemDesc.itemdefid
    if (itemDefId in rawInventoryItemAmountsByItemdefId)
      rawInventoryItemAmountsByItemdefId[itemDefId] += itemDesc.quantity
    else
      rawInventoryItemAmountsByItemdefId[itemDefId] <- itemDesc.quantity

    if (!itemDefDesc.len()) 
      continue

    let iType = getInventoryItemType(itemDefDesc?.tags.type ?? "")
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

  
  let itemdefsToRequest = []
  foreach (itemdefid, amount in transferAmounts) {
    let itemdef = inventoryClient.getItemdefs()?[itemdefid]
    if (!itemdef) {
      itemdefsToRequest.append(itemdefid)
      continue
    }
    let iType = getInventoryItemType(itemdef?.tags.type ?? "")
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
  setExtInventoryUpdateTime(get_time_msec())
}

function needIgnoreItemLimits() {
  return ignoreItemLimits
}

return {
  setReqUpdateList = @(v) reqUpdateList = v
  getReqUpdateItemDefsList = @() reqUpdateItemDefsList
  setReqUpdateItemDefsList = @(v) reqUpdateItemDefsList = v
  getNeedInventoryUpdate = @() needInventoryUpdate
  setNeedInventoryUpdate = @(v) needInventoryUpdate = v

  genericItemsForCyberCafeLevel
  checkUpdateList
  checkInventoryUpdate
  needIgnoreItemLimits
}