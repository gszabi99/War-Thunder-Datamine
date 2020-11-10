local enums = require("sqStdLibs/helpers/enums.nut")
local string = require("std/string.nut")
local stdMath = require("std/math.nut")
local countMeasure = require("scripts/options/optionsMeasureUnits.nut").countMeasure
local { KGF_TO_NEWTON } = require("scripts/weaponry/weaponryInfo.nut")

const GOOD_COLOR = "@goodTextColor"
const BAD_COLOR = "@badTextColor"
const NEUTRAL_COLOR = "@activeTextColor"

const MEASURE_UNIT_SPEED = 0
const MEASURE_UNIT_ALT = 1
const MEASURE_UNIT_CLIMB_SPEED = 3


/**************************************** CACHED PARAMS FOR SINLGE CALCULATION ******************************************************/
local UPGRADES_ORDER = ["withLevel", "withOverdrive"] //const
local upgradesKeys = []
local needToShowDiff = false


/**************************************** EFFECTS PRESETS ******************************************************/

local presetsList = {
  SPEED = {
    measureType = MEASURE_UNIT_SPEED
    validateValue = @(value) ::fabs(value) * 3.6 > 0.1 ? value : null
    presize = 0.1
  }
  CLIMB_SPEED = {
    measureType = MEASURE_UNIT_CLIMB_SPEED
    validateValue = @(value) ::fabs(value) > 0.1 ? value : null
  }
  PERCENT_FLOAT = {
    measureType = "percent"
    validateValue = @(v) 100.0 * v
  }
  TANK_RESPAWN_COST = {
    measureType = "percent"
    validateValue = @(v) 100.0 * v
    isInverted = true
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
    getText = function (unit, effects, modeId)
    {
      if (!canShowForUnit(unit))
        return ""
      local value = getValue(unit, effects, modeId)
      local value2 = effects?[modeId]?[id+"_base"]
      if (value2 != null)
        value2 = validateValue(value2)
      if (value != null && value2 != null)
        return ::loc(getLocId(unit, effects),
                  {
                    valueWithMod = valueToString(value),
                    valueWithoutMod = valueToString(value2)
                  })
      return ""
    }
  }
  COLORED_PLURAL_VALUE = {
    getText = function (unit, effects, modeId)
    {
      if (!canShowForUnit(unit))
        return ""
      local value = getValue(unit, effects, modeId)
      if (value != null)
        return ::loc(getLocId(unit, effects),
                  {
                    value = value,
                    valueColored = valueToString(value)
                  })
      return ""
    }
  }
}


/**************************************** EFFECT TEMPLATE ******************************************************/

local effectTypeTemplate = {
  id = ""
  measureType = ""
  presize = 1
  shouldColorByValue = true
  isInverted = false //when isInverted, negative values are better than positive
  preset = null //set of parameter to override on type creation

  getLocId = @(unit, effects) "modification/" + id + "_change"
  validateValue = @(value) value  //return null if no need to show effect
  canShowForUnit = @(unit) true

  valueToString = function(value, needAdditionToZero = false)
  {
    local res = ""
    if (!::u.isString(measureType))
      res = countMeasure(measureType, value)
    else
      res = string.floatToStringRounded(stdMath.round_by_value(value, presize), presize)
        + (measureType.len() ? ::loc("measureUnits/" + measureType) : "")

    if (value > 0 || (needAdditionToZero && value == 0))
      res = "+" + res
    if (value != 0)
      res = ::colorize(
        !shouldColorByValue ? NEUTRAL_COLOR
          : (value < 0 == isInverted) ? GOOD_COLOR
          : BAD_COLOR,
        res)
    return res
  }

  getValuePart = function(unit, effects, modeId)
  {
    local value = effects?[modeId]?[id] ?? effects?[id]
    if (value == null)
      return value
    value = validateValue(value)
    return value
  }

  getValue = function(unit, effects, modeId)
  {
    local res = getValuePart(unit, effects, modeId)
    if (res == null)
      return res
    foreach(key in upgradesKeys)
    {
      local value = getValuePart(unit, effects?[key], modeId)
      if (value != null)
        res += value
    }
    return ::fabs(res / presize) > 0.5 ? res : null
  }

  getText = function(unit, effects, modeId)
  {
    if (!canShowForUnit(unit))
      return ""
    local value = getValue(unit, effects, modeId)
    if (value == null)
      return ""

    local res = ::format(::loc(getLocId(unit, effects)), valueToString(value))
    if (!needToShowDiff)
      return res

    local hasAddValues = false
    local addValueText = ""
    foreach(key in upgradesKeys)
    {
      local addVal = getValuePart(unit, effects?[key], modeId) ?? 0.0
      hasAddValues = hasAddValues || addVal != 0
      addValueText += " " + valueToString(addVal, true)
    }
    if (!hasAddValues)
      return res

    addValueText = valueToString(getValuePart(unit, effects, modeId) ?? 0.0) + addValueText
    res += ::loc("ui/parentheses/space", { text = addValueText })

    return res
  }
}

local function effectTypeConstructor()
{
  if (preset in presetsList)
    foreach(key, value in presetsList[preset])
      this[key] <- value
}


/**************************************** USUAL EFFECTS ******************************************************/

local effectsType = {
  types = []
  template = effectTypeTemplate
}

enums.addTypes(effectsType, [
  { id = "armor",                  measureType = "percent" }
  { id = "cutProbability",         measureType = "percent" }
  { id = "overheadCooldown",       measureType = "percent", isInverted = true }
  { id = "mass",                   measureType = "kg", isInverted = true, presize = 0.1
    validateValue = @(value) ::fabs(value) > 0.5 ? value : null
  }
  { id = "oswalds",                measureType = "percent", presize = 0.001 }
  { id = "cdMinFusel",             measureType = "percent", presize = 0.01, isInverted = true }
  { id = "cdMinTail",              measureType = "percent", presize = 0.01, isInverted = true }
  { id = "cdMinWing",              measureType = "percent", presize = 0.01, isInverted = true }

  { id = "ailThrSpd",              preset = "SPEED" }
  { id = "ruddThrSpd",             preset = "SPEED" }
  { id = "elevThrSpd",             preset = "SPEED" }

  { id = "horsePowers",             measureType = "hp", presize = 0.1
    canShowForUnit = @(unit) !unit?.isTank() || ::has_feature("TankModEffect")
    getLocId = function(unit, effects) {
      local key = effects?.modifName == "new_tank_transmission" ? "horsePowersTransmission" : "horsePowers"
      return "modification/" + key + "_change"
    }
  }
  { id = "thrust",                 measureType = "kgf", presize = 0.1
    validateValue = @(value) value / KGF_TO_NEWTON
  }
  { id = "cdParasite",             measureType = "kgf", isInverted = true, presize = 0.00001 }
  { id = "speed",                  preset = "SPEED" }
  { id = "climb",                  preset = "CLIMB_SPEED" }
  { id = "roll",                   measureType = "deg_per_sec", presize = 0.1 }
  { id = "virage",                 measureType = "seconds", isInverted = true, presize = 0.1
    validateValue = @(value) fabs(value) < 20.0 ? value : null
  }
  { id = "blackoutG",              measureType = "", presize = 0.01 }
  { id = "redoutG",                measureType = "", presize = 0.01, isInverted = true }

  /****************************** TANK EFFECTS ***********************************************/
  { id = "turnTurretSpeedK",       preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "gunPitchSpeedK",         preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "maxInclination",         measureType = "deg"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
    validateValue = @(value) value * 180.0 / PI
  }
  { id = "maxDeltaAngleK",         preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "maxDeltaAngleVerticalK", preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "maxBrakeForceK",         preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "suspensionDampeningForceK", preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "timeToBrake",            measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "distToBrake",            measureType = "meters_alt", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "trackFricFrontalK",      preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "accelTime",              measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "partHpMult",             preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "viewDist",               preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "reloadTime",             measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
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
  { id = "waterMassVelTime",       measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "mainSpeedYawK",          preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "mainSpeedPitchK",        preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "auxSpeedYawK",           preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "auxSpeedPitchK",         preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "aaSpeedYawK",            preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "aaSpeedPitchK",          preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "shipDistancePrecision",  measureType = "percent"
    canShowForUnit = @(unit) ::has_feature("Ships")
    validateValue = @(value) -100.0 * value
  }
  { id = "turnRadius",             preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "turnTime",               preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "distToLiveTorpedo",      measureType = "meters_alt"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "maxSpeedInWaterTorpedo", measureType = "metersPerSecond_climbSpeed"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "diveDepthTorpedo",       measureType = "meters_alt", shouldColorByValue = false
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "speedShip",              preset = "SPEED"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "reverseSpeed",           preset = "SPEED"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "timeToMaxSpeed",         measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "timeToMaxReverseSpeed",  measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
],
effectTypeConstructor)


/**************************************** WEAPONS EFFECTS ******************************************************/

local weaponEffectsType = {
  types = []
  template = effectTypeTemplate
}

enums.addTypes(weaponEffectsType, [
  { id = "spread",                 measureType = "meters_alt", isInverted = true, presize = 0.1 }
  { id = "overheat",               preset = "PERCENT_FLOAT" }
],
effectTypeConstructor)


/**************************************** FULL DESC GENERATION ******************************************************/

local startTab = ::nbsp + ::nbsp + ::nbsp + ::nbsp
local getEffectsStackFunc = function(unit, effectsConfig, modeId)
{
  return function(res, eType) {
    local text = eType.getText(unit, effectsConfig, modeId)
    if (text.len())
      res += "\n" + startTab + text
    return res
  }
}

local function hasNotZeroDiff(effects1, effects2)
{
  if (!effects1 || !effects2)
    return false

  foreach(key, value in effects2)
    if (::is_numeric(value) && value != 0 && ::is_numeric(effects1?[key])
        && fabs(effects1[key] / value) <= 100)
      return true
  return false
}

local function hasNotZeroDiffSublist(list1, list2)
{
  if (!list1 || !list2)
    return false
  foreach(key, effects in list1)
    if (hasNotZeroDiff(effects, list2?[key]))
      return true
  return false
}

local function prepareCalculationParams(unit, effects, modeId)
{
  upgradesKeys.clear()
  foreach(key in UPGRADES_ORDER)
    if (hasNotZeroDiff(effects, effects?[key])
        || hasNotZeroDiff(effects?[modeId], effects?[key]?[modeId])
        || hasNotZeroDiffSublist(effects?.weaponMods, effects?[key]?.weaponMods))
      upgradesKeys.append(key)
  needToShowDiff = upgradesKeys.len() > 0 && ::has_feature("ModUpgradeDifference")
}

local DESC_PARAMS = { needComment = true }
local function getDesc(unit, effects, p = DESC_PARAMS)
{
  p = DESC_PARAMS.__merge(p)

  local modeId = ::get_current_shop_difficulty().crewSkillName
  prepareCalculationParams(unit, effects, modeId)

  local res = ""
  local desc = effectsType.types.reduce(getEffectsStackFunc(unit, effects, modeId), "")
  if (desc != "")
    res = "\n" + ::loc("modifications/specs_change") + ::loc("ui/colon") + desc

  if ("weaponMods" in effects)
    foreach(idx, w in effects.weaponMods)
    {
      w.withLevel     <- effects?.withLevel?.weaponMods?[idx] ?? {}
      w.withOverdrive <- effects?.withOverdrive?.weaponMods?[idx] ?? {}

      desc = weaponEffectsType.types.reduce(getEffectsStackFunc(unit, w, modeId), "")
      if (desc.len())
        res += "\n" + ::loc(w.name) + ::loc("ui/colon") + desc
    }

  if(p.needComment && res != "")
    res += "\n" + "<color=@fadedTextColor>" + ::loc("weaponry/modsEffectsNotification") + "</color>"
  return res
}

return {
  getDesc = getDesc //(unit, effects)  //eefects - is effects table generated by calculate_mod_or_weapon_effect
}