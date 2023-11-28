from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let inventoryItemTypeByTag = {
  skin                = itemType.SKIN
  decal               = itemType.DECAL
  attachable          = itemType.ATTACHABLE
  key                 = itemType.KEY
  chest               = itemType.CHEST
  aircraft            = itemType.VEHICLE
  tank                = itemType.VEHICLE
  helicopter          = itemType.VEHICLE
  ship                = itemType.VEHICLE
  warbonds            = itemType.WARBONDS
  craft_part          = itemType.CRAFT_PART
  craft_process       = itemType.CRAFT_PROCESS
  internal_item       = itemType.INTERNAL_ITEM
  entitlement         = itemType.ENTITLEMENT
  warpoints           = itemType.WARPOINTS
  unlock              = itemType.UNLOCK
  battlePass          = itemType.BATTLE_PASS
  rented_unit         = itemType.RENTED_UNIT
  unit_coupon_mod     = itemType.UNIT_COUPON_MOD
  profile_icon        = itemType.PROFILE_ICON
}

return inventoryItemTypeByTag