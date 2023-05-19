//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock  = require("DataBlock")
let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let { eachBlock } = require("%sqstd/datablock.nut")
let time = require("%scripts/time.nut")
let { PI, round, roundToDigits } = require("%sqstd/math.nut")
let { getUnitRole, getUnitBasicRole, getRoleText, getUnitTooltipImage,
  getFullUnitRoleText, getShipMaterialTexts } = require("%scripts/unit/unitInfoTexts.nut")
let { countMeasure } = require("%scripts/options/optionsMeasureUnits.nut")
let { getWeaponInfoText } = require("%scripts/weaponry/weaponryDescription.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { isBullets, getModificationInfo, getModificationName } = require("%scripts/weaponry/bulletsInfo.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getUnitMassPerSecValue, getUnitWeaponPresetsCount } = require("%scripts/unit/unitWeaponryInfo.nut")

let UNIT_INFO_ARMY_TYPE  = {
  AIR        = unitTypes.AIRCRAFT.bit
  TANK       = unitTypes.TANK.bit
  SHIP       = unitTypes.SHIP.bit
  HELICOPTER = unitTypes.HELICOPTER.bit
  BOAT       = unitTypes.BOAT.bit

  AIR_TANK   = unitTypes.AIRCRAFT.bit | unitTypes.TANK.bit
  AIR_HELICOPTER   = unitTypes.AIRCRAFT.bit | unitTypes.HELICOPTER.bit
  SHIP_BOAT  = unitTypes.SHIP.bit | unitTypes.BOAT.bit
  ALL        = unitTypes.AIRCRAFT.bit | unitTypes.TANK.bit
               | unitTypes.SHIP.bit | unitTypes.HELICOPTER.bit | unitTypes.BOAT.bit
}
enum UNIT_INFO_ORDER{
  TRAIN_COST = 0,
  FREE_REPAIRS,
  FULL_REPAIR_COST,
  FULL_REPAIR_TIME_CREW,
  MAX_SPEED,
  MAX_SPEED_ALT,
  MAX_ALTITUDE,
  TURN_TIME,
  CLIMB_SPEED,
  AIRFIELD_LEN,
  WEAPON_PRESETS,
  MASS_PER_SEC,
  CLIMB_ALT,
  CLIMB_TIME,
  WING_LOADING,
  THRUST_TO_WEIGHT_RATIO,
  POWER_TO_WEIGHT_RATIO,
  MASS,
  HORSE_POWERS,
  HORSE_POWERS_RPM,
  MAX_SPEED_TANK,
  MAX_INCLINATION,
  TURN_TURRET_SPEED,
  MIN_ANGLE_VERTICAL_GUIDANCE,
  MAX_ANGLE_VERTICAL_GUIDANCE,
  ARMOR_THICKNESS_HULL_FRONT,
  ARMOR_THICKNESS_HULL_REAR,
  ARMOR_THICKNESS_HULL_BACK,
  ARMOR_THICKNESS_TURRET_FRONT,
  ARMOR_THICKNESS_TURRET_REAR,
  ARMOR_THICKNESS_TURRET_BACK,
  ARMOR_PIERCING_10,
  ARMOR_PIERCING_100,
  ARMOR_PIERCING_500,
  SHOT_FREQ,
  RELOAD_TIME,
  VISIBILITY,
  WEAPON_PRESET_TANK,
  SHIP_SPEED,
  DISPLACEMENT,
  ARMOR_THICKNESS_CITADEL_FRONT,
  ARMOR_THICKNESS_CITADEL_REAR,
  ARMOR_THICKNESS_CITADEL_BACK,
  ARMOR_THICKNESS_TOWER_FRONT,
  ARMOR_THICKNESS_TOWER_REAR,
  ARMOR_THICKNESS_TOWER_BACK,
  HULL_MATERIAL,
  SUPERSTRUCTURE_MATERIAL,
  WEAPON_INFO_TEXT,
  MODIFICATIONS
}

const UNIT_CONFIGURATION_MIN = "minChars"
const UNIT_CONFIGURATION_MAX = "maxChars"

const COMPARE_MORE_BETTER = "more"
const COMPARE_LESS_BETTER = "less"
const COMPARE_NO_COMPARE = "no"

::g_unit_info_type <- {
  types = []
}

::g_unit_info_type.template <- {
  id = ""
  infoArmyType = UNIT_INFO_ARMY_TYPE.ALL
  headerLocId = null
  getValue = function(_unit)            { return null }
  getValueText = function(value, _unit) {
    if (value == null)
      return null
    return u.isString(value) ? value : toString(value)
  }
  compare = COMPARE_NO_COMPARE
  order = -1
  addToExportTankDataBlock = function(blk, unit, unitConfiguration) {
    blk.value = DataBlock()
    blk.valueText = DataBlock()
    foreach (diff in ::g_difficulty.types)
      if (diff.egdCode != EGD_NONE) {
        let mode = diff.getEgdName()

        let currentParams = unit[unitConfiguration][diff.crewSkillName];
        this.addToExportTankDataBlockValues(blk, currentParams, mode)
      }
  }

  addToExportTankDataBlockValues = function(_blk, _params, _mode) {}

  exportToDataBlock = function(unit, unitConfiguration = UNIT_CONFIGURATION_MIN) {
    let blk = DataBlock()
    if (!(unit.unitType.bit & this.infoArmyType)) {
        blk.hide = true
        return blk
    }
    let value = this.getValue(unit)
    if (value != null)
      blk.value = value
    let valueText = this.getValueText(value, unit)
    if (valueText != null)
      blk.valueText = valueText
    this.addToExportDataBlock(blk, unit, unitConfiguration)
    return blk
  }

  exportCommonToDataBlock = function() {
    let blk = DataBlock()

    if (this.headerLocId)
      blk.header = loc(this.headerLocId)

    blk.compare = this.compare
    blk.order = this.order
    return blk
  }

  addToExportDataBlock = function(_blk, _unit, _unitConfiguration) {} //for unique data to export.
  addToBlkFromParams = function(blk, unit, item, unitConfiguration) {
    blk.value = DataBlock()
    blk.valueText = DataBlock()
    foreach (diff in ::g_difficulty.types)
      if (diff.egdCode != EGD_NONE) {
        let mode = diff.getEgdName()
        let characteristicArr = ::getCharacteristicActualValue(unit, [item.id, item.id2], function(_value) { return "" }, diff.crewSkillName, false)
        blk.value[mode] = unitConfiguration == UNIT_CONFIGURATION_MIN ? characteristicArr[2] : characteristicArr[3]
        blk.valueText[mode] = item.prepareTextFunc(characteristicArr[2])
      }
  }

  addSingleValue = function(blk, _unit, value, valueText) {
    blk.value = DataBlock()
    blk.valueText = DataBlock()
    foreach (diff in ::g_difficulty.types)
      if (diff.egdCode != EGD_NONE) {
        let mode = diff.getEgdName()
        blk.value[mode] = value
        blk.valueText[mode] = valueText
      }
  }
}

enums.addTypesByGlobalName("g_unit_info_type", [
  {
    id = "name"
    getValueText = function(_value, unit) { return ::getUnitName(unit) }
  }
  {
    id = "image"
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      blk.image = getUnitTooltipImage(unit)
      blk.cardImage = ::image_for_air(unit)
      blk.icon = ::getUnitClassIco(unit)
      blk.iconColor = ::get_main_gui_scene().getConstantValue(::getUnitClassColor(unit)) || ""
    }
  }

  {
    id = "role"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_TANK
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
        blk.stringValue = getUnitRole(unit)
    }
    getValueText = function(_value, unit) { return getFullUnitRoleText(unit) }
  }

  {
    id = "role"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
        blk.stringValue = getUnitBasicRole(unit)
    }
    getValueText = function(_value, unit) { return getRoleText(getUnitBasicRole(unit)) }
  }

  {
    id = "tags"
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      foreach (t in unit.tags)
        blk.tag <- t
    }
  }
/*  {
    id = "description"
    getValueText = function(value, unit)
    {
      return loc(format("encyclopedia/%s/desc", unit.name))
    }
  }*/
  {
    id = "battle_rating"
    headerLocId = "shop/battle_rating"
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      blk.value = DataBlock()
      blk.valueText = DataBlock()
      foreach (diff in ::g_difficulty.types)
        if (diff.egdCode != EGD_NONE) {
          let mode = diff.getEgdName()
          blk.value[mode] = unit.getBattleRating(diff.getEdiff())
          blk.valueText[mode] = format("%.1f", blk.value[mode])
        }
    }
  }
  {
    id = "price"
    headerLocId = "ugm/price"
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let valueText = ::getUnitCost(unit).getUncoloredText()
      if (valueText == "") {
          blk.hide = true
          return
      }
      blk.valueText = DataBlock()
      foreach (diff in ::g_difficulty.types)
        if (diff.egdCode != EGD_NONE)
          blk.valueText[diff.getEgdName()] = valueText

      let cost = ::getUnitCost(unit)
      blk.wp = cost.wp
      blk.gold = cost.gold
    }
  }
  {
    id = "wp_bonus"
    getHeader = function(_unit) {
      return loc("reward") + loc("ui/parentheses/space", { text = loc("charServer/chapter/warpoints") }) + ":"
    }
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      blk.value = DataBlock()
      blk.valueText = DataBlock()
      foreach (diff in ::g_difficulty.types)
        if (diff.egdCode != EGD_NONE) {
          let mode = diff.getEgdName()
          let wpMuls = unit.getWpRewardMulList(diff)
          let value = (wpMuls.wpMul * wpMuls.premMul * 100.0 + 0.5).tointeger()
          blk.value[mode] = value
          blk.valueText[mode] = format("%d%%", value)
        }
    }
  }
  {
    id = "exp_bonus"
    getHeader = function(_unit) {
      return loc("reward") + loc("ui/parentheses/space", { text = loc("currency/researchPoints/name") }) + ":"
    }
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let talismanMul = ::isUnitSpecial(unit) ? (::get_ranks_blk()?.goldPlaneExpMul ?? 1.0) : 1.0
      let value = (unit.expMul * talismanMul * 100.0 + 0.5).tointeger()
      if (value == 100) {
        blk.hide = true
        return
      }
      let valueText = format("%d%%", value)
      blk.value = DataBlock()
      blk.valueText = DataBlock()
      foreach (diff in ::g_difficulty.types)
        if (diff.egdCode != EGD_NONE) {
          let mode = diff.getEgdName()
          blk.value[mode] = value
          blk.valueText[mode] = valueText
        }
    }
  }

  {
    id = "train_cost"
    compare = COMPARE_LESS_BETTER
    order = UNIT_INFO_ORDER.TRAIN_COST
    headerLocId = "shop/crew_train_cost"
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = unit.trainCost
      if (value == 0) {
        blk.hide = true
        return
      }
      let valueText = Cost(value).getUncoloredText()
      blk.value = DataBlock()
      blk.valueText = DataBlock()
      foreach (diff in ::g_difficulty.types)
        if (diff.egdCode != EGD_NONE) {
          let mode = diff.getEgdName()
          blk.value[mode] = value
          blk.valueText[mode] = valueText
        }
    }
  }
  {
    id = "full_repair_cost"
    order = UNIT_INFO_ORDER.FULL_REPAIR_COST
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/full_repair_cost"
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      blk.value = DataBlock()
      blk.valueText = DataBlock()

      local costMultiplier = 1.0
      if (unitConfiguration == UNIT_CONFIGURATION_MAX) {
        let mods = ::get_wpcost_blk()?[unit.name]?.modifications
        if (mods != null)
          eachBlock(mods, function(mod, _) {
            costMultiplier += mod?.repairCostCoef ?? 0.0
          })
      }

      foreach (diff in ::g_difficulty.types)
        if (diff.egdCode != EGD_NONE) {
          let mode = diff.getEgdName()
          let field = "repairCost" + mode
          local value = ::get_wpcost_blk()?[unit.name]?[field] ?? 0
          value =  value * (::get_warpoints_blk()?.avgRepairMul ?? 1.0) //avgRepairMul same as in tooltip
          value *= costMultiplier
          blk.value[mode] = value
          blk.valueText[mode] = value ? Cost(value).getUncoloredText() : loc("shop/free")
        }
    }
  }
  {
    id = "free_repairs"
    order = UNIT_INFO_ORDER.FREE_REPAIRS
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/free_repairs"
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      if (::is_default_aircraft(unit.name)) {
        blk.hide = true
        return
      }
      let value = getTblValue("freeRepairs", unit)
      let valueText = toString(value)
      blk.value = DataBlock()
      blk.valueText = DataBlock()
      foreach (diff in ::g_difficulty.types)
        if (diff.egdCode != EGD_NONE) {
          let mode = diff.getEgdName()
          blk.value[mode] = value
          blk.valueText[mode] = valueText
        }
    }
  }
  {
    id = "full_repair_time_crew"
    order = UNIT_INFO_ORDER.FULL_REPAIR_TIME_CREW
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/full_repair_time"
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      blk.value = DataBlock()
      blk.valueText = DataBlock()
      foreach (diff in ::g_difficulty.types)
        if (diff.egdCode != EGD_NONE) {
          let mode = diff.getEgdName()
          let field = "repairTimeHrs" + mode
          let value = ::get_wpcost_blk()?[unit.name]?[field] ?? 0.0
          if (value == 0.0) {
            blk.hide = true
            return
          }
          blk.value[mode] = value
          blk.valueText[mode] = time.hoursToString(value, false)
        }
    }
  }
  {
    id = "weapon_info_text"
    order = UNIT_INFO_ORDER.WEAPON_INFO_TEXT
    getValueText = function(_value, unit) {
      let valueText = DataBlock()
      foreach (diff in ::g_difficulty.types)
        if (diff.egdCode != EGD_NONE)
          valueText[diff.getEgdName()] = getWeaponInfoText(unit.name)
      return valueText
    }
  }
  {
    id = "max_speed"
    order = UNIT_INFO_ORDER.MAX_SPEED
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_speed"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      let item = { id = "maxSpeed", id2 = "speed", prepareTextFunc = @(value) countMeasure(0, value) }
      this.addToBlkFromParams(blk, unit, item, unitConfiguration)
    }
  }
  {
    id = "max_speed_alt"
    order = UNIT_INFO_ORDER.MAX_SPEED_ALT
    headerLocId = "shop/max_speed_alt"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = unit.shop.maxSpeedAlt
      let valueText = countMeasure(1, unit.shop.maxSpeedAlt)
      this.addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "turn_time"
    order = UNIT_INFO_ORDER.TURN_TIME
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/turn_time"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      let item = { id = "turnTime", id2 = "virage", prepareTextFunc = function(value) { return format("%.1f %s", value, loc("measureUnits/seconds")) } }
      this.addToBlkFromParams(blk, unit, item, unitConfiguration)
    }
  }
  {
    id = "climb_speed"
    order = UNIT_INFO_ORDER.CLIMB_SPEED
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_climbSpeed"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER

    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      let item = { id = "climbSpeed", id2 = "climb", prepareTextFunc = @(value) countMeasure(3, value) }
      this.addToBlkFromParams(blk, unit, item, unitConfiguration)
    }
  }
  {
    id = "max_altitude"
    order = UNIT_INFO_ORDER.MAX_ALTITUDE
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_altitude"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER

    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = unit.shop.maxAltitude
      let valueText = countMeasure(1, value)
      this.addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "airfield_len"
    order = UNIT_INFO_ORDER.AIRFIELD_LEN
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/airfieldLen"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER

    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = unit.shop.airfieldLen
      let valueText = countMeasure(1, value)
      this.addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "wing_loading"
    order = UNIT_INFO_ORDER.WING_LOADING
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/wing_loading"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER

    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = unit.shop.wingLoading
      let valueText = value.tostring()
      this.addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "thrust_to_weight_ratio"
    order = UNIT_INFO_ORDER.THRUST_TO_WEIGHT_RATIO
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/thrust_to_weight_ratio"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER

    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      if ("thrustToWeightRatio" in unit.shop) {
        let value = unit.shop.thrustToWeightRatio
        let valueText = value.tostring()
        this.addSingleValue(blk, unit, value, valueText)
      }
    }
  }
  {
    id = "power_to_weight_ratio"
    order = UNIT_INFO_ORDER.POWER_TO_WEIGHT_RATIO
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/power_to_weight_ratio"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR

    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      if ("powerToWeightRatio" in unit.shop) {
        let value = unit.shop.powerToWeightRatio
        let valueText = value.tostring()
        this.addSingleValue(blk, unit, value, valueText)
      }
    }
  }
  {
    id = "climb_alt"
    order = UNIT_INFO_ORDER.CLIMB_ALT
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/climb_alt"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER

    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = unit.shop.climbAlt
      let valueText = countMeasure(1, value)
      this.addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "climb_time"
    order = UNIT_INFO_ORDER.CLIMB_ALT
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/climb_time"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_HELICOPTER

    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = unit.shop.climbTime
      let valueText = format("%.1f %s", value, loc("measureUnits/seconds"))
      this.addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "weapon_presets"
    order = UNIT_INFO_ORDER.WEAPON_PRESETS
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/weaponPresets"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = getUnitWeaponPresetsCount(unit)
      let valueText = value.tostring()
      this.addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "mass_per_sec"
    order = UNIT_INFO_ORDER.MASS_PER_SEC
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/massPerSec"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let massPerSecValue = getUnitMassPerSecValue(unit)
      let valueText = massPerSecValue == 0 ? "" : format("%.2f %s", massPerSecValue, loc("measureUnits/kgPerSec"))
      this.addSingleValue(blk, unit, massPerSecValue, valueText)
    }
  }
  {
    id = "mass"
    order = UNIT_INFO_ORDER.MASS
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/tank_mass"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      let item = { id = "mass", id2 = "mass", prepareTextFunc = function(value) { return format("%.1f %s", (value / 1000.0), loc("measureUnits/ton")) } }
      this.addToBlkFromParams(blk, unit, item, unitConfiguration)
    }
  }
  {
    id = "horse_powers"
    order = UNIT_INFO_ORDER.HORSE_POWERS
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/horsePowers"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
        let horsePowers = params.horsePowers;
        let horsePowersRPM = params.maxHorsePowersRPM;

        blk.value[mode] = horsePowers
        blk.valueText[mode] = format("%s %s %d %s",
          ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(horsePowers),
          loc("shop/unitValidCondition"), horsePowersRPM.tointeger(), loc("measureUnits/rpm"))
    }

    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "horse_powers_rpm"
    order = UNIT_INFO_ORDER.HORSE_POWERS_RPM
    compare = COMPARE_NO_COMPARE
    headerLocId = "shop/horsePowers"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
        let horsePowersRPM = params.maxHorsePowersRPM.tointeger()

        blk.value[mode] = horsePowersRPM
        blk.valueText[mode] = horsePowersRPM.tostring()
    }

    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "max_speed_tank"
    order = UNIT_INFO_ORDER.MAX_SPEED_TANK
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_speed"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      let item = { id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value) }
      this.addToBlkFromParams(blk, unit, item, unitConfiguration)
    }
  }
  {
    id = "max_inclination"
    order = UNIT_INFO_ORDER.MAX_INCLINATION
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_inclination"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      let item = { id = "maxInclination", id2 = "maxInclination", prepareTextFunc = function(value) { return format("%d%s", (value * 180.0 / PI).tointeger(), loc("measureUnits/deg")) } }
      this.addToBlkFromParams(blk, unit, item, unitConfiguration)
    }
  }
  {
    id = "turn_turret_speed"
    order = UNIT_INFO_ORDER.TURN_TURRET_SPEED
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/turnTurretTime"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      let item = { id = "turnTurretTime", id2 = "turnTurretSpeed", prepareTextFunc = function(value) { return format("%.1f%s", value.tofloat(), loc("measureUnits/deg_per_sec")) } }
      this.addToBlkFromParams(blk, unit, item, unitConfiguration)
    }
  }
  {
    id = "min_angle_vertical_guidance"
    order = UNIT_INFO_ORDER.MIN_ANGLE_VERTICAL_GUIDANCE
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/angleVerticalGuidance"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      let angles = params.angleVerticalGuidance;
      blk.value[mode] = angles[0].tointeger()
      blk.valueText[mode] = format("%d%s", angles[0].tointeger(), loc("measureUnits/deg"))
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "max_angle_vertical_guidance"
    order = UNIT_INFO_ORDER.MAX_ANGLE_VERTICAL_GUIDANCE
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/angleVerticalGuidance"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      let angles = params.angleVerticalGuidance;
      blk.value[mode] = angles[1].tointeger()
      blk.valueText[mode] = format("%d%s", angles[1].tointeger(), loc("measureUnits/deg"))
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "armor_thickness_hull_front"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_HULL_FRONT
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessHull"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      let thickness = params.armorThicknessHull;
      blk.value[mode] = thickness[0].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[0].tointeger(), loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "armor_thickness_hull_rear"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_HULL_REAR
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessHull"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      let thickness = params.armorThicknessHull;
      blk.value[mode] = thickness[1].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[1].tointeger(), loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "armor_thickness_hull_back"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_HULL_BACK
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessHull"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      let thickness = params.armorThicknessHull;
      blk.value[mode] = thickness[2].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[2].tointeger(), loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "armor_thickness_turret_front"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TURRET_FRONT
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessTurret"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      let thickness = params.armorThicknessTurret;
      blk.value[mode] = thickness[0].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[0].tointeger(), loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "armor_thickness_turret_rear"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TURRET_REAR
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessTurret"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      let thickness = params.armorThicknessTurret;
      blk.value[mode] = thickness[1].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[1].tointeger(), loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "armor_thickness_turret_back"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TURRET_BACK
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessTurret"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      let thickness = params.armorThicknessTurret;
      blk.value[mode] = thickness[2].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[2].tointeger(), loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "armor_piercing_10"
    order = UNIT_INFO_ORDER.ARMOR_PIERCING_10
    compare = COMPARE_MORE_BETTER
    getHeader = function(_unit) {
      return format("%s (%s 10 %s)", loc("shop/armorPiercing"), loc("shop/armorPiercingDist"), loc("measureUnits/meters_alt"))
    }
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      if (blk?.hide ?? false)
        return
      let armorPiercing = params.armorPiercing;
      if (armorPiercing.len() > 2) {
        let val = round(armorPiercing[0]).tointeger()
        blk.value[mode] = val
        blk.valueText[mode] = format("%d %s", val, loc("measureUnits/mm"))
      }
      else {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "armor_piercing_100"
    order = UNIT_INFO_ORDER.ARMOR_PIERCING_100
    compare = COMPARE_MORE_BETTER
    getHeader = function(_unit) {
      return format("%s (%s 100 %s)", loc("shop/armorPiercing"), loc("shop/armorPiercingDist"), loc("measureUnits/meters_alt"))
    }
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      if (blk?.hide ?? false)
        return
      let armorPiercing = params.armorPiercing;
      if (armorPiercing.len() > 2) {
        let val = round(armorPiercing[1]).tointeger()
        blk.value[mode] = val
        blk.valueText[mode] = format("%d %s", val, loc("measureUnits/mm"))
      }
      else {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "armor_piercing_500"
    order = UNIT_INFO_ORDER.ARMOR_PIERCING_500
    compare = COMPARE_MORE_BETTER
    getHeader = function(_unit) {
      return format("%s (%s 500 %s)", loc("shop/armorPiercing"), loc("shop/armorPiercingDist"), loc("measureUnits/meters_alt"))
    }

    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      if (blk?.hide ?? false)
        return
      let armorPiercing = params.armorPiercing;
      if (armorPiercing.len() > 2) {
        let val = round(armorPiercing[2]).tointeger()
        blk.value[mode] = val
        blk.valueText[mode] = format("%d %s", val, loc("measureUnits/mm"))
      }
      else {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "shot_freq"
    order = UNIT_INFO_ORDER.SHOT_FREQ
    headerLocId = "shop/shotFreq"
    compare = COMPARE_MORE_BETTER
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      if (blk?.hide ?? false)
        return
      let shotFreq = params.shotFreq;
      if (shotFreq > 0) {
        let perMinute = roundToDigits(shotFreq * 60, 3)
        blk.value[mode] = perMinute
        blk.valueText[mode] = format("%s %s", perMinute.tostring(), loc("measureUnits/shotPerMinute"))
      }
      else {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "reload_time"
    order = UNIT_INFO_ORDER.RELOAD_TIME
    headerLocId = "bullet_properties/cooldown"
    getHeader = function(_unit) {
      return format("%s:", loc("bullet_properties/cooldown"))
    }
    compare = COMPARE_LESS_BETTER
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      if (blk?.hide ?? false)
        return
      let reloadTime = params.reloadTime;
      if (reloadTime > 0) {
        blk.value[mode] = reloadTime
        blk.valueText[mode] = format("%.1f %s", reloadTime, loc("measureUnits/seconds"))
      }
      else {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "weapon_presets_tank"
    order = UNIT_INFO_ORDER.WEAPON_PRESET_TANK
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/weaponPresets"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = getUnitWeaponPresetsCount(unit)
      let valueText = value.tostring()
      this.addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "visibility"
    order = UNIT_INFO_ORDER.VISIBILITY
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/visibilityFactor"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode) {
      if (blk?.hide ?? false)
        return
      if (!("visibilityFactor" in params) || params.visibilityFactor <= 0) {
        blk.hide = true
      }
      else {
        let visibilityFactor = params.visibilityFactor
        blk.value[mode] = visibilityFactor
        blk.valueText[mode] = format("%d %%", visibilityFactor)
      }

    }
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      this.addToExportTankDataBlock(blk, unit, unitConfiguration)
    }
  }
  {
    id = "displacement"
    order = UNIT_INFO_ORDER.DISPLACEMENT
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/displacement"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = ::get_full_unit_blk(unit.name)?.ShipPhys?.mass?.TakeOff
      local valueText = ""
      if (value != null) {
        valueText = ::g_measure_type.SHIP_DISPLACEMENT_TON.getMeasureUnitsText(value / 1000, true)
        this.addSingleValue(blk, unit, value, valueText)
      }
      else {
        blk.hide = true
      }
    }
  }

  {
    id = "ship_speed"
    order = UNIT_INFO_ORDER.SHIP_SPEED
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_speed"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, unitConfiguration) {
      let item = { id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value) }
      this.addToBlkFromParams(blk, unit, item, unitConfiguration)
    }
  }
  {
    id = "armor_thickness_citadel_front"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_CITADEL_FRONT
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/citadelArmor"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let armorThicknessCitadel = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessCitadel

      if (armorThicknessCitadel != null) {
        let value = round(armorThicknessCitadel.x).tointeger()
        let valueText =  format("%d %s", value, loc("measureUnits/mm"))
        this.addSingleValue(blk, unit, value, valueText)
      }
      else {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_citadel_rear"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_CITADEL_REAR
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/citadelArmor"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let armorThicknessCitadel = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessCitadel

      if (armorThicknessCitadel != null) {
        let value = round(armorThicknessCitadel.y).tointeger()
        let valueText =  format("%d %s", value, loc("measureUnits/mm"))
        this.addSingleValue(blk, unit, value, valueText)
      }
      else {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_citadel_back"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_CITADEL_BACK
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/citadelArmor"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let armorThicknessCitadel = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessCitadel

      if (armorThicknessCitadel != null) {
        let value = round(armorThicknessCitadel.z).tointeger()
        let valueText =  format("%d %s", value, loc("measureUnits/mm"))
        this.addSingleValue(blk, unit, value, valueText)
      }
      else {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_tower_front"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TOWER_FRONT
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/mainFireTower"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let armorThicknessMainFireTower = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessTurretMainCaliber

      if (armorThicknessMainFireTower != null) {
        let value = round(armorThicknessMainFireTower.x).tointeger()
        let valueText =  format("%d %s", value, loc("measureUnits/mm"))
        this.addSingleValue(blk, unit, value, valueText)
      }
      else {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_tower_rear"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TOWER_REAR
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/mainFireTower"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let armorThicknessMainFireTower = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessTurretMainCaliber

      if (armorThicknessMainFireTower != null) {
        let value = round(armorThicknessMainFireTower.y).tointeger()
        let valueText =  format("%d %s", value, loc("measureUnits/mm"))
        this.addSingleValue(blk, unit, value, valueText)
      }
      else {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_tower_back"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TOWER_BACK
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/mainFireTower"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let armorThicknessMainFireTower = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessTurretMainCaliber

      if (armorThicknessMainFireTower != null) {
        let value = round(armorThicknessMainFireTower.z).tointeger()
        let valueText =  format("%d %s", value, loc("measureUnits/mm"))
        this.addSingleValue(blk, unit, value, valueText)
      }
      else {
        blk.hide = true
      }
    }
  }
  {
    id = "hull_material"
    order = UNIT_INFO_ORDER.HULL_MATERIAL
    compare = COMPARE_NO_COMPARE
    headerLocId = "info/ship/part/hull"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = (::get_wpcost_blk()?[unit.name]?.Shop?.hullThickness ?? 0).tointeger()
      let valueText = getShipMaterialTexts(unit.name)?.hullValue ?? ""
      if (valueText != "")
        this.addSingleValue(blk, unit, value, valueText)
      else
        blk.hide = true
    }
  }
  {
    id = "superstructure_material"
    order = UNIT_INFO_ORDER.SUPERSTRUCTURE_MATERIAL
    compare = COMPARE_NO_COMPARE
    headerLocId = "info/ship/part/superstructure"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP_BOAT
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let value = (::get_wpcost_blk()?[unit.name]?.Shop?.superstructureThickness ?? 0).tointeger()
      let valueText = getShipMaterialTexts(unit.name)?.superstructureValue ?? ""
      if (valueText != "")
        this.addSingleValue(blk, unit, value, valueText)
      else
        blk.hide = true
    }
  }
  {
    id = "require"
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      if (unit.reqAir == null || unit.reqAir == "")
        blk.hide = true
      else
        blk.value = unit.reqAir
    }
  }
  {
    id = "modifications"
    addToExportDataBlock = function(blk, unit, _unitConfiguration) {
      let mods = ::get_wpcost_blk()?[unit.name]?.modifications
      if (mods != null)
        eachBlock(mods, function(_, mod_id) {
          blk[mod_id] = DataBlock()
          blk[mod_id].name <- getModificationName(unit, mod_id)
          blk[mod_id].desc <- getModificationInfo(unit, mod_id).desc
          let mod_info = getModificationByName(unit, mod_id)
          blk[mod_id].isBullets <- isBullets(mod_info)
        })
    }
  }
])

return {
  UNIT_CONFIGURATION_MIN,
  UNIT_CONFIGURATION_MAX
}