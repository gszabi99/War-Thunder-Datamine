local sortIdxByExpClass = {
  fighter = 0
  assault = 1
  bomber  = 2
}

local wwUnitClassParams = {
  [WW_UNIT_CLASS.FIGHTER] = {
    name = "fighter"
    iconText = @() ::loc("worldWar/iconAirFighter")
    color = "medium_fighterColor"
  },
  [WW_UNIT_CLASS.ASSAULT] = {
    name = "assault"
    iconText = @() ::loc("worldWar/iconAirAssault")
    color = "common_assaultColor"
  },
  [WW_UNIT_CLASS.BOMBER] = {
    name = "bomber"
    iconText = @() ::loc("worldWar/iconAirBomber")
    color = "medium_bomberColor"
  }
}

local getSortIdx = @(expClass) sortIdxByExpClass?[expClass] ?? sortIdxByExpClass.len()
local getText = @(unitClass) wwUnitClassParams?[unitClass].name ?? "unknown"
local function getIconText(unitClass, needColorize = false) {
  local params = wwUnitClassParams?[unitClass]
  if (params == null)
    return ""

  local text = params.iconText()
  if (needColorize)
    text = ::colorize(params.color, text)

  return text
}

local unknownClassData = {
  unitClass = WW_UNIT_CLASS.UNKNOWN
  flyOutUnitClass = WW_UNIT_CLASS.UNKNOWN
  tooltipTextLocId = ""
}

local classDataByExpClass = {
  fighter = {
    expClass = "fighter"
    unitClass = WW_UNIT_CLASS.FIGHTER
    flyOutUnitClass = WW_UNIT_CLASS.FIGHTER
    tooltipTextLocId = "mainmenu/type_fighter"
  }
  assault = {
    expClass = "assault"
    unitClass = WW_UNIT_CLASS.ASSAULT
    flyOutUnitClass = WW_UNIT_CLASS.BOMBER
    tooltipTextLocId = "mainmenu/type_assault"
  }
  bomber = {
    expClass = "bomber"
    unitClass = WW_UNIT_CLASS.BOMBER
    flyOutUnitClass = WW_UNIT_CLASS.BOMBER
    tooltipTextLocId = "mainmenu/type_bomber"
  }
}

local function getDefaultUnitClassData(unit)
{
  if (!unit.isAir())
    return unknownClassData

  return classDataByExpClass?[unit.expClass] ?? unknownClassData
}

local function getUnitClassData(unit, weapPreset = null)
{
  local res = {}.__update(getDefaultUnitClassData(unit))

  if (unit.expClass == "fighter" && weapPreset != null)
  {
    local weaponmask = ::get_weapon_by_name(unit.unit, weapPreset)?.weaponmask ?? 0
    local requiredWeaponmask = ::g_world_war.getWWConfigurableValue("fighterToAssaultWeaponMask", 0)
    local isFighter = !(weaponmask & requiredWeaponmask)
    res.unitClass = isFighter ? WW_UNIT_CLASS.FIGHTER : WW_UNIT_CLASS.ASSAULT
    res.flyOutUnitClass = isFighter ? WW_UNIT_CLASS.FIGHTER : WW_UNIT_CLASS.BOMBER
    res.tooltipTextLocId = isFighter ? "mainmenu/type_fighter" : "mainmenu/type_assault_fighter"
  }

  return res
}

local function getFighterToAssaultWeapon(unit)
{
  local customClassWeaponMask = ::g_world_war.getWWConfigurableValue("fighterToAssaultWeaponMask", 0)
  return ::u.search(unit?.weapons, @(w) (w?.weaponmask ?? 0) & customClassWeaponMask)
}

local function getAvailableClasses(unit)
{
  local res = [getDefaultUnitClassData(unit)]

  if (unit.expClass == "fighter" && getFighterToAssaultWeapon(unit.unit) != null)
    res.append(classDataByExpClass.assault)

  return res
}

local function getWeaponNameByExpClass(unit, expClass)
{
  return expClass == "assault" ? getFighterToAssaultWeapon(unit)?.name ?? "" : ""
}

return {
  getSortIdx = getSortIdx
  getText = getText
  getIconText = getIconText
  getUnitClassData = getUnitClassData
  getAvailableClasses = getAvailableClasses
  getFighterToAssaultWeapon = getFighterToAssaultWeapon
  getWeaponNameByExpClass = getWeaponNameByExpClass
}