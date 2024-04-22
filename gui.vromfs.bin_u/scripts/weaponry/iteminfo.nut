//-file:plus-string
from "%scripts/dagui_natives.nut" import wp_get_modification_cost, get_modification_level, shop_get_module_exp, wp_get_modification_max_count, shop_get_module_research_status
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem

let { getCurrentShopDifficulty } = require("%scripts/gameModes/gameModeManagerState.nut")
let { Cost } = require("%scripts/money.nut")

let { isBullets,
        getBulletGroupIndex } = require("%scripts/weaponry/bulletsInfo.nut")
let { AMMO,
        getAmmoAmount,
        getAmmoMaxAmount,
        getAmmoWarningMinimum } = require("%scripts/weaponry/ammoInfo.nut")
let { getLastWeapon,
        isWeaponEnabled,
        isWeaponUnlocked,
        getLastPrimaryWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { canBuyMod, canResearchMod, isModUpgradeable, isReqModificationsUnlocked,
  getModificationByName, isModificationEnabled } = require("%scripts/weaponry/modificationInfo.nut")
let { getSavedBullets } = require("%scripts/weaponry/savedWeaponry.nut")

const MAX_SPARE_AMOUNT = 100

function getItemAmount(unit, item) {
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getAmount(unit, item)
}

function isResearchableItem(item) {
  return item.type == weaponsItem.modification
}

function canBeResearched(unit, item, checkCurrent = true) {
  if (isResearchableItem(item))
    return canResearchMod(unit, item, checkCurrent)
  return false
}

function canResearchItem(unit, item, checkCurrent = true) {
  return item.type == weaponsItem.modification &&
         canBeResearched(unit, item, checkCurrent)
}

function getItemCost(unit, item) {
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getCost(unit, item)
}

function isModStatusResearched(unit, mod) {
  let s = shop_get_module_research_status(unit.name, mod.name)
  return (s & ES_ITEM_STATUS_RESEARCHED) != 0
}

function getItemStatusTbl(unit, item) {
  let isOwn = ::isUnitUsable(unit)
  let res = {
    amount = getItemAmount(unit, item)
    maxAmount = 0
    amountWarningValue = 0
    modExp = 0
    showMaxAmount = false
    canBuyMore = false
    equipped = false
    goldUnlockable = false
    unlocked = false
    canBuyForWP = false
    showPrice = true
    discountType = ""
    canShowDiscount = true
    curUpgrade = 0
    maxUpgrade = 0
  }

  if (item.type == weaponsItem.weapon) {
    res.maxAmount = getAmmoMaxAmount(unit, item.name, AMMO.WEAPON)
    res.amount = getAmmoAmount(unit, item.name, AMMO.WEAPON)
    res.showMaxAmount = res.maxAmount > 1
    res.amountWarningValue = getAmmoWarningMinimum(AMMO.WEAPON, unit, res.maxAmount)
    res.canBuyMore = res.amount < res.maxAmount
    res.equipped = res.amount && getLastWeapon(unit.name) == item.name
    res.unlocked = isWeaponEnabled(unit, item) || (isOwn && isWeaponUnlocked(unit, item))
    res.discountType = "weapons"
  }
  else if (item.type == weaponsItem.primaryWeapon) {
    res.equipped = getLastPrimaryWeapon(unit) == item.name
    if (item.name == "") //default
      res.unlocked = isOwn
    else {
      res.maxAmount = wp_get_modification_max_count(unit.name, item.name)
      res.equipped = res.amount && isModificationEnabled(unit.name, item.name)
      res.unlocked = res.amount || canBuyMod(unit, item)
      res.showPrice = false //amount < maxAmount
    }
  }
  else if (item.type == weaponsItem.modification || item.type == weaponsItem.expendables) {
    let groupDef = ("isDefaultForGroup" in item) ? item.isDefaultForGroup : -1
    if (groupDef >= 0) { //default bullets, always bought.
      res.unlocked = isOwn
      let currBullet = groupDef < unit.unitType.bulletSetsQuantity ? getSavedBullets(unit.name, groupDef) : ""
      res.equipped = currBullet == "" || currBullet == item.name
      res.showPrice = false
    }
    else {
      res.unlocked = res.amount || canBuyMod(unit, item)
      res.maxAmount = wp_get_modification_max_count(unit.name, item.name)
      res.amountWarningValue = getAmmoWarningMinimum(AMMO.MODIFICATION, unit, res.maxAmount)
      res.canBuyMore = res.amount < res.maxAmount
      res.modExp = shop_get_module_exp(unit.name, item.name)
      res.discountType = "mods"
      if (!isBullets(item)) {
        res.canBuyForWP = res.unlocked
          && res.maxAmount == 1
          && res.canBuyMore
          && getItemCost(unit, item).wp > 0
        res.equipped = res.amount && isModificationEnabled(unit.name, item.name)
        res.goldUnlockable = !res.unlocked && hasFeature("SpendGold")
          && isReqModificationsUnlocked(unit, item) && canBeResearched(unit, item, false)
        if (item.type == weaponsItem.expendables)
          res.showPrice = !res.amount || canBuyMod(unit, item)
        else {
          res.canShowDiscount = res.canBuyMore
          res.showPrice = !res.amount
            && (canBuyMod(unit, item) || isModStatusResearched(unit, item))
        }

        if (isOwn && res.amount && isModUpgradeable(item.name)) {
          res.curUpgrade = get_modification_level(unit.name, item.name)
          res.maxUpgrade = 1 //only 1 upgrade level planned to be used atm.
          //so no point to add complex logic about max upgrade detection right now.
        }
      }
      else {
        res.equipped = false
        res.showMaxAmount = res.maxAmount > 1
        let id = getBulletGroupIndex(unit.name, item.name)
        if (id >= 0) {
          let currBullet = getSavedBullets(unit.name, id)
          res.equipped = res.amount && (currBullet == item.name)
        }
      }
    }
  }
  else if (item.type == weaponsItem.spare) {
    res.equipped = res.amount > 0
    res.maxAmount = MAX_SPARE_AMOUNT
    res.showMaxAmount = false
    res.canBuyMore = res.amount < res.maxAmount
    res.unlocked = isOwn
    res.discountType = "spare"
  }
  return res
}

function getBundleCurItem(unit, bundle) {
  if (!("itemsType" in bundle))
    return null

  if (bundle.itemsType == weaponsItem.weapon) {
    let curWeapon = getLastWeapon(unit.name)
    foreach (item in bundle.itemsList)
      if (curWeapon == item.name)
        return item
    return bundle.itemsList[0]
  }
  else if (bundle.itemsType == weaponsItem.bullets) {
    let curName = getSavedBullets(unit.name, bundle?.subType ?? 0)
    local def = null
    foreach (item in bundle.itemsList)
      if (curName == item.name)
        return item
      else if (("isDefaultForGroup" in item)
               || (!def && curName == "" && !wp_get_modification_cost(unit.name, item.name)))
        def = item
    return def
  }
  else if (bundle.itemsType == weaponsItem.primaryWeapon) {
    let curPrimaryWeaponName = getLastPrimaryWeapon(unit)
    foreach (item in bundle.itemsList)
      if (item.name == curPrimaryWeaponName)
        return item
  }
  return null
}

function getByCurBundle(unit, bundle, func, defValue = "") {
  let cur = getBundleCurItem(unit, bundle)
  return cur ? func(unit, cur) : defValue
}

function getItemUnlockCost(unit, item) {
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getUnlockCost(unit, item)
}

function isCanBeDisabled(item) {
  return (item.type == weaponsItem.modification || item.type == weaponsItem.expendables) &&
         (!("deactivationIsAllowed" in item) || item.deactivationIsAllowed) &&
         !isBullets(item)
}

function isModInResearch(unit, item) {
  if (item.name == "" || !("type" in item) || item.type != weaponsItem.modification)
    return false

  let status = shop_get_module_research_status(unit.name, item.name)
  return status == ES_ITEM_STATUS_IN_RESEARCH
}

function getItemUpgradesList(item) {
  if ("weaponUpgrades" in item)
    return item.weaponUpgrades
  else if ("weaponMod" in item && item.weaponMod != null && "weaponUpgrades" in item.weaponMod)
    return item.weaponMod.weaponUpgrades
  return null
}

function countWeaponsUpgrade(unit, item) {
  local upgradesTotal = 0
  local upgraded = 0
  let upgrades = getItemUpgradesList(item)

  if (!upgrades)
    return null

  foreach (_i, modsArray in upgrades) {
    if (modsArray.len() == 0)
      continue

    upgradesTotal++

    foreach (modName in modsArray)
      if (isModificationEnabled(unit.name, modName)) {
        upgraded++
        break
      }
  }
  return [upgraded, upgradesTotal]
}

function getItemUpgradesStatus(unit, item) {
  if (item.type == weaponsItem.primaryWeapon) {
    let countData = countWeaponsUpgrade(unit, item)
    return !countData?[1] ? ""
      : countData[0] >= countData[1] ? "full"
      : "part"
  }
  if (item.type == weaponsItem.modification) {
    let curPrimWeaponName = getLastPrimaryWeapon(unit)
    let weapMod = getModificationByName(unit, curPrimWeaponName)
    let upgradesList = getItemUpgradesList(weapMod || unit) //default weapon upgrades stored in unit
    if (upgradesList)
      foreach (list in upgradesList)
        if (isInArray(item.name, list))
          return "mod"
  }
  return ""
}

function getRepairCostCoef(item) {
  let modeName = getCurrentShopDifficulty().getEgdName(true)
  return item?["repairCostCoef" + modeName] ?? item?.repairCostCoef ?? 0
}

function getDiscountPath(unit, item, discountType) {
  let discountPath = ["aircrafts", unit.name, item.name]
  if (item.type != weaponsItem.spare)
    discountPath.insert(2, discountType)

  return discountPath
}

function getAllModsCost(unit, open = false) {
  local modsCost = Cost()
  foreach (modification in (unit?.modifications ?? {})) {
    let statusTbl = getItemStatusTbl(unit, modification)
    if (statusTbl.maxAmount == statusTbl.amount)
      continue

    local skipSummary = false
    local _modCost = Cost()

    if (open) {
      let openCost = getItemUnlockCost(unit, modification)
      if (!openCost.isZero())
        _modCost = openCost
    }

    if (canBuyMod(unit, modification) || isModStatusResearched(unit, modification)) {
      let modificationCost = getItemCost(unit, modification)
      if (!modificationCost.isZero()) {
        skipSummary = statusTbl.maxAmount > 1

        if (modificationCost.gold > 0)
          skipSummary = true

        _modCost = modificationCost
      }
    }

    // premium modifications or ammo is separated,
    // so no need to show it's price with other modifications.
    if (skipSummary)
      continue

    modsCost += _modCost
  }

  return modsCost
}

return {
  MAX_SPARE_AMOUNT
  getItemAmount         = getItemAmount
  isResearchableItem    = isResearchableItem
  canBeResearched       = canBeResearched
  canResearchItem       = canResearchItem
  getItemStatusTbl      = getItemStatusTbl
  getBundleCurItem      = getBundleCurItem
  getByCurBundle        = getByCurBundle
  getItemCost           = getItemCost
  getItemUnlockCost     = getItemUnlockCost
  isCanBeDisabled       = isCanBeDisabled
  isModInResearch       = isModInResearch
  getItemUpgradesList   = getItemUpgradesList
  countWeaponsUpgrade   = countWeaponsUpgrade
  getItemUpgradesStatus = getItemUpgradesStatus
  getRepairCostCoef     = getRepairCostCoef
  getDiscountPath       = getDiscountPath
  getAllModsCost        = getAllModsCost
}
