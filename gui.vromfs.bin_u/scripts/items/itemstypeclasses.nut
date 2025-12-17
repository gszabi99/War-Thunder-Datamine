from "%scripts/dagui_library.nut" import *
let { number_of_set_bits } = require("%sqstd/math.nut")
let { buyableSmokesList } = require("%scripts/unlocks/unlockSmoke.nut")
let { itemType } = require("%scripts/items/itemsConsts.nut")

const BASE_ITEM_TYPE_ICON = "#ui/gameuiskin#item_type_placeholder.svg"

local baseItemClass = null
let isAddeditemTypeSmoke = Watched(false)

let itemTypeClasses = {}

function registerItemClass(itemClass) {
  let iType = itemClass.iType
  if (number_of_set_bits(iType) != 1)
    assert(false, $"Incorrect item class iType {iType} must be a power of 2")
  if (iType in itemTypeClasses) {
    assert(false, $"duplicate iType in item classes {iType}")
    return
  }

  itemTypeClasses[iType] <- itemClass
  if (iType == itemType.SMOKE)
    isAddeditemTypeSmoke.set(true)
}

function registerBaseItemClass(itemClass) {
  if (baseItemClass != null) {
    assert(false, "baseItemClass already register")
    return
  }
  baseItemClass = itemClass
}

let getItemClass = @(iType) itemTypeClasses?[iType] ?? baseItemClass

function createItem(item_type, blk, inventoryBlk = null, slotData = null) {
  let iClass = getItemClass(item_type)
  return iClass(blk, inventoryBlk, slotData)
}

let shopSmokeItems = Computed(@() !isAddeditemTypeSmoke.get() ? []
  : buyableSmokesList.get().map(@(blk) createItem(itemType.SMOKE, blk)))

return {
  BASE_ITEM_TYPE_ICON
  registerBaseItemClass
  registerItemClass
  getItemClass

  shopSmokeItems
  createItem
}