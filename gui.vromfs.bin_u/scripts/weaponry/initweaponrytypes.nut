from "%scripts/dagui_natives.nut" import wp_get_cost_gold2, wp_get_cost2, get_spare_aircrafts_count, wp_get_modification_cost, wp_get_weapon_max_count, wp_get_modification_open_cost_gold, shop_is_weapon_purchased, shop_get_spawn_score, wp_get_spare_cost_gold, wp_get_spare_cost, wp_get_modification_max_count, wp_get_modification_cost_gold
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem, MAX_SPARE_AMOUNT

let { Cost } = require("%scripts/money.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { getWeaponNameText } = require("%scripts/weaponry/weaponryDescription.nut")
let { getModificationName, getUnitLastBullets, getBulletGroupIndex, getWeaponBlkNameByGroupIdx } = require("%scripts/weaponry/bulletsInfo.nut")
let { getByCurBundle } = require("%scripts/weaponry/itemInfo.nut")
let { canBuyMod } = require("%scripts/weaponry/modificationInfo.nut")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { shopIsModificationPurchased } = require("chardResearch")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { isUnitUsable } = require("%scripts/unit/unitStatus.nut")
let { addEnumWeaponryTypes, getUpgradeTypeByItem } = require("%scripts/weaponry/weaponryTypes.nut")

function getUnlockCostImpl(unit, item) {
  if (item.name == "")
    return Cost()
  return Cost(0, wp_get_modification_open_cost_gold(unit.name, item.name))
}

function getCostImpl(unit, item) {
  if (item.name == "")
    return Cost()
  return Cost(
    wp_get_modification_cost(unit.name, item.name),
    wp_get_modification_cost_gold(unit.name, item.name)
  )
}

function getAmountImpl(unit, item) {
  if (("isDefaultForGroup" in item) && item.isDefaultForGroup >= 0)
    return 1
  return shopIsModificationPurchased(unit.name, item.name)
}

addEnumWeaponryTypes({
  UNKNOWN = {}


  WEAPON = {
    type = weaponsItem.weapon
    getLocName = @ (unit, item, _limitedName = false) getWeaponNameText(unit, false, item.name, ",  ")
    getHeader = @(unit) (unit.isAir() || unit.isHelicopter()) ? loc("options/secondary_weapons")
      



      : loc("options/additional_weapons")
    getCost = function(unit, item) {
      return Cost(
        wp_get_cost2(unit.name, item.name),
        wp_get_cost_gold2(unit.name, item.name)
      )
    }
    getAmount = function(unit, item) { return shop_is_weapon_purchased(unit.name, item.name) }
    getMaxAmount = function(unit, item) { return wp_get_weapon_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return isUnitUsable(unit) && this.getAmount(unit, item) < this.getMaxAmount(unit, item) }

    getScoreCostText = function(unit, item, needToShowFullCost) {
      let lastBullets = getUnitLastBullets(unit)
      let fullCost = shop_get_spawn_score(unit.name, item.name, lastBullets, true, true)
      if (!fullCost)
        return ""

      local cost = fullCost
      if (!needToShowFullCost) {
        let emptyCost = shop_get_spawn_score(unit.name, item.name, lastBullets, false, true)
        cost = fullCost - emptyCost
        if (!cost)
          return ""
      }

      if (getCurMissionRules().getCurSpawnScore() < fullCost)
        cost = colorize("badTextColor", cost)
      cost = loc("shop/spawnScore", { cost = cost })
      return needToShowFullCost ? loc("ui/sum", { text = cost }) : cost
    }
  }


  BULLETS = {
    type = weaponsItem.bullets
    getLocName = @(unit, item, limitedName = false) getModificationName(unit, item.name, limitedName)
    getCost = getCostImpl
    getAmount = getAmountImpl
    getMaxAmount = function(unit, item) { return wp_get_modification_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return isUnitUsable(unit) && canBuyMod(unit, item) }
  }


  MODIFICATION = {
   type = weaponsItem.modification
    getLocName = @(unit, item, limitedName = false) getModificationName(unit, item.name, limitedName)
    getUnlockCost = getUnlockCostImpl
    getCost = getCostImpl
    getAmount = @(unit, item) this.getUnlockCost(unit, item).isZero()
        && this.getCost(unit, item).isZero()
        && (item?.reqExp ?? 0) == 0
        && item?.reqModification == null
      ? 1
      : getAmountImpl(unit, item)
    getMaxAmount = function(unit, item) { return wp_get_modification_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return isUnitUsable(unit) && canBuyMod(unit, item) }

    getScoreCostText = function(unit, item, needToShowFullCost) {
      let bulletsForCalculation = clone getUnitLastBullets(unit)

      let groupIndex = getBulletGroupIndex(unit.name, item.name)
      let weaponName = getWeaponBlkNameByGroupIdx(unit, groupIndex)

      let weaponInSetIndex = bulletsForCalculation.map(@(v) v.weapon).indexof(weaponName)
      if (weaponInSetIndex != null)
        bulletsForCalculation.remove(weaponInSetIndex)
      bulletsForCalculation.append({name = item.name, weapon = weaponName})

      let fullCost = shop_get_spawn_score(unit.name, getLastWeapon(unit.name), bulletsForCalculation, true, true)
      if (!fullCost)
        return ""

      local cost = fullCost
      if (!needToShowFullCost) {
        let curIndex = bulletsForCalculation.map(@(v) v.weapon).indexof(weaponName)
        if (curIndex != null)
          bulletsForCalculation.remove(curIndex)
        let withoutCurrentCost = shop_get_spawn_score(unit.name, getLastWeapon(unit.name), bulletsForCalculation, true, true)
        cost = fullCost - withoutCurrentCost
        if (cost <= 0)
          return ""
      }
      if (getCurMissionRules().getCurSpawnScore() < fullCost)
        cost = colorize("badTextColor", cost)
      cost = loc("shop/spawnScore", { cost = cost })
      return needToShowFullCost ? loc("ui/sum", { text = cost }) : cost
    }
  }


  EXPENDABLES = {
    type = weaponsItem.expendables
    getLocName = @(unit, item, limitedName = false) getModificationName(unit, item.name, limitedName)
    getUnlockCost = getUnlockCostImpl
    getCost = getCostImpl
    getAmount = getAmountImpl
    getMaxAmount = function(unit, item) { return wp_get_modification_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return isUnitUsable(unit) && canBuyMod(unit, item) }
  }


  SPARE = {
    type = weaponsItem.spare
    getLocName = function(_unit, item, ...) { return loc($"spare/{item.name}") }
    getCost = function(unit, ...) { return Cost(
      wp_get_spare_cost(unit.name),
      wp_get_spare_cost_gold(unit.name)
    ) }
    getAmount = function(unit, ...) { return get_spare_aircrafts_count(unit.name) }
    getMaxAmount = function(...) { return MAX_SPARE_AMOUNT }
    canBuy = function(unit, item) { return isUnitUsable(unit) && this.getAmount(unit, item) < this.getMaxAmount(unit, item) }
  }




  PRIMARYWEAPON = {
    type = weaponsItem.primaryWeapon
    getLocName = function(unit, item, _limitedName = false) { return getWeaponNameText(unit, true, item.name, " ") }
    getCost = getCostImpl
    getAmount = function(unit, item) { return isEmpty(item.name) ? 1 : shopIsModificationPurchased(unit.name, item.name) }
    getMaxAmount = function(unit, item) { return wp_get_modification_max_count(unit.name, item.name) }
    canBuy = function(unit, item) { return isUnitUsable(unit) && canBuyMod(unit, item) }
  }


  BUNDLE = {
    type = weaponsItem.bundle
    getLocName = function(unit, item, limitedName = false) {
      return getByCurBundle(unit, item,  function(unit_, curItem) {
        return getUpgradeTypeByItem(curItem).getLocName(unit_, curItem, limitedName)
      })
    }
    getUnlockCost = function(unit, item) {
      return getByCurBundle(unit, item, function(unit_, curItem) {
        return getUpgradeTypeByItem(curItem).getUnlockCost(unit_, curItem)
      })
    }
    getCost = function(unit, item) {
      return getByCurBundle(unit, item, function(unit_, curItem) {
        return getUpgradeTypeByItem(curItem).getCost(unit_, curItem)
      })
    }
  }


  NEXTUNIT = {
    type = weaponsItem.nextUnit
    getLocName = function(_unit, item, ...) { return loc($"elite/{item.name}") }
  }

  














})
