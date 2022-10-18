from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let enums = require("%sqStdLibs/helpers/enums.nut")
let { getUnitRole } = require("%scripts/unit/unitInfoTexts.nut")

let fakeInfantryUnitName = "fake_infantry"
const ALL_WW_UNITS_CODE = -2
const WW_TRANSPORT_CODE = -3
const WW_HELICOPTER_CODE = -4

::g_ww_unit_type <- {
  types = []
  cache = {
    byName = {}
    byCode = {}
    byTextCode = {}
    byEsUnitCode = {}
  }
}

::g_ww_unit_type.template <- {
  code = -1
  textCode = ""
  sortCode = WW_UNIT_SORT_CODE.UNKNOWN
  esUnitCode = ES_UNIT_TYPE_INVALID
  name = ""
  fontIcon = ""
  moveSound = ""
  deploySound = ""
  expClass = null
  canBeControlledByPlayer = false

  getUnitName = @(name) ::getUnitName(name)
  getUnitClassIcon = @(unit) ::getUnitClassIco(unit)
  getUnitRole = @(unit) getUnitRole(unit)
}

enums.addTypesByGlobalName("g_ww_unit_type", {
  UNKNOWN = {
  }
  AIR = {
    code = UT_AIR
    textCode = "UT_AIR"
    sortCode = WW_UNIT_SORT_CODE.AIR
    esUnitCode = ES_UNIT_TYPE_AIRCRAFT
    name = "Aircraft"
    fontIcon = loc("worldwar/iconAir")
    moveSound = "ww_unit_move_airplanes"
    deploySound = "ww_unit_move_airplanes"
    canBeControlledByPlayer = true
  }
  HELICOPTER = {
    code = WW_HELICOPTER_CODE
    textCode = "HELICOPTER"
    sortCode = WW_UNIT_SORT_CODE.HELICOPTER
    esUnitCode = ES_UNIT_TYPE_HELICOPTER
    name = "Helicopter"
    fontIcon = loc("worldwar/iconHelicopter")
    moveSound = "ww_unit_move_helicopters"
    deploySound = "ww_unit_move_helicopters"
    canBeControlledByPlayer = true
  }
  GROUND = {
    code = UT_GROUND
    textCode = "UT_GROUND"
    sortCode = WW_UNIT_SORT_CODE.GROUND
    esUnitCode = ES_UNIT_TYPE_TANK
    name = "Tank"
    fontIcon = loc("worldwar/iconGround")
    moveSound = "ww_unit_move_tanks"
    deploySound = "ww_unit_move_tanks"
    canBeControlledByPlayer = true
  }
  WATER = {
    code = UT_WATER
    textCode = "UT_WATER"
    sortCode = WW_UNIT_SORT_CODE.WATER
    esUnitCode = ES_UNIT_TYPE_SHIP
    name = "Ship"
    fontIcon = loc("worldwar/iconWater")
    canBeControlledByPlayer = true
  }
  INFANTRY = {
    code = UT_INFANTRY
    textCode = "UT_INFANTRY"
    sortCode = WW_UNIT_SORT_CODE.INFANTRY
    name = "Infantry"
    fontIcon = loc("worldwar/iconInfantry")
    expClass = "infantry"
    moveSound = "ww_unit_move_infantry"
    deploySound = "ww_unit_move_infantry"
    getUnitName = @(_name) loc("mainmenu/type_infantry")
    getUnitClassIcon = @(_unit) "#ui/gameuiskin#icon_infantry.svg"
    getUnitRole = @(_unit) "infantry"
  }
  ARTILLERY = {
    code = UT_ARTILLERY
    textCode = "UT_ARTILLERY"
    sortCode = WW_UNIT_SORT_CODE.ARTILLERY
    name = "Artillery"
    fontIcon = loc("worldwar/iconArtillery")
    expClass = "artillery"
    moveSound = "ww_unit_move_artillery"
    deploySound = "ww_unit_move_artillery"
    getUnitName = @(_name) loc("mainmenu/type_artillery")
    getUnitClassIcon = @(_unit) "#ui/gameuiskin#icon_artillery.svg"
    getUnitRole = @(_unit) "artillery"
  }
  TRANSPORT = {
    code = WW_TRANSPORT_CODE
    textCode = "TRANSPORT"
    sortCode = WW_UNIT_SORT_CODE.TRANSPORT
    name = "Transport"
    fontIcon = loc("worldwar/iconLandingCraftEmpty")
    expClass = "landing_craft"
    getUnitName = @(_name) loc("mainmenu/type_landing_craft")
    getUnitClassIcon = @(_unit) "#ui/gameuiskin#landing_craft.svg"
    getUnitRole = @(_unit) "transport"
  }
  ALL = {
    code = ALL_WW_UNITS_CODE
    textCode = "ALL"
    fontIcon = loc("worldwar/iconAllVehicle")
  }
})


::g_ww_unit_type.getUnitTypeByCode <- function getUnitTypeByCode(wwUnitTypeCode)
{
  return enums.getCachedType(
    "code",
    wwUnitTypeCode,
    this.cache.byCode,
    this,
    this.UNKNOWN
  )
}


::g_ww_unit_type.getUnitTypeByTextCode <- function getUnitTypeByTextCode(wwUnitTypeTextCode)
{
  return enums.getCachedType(
    "textCode",
    wwUnitTypeTextCode,
    this.cache.byTextCode,
    this,
    this.UNKNOWN
  )
}


::g_ww_unit_type.getUnitTypeByEsUnitCode <- function getUnitTypeByEsUnitCode(esUnitCode) {
  return enums.getCachedType(
    "esUnitCode",
    esUnitCode,
    this.cache.byEsUnitCode,
    this,
    this.UNKNOWN
  )
}


::g_ww_unit_type.getUnitTypeByWwUnit <- function getUnitTypeByWwUnit(wwUnit) {
  let name = wwUnit.name
  if (name in this.cache.byName)
    return this.cache.byName[name]

  let esUnitType = ::get_es_unit_type(wwUnit.unit)
  if (esUnitType != ES_UNIT_TYPE_INVALID)
    return ::g_ww_unit_type.getUnitTypeByEsUnitCode(esUnitType)
  else if (name == fakeInfantryUnitName || name in ::g_world_war.getInfantryUnits())
    return ::g_ww_unit_type.INFANTRY
  else if (name in ::g_world_war.getArtilleryUnits())
    return ::g_ww_unit_type.ARTILLERY
  else if (name in ::g_world_war.getTransportUnits())
    return ::g_ww_unit_type.TRANSPORT

  return ::g_ww_unit_type.UNKNOWN
}


::g_ww_unit_type.getUnitTypeFontIcon <- function getUnitTypeFontIcon(wwUnitTypeCode) {
  return getUnitTypeByCode(wwUnitTypeCode).fontIcon
}


::g_ww_unit_type.isAir <- function isAir(wwUnitTypeCode) {
  return wwUnitTypeCode == this.AIR.code || wwUnitTypeCode == this.HELICOPTER.code
}


::g_ww_unit_type.isHelicopter <- function isHelicopter(wwUnitTypeCode) {
  return wwUnitTypeCode == this.HELICOPTER.code
}


::g_ww_unit_type.isGround <- function isGround(wwUnitTypeCode) {
  return wwUnitTypeCode == this.GROUND.code
}


::g_ww_unit_type.isWater <- function isWater(wwUnitTypeCode) {
  return wwUnitTypeCode == this.WATER.code
}


::g_ww_unit_type.isInfantry <- function isInfantry(wwUnitTypeCode) {
  return wwUnitTypeCode == this.INFANTRY.code
}


::g_ww_unit_type.isArtillery <- function isArtillery(wwUnitTypeCode) {
  return wwUnitTypeCode == this.ARTILLERY.code
}

::g_ww_unit_type.canBeSurrounded <- function canBeSurrounded(wwUnitTypeCode) {
  return !isAir(wwUnitTypeCode)
}
