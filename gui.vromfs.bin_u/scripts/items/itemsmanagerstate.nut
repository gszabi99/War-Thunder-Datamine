from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import item_get_type_id_by_type_name

let { itemType } = require("%scripts/items/itemsConsts.nut")
let inventoryItemTypeByTag = require("%scripts/items/inventoryItemTypeByTag.nut")

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


let itemsShopListVersion = Watched(0)
let inventoryListVersion = Watched(0)

let itemsList = []
let inventory = []
let inventoryItemById = {}
let shopItemById = {}
let itemsListExternal = []
let itemsByItemdefId = {}
let rawInventoryItemAmountsByItemdefId = {}
let itemsListInternal = []

let shopVisibleSeenIds = Watched(null)

local extInventoryUpdateTime = 0

function getInventoryItemType(blkType) {
  if (type(blkType) == "string") {
    if (blkType in inventoryItemTypeByTag)
      return inventoryItemTypeByTag[blkType]

    blkType = item_get_type_id_by_type_name(blkType)
  }
  return itemTypeByBlkType?[blkType] ?? itemType.UNKNOWN
}

function getExtInventoryUpdateTime() {
  return extInventoryUpdateTime
}

return {
  itemsListInternal
  itemsShopListVersion
  inventoryListVersion
  itemsList
  inventory
  inventoryItemById
  shopItemById
  itemsListExternal
  itemsByItemdefId
  rawInventoryItemAmountsByItemdefId
  shopVisibleSeenIds
  setExtInventoryUpdateTime = @(val) extInventoryUpdateTime = val
  getInventoryItemType
  getExtInventoryUpdateTime
}