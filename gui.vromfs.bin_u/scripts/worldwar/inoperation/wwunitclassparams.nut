//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { getWeaponByName } = require("%scripts/weaponry/weaponryInfo.nut")

let sortIdxByExpClass = {
  fighter = 0
  assault = 1
  bomber  = 2
}

let wwUnitClassParams = {
  [WW_UNIT_CLASS.FIGHTER] = {
    name = "fighter"
    iconText = @() loc("worldWar/iconAirFighter")
    color = "medium_fighterColor"
  },
  [WW_UNIT_CLASS.ASSAULT] = {
    name = "assault"
    iconText = @() loc("worldWar/iconAirAssault")
    color = "common_assaultColor"
  },
  [WW_UNIT_CLASS.BOMBER] = {
    name = "bomber"
    iconText = @() loc("worldWar/iconAirBomber")
    color = "medium_bomberColor"
  },
  [WW_UNIT_CLASS.HELICOPTER] = {
    name = "helicopter"
    iconText = @() loc("worldWar/iconAirHelicopter")
    color = "attack_helicopterColor"
  }
}

let getSortIdx = @(expClass) sortIdxByExpClass?[expClass] ?? sortIdxByExpClass.len()
let getText = @(unitClass) wwUnitClassParams?[unitClass].name ?? "unknown"
let function getIconText(unitClass, needColorize = false) {
  let params = wwUnitClassParams?[unitClass]
  if (params == null)
    return ""

  local text = params.iconText()
  if (needColorize)
    text = colorize(params.color, text)

  return text
}

let unknownClassData = {
  expClass = "unknown"
  unitClass = WW_UNIT_CLASS.UNKNOWN
  flyOutUnitClass = WW_UNIT_CLASS.UNKNOWN
  tooltipTextLocId = ""
}

let classDataByExpClass = {
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
  helicopter = {
    expClass = "helicopter"
    unitClass = WW_UNIT_CLASS.HELICOPTER
    flyOutUnitClass = WW_UNIT_CLASS.HELICOPTER
    tooltipTextLocId = "mainmenu/type_helicopter"
  }
}

let function getDefaultUnitClassData(unit) {
  if (!unit.isAir())
    return unknownClassData

  return classDataByExpClass?[unit.expClass] ?? unknownClassData
}

let function getUnitClassData(unit, weapPreset = null) {
  let res = {}.__update(getDefaultUnitClassData(unit))

  if (unit.expClass == "fighter" && weapPreset != null) {
    let weaponmask = getWeaponByName(unit.unit, weapPreset)?.weaponmask ?? 0
    let requiredWeaponmask = ::g_world_war.getWWConfigurableValue("fighterToAssaultWeaponMask", 0)
    let isFighter = !(weaponmask & requiredWeaponmask)
    res.unitClass = isFighter ? WW_UNIT_CLASS.FIGHTER : WW_UNIT_CLASS.ASSAULT
    res.flyOutUnitClass = isFighter ? WW_UNIT_CLASS.FIGHTER : WW_UNIT_CLASS.BOMBER
    res.tooltipTextLocId = isFighter ? "mainmenu/type_fighter" : "mainmenu/type_assault_fighter"
  }

  return res
}

let function getFighterToAssaultWeapon(unit) {
  let customClassWeaponMask = ::g_world_war.getWWConfigurableValue("fighterToAssaultWeaponMask", 0)
  return unit?.getWeapons().findvalue(@(w) (w?.weaponmask ?? 0) & customClassWeaponMask)
}

let function getAvailableClasses(unit) {
  let res = [getDefaultUnitClassData(unit)]

  if (unit.expClass == "fighter" && getFighterToAssaultWeapon(unit.unit) != null)
    res.append(classDataByExpClass.assault)

  return res
}

let function getWeaponNameByExpClass(unit, expClass) {
  return expClass == "assault" ? getFighterToAssaultWeapon(unit)?.name ?? "" : ""
}

return {
  getSortIdx
  getText
  getIconText
  getUnitClassData
  getAvailableClasses
  getFighterToAssaultWeapon
  getWeaponNameByExpClass
}