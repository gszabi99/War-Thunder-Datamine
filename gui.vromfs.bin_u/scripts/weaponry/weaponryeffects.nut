//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { floatToStringRounded } = require("%sqstd/string.nut")
let { round_by_value, PI, fabs } = require("%sqstd/math.nut")
let countMeasure = require("%scripts/options/optionsMeasureUnits.nut").countMeasure
let { KGF_TO_NEWTON } = require("%scripts/weaponry/weaponryInfo.nut")

const GOOD_COLOR = "@goodTextColor"
const BAD_COLOR = "@badTextColor"
const NEUTRAL_COLOR = "@activeTextColor"

const MEASURE_UNIT_SPEED = 0
const MEASURE_UNIT_ALT = 1
const MEASURE_UNIT_CLIMB_SPEED = 3


/**************************************** CACHED PARAMS FOR SINLGE CALCULATION ******************************************************/
let UPGRADES_ORDER = ["withLevel", "withOverdrive"] //const
let upgradesKeys = []
local needToShowDiff = false


/**************************************** EFFECTS PRESETS ******************************************************/

let presetsList = {
  SPEED = {
    measureType = MEASURE_UNIT_SPEED
    validateValue = @(value) fabs(value) * 3.6 > 0.1 ? value : null
    presize = 0.1
  }
  CLIMB_SPEED = {
    measureType = MEASURE_UNIT_CLIMB_SPEED
    validateValue = @(value) fabs(value) > 0.1 ? value : null
  }
  PERCENT_FLOAT = {
    measureType = "percent"
    validateValue = @(v) 100.0 * v
  }
  TANK_RESPAWN_COST = {
    measureType = "percent"
    validateValue = @(v) 100.0 * v
    isInverted = true
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
    getText = function (unit, effects, modeId) {
      if (!this.canShowForUnit(unit))
        return ""
      let value = this.getValue(unit, effects, modeId)
      local value2 = effects?[modeId]?[this.id + "_base"]
      if (value2 != null)
        value2 = this.validateValue(value2)
      if (value != null && value2 != null)
        return loc(this.getLocId(unit, effects),
                  {
                    valueWithMod = this.valueToString(value),
                    valueWithoutMod = this.valueToString(value2)
                  })
      return ""
    }
  }
  COLORED_PLURAL_VALUE = {
    getText = function (unit, effects, modeId) {
      if (!this.canShowForUnit(unit))
        return ""
      let value = this.getValue(unit, effects, modeId)
      if (value != null)
        return loc(this.getLocId(unit, effects),
                  {
                    value = value,
                    valueColored = this.valueToString(value)
                  })
      return ""
    }
  }
}


/**************************************** EFFECT TEMPLATE ******************************************************/

let effectTypeTemplate = {
  id = ""
  measureType = ""
  measureSeparate = " "
  presize = 1
  shouldColorByValue = true
  isInverted = false //when isInverted, negative values are better than positive
  preset = null //set of parameter to override on type creation

  getLocId = @(_unit, _effects) "modification/" + this.id + "_change"
  validateValue = @(value) value  //return null if no need to show effect
  canShowForUnit = @(_unit) true

  valueToString = function(value, needAdditionToZero = false) {
    local res = ""
    if (!::u.isString(this.measureType))
      res = countMeasure(this.measureType, value)
    else {
      let measureText = this.measureType != ""
        ? "".concat(this.measureSeparate, loc($"measureUnits/{this.measureType}"))
        : ""
      res = "".concat(
        floatToStringRounded(round_by_value(value, this.presize), this.presize),
        measureText
      )
    }

    if (value > 0 || (needAdditionToZero && value == 0))
      res = "+" + res
    if (value != 0)
      res = colorize(
        !this.shouldColorByValue ? NEUTRAL_COLOR
          : (value < 0 == this.isInverted) ? GOOD_COLOR
          : BAD_COLOR,
        res)
    return res
  }

  getValuePart = function(_unit, effects, modeId) {
    local value = effects?[modeId]?[this.id] ?? effects?[this.id]
    if (value == null)
      return value
    value = this.validateValue(value)
    return value
  }

  getValue = function(unit, effects, modeId) {
    local res = this.getValuePart(unit, effects, modeId)
    if (res == null)
      return res
    foreach (key in upgradesKeys) {
      let value = this.getValuePart(unit, effects?[key], modeId)
      if (value != null)
        res += value
    }
    return fabs(res / this.presize) > 0.5 ? res : null
  }

  getText = function(unit, effects, modeId) {
    if (!this.canShowForUnit(unit))
      return ""
    let value = this.getValue(unit, effects, modeId)
    if (value == null)
      return ""

    local res = format(loc(this.getLocId(unit, effects)), this.valueToString(value))
    if (!needToShowDiff)
      return res

    local hasAddValues = false
    local addValueText = ""
    foreach (key in upgradesKeys) {
      let addVal = this.getValuePart(unit, effects?[key], modeId) ?? 0.0
      hasAddValues = hasAddValues || addVal != 0
      addValueText += " " + this.valueToString(addVal, true)
    }
    if (!hasAddValues)
      return res

    addValueText = this.valueToString(this.getValuePart(unit, effects, modeId) ?? 0.0) + addValueText
    res += loc("ui/parentheses/space", { text = addValueText })

    return res
  }
}

let function effectTypeConstructor() {
  if (this.preset in presetsList)
    foreach (key, value in presetsList[this.preset])
      this[key] <- value
}


/**************************************** USUAL EFFECTS ******************************************************/

let effectsType = {
  types = []
  template = effectTypeTemplate
}

enums.addTypes(effectsType, [
  { id = "armor",                  measureType = "percent" }
  { id = "cutProbability",         measureType = "percent" }
  { id = "overheadCooldown",       measureType = "percent", isInverted = true }
  { id = "mass",                   measureType = "kg", isInverted = true, presize = 0.1
    validateValue = @(value) fabs(value) > 0.5 ? value : null
  }
  { id = "oswalds",                measureType = "percent", presize = 0.001 }
  { id = "cdMinFusel",             measureType = "percent", presize = 0.01, isInverted = true }
  { id = "cdMinTail",              measureType = "percent", presize = 0.01, isInverted = true }
  { id = "cdMinWing",              measureType = "percent", presize = 0.01, isInverted = true }

  { id = "ailThrSpd",              preset = "SPEED" }
  { id = "ruddThrSpd",             preset = "SPEED" }
  { id = "elevThrSpd",             preset = "SPEED" }

  { id = "horsePowers",             measureType = "hp", presize = 0.1
    canShowForUnit = @(unit) !unit?.isTank() || hasFeature("TankModEffect")
    getLocId = function(_unit, effects) {
      let key = effects?.modifName == "new_tank_transmission" ? "horsePowersTransmission" : "horsePowers"
      return "modification/" + key + "_change"
    }
  }
  { id = "thrust",                 measureType = "kgf", presize = 0.1
    validateValue = @(value) value / KGF_TO_NEWTON
  }
  { id = "cdParasite",             measureType = "kgf", isInverted = true, presize = 0.00001 }
  { id = "speed",                  preset = "SPEED" }
  { id = "climb",                  preset = "CLIMB_SPEED" }
  { id = "roll",                   measureType = "deg_per_sec", measureSeparate = "", presize = 0.1 }
  { id = "virage",                 measureType = "seconds", isInverted = true, presize = 0.1
    validateValue = @(value) fabs(value) < 20.0 ? value : null
  }
  { id = "blackoutG",              measureType = "", presize = 0.01 }
  { id = "redoutG",                measureType = "", presize = 0.01, isInverted = true }

  /****************************** TANK EFFECTS ***********************************************/
  { id = "turnTurretSpeedK",       preset = "PERCENT_FLOAT"
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "gunPitchSpeedK",         preset = "PERCENT_FLOAT"
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "maxInclination",         measureType = "deg", measureSeparate = "",
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
    validateValue = @(value) value * 180.0 / PI
  }
  { id = "maxDeltaAngleK",         preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "maxDeltaAngleVerticalK", preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "maxBrakeForceK",         preset = "PERCENT_FLOAT"
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "suspensionDampeningForceK", preset = "PERCENT_FLOAT"
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "timeToBrake",            measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "distToBrake",            measureType = "meters_alt", isInverted = true, presize = 0.1
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "trackFricFrontalK",      preset = "PERCENT_FLOAT"
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "accelTime",              measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "partHpMult",             preset = "PERCENT_FLOAT"
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "viewDist",               preset = "PERCENT_FLOAT"
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "reloadTime",             measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(_unit) hasFeature("TankModEffect")
  }
  { id = "respawnCost_killScore_exp_fighter",  preset = "TANK_RESPAWN_COST" }
  { id = "respawnCost_killScore_exp_assault", preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_killScore_exp_bomber",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_hitScore_exp_fighter",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_hitScore_exp_assault",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_hitScore_exp_bomber",   preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_scoutScore_exp_fighter", preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_scoutScore_exp_assault", preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_scoutScore_exp_bomber",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_killScore_aircrafts",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_hitScore_aircrafts",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_scoutScore_aircrafts", preset = "TANK_RESPAWN_COST"  }

  { id = "healingTimeMultiplier", preset = "PERCENT_FLOAT" }
  { id = "repairSpeedMultiplier", preset = "PERCENT_FLOAT" }
  { id = "extinguisherReductionTime", measureType = "seconds", presize = 0.1, isInverted = true }
  { id = "extinguisherActivationAdditionalCount", preset = "COLORED_PLURAL_VALUE" }
  { id = "medicalkitAdditionalCount", preset = "COLORED_PLURAL_VALUE" }

  /****************************** SHIP EFFECTS ***********************************************/
  { id = "waterMassVelTime",       measureType = "seconds", isInverted = true, presize = 0.1 }
  { id = "mainSpeedYawK",          preset = "PERCENT_FLOAT" }
  { id = "mainSpeedPitchK",        preset = "PERCENT_FLOAT" }
  { id = "auxSpeedYawK",           preset = "PERCENT_FLOAT" }
  { id = "auxSpeedPitchK",         preset = "PERCENT_FLOAT" }
  { id = "aaSpeedYawK",            preset = "PERCENT_FLOAT" }
  { id = "aaSpeedPitchK",          preset = "PERCENT_FLOAT" }
  { id = "shipDistancePrecision",  measureType = "percent", validateValue = @(value) - 100.0 * value }
  { id = "turnRadius",             preset = "PERCENT_FLOAT", isInverted = true }
  { id = "turnTime",               preset = "PERCENT_FLOAT", isInverted = true }
  { id = "distToLiveTorpedo",      measureType = "meters_alt" }
  { id = "maxSpeedInWaterTorpedo", measureType = "metersPerSecond_climbSpeed" }
  { id = "diveDepthTorpedo",       measureType = "meters_alt", shouldColorByValue = false }
  { id = "speedShip",              preset = "SPEED" }
  { id = "reverseSpeed",           preset = "SPEED" }
  { id = "timeToMaxSpeed",         measureType = "seconds", isInverted = true, presize = 0.1 }
  { id = "timeToMaxReverseSpeed",  measureType = "seconds", isInverted = true, presize = 0.1 }
],
effectTypeConstructor)


/**************************************** WEAPONS EFFECTS ******************************************************/

let weaponEffectsType = {
  types = []
  template = effectTypeTemplate
}

enums.addTypes(weaponEffectsType, [
  { id = "spread",                 measureType = "meters_alt", isInverted = true, presize = 0.1 }
  { id = "overheat",               preset = "PERCENT_FLOAT" }
],
effectTypeConstructor)


/**************************************** FULL DESC GENERATION ******************************************************/

let startTab = ::nbsp + ::nbsp + ::nbsp + ::nbsp
local getEffectsStackFunc = function(unit, effectsConfig, modeId) {
  return function(res, eType) {
    let text = eType.getText(unit, effectsConfig, modeId)
    if (text.len())
      res += "\n" + startTab + text
    return res
  }
}

let function hasNotZeroDiff(effects1, effects2) {
  if (!effects1 || !effects2)
    return false

  foreach (key, value in effects2)
    if (::is_numeric(value) && value != 0 && ::is_numeric(effects1?[key])
        && fabs(effects1[key] / value) <= 100)
      return true
  return false
}

let function hasNotZeroDiffSublist(list1, list2) {
  if (!list1 || !list2)
    return false
  foreach (key, effects in list1)
    if (hasNotZeroDiff(effects, list2?[key]))
      return true
  return false
}

let function prepareCalculationParams(_unit, effects, modeId) {
  upgradesKeys.clear()
  foreach (key in UPGRADES_ORDER)
    if (hasNotZeroDiff(effects, effects?[key])
        || hasNotZeroDiff(effects?[modeId], effects?[key]?[modeId])
        || hasNotZeroDiffSublist(effects?.weaponMods, effects?[key]?.weaponMods))
      upgradesKeys.append(key)
  needToShowDiff = upgradesKeys.len() > 0 && hasFeature("ModUpgradeDifference")
}

let DESC_PARAMS = { needComment = true, curEdiff = null }
local function getDesc(unit, effects, p = DESC_PARAMS) {
  p = DESC_PARAMS.__merge(p)

  let modeId = (p.curEdiff != null
    ? ::get_difficulty_by_ediff(p.curEdiff)
    : ::get_current_shop_difficulty()).crewSkillName
  prepareCalculationParams(unit, effects, modeId)

  local res = ""
  local desc = effectsType.types.reduce(getEffectsStackFunc(unit, effects, modeId), "")
  if (desc != "")
    res = "\n" + loc("modifications/specs_change") + loc("ui/colon") + desc

  if ("weaponMods" in effects)
    foreach (idx, w in effects.weaponMods) {
      w.withLevel     <- effects?.withLevel?.weaponMods?[idx] ?? {}
      w.withOverdrive <- effects?.withOverdrive?.weaponMods?[idx] ?? {}

      desc = weaponEffectsType.types.reduce(getEffectsStackFunc(unit, w, modeId), "")
      if (desc.len())
        res += "\n" + loc(w.name) + loc("ui/colon") + desc
    }

  if (p.needComment && res != "")
    res += "\n" + "<color=@fadedTextColor>" + loc("weaponry/modsEffectsNotification") + "</color>"
  return res
}

return {
  getDesc = getDesc //(unit, effects)  //eefects - is effects table generated by calculate_mod_or_weapon_effect
}