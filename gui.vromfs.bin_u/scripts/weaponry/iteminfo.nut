local { isBullets,
        getBulletGroupIndex } = require("scripts/weaponry/bulletsInfo.nut")
local { AMMO,
        getAmmoAmount,
        getAmmoMaxAmount,
        getAmmoWarningMinimum } = require("scripts/weaponry/ammoInfo.nut")
local { getLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")
local { canBuyMod,
        canResearchMod,
        isModUpgradeable } = require("scripts/weaponry/modificationInfo.nut")

local function getItemAmount(unit, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getAmount(unit, item)
}

local function isResearchableItem(item)
{
  return item.type == weaponsItem.modification
}

local function canBeResearched(unit, item, checkCurrent = true)
{
  if (isResearchableItem(item))
    return canResearchMod(unit, item, checkCurrent)
  return false
}

local function canResearchItem(unit, item, checkCurrent = true)
{
  return item.type == weaponsItem.modification &&
         canBeResearched(unit, item, checkCurrent)
}

local function getItemStatusTbl(unit, item)
{
  local isOwn = ::isUnitUsable(unit)
  local res = {
    amount = getItemAmount(unit, item)
    maxAmount = 0
    amountWarningValue = 0
    modExp = 0
    showMaxAmount = false
    canBuyMore = false
    equipped = false
    goldUnlockable = false
    unlocked = false
    showPrice = true
    discountType = ""
    canShowDiscount = true
    curUpgrade = 0
    maxUpgrade = 0
  }

  if (item.type == weaponsItem.weapon)
  {
    res.maxAmount = getAmmoMaxAmount(unit, item.name, AMMO.WEAPON)
    res.amount = getAmmoAmount(unit, item.name, AMMO.WEAPON)
    res.showMaxAmount = res.maxAmount > 1
    res.amountWarningValue = getAmmoWarningMinimum(AMMO.WEAPON, unit, res.maxAmount)
    res.canBuyMore = res.amount < res.maxAmount
    res.equipped = res.amount && getLastWeapon(unit.name) == item.name
    res.unlocked = ::is_weapon_enabled(unit, item) || (isOwn && ::is_weapon_unlocked(unit, item))
    res.discountType = "weapons"
  }
  else if (item.type == weaponsItem.primaryWeapon)
  {
    res.equipped = ::get_last_primary_weapon(unit) == item.name
    if (item.name == "") //default
      res.unlocked = isOwn
    else
    {
      res.maxAmount = ::wp_get_modification_max_count(unit.name, item.name)
      res.equipped = res.amount && ::shop_is_modification_enabled(unit.name, item.name)
      res.unlocked = res.amount || canBuyMod(unit, item)
      res.showPrice = false//amount < maxAmount
    }
  }
  else if (item.type == weaponsItem.modification || item.type == weaponsItem.expendables)
  {
    local groupDef = ("isDefaultForGroup" in item)? item.isDefaultForGroup : -1
    if (groupDef >= 0) //default bullets, always bought.
    {
      res.unlocked = isOwn
      local currBullet = ::get_last_bullets(unit.name, groupDef)
      res.equipped = !currBullet || currBullet == "" || currBullet == item.name
      res.showPrice = false
    }
    else
    {
      res.unlocked = res.amount || canBuyMod(unit, item)
      res.maxAmount = ::wp_get_modification_max_count(unit.name, item.name)
      res.amountWarningValue = getAmmoWarningMinimum(AMMO.MODIFICATION, unit, res.maxAmount)
      res.canBuyMore = res.amount < res.maxAmount
      res.modExp = ::shop_get_module_exp(unit.name, item.name)
      res.discountType = "mods"
      if (!isBullets(item))
      {
        res.equipped = res.amount && ::shop_is_modification_enabled(unit.name, item.name)
        res.goldUnlockable = !res.unlocked && ::has_feature("SpendGold")
          && canBeResearched(unit, item, false)
        if (item.type == weaponsItem.expendables)
          res.showPrice = !res.amount || canBuyMod(unit, item)
        else
        {
          res.canShowDiscount = res.canBuyMore
          res.showPrice = !res.amount && canBuyMod(unit, item)
        }

        if (isOwn && res.amount && isModUpgradeable(item.name))
        {
          res.curUpgrade = ::get_modification_level(unit.name, item.name)
          res.maxUpgrade = 1 //only 1 upgrade level planned to be used atm.
          //so no point to add complex logic about max upgrade detection right now.
        }
      }
      else
      {
        res.equipped = false
        res.showMaxAmount = res.maxAmount > 1
        local id = getBulletGroupIndex(unit.name, item.name)
        if (id >= 0)
        {
          local currBullet = ::get_last_bullets(unit.name, id)
          res.equipped = res.amount && (currBullet == item.name)
        }
      }
    }
  }
  else if (item.type == weaponsItem.spare)
  {
    res.equipped = res.amount > 0
    res.maxAmount = ::max_spare_amount
    res.showMaxAmount = false
    res.canBuyMore = res.amount < res.maxAmount
    res.unlocked = isOwn
    res.discountType = "spare"
  }
  return res
}

local function getBundleCurItem(unit, bundle)
{
  if (!("itemsType" in bundle))
    return null

  if (bundle.itemsType == weaponsItem.weapon)
  {
    local curWeapon = getLastWeapon(unit.name)
    foreach(item in bundle.itemsList)
      if (curWeapon == item.name)
        return item
    return bundle.itemsList[0]
  }
  else if (bundle.itemsType == weaponsItem.bullets)
  {
    local curName = ::get_last_bullets(unit.name, bundle?.subType ?? 0)
    local def = null
    foreach(item in bundle.itemsList)
      if (curName == item.name)
        return item
      else if (("isDefaultForGroup" in item)
               || (!def && curName == "" && !::wp_get_modification_cost(unit.name, item.name)))
        def = item
    return def
  }
  else if (bundle.itemsType == weaponsItem.primaryWeapon)
  {
    local curPrimaryWeaponName = ::get_last_primary_weapon(unit)
    foreach (item in bundle.itemsList)
      if(item.name == curPrimaryWeaponName)
        return item
  }
  return null
}

local function getByCurBundle(unit, bundle, func, defValue = "")
{
  local cur = getBundleCurItem(unit, bundle)
  return cur? func(unit, cur) : defValue
}

local function getItemCost(unit, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getCost(unit, item)
}

local function getItemUnlockCost(unit, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getUnlockCost(unit, item)
}

local function isCanBeDisabled(item)
{
  return (item.type == weaponsItem.modification || item.type == weaponsItem.expendables) &&
         (!("deactivationIsAllowed" in item) || item.deactivationIsAllowed) &&
         !isBullets(item)
}

local function isModInResearch(unit, item)
{
  if (item.name == "" || !("type" in item) || item.type != weaponsItem.modification)
    return false

  local status = ::shop_get_module_research_status(unit.name, item.name)
  return status == ::ES_ITEM_STATUS_IN_RESEARCH
}

local function getItemUpgradesList(item)
{
  if ("weaponUpgrades" in item)
    return item.weaponUpgrades
  else if ("weaponMod" in item && item.weaponMod != null && "weaponUpgrades" in item.weaponMod)
    return item.weaponMod.weaponUpgrades
  return null
}

local function countWeaponsUpgrade(unit, item)
{
  local upgradesTotal = 0
  local upgraded = 0
  local upgrades = getItemUpgradesList(item)

  if (!upgrades)
    return null

  foreach (i, modsArray in upgrades)
  {
    if (modsArray.len() == 0)
      continue

    upgradesTotal++

    foreach(modName in modsArray)
      if (::shop_is_modification_enabled(unit.name, modName))
      {
        upgraded++
        break
      }
  }
  return [upgraded, upgradesTotal]
}

local function getItemUpgradesStatus(unit, item)
{
  if (item.type == weaponsItem.primaryWeapon)
  {
    local countData = countWeaponsUpgrade(unit, item)
    return !countData?[1] ? ""
      : countData[0] >= countData[1] ? "full"
      : "part"
  }
  if (item.type == weaponsItem.modification)
  {
    local curPrimWeaponName = ::get_last_primary_weapon(unit)
    local weapMod = ::getModificationByName(unit, curPrimWeaponName)
    local upgradesList = getItemUpgradesList(weapMod || unit) //default weapon upgrades stored in unit
    if (upgradesList)
      foreach(list in upgradesList)
        if (::isInArray(item.name, list))
          return "mod"
  }
  return ""
}

local function getRepairCostCoef(item)
{
  local modeName = ::get_current_shop_difficulty().getEgdName(true)
  return item?["repairCostCoef" + modeName] ?? item?.repairCostCoef ?? 0
}

local function getDiscountPath(unit, item, discountType)
{
  local discountPath = ["aircrafts", unit.name, item.name]
  if (item.type != weaponsItem.spare)
    discountPath.insert(2, discountType)

  return discountPath
}

return {
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
}