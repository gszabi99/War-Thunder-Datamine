from "%scripts/dagui_library.nut" import *

let { Attachable } = require("itemAttachable.nut")
let { BattlePass } = require("itemBattlePass.nut")
let { FakeBooster, Booster } = require("itemBooster.nut")
let { Chest } = require("itemChest.nut")
let { CraftPart } = require("itemCraftPart.nut")
let { CraftProcess } = require("itemCraftProcess.nut")
let { Decal } = require("itemDecal.nut")
let { Discount } = require("itemDiscount.nut")
let { Entitlement } = require("itemEntitlement.nut")
let { InternalItem } = require("itemInternalItem.nut")
let { Key } = require("itemKey.nut")
let { ModOverdrive } = require("itemModOverdrive.nut")
let { ModUpgrade } = require("itemModUpgrade.nut")
let { Order } = require("itemOrder.nut")
let { ProfileIcon } = require("itemProfileIcon.nut")
let { RecipesBundle } = require("itemRecipesBundle.nut")
let { RentedUnit } = require("itemRentedUnit.nut")
let { Skin } = require("itemSkin.nut")
let { Smoke } = require("itemSmoke.nut")
let { Ticket } = require("itemTicket.nut")
let { Trophy } = require("itemTrophy.nut")
let { ItemUnitCouponMod } = require("itemUnitCouponMod.nut")
let { UniversalSpare } = require("itemUniversalSpare.nut")
let { Unlock } = require("itemUnlock.nut")
let { ItemVehicle } = require("itemVehicle.nut")
let { Wager } = require("itemWager.nut")
let { Warbonds } = require("itemWarbonds.nut")
let { Warpoints } = require("itemWarpoints.nut")

let items_classes = freeze({
  Attachable
  BattlePass
  FakeBooster
  Booster
  Chest
  CraftPart
  CraftProcess
  Decal
  Discount
  Entitlement
  InternalItem
  Key
  ModOverdrive
  ModUpgrade
  Order
  ProfileIcon
  RecipesBundle
  RentedUnit
  Skin
  Smoke
  Ticket
  Trophy
  ItemUnitCouponMod
  UniversalSpare
  Unlock
  ItemVehicle
  Wager
  Warbonds
  Warpoints
})

return { items_classes }