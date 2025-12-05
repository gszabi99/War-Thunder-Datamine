from "%scripts/dagui_natives.nut" import is_gun_vertical_convergence_allowed
from "%scripts/dagui_library.nut" import *
from "weaponryOptions" import get_option_torpedo_dive_depth_auto
from "%scripts/controls/controlsConsts.nut" import optionControlType
from "%scripts/respawn/respawnConsts.nut" import RespawnOptUpdBit
from "radarOptions" import get_radar_mode_names, set_option_radar_name, get_radar_scan_pattern_names, set_option_radar_scan_pattern_name, get_radar_range_values
from "%scripts/options/optionsCtors.nut" import create_option_list

let enums = require("%sqStdLibs/helpers/enums.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getCurrentPreset, bombNbr, hasCountermeasures, hasBombDelayExplosion } = require("%scripts/unit/unitWeaponryInfo.nut")
let { isTripleColorSmokeAvailable } = require("%scripts/options/optionsManager.nut")
let { getSkinsOption } = require("%scripts/customization/skins.nut")
let { USEROPT_USER_SKIN, USEROPT_GUN_TARGET_DISTANCE, USEROPT_AEROBATICS_SMOKE_TAIL_COLOR,
  USEROPT_GUN_VERTICAL_TARGETING, USEROPT_BOMB_ACTIVATION_TIME, USEROPT_BOMB_SERIES,
  USEROPT_DEPTHCHARGE_ACTIVATION_TIME, USEROPT_ROCKET_FUSE_DIST, USEROPT_TORPEDO_DIVE_DEPTH,
  USEROPT_LOAD_FUEL_AMOUNT, USEROPT_COUNTERMEASURES_PERIODS, USEROPT_COUNTERMEASURES_SERIES,
  USEROPT_COUNTERMEASURES_SERIES_PERIODS, USEROPT_AEROBATICS_SMOKE_TYPE, USEROPT_SKIN,
  USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, USEROPT_FUEL_AMOUNT_CUSTOM,
  USEROPT_RADAR_MODE_SELECTED_UNIT_SELECT, USEROPT_RADAR_SCAN_PATTERN_SELECTED_UNIT_SELECT,
  USEROPT_INFANTRY_SKIN,
  USEROPT_RADAR_SCAN_RANGE_SELECTED_UNIT_SELECT, USEROPT_SAVE_AIRCRAFT_SPAWN
} = require("%scripts/options/optionsExtNames.nut")
let { isSkinBanned } = require("%scripts/customization/bannedSkins.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let respawnBases = require("%scripts/respawn/respawnBases.nut")
let { getInfantrySkinOnLocation, getLocationInfantrySkins, getTierByMrank,
  hasSkinsForLocation
} = require("%scripts/customization/infantryCamouflageStorage.nut")
let { convertLevelNameToLocation, getInfantrySkinTooltip, getCamoNameById
} = require("%scripts/customization/infantryCamouflageUtils.nut")


let options = {
  types = []
  cache = {
    byUserOptionId = {}
  }
  function getByUserOptionId(userOptionId) {
    return enums.getCachedType("userOption", userOptionId, this.cache.byUserOptionId, this, this.unknown)
  }
}

let _isVisible = @(p) p.unit != null
  && this.isAvailableInMission()
  && this.isShowForUnit(p)

let _isNeedUpdateByTrigger = @(trigger) this.isAvailableInMission() && (trigger & this.triggerUpdateBitMask) != 0
let _isNeedUpdContentByTrigger = @(trigger, _p) (trigger & this.triggerUpdContentBitMask) != 0

function hasRadarOptions(name, weapName) {
  let radarModesCount = get_radar_mode_names(name, weapName).len()
  return hasFeature("allowRadarModeOptions") && radarModesCount > 0
    && (radarModesCount > 1
      || get_radar_scan_pattern_names(name, weapName).len() > 1
      || get_radar_range_values(name, weapName).len() > 1)
}

function _update(p, trigger, isAlreadyFilled) {
  if (!this.isNeedUpdateByTrigger(trigger))
    return false

  let isShow = this.isVisible(p)
  let isEnable = isShow && p.canChangeAircraft
  let isNeedUpdateContent = !isAlreadyFilled || this.isNeedUpdContentByTrigger(trigger, p)
  local isFilled = false

  let obj = p.handler.scene.findObject(this.id)
  if (obj?.isValid()) {
    obj.enable(isEnable)
    if (isShow) {
      let opt = this.getUseropt(p)
      let objOptionValue = obj.getValue()
      if (isNeedUpdateContent) {
        if (this.cType == optionControlType.LIST) {
          let markup = create_option_list(null, opt.items, opt.value, null, false)
          p.handler.guiScene.replaceContentFromText(obj, markup, markup.len(), p.handler)
        }
        else if (this.cType == optionControlType.SLIDER) {
          obj["min"] = opt.min
          obj["max"] = opt.max
          obj["step"] = opt.step
          local newValue = opt.value

          if(this.userOption == USEROPT_FUEL_AMOUNT_CUSTOM) {
            let loadFuelAmountOpt = get_option(USEROPT_LOAD_FUEL_AMOUNT)
            newValue = loadFuelAmountOpt.values[loadFuelAmountOpt.value]
          }

          if(objOptionValue != newValue)
            obj.setValue(newValue)
        }
        else if (this.cType == optionControlType.CHECKBOX)
          if (objOptionValue != opt.value)
            obj.setValue(opt.value)
        isFilled = true
        if (this.needCallCbOnContentUpdate)
          p.handler?[this.cb].call(p.handler, obj)
      }
      if (this.needCheckValueWhenOptionUpdate && objOptionValue != opt.value)
        obj.setValue(opt.value)
    }
  }

  let rowObj = p.handler.scene.findObject($"{this.id}_tr")
  if (rowObj?.isValid()) {
    rowObj.show(isShow)
  }
  return isFilled
}

function getRespawnBasesIndexBySpawnType(list, spawntype) {
  if (spawntype == "auto")
    return list.findindex(@(v) v.isAutoSelected)
  else if (spawntype == "airfield")
    return list.findindex(@(v) v.isGround && !v.isAutoSelected)
  return list.findindex(@(v) !v.isGround && !v.isAutoSelected)
}

options.template <- {
  id = "" 
  sortId = 0
  getLabelText = @() loc($"options/{this.id}")
  userOption = -1
  triggerUpdateBitMask = 0
  triggerUpdContentBitMask = 0
  cType = optionControlType.LIST
  needSetToReqData = false
  cb = "checkReady"
  needCallCbOnContentUpdate = false

  isAvailableInMission = @() true
  isShowForUnit = @(_p) false
  isVisible = _isVisible
  getUseropt = @(_p) get_option(this.userOption)
  isNeedUpdateByTrigger = _isNeedUpdateByTrigger
  isNeedUpdContentByTrigger = _isNeedUpdContentByTrigger
  update = _update
  tooltipName = null

  needCheckValueWhenOptionUpdate = false 
}

options.addTypes <- function(typesTable) {
  enums.addTypes(this, typesTable, null, "id")
  this.types.sort(@(a, b) a.sortIdx <=> b.sortIdx)
}

local idx = -1
options.addTypes({
  unknown = {
    sortIdx = idx++
    userOption = -1
    isAvailableInMission = @() false
  }
  skin = {
    sortIdx = idx++
    userOption = USEROPT_SKIN
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForUnit = @(_p) true
    tooltipName = "skin_tooltip"
    cb = "onSkinSelect"
    getUseropt = function(p) {
      let skinsOpt = getSkinsOption(p.unit?.name ?? "")
      skinsOpt.items = skinsOpt.items.map(function(v, i) {
        let isBanned = isSkinBanned(skinsOpt.decorators[i].id)
        if(isBanned)
          v.text = colorize("disabledTextColor", v.text)
        return v.__merge({
          tooltipObj = { id = getTooltipType("DECORATION").getTooltipId(skinsOpt.decorators[i].id, UNLOCKABLE_SKIN,
          {
            hideDesignedFor = true
            hideUnlockInfo = true
            isBanned
          })}
        })}
      )
      return skinsOpt
    }
  }
  infantry_skin = {
    sortIdx = idx++
    userOption = USEROPT_INFANTRY_SKIN
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForUnit = @(p) p.unit.isHuman() && hasSkinsForLocation(p.location)
    tooltipName = "infantry_skin_tooltip"
    cb = "onInfantrySkinSelect"
    getUseropt = function(p) {
      let locationName = convertLevelNameToLocation(p.handler.missionTable.level)
      let team = p.handler.mplayerTable.team

      let unit = p.handler.getCurSlotUnit()
      let ediff = p.handler.getCurrentEdiff()
      let unitMRank = unit.getEconomicRank(ediff)
      let tier = getTierByMrank(locationName, team, unitMRank)
      let skins = getLocationInfantrySkins(locationName, team, tier)

      let skinsOpt = {items = [], values = []}
      let curSkin = getInfantrySkinOnLocation(locationName, team, tier, unit.name) ?? skins[0]
      skinsOpt.value <- skins.indexof(curSkin) ?? 0
      foreach (skin in skins) {
        skinsOpt.values.append(skin)
        skinsOpt.items.append({
          text = getCamoNameById(skin)
          textStyle = "textStyle:t='textarea'"
          image = null
          tooltip = getInfantrySkinTooltip(skin)
        })
      }
      return skinsOpt
    }
  }
  user_skins = {
    sortIdx = idx++
    userOption = USEROPT_USER_SKIN
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isAvailableInMission = @() hasFeature("UserSkins")
    isShowForUnit = @(_p) true
  }
  gun_target_dist = {
    sortIdx = idx++
    userOption = USEROPT_GUN_TARGET_DISTANCE
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    needSetToReqData = true
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
  }
  gun_vertical_targeting = {
    sortIdx = idx++
    userOption = USEROPT_GUN_VERTICAL_TARGETING
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    cType = optionControlType.CHECKBOX
    needSetToReqData = true
    isAvailableInMission = @() is_gun_vertical_convergence_allowed()
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
  }
  bomb_activation_time = {
    sortIdx = idx++
    userOption = USEROPT_BOMB_ACTIVATION_TIME
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForUnit = @(p) hasBombDelayExplosion(p.unit)
  }
  bomb_series = {
    sortIdx = idx++
    userOption = USEROPT_BOMB_SERIES
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && bombNbr(p.unit) > 1
  }
  depthcharge_activation_time = {
    sortIdx = idx++
    userOption = USEROPT_DEPTHCHARGE_ACTIVATION_TIME
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    isShowForUnit = @(p) p.unit.isShipOrBoat()
      && p.unit.isDepthChargeAvailable()
      && (getCurrentPreset(p.unit)?.hasDepthCharge ?? false)
  }
  rocket_fuse_dist = {
    sortIdx = idx++
    userOption = USEROPT_ROCKET_FUSE_DIST
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    needCheckValueWhenOptionUpdate = true
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
      && (getCurrentPreset(p.unit)?.hasRocketDistanceFuse ?? false)
  }
  torpedo_dive_depth = {
    sortIdx = idx++
    userOption = USEROPT_TORPEDO_DIVE_DEPTH
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    needCheckValueWhenOptionUpdate = true
    isAvailableInMission = @() !get_option_torpedo_dive_depth_auto()
    isShowForUnit = @(p) (getCurrentPreset(p.unit)?.torpedo ?? false)
  }
  fuel_amount = {
    sortIdx = idx++
    userOption = USEROPT_LOAD_FUEL_AMOUNT
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    needCheckValueWhenOptionUpdate = true
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter())
    cb = "onLoadFuelChange"
  }
  adjustable_fuel_quantity = {
    sortIdx = idx++
    userOption = USEROPT_FUEL_AMOUNT_CUSTOM
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    needCheckValueWhenOptionUpdate = false
    isShowForUnit = @(p) ((p.unit.isAir() || p.unit.isHelicopter()) && getCurMissionRules().getUnitFuelPercent(p.unit.name) == 0)
    cType = optionControlType.SLIDER
    cb = "onLoadFuelCustomChange"
  }

  countermeasures_periods = {
    sortIdx = idx++
    userOption = USEROPT_COUNTERMEASURES_PERIODS
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && hasCountermeasures(p.unit)
  }
  countermeasures_series_periods = {
    sortIdx = idx++
    userOption = USEROPT_COUNTERMEASURES_SERIES_PERIODS
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID
    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && hasCountermeasures(p.unit)
  }
  countermeasures_series = {
    sortIdx = idx++
    userOption = USEROPT_COUNTERMEASURES_SERIES
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.UNIT_WEAPONS
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID

    isShowForUnit = @(p) (p.unit.isAir() || p.unit.isHelicopter()) && hasCountermeasures(p.unit)
  }
  respawn_base = {
    sortIdx = idx++
    userOption = -1
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.RESPAWN_BASES
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.RESPAWN_BASES
    cb = "onRespawnbaseOptionUpdate"
    needCallCbOnContentUpdate = true
    isShowForUnit = @(p) p.haveRespawnBases
    getUseropt = function(p) {
      local value = p.respawnBasesList.indexof(p.curRespawnBase) ?? -1
      let savedSpawnType = p.unit?.isAir() ? respawnBases.getSavedBaseType() : null
      if (savedSpawnType != null)
        value = getRespawnBasesIndexBySpawnType(p.respawnBasesList, savedSpawnType) ?? value
      return {
        items = p.respawnBasesList.map(function(spawn) {
          let res = { text = spawn.getTitle() }
          if (p?.isBadWeatherForAircraft && spawn.isSpawnIsAirfiled())
            res.image <- "#ui/gameuiskin#weather_cloud_lightning.svg"
          return res
        })
        value
      }
    }
    isNeedUpdContentByTrigger = @(trigger, p) _isNeedUpdContentByTrigger(trigger, p) && p.isRespawnBasesChanged

  }
  save_aircraft_spawn = {
    sortIdx = idx++
    userOption = USEROPT_SAVE_AIRCRAFT_SPAWN
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.RESPAWN_BASES
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.RESPAWN_BASES
    cType = optionControlType.CHECKBOX
    needSetToReqData = true
    isShowForUnit = @(p) p.unit.isAir() && p.haveRespawnBases
    cb = "saveSpawnForMission"
  }
  aerobatics_smoke_type = {
    sortIdx = idx++
    userOption = USEROPT_AEROBATICS_SMOKE_TYPE
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    cb = "onSmokeTypeUpdate"
    isShowForUnit = @(p) p.unit.isAir()
  }
  aerobatics_smoke_left_color = {
    sortIdx = idx++
    userOption = USEROPT_AEROBATICS_SMOKE_LEFT_COLOR
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.SMOKE_TYPE
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    isShowForUnit = @(p) p.unit.isAir() && isTripleColorSmokeAvailable()
  }
  aerobatics_smoke_right_color = {
    sortIdx = idx++
    userOption = USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.SMOKE_TYPE
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    isShowForUnit = @(p) p.unit.isAir() && isTripleColorSmokeAvailable()
  }
  aerobatics_smoke_tail_color = {
    sortIdx = idx++
    userOption = USEROPT_AEROBATICS_SMOKE_TAIL_COLOR
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_ID | RespawnOptUpdBit.SMOKE_TYPE
    triggerUpdContentBitMask = RespawnOptUpdBit.NEVER
    isShowForUnit = @(p) p.unit.isAir() && isTripleColorSmokeAvailable()
  }
  radar_mode_select = {
    sortIdx = idx++
    userOption = USEROPT_RADAR_MODE_SELECTED_UNIT_SELECT
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_WEAPONS | RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_WEAPONS | RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    needCheckValueWhenOptionUpdate = true
    isShowForUnit = @(p) (hasRadarOptions(p.unit.name, getLastWeapon(p.unit.name)))
    cb="onChangeRadarModeSelectedUnit"
  }
  radar_scan_pattern_select = {
    sortIdx = idx++
    userOption = USEROPT_RADAR_SCAN_PATTERN_SELECTED_UNIT_SELECT
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_WEAPONS | RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_WEAPONS | RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    needCheckValueWhenOptionUpdate = true
    isShowForUnit = @(p) (hasRadarOptions(p.unit.name, getLastWeapon(p.unit.name)))
    cb="onChangeRadarScanRangeSelectedUnit"
  }
  radar_scan_range_select = {
    sortIdx = idx++
    userOption = USEROPT_RADAR_SCAN_RANGE_SELECTED_UNIT_SELECT
    triggerUpdateBitMask = RespawnOptUpdBit.UNIT_WEAPONS | RespawnOptUpdBit.UNIT_ID
    triggerUpdContentBitMask = RespawnOptUpdBit.UNIT_WEAPONS | RespawnOptUpdBit.UNIT_ID
    needSetToReqData = true
    needCheckValueWhenOptionUpdate = true
    isShowForUnit = @(p) (hasRadarOptions(p.unit.name, getLastWeapon(p.unit.name)))
  }
})

options.get <- @(id) this?[id] ?? this.unknown

return options
