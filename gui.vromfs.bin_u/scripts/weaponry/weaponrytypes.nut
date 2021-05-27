local enums = require("sqStdLibs/helpers/enums.nut")
local { getWeaponNameText } = require("scripts/weaponry/weaponryDescription.nut")
local { getModificationName } = require("scripts/weaponry/bulletsVisual.nut")
local { getBulletsSetData } = require("scripts/weaponry/bulletsInfo.nut")
local { getByCurBundle } = require("scripts/weaponry/itemInfo.nut")
local { canBuyMod } = require("scripts/weaponry/modificationInfo.nut")
local { getLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")

::g_weaponry_types <- {
  types = []
  cache = {
    byType = {}
  }

  template = {
    type = weaponsItem.unknown
    isSpendable = false
    isPremium = false

    getLocName = function(unit, item, limitedName = false) { return "" }
    getHeader = @(unit) ""

    canBuy = function(unit, item) { return false }
    getAmount = function(unit, item) { return 0 }
    getMaxAmount = function(unit, item) { return 0 }

    getUnlockCost = function(unit, item) { return ::Cost() }
    getCost = function(unit, item) { return ::Cost() }
    getScoreCostText = function(unit, item) { return "" }

    purchase = function() {}
    canPurchase = function() { return false }
  }
}

g_weaponry_types._getUnlockCost <- function _getUnlockCost(unit, item)
{
  if (item.name == "")
    return ::Cost()
  return ::Cost(0, ::wp_get_modification_open_cost_gold(unit.name, item.name))
}

g_weaponry_types._getCost <- function _getCost(unit, item)
{
  if (item.name == "")
    return ::Cost()
  return ::Cost(
    ::wp_get_modification_cost(unit.name, item.name),
    ::wp_get_modification_cost_gold(unit.name, item.name)
  )
}

g_weaponry_types._getAmount <- function _getAmount(unit, item)
{
  if (("isDefaultForGroup" in item) && item.isDefaultForGroup >= 0)
    return 1
  return ::shop_is_modification_purchased(unit.name, item.name)
}

enums.addTypesByGlobalName("g_weaponry_types", {
  UNKNOWN = {}

//************************* WEAPON *********************************************
  WEAPON = {
    type = weaponsItem.weapon
    getLocName = @ (unit, item, limitedName = false) getWeaponNameText(unit, false, item.name, ",  ")
    getHeader = @(unit) (unit.isAir() || unit.isHelicopter()) ? ::loc("options/secondary_weapons")
       : ::loc("options/additional_weapons")
    getCost = function(unit, item) {
      return ::Cost(
        ::wp_get_cost2(unit.name, item.name),
        ::wp_get_cost_gold2(unit.name, item.name)
      )
    }
    getAmount = function(unit, item) { return ::shop_is_weapon_purchased(unit.name, item.name) }
    getMaxAmount = function(unit, item) { return ::wp_get_weapon_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return ::isUnitUsable(unit) && getAmount(unit, item) < getMaxAmount(unit, item) }

    getScoreCostText = function(unit, item)
    {
      local fullCost = ::shop_get_spawn_score(unit.name, item.name, [])
      if (!fullCost)
        return ""

      local emptyCost = ::shop_get_spawn_score(unit.name, "", [])
      local weapCost = fullCost - emptyCost
      if (!weapCost)
        return ""

      if (::g_mis_custom_state.getCurMissionRules().getCurSpawnScore() < fullCost)
        weapCost = ::colorize("badTextColor", weapCost)
      return ::loc("shop/spawnScore", { cost = weapCost })
    }
  }

//*********************** BULLETS **********************************************
  BULLETS = {
    type = weaponsItem.bullets
    getLocName = @(unit, item, limitedName = false)
      getModificationName(unit, item.name, getBulletsSetData(unit, item.name), limitedName)
    getCost = ::g_weaponry_types._getCost
    getAmount = ::g_weaponry_types._getAmount
    getMaxAmount = function(unit, item) { return ::wp_get_modification_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return ::isUnitUsable(unit) && canBuyMod(unit, item) }
  }

//********************* MODIFICATION *******************************************
  MODIFICATION = {
    type = weaponsItem.modification
    getLocName = @(unit, item, limitedName = false)
      getModificationName(unit, item.name, getBulletsSetData(unit, item.name), limitedName)
    getUnlockCost = ::g_weaponry_types._getUnlockCost
    getCost = ::g_weaponry_types._getCost
    getAmount = @(unit, item) getUnlockCost(unit, item).isZero()
        && getCost(unit, item).isZero()
        && (item?.reqExp ?? 0) == 0
      ? 1
      : ::g_weaponry_types._getAmount(unit, item)
    getMaxAmount = function(unit, item) { return ::wp_get_modification_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return ::isUnitUsable(unit) && canBuyMod(unit, item) }

    getScoreCostText = function(unit, item)
    {
      local fullCost = ::shop_get_spawn_score(unit.name, getLastWeapon(unit.name), [ item.name ] )
      if (!fullCost)
        return ""

      local emptyCost = ::shop_get_spawn_score(unit.name, getLastWeapon(unit.name), [])
      local bulletCost = fullCost - emptyCost
      if (!bulletCost)
        return ""

      if (::g_mis_custom_state.getCurMissionRules().getCurSpawnScore() < fullCost)
        bulletCost = ::colorize("badTextColor", bulletCost)
      return ::loc("shop/spawnScore", { cost = bulletCost })
    }
  }

//********************* EXPENDABLES *******************************************
  EXPENDABLES = {
    type = weaponsItem.expendables
    getLocName = @(unit, item, limitedName = false)
      getModificationName(unit, item.name, getBulletsSetData(unit, item.name), limitedName)
    getUnlockCost = ::g_weaponry_types._getUnlockCost
    getCost = ::g_weaponry_types._getCost
    getAmount = ::g_weaponry_types._getAmount
    getMaxAmount = function(unit, item) { return ::wp_get_modification_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return ::isUnitUsable(unit) && canBuyMod(unit, item) }
  }

//********************** SPARE *************************************************
  SPARE = {
    type = weaponsItem.spare
    getLocName = function(unit, item, ...) { return ::loc("spare/" + item.name) }
    getCost = function(unit, ...) { return ::Cost(
      ::wp_get_spare_cost(unit.name),
      ::wp_get_spare_cost_gold(unit.name)
    )}
    getAmount = function(unit, ...) { return ::get_spare_aircrafts_count(unit.name) }
    getMaxAmount = function(...) { return ::max_spare_amount }
    canBuy = function(unit, item) { return ::isUnitUsable(unit) && getAmount(unit, item) < getMaxAmount(unit, item) }
  }

//=============================== PSEUDO TYPES =================================

//*************** PRIMARY WEAPON ***********************************************
  PRIMARYWEAPON = {
    type = weaponsItem.primaryWeapon
    getLocName = function(unit, item, limitedName = false) { return getWeaponNameText(unit, true, item.name, " ") }
    getCost = ::g_weaponry_types._getCost
    getAmount = function(unit, item) { return ::u.isEmpty(item.name)? 1 : ::shop_is_modification_purchased(unit.name, item.name) }
    getMaxAmount = function(unit, item) { return ::wp_get_modification_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return ::isUnitUsable(unit) && canBuyMod(unit, item) }
  }

//****************** BUNDLE ****************************************************
  BUNDLE = {
    type = weaponsItem.bundle
    getLocName = function(unit, item, limitedName = false)
    {
      return getByCurBundle(unit, item, (@(limitedName) function(unit, curItem) {
        return ::g_weaponry_types.getUpgradeTypeByItem(curItem).getLocName(unit, curItem, limitedName)
      })(limitedName))
    }
    getUnlockCost = function(unit, item)
    {
      return getByCurBundle(unit, item, function(unit, curItem) {
        return ::g_weaponry_types.getUpgradeTypeByItem(curItem).getUnlockCost(unit, curItem)
      })
    }
    getCost = function(unit, item)
    {
      return getByCurBundle(unit, item, function(unit, curItem) {
        return ::g_weaponry_types.getUpgradeTypeByItem(curItem).getCost(unit, curItem)
      })
    }
  }

//********************** NEXT UNIT *********************************************
  NEXTUNIT = {
    type = weaponsItem.nextUnit
    getLocName = function(unit, item, ...) { return ::loc("elite/" + item.name) }
  }
}, null, "typeName")

/*::g_weaponry_types.types.sort(function(a,b)
{
  if (a.type != b.type)
    return a.type > b.type? 1 : -1
  return 0
})*/

g_weaponry_types.getUpgradeTypeByItem <- function getUpgradeTypeByItem(item)
{
  if (!("type" in item))
    return ::g_weaponry_types.UNKNOWN

  return enums.getCachedType("type", item.type, ::g_weaponry_types.cache.byType, ::g_weaponry_types, ::g_weaponry_types.UNKNOWN)
}
