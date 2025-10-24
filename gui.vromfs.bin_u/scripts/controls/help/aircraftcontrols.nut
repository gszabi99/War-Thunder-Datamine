from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET

let { isInFlight } = require("gameplayBinding")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { CONTROL_HELP_PATTERN } = require("%scripts/controls/controlsConsts.nut")
let { getUnitWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { TRIGGER_TYPE } = require("%scripts/weaponry/weaponryInfo.nut")
let { isUnitWithRadar, isUnitWithRwr } = require("%scripts/unit/unitWeaponryInfo.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")

let cache = {}

function getAircraftHelpType() {
  let curUnit = getPlayerCurUnit()
  if(curUnit == null)
    return "NORMAL"

  let unitName = curUnit.name
  if(cache?[unitName] != null)
    return cache[unitName]

  if(!curUnit.isAir()) {
    cache[unitName] <- "NORMAL"
    return cache[unitName]
  }

  let weapons = getUnitWeapons(unitName, getFullUnitBlk(unitName))

  local hasAAM = false
  local hasATGM = false

  foreach (weap in weapons) {
    hasAAM = hasAAM || weap.trigger == TRIGGER_TYPE.AAM
    hasATGM = hasATGM || weap.trigger == TRIGGER_TYPE.ATGM || weap.trigger == TRIGGER_TYPE.GUIDED_BOMBS
  }

  if(hasAAM && hasATGM) {
    if(curUnit.tags.indexof("type_fighter") != null)
      cache[unitName] <- "AAM"
    else if(curUnit.tags.indexof("type_assault") != null)
      cache[unitName] <- "ATGM"
    else
      cache[unitName] <- "NORMAL"
    return cache[unitName]
  }
  else if(hasAAM) {
    cache[unitName] <- "AAM"
    return cache[unitName]
  }
  else if(hasATGM) {
    cache[unitName] <- "ATGM"
    return cache[unitName]
  }
  cache[unitName] <- "NORMAL"
  return cache[unitName]
}

let aircraftControls = {
  NORMAL = {
    specificCheck = @() getAircraftHelpType() == "NORMAL"
    subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"
    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE

    checkFeature = unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = "%gui/help/controlsAircraft.blk"
    imagePattern = "#ui/images/country_%s_controls_help?P1"
    defaultValues = { country = "ussr" }
    hasImageByCountries = [ "ussr", "usa", "britain", "germany", "japan", "china", "italy",
      "france", "sweden" ]
    linkLines = {
      obstacles = ["ID_LOCK_TARGET_not_default_0"]
      links = [
        { end = "throttle_value", start = "base_hud_param_label" }
        { end = "real_speed_value", start = "base_hud_param_label" }
        { end = "altitude_value", start = "base_hud_param_label" }
        { end = "throttle_value_2", start = "throttle_and_speed_relaitive_label" }
        { end = "speed_value_2", start = "throttle_and_speed_relaitive_label" }
        { end = "wep_value", start = "wep_description_label" }
        { end = "crosshairs_target_point", start = "crosshairs_label" }
        { end = "target_lead_target_point", start = "target_lead_text_label" }
        { end = "bomb_value", start = "ammo_count_label" }
        { end = "machine_guns_reload_time", start = "weapon_reload_time_label" }
        { end = "cannons_reload_time", start = "weapon_reload_time_label" }
        { end = "bomb_crosshair_target_point", start = "bomb_crosshair_label" }
        { end = "bombs_target_controls_frame_attack_image", start = "bombs_target_text_label" }
        { end = "fire_guns_controls_target_point", start = "fire_guns_controls_frame" }
        { end = "fire_guns_controls_target_point", start = "ID_FIRE_MGUNS_not_default_0" }
      ]
    }
    defaultControlsIds = [ 
      { frameId = "fire_guns_controls_frame", shortcut = "ID_FIRE_MGUNS" }
      { frameId = "lock_target_controls_frame", shortcut = "ID_LOCK_TARGET" }
      { frameId = "zoom_controls_frame", shortcut = "ID_ZOOM_TOGGLE" }
      { frameId = "bombs_controls_frame", shortcut = "ID_BOMBS" }
      { frameId = "throttle_down_controls_frame" }
      { frameId = "throttle_up_controls_frame" }
      { frameId = "throttle_up_controls_frame_2" }
    ]
    moveControlsFrames = function (defaultControls, scene) {
      if (!defaultControls) {
        scene.findObject("target_lead_text_label").pos = "350/1760pw-w, 690/900ph";
        scene.findObject("bombs_target_text_label").pos = "900/1760pw, 280/900ph-h";
        scene.findObject("bombs_target_controls_frame").pos = "898/1760pw, 323/900ph";
      }
      else {
        scene.findObject("target_lead_text_label").pos = "860/1760pw-w, 650/900ph";
        scene.findObject("bombs_target_text_label").pos = "900/1760pw, 355/900ph-h";
        scene.findObject("bombs_target_controls_frame").pos = "898/1760pw, 393/900ph";
      }
    }
  }

  AAM = {
    specificCheck = @() getAircraftHelpType() == "AAM"
    subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"
    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE

    checkFeature = unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = "%gui/help/controlsAircraftAam.blk"
    imagePattern = "#ui/images/help/country_%s_fighter_controls_help?P1"
    defaultValues = { country = "ussr" }
    hasImageByCountries = [ "ussr" ]
    linkLines = {
      obstacles = ["ID_LOCK_TARGET_not_default_0"]
      links = [
        { end = "thr_value", start = "base_info_label" }
        { end = "aam_track_value", start = "base_info_label" }
        { end = "rls_info_value", start = "rls_info_label" }
        { end = "spo_info_value", start = "spo_info_label" }
        { end = "rocket_launch_value", start = "rocket_launch_label" }
      ]
    }
  }

  ATGM = {
    specificCheck = @() getAircraftHelpType() == "ATGM"
    subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE

    checkFeature = unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = "%gui/help/controlsAircraftAtgm.blk"
    imagePattern = "#ui/images/help/country_%s_assault_controls_help?P1"
    defaultValues = { country = "usa" }
    hasImageByCountries = [ "usa" ]
    linkLines = {
      obstacles = ["ID_LOCK_TARGET_not_default_0"]
      links = [
        { end = "thr_value", start = "base_info_label" }
        { end = "aam_track_value", start = "base_info_label" }
        { end = "spo_info_value", start = "spo_info_label" }
        { end = "rocket_launch_value", start = "rocket_launch_label" }
      ]
    }
  }

  RADAR_AIRCRAFT = {
    subTabName = "#radar"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.RADAR

    specificCheck = @() !isInFlight() || isUnitWithRadar(getPlayerCurUnit())
    checkFeature = @() unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = "%gui/help/radarAircraft.blk"
    imagePattern = "#ui/images/help/help_radar_air_%s?P1"
    defaultValues = { country = "usa" }
    hasImageByCountries = [ "usa" ]
    countryRelatedObjs = { usa = [] }
    linkLines = {
      links = [
        { start = "bscope_target_lock_area_label", end = "bscope_target_lock_area_point" }
        { start = "bscope_scan_area_label", end = "bscope_scan_area_point" }
        { start = "bscope_gimbal_limits_label", end = "bscope_gimbal_limits_point" }
        { start = "bscope_active_label", end = "bscope_active_value" }
        { start = "bscope_search_beam_label", end = "bscope_search_beam_point" }
        { start = "bscope_tracking_beam_label", end = "bscope_tracking_beam_point" }
        { start = "bscope_target_detected_label", end = "bscope_target_detected_point" }
        { start = "bscope_target_selected_label", end = "bscope_target_selected_point" }
        { start = "bscope_target_tracking_label", end = "bscope_target_tracking_point" }
        { start = "bscope_range_scale_label", end = "bscope_range_scale_point" }
        { start = "cscope_target_detected_label", end = "cscope_target_detected_point" }
        { start = "cscope_target_selected_label", end = "cscope_target_selected_point" }
        { start = "cscope_target_tracking_label", end = "cscope_target_tracking_point" }
        { start = "cscope_search_beam_label", end = "cscope_search_beam_point" }
        { start = "cscope_scan_area_label", end = "cscope_scan_area_point" }
        { start = "cscope_gimbal_limits_label", end = "cscope_gimbal_limits_point" }
        { start = "cscope_gimbal_limits_x_label", end = "cscope_gimbal_limits_x_value" }
        { start = "cscope_gimbal_limits_y_label", end = "cscope_gimbal_limits_y_value" }
        { start = "compass_target_detected_label", end = "compass_target_detected_point" }
        { start = "compass_target_selected_label", end = "compass_target_selected_point" }
        { start = "compass_target_tracking_label", end = "compass_target_tracking_point" }
        { start = "marker_target_tracking_label", end = "marker_target_tracking_point" }
        { start = "marker_distance_label", end = "marker_distance_value" }
        { start = "marker_approach_speed_label", end = "marker_approach_speed_value" }
        { start = "rwr_enemy_tracking_label", end = "rwr_enemy_tracking_point" }
        { start = "rwr_enemy_detected_label", end = "rwr_enemy_detected_point" }
        { start = "rwr_ally_detected_label", end = "rwr_ally_detected_point" }
      ]
    }
  }
  RWR_AIRCRAFT = {
    subTabName = "#avionics_sensor_rwr"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.RWR

    specificCheck = @() !isInFlight() || isUnitWithRwr(getPlayerCurUnit())
    checkFeature = @() unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = "%gui/help/rwrAircraft.blk"
    imagePattern = "#ui/images/help/help_rwr.avif?P1"
    defaultValues = { country = "ussr" }
    hasImageByCountries = [ "ussr" ]
    countryRelatedObjs = { ussr = [] }
    linkLines = {
      links = [
        { start = "basic_direction_label", end = "basic_direction_point" }
        { start = "basic_types_label", end = "basic_types_point" }
        { start = "mode_track_label", end = "mode_track_1_point" }
        { start = "mode_track_label", end = "mode_track_2_point" }
        { start = "mode_launch_label", end = "mode_launch_1_point" }
        { start = "mode_launch_label", end = "mode_launch_2_point" }
        { start = "target_identified_1_label", end = "target_identified_1_1_point" }
        { start = "target_identified_1_label", end = "target_identified_1_2_point" }
        { start = "target_identified_1_label", end = "target_identified_1_3_point" }
        { start = "target_identified_2_label", end = "target_identified_2_point" }
        { start = "target_unidentified_label", end = "target_unidentified_point" }
        { start = "types_and_modes_label", end = "types_and_modes_point" }
        { start = "direction_precise_label", end = "direction_precise_point" }
        { start = "direction_sector_label", end = "direction_sector_point" }
      ]
    }
  }
}

return aircraftControls