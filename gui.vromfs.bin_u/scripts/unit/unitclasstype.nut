from "%scripts/dagui_library.nut" import *

let { getUnitRoleIcon } = require("%scripts/unit/unitInfoTexts.nut")
let enums = require("%sqStdLibs/helpers/enums.nut")

local unitClassType = {
  types = []
}

unitClassType.template <- {
  code = -1
  name = ""
  expClassName = "" //filled automatically
  unitTypeCode = ES_UNIT_TYPE_INVALID
  checkOrder = -1
  isDeprecated = false

  /** Returns localized name of unit class type. */
  getShortName = @() loc($"mainmenu/type_{this.name}")
  getName = @() this.getShortName()

  /** Check code against specified code mask. */
  checkCode = function(codeMask) {
    if (this.code < 0)
      return false
    codeMask = codeMask.tointeger()
    return (codeMask & (1 << this.code)) != 0
  }

  /** Check if it is valid type. */
  isValid = @() this.code >= 0

  /** Returns unit exp class written in wpcost.blk. */
  getExpClass = @() $"exp_{this.name}"

  /** Returns a related basic role font icon. */
  getFontIcon = @() getUnitRoleIcon(this.name)
}

local checkOrder = 0
enums.addTypes(unitClassType, {
  UNKNOWN = {
    name = "unknown"
  }

  FIGHTER = {
    code = EUCT_FIGHTER
    name = "fighter"
    unitTypeCode = ES_UNIT_TYPE_AIRCRAFT
    checkOrder = checkOrder++
  }

  BOMBER = {
    code = EUCT_BOMBER
    name = "bomber"
    unitTypeCode = ES_UNIT_TYPE_AIRCRAFT
    checkOrder = checkOrder++
  }

  ASSAULT = {
    code = EUCT_ASSAULT
    name = "assault"
    unitTypeCode = ES_UNIT_TYPE_AIRCRAFT
    checkOrder = checkOrder++
  }

  TANK = {
    code = EUCT_TANK
    name = "tank"
    unitTypeCode = ES_UNIT_TYPE_TANK
    checkOrder = checkOrder++

    getName = @() "".concat(loc("mainmenu/type_medium_tank"), loc("ui/slash"), loc("mainmenu/type_light_tank"))
    getFontIcon = @() getUnitRoleIcon("medium_tank")
  }

  HEAVY_TANK = {
    code = EUCT_HEAVY_TANK
    name = "heavy_tank"
    unitTypeCode = ES_UNIT_TYPE_TANK
    checkOrder = checkOrder++
  }

  TANK_DESTROYER = {
    code = EUCT_TANK_DESTROYER
    name = "tank_destroyer"
    unitTypeCode = ES_UNIT_TYPE_TANK
    checkOrder = checkOrder++
  }

  SPAA = {
    code = EUCT_SPAA
    name = "spaa"
    unitTypeCode = ES_UNIT_TYPE_TANK
    checkOrder = checkOrder++

    getExpClass = function () {
      // Name in uppercase.
      return "exp_SPAA"
    }
  }

  SHIP = {
    code = EUCT_SHIP
    name = "ship"
    unitTypeCode = ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
    isDeprecated = true
  }

  TORPEDO_BOAT = {
    code = EUCT_TORPEDO_BOAT
    name = "torpedo_boat"
    unitTypeCode = ES_UNIT_TYPE_BOAT
    checkOrder = checkOrder++
  }

  GUN_BOAT = {
    code = EUCT_GUN_BOAT
    name = "gun_boat"
    unitTypeCode = ES_UNIT_TYPE_BOAT
    checkOrder = checkOrder++
  }

  TORPEDO_GUN_BOAT = {
    code = EUCT_TORPEDO_GUN_BOAT
    name = "torpedo_gun_boat"
    unitTypeCode = ES_UNIT_TYPE_BOAT
    checkOrder = checkOrder++
  }

  SUBMARINE_CHASER = {
    code = EUCT_SUBMARINE_CHASER
    name = "submarine_chaser"
    unitTypeCode = ES_UNIT_TYPE_BOAT
    checkOrder = checkOrder++
  }

  DESTROYER = {
    code = EUCT_DESTROYER
    name = "destroyer"
    unitTypeCode = ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }

  NAVAL_FERRY_BARGE = {
    code = EUCT_NAVAL_FERRY_BARGE
    name = "naval_ferry_barge"
    unitTypeCode = ES_UNIT_TYPE_BOAT
    checkOrder = checkOrder++
  }

  HELICOPTER = {
    code = EUCT_HELICOPTER
    name = "helicopter"
    unitTypeCode = ES_UNIT_TYPE_HELICOPTER
    checkOrder = checkOrder++
  }

  CRUISER = {
    code = EUCT_CRUISER
    name = "cruiser"
    unitTypeCode = ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }
},
function() {
  this.expClassName = this.code == EUCT_SPAA ? this.name.toupper() : this.name
})

unitClassType.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

function getTypesFromCodeMask(codeMask) {
  let resultTypes = []
  foreach (t in unitClassType.types)
    if (t.checkCode(codeMask))
      resultTypes.append(t)
  return resultTypes
}

let classTypesCache = {
  byExpClass = {}
}

function getTypeByExpClass(expClass) {
  return enums.getCachedType("getExpClass", expClass, classTypesCache.byExpClass,
    unitClassType, unitClassType.UNKNOWN)
}

function getTypesByEsUnitType(esUnitType = null) { //null if all unit types
  return unitClassType.types.filter(@(t) (esUnitType == null && t.unitTypeCode != ES_UNIT_TYPE_INVALID)
    || t.unitTypeCode == esUnitType)
}

let remapShipTypes = {
  ship = "ship_only"
  boat = "boat_only"
}
function processUnitTypeArray(unitTypeArray) {
  let res = unitTypeArray.filter(@(v) v not in remapShipTypes)
  if (unitTypeArray.len() >= res.len() + remapShipTypes.len())
    return res.append("ship_and_boat")
  return unitTypeArray.map(@(v) remapShipTypes?[v] ?? v)
}

return {
  getUnitClassTypesFromCodeMask = getTypesFromCodeMask
  getUnitClassTypeByExpClass = getTypeByExpClass
  getUnitClassTypesByEsUnitType = getTypesByEsUnitType
  unitClassType = unitClassType
  processUnitTypeArray
}
