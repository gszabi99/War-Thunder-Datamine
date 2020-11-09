local { AMMO,
        getAmmoAmount,
        getAmmoMaxAmount } = require("scripts/weaponry/ammoInfo.nut")

local function canBuyMod(unit, mod)
{
  local status = ::shop_get_module_research_status(unit.name, mod.name)
  if (status & ::ES_ITEM_STATUS_CAN_BUY)
    return true

  if (status & (::ES_ITEM_STATUS_MOUNTED | ::ES_ITEM_STATUS_OWNED))
  {
    local amount = getAmmoAmount(unit, mod.name, AMMO.MODIFICATION)
    local maxAmount = getAmmoMaxAmount(unit, mod.name, AMMO.MODIFICATION)
    return amount < maxAmount
  }

  return false
}

local function isModResearched(unit, mod)
{
  local status = ::shop_get_module_research_status(unit.name, mod.name)
  if (status & (::ES_ITEM_STATUS_CAN_BUY | ES_ITEM_STATUS_OWNED | ES_ITEM_STATUS_MOUNTED | ES_ITEM_STATUS_RESEARCHED))
    return true

  return false
}

local isModClassPremium = @(moduleData) (moduleData?.modClass ?? "") == "premium"
local isModClassExpendable = @(moduleData) (moduleData?.modClass ?? "") == "expendable"

local function canResearchMod(unit, mod, checkCurrent = false)
{
  local status = ::shop_get_module_research_status(unit.name, mod.name)
  local canResearch = checkCurrent ? status == ::ES_ITEM_STATUS_CAN_RESEARCH :
                        0 != (status & (::ES_ITEM_STATUS_CAN_RESEARCH | ::ES_ITEM_STATUS_IN_RESEARCH))

  return canResearch
}

local function findAnyNotResearchedMod(unit)
{
  if (!("modifications" in unit))
    return null

  foreach(mod in unit.modifications)
    if (canResearchMod(unit, mod) && !isModResearched(unit, mod))
      return mod

  return null
}

local function isModAvailableOrFree(unitName, modName)
{
  return (::shop_is_modification_available(unitName, modName, true)
          || (!::wp_get_modification_cost(unitName, modName) && !wp_get_modification_cost_gold(unitName, modName)))
}

local function getModBlock(modName, blockName, templateKey)
{
  local modsBlk = ::get_modifications_blk()
  local modBlock = modsBlk?.modifications?[modName]
  if (!modBlock || modBlock?[blockName])
    return modBlock?[blockName]
  local tName = modBlock?[templateKey]
  return tName ? modsBlk?.templates?[tName]?[blockName] : null
}

local isModUpgradeable = @(modName) getModBlock(modName, "upgradeEffect", "modUpgradeType")
local hasActiveOverdrive = @(unitName, modName) ::get_modifications_overdrive(unitName).len() > 0
  && getModBlock(modName, "overdriveEffect", "modOverdriveType")

local function getModificationByName(unit, modName)
{
  if (!("modifications" in unit))
    return null

  foreach(i, modif in unit.modifications)
    if (modif.name == modName)
      return modif

  return null
}

return {
  canBuyMod               = canBuyMod
  isModResearched         = isModResearched
  isModClassPremium       = isModClassPremium
  isModClassExpendable    = isModClassExpendable
  canResearchMod          = canResearchMod
  findAnyNotResearchedMod = findAnyNotResearchedMod
  isModAvailableOrFree    = isModAvailableOrFree
  isModUpgradeable        = isModUpgradeable
  hasActiveOverdrive      = hasActiveOverdrive
  getModificationByName   = getModificationByName
}