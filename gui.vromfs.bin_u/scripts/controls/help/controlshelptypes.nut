local enums = ::require("sqStdlibs/helpers/enums.nut")
local helpMarkup = require("scripts/controls/help/controlsHelpMarkup.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

local result = {
  types = []

  template = {
    subTabName = ""
    imagePattern = ""
    helpPattern = CONTROL_HELP_PATTERN.NONE

    pageUnitTypeBit = 0 // bit mask
    pageUnitTag = null

    showInSets = []
    checkFeature = @() true
    specificCheck = @() true
    showBySet = @(contentSet) showInSets.indexof(contentSet) != null
    showByUnit = @(unit, unitTag) pageUnitTag == unitTag && (pageUnitTypeBit & (unit?.unitType.bit ?? 0))
    needShow = @(contentSet) showBySet(contentSet)
                             && specificCheck()
                             && checkFeature()
  }
}

local function isUnitWithRadarOrRwr(unit)
{
  local unitBlk = ::get_full_unit_blk(unit?.name ?? "")
  local sensorTypes = [ "radar", "rwr" ]
  if (unitBlk?.sensors)
    foreach (sensor in (unitBlk.sensors % "sensor"))
      if (sensorTypes.indexof(::DataBlock(sensor?.blk ?? "")?.type) != null)
        return true
  return false
}

enums.addTypes(result, {
  MISSION_OBJECTIVES = {
    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.LOADING ]
    helpPattern = CONTROL_HELP_PATTERN.MISSION

    showByUnit = function(unit, unitTag) {
      local difficulty = ::is_in_flight() ? ::get_mission_difficulty_int() : ::get_current_shop_difficulty().diffCode
      local isAdvanced = difficulty == ::DIFFICULTY_HARDCORE
      return !::is_me_newbie() && unitTag == null && !isAdvanced
    }

    specificCheck = @() (::get_game_type_by_mode(::get_game_mode()) & ::GT_VERSUS)
      ? ::g_mission_type.getHelpPathForCurrentMission() != null
      : false

    pageFillfuncName = "fillMissionObjectivesTexts"
  }
  HOTAS4_COMMON = {
    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.HOTAS4

    specificCheck = @() ::check_joystick_thustmaster_hotas(false)
    checkFeature = unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageFillfuncName = "fillHotas4Image"
    pageBlkName = "gui/help/internalHelp.blk"
  }
  IMAGE_AIRCRAFT = {
    subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE

    checkFeature = unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = "gui/help/controlsAircraft.blk"
    imagePattern = "#ui/images/country_%s_controls_help.jpg?P1"
    defaultValues = { country = "ussr" }
    hasImageByCountries = [ "ussr", "usa", "britain", "germany", "japan", "china", "italy",
      "france", "sweden" ]
    linkLines = {
      obstacles = ["ID_LOCK_TARGET_not_default_0"]
      links = [
        {end = "throttle_value", start = "base_hud_param_label"}
        {end = "real_speed_value", start = "base_hud_param_label"}
        {end = "altitude_value", start = "base_hud_param_label"}
        {end = "throttle_value_2", start = "throttle_and_speed_relaitive_label"}
        {end = "speed_value_2", start = "throttle_and_speed_relaitive_label"}
        {end = "wep_value", start = "wep_description_label"}
        {end = "crosshairs_target_point", start = "crosshairs_label"}
        {end = "target_lead_target_point", start = "target_lead_text_label"}
        {end = "bomb_value", start = "ammo_count_label"}
        {end = "machine_guns_reload_time", start = "weapon_reload_time_label"}
        {end = "cannons_reload_time", start = "weapon_reload_time_label"}
        {end = "bomb_crosshair_target_point", start = "bomb_crosshair_label"}
        {end = "bombs_target_controls_frame_attack_image", start = "bombs_target_text_label"}
        {end = "fire_guns_controls_target_point", start = "fire_guns_controls_frame"}
        {end = "fire_guns_controls_target_point", start = "ID_FIRE_MGUNS_not_default_0"}
      ]
    }
    defaultControlsIds = [ //for default constrols we can see frameId, but for not default custom shortcut
      { frameId = "fire_guns_controls_frame", shortcut = "ID_FIRE_MGUNS" }
      { frameId = "lock_target_controls_frame", shortcut = "ID_LOCK_TARGET" }
      { frameId = "zoom_controls_frame", shortcut = "ID_ZOOM_TOGGLE" }
      { frameId = "bombs_controls_frame", shortcut = "ID_BOMBS" }
      { frameId = "throttle_down_controls_frame" }
      { frameId = "throttle_up_controls_frame" }
      { frameId = "throttle_up_controls_frame_2" }
    ]
    moveControlsFrames = function (defaultControls, scene)
    {
      if (!defaultControls)
      {
        scene.findObject("target_lead_text_label").pos = "350/1760pw-w, 690/900ph";
        scene.findObject("bombs_target_text_label").pos = "900/1760pw, 280/900ph-h";
        scene.findObject("bombs_target_controls_frame").pos = "898/1760pw, 323/900ph";
      }
      else
      {
        scene.findObject("target_lead_text_label").pos = "860/1760pw-w, 650/900ph";
        scene.findObject("bombs_target_text_label").pos = "900/1760pw, 355/900ph-h";
        scene.findObject("bombs_target_controls_frame").pos = "898/1760pw, 393/900ph";
      }
    }
  }
  IMAGE_TANK = {
    subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE

    checkFeature = unitTypes.TANK.isAvailable
    pageUnitTypeBit = unitTypes.TANK.bit

    pageBlkName = "gui/help/controlsTank.blk"

    imagePattern = "#ui/images/country_%s_tank_controls_help.jpg?P1"
    defaultValues = { country = "ussr" }
    hasImageByCountries = ["ussr", "germany"]
    countryRelatedObjs = {
      germany = [
        "transmission_label_1", "transmission_target_point_1",
        "diesel_engine_label_1", "diesel_engine_target_point_1",
        "stowage_area_label_1", "stowage_area_target_point_1",
        "place_gunner_target_point_1",
        "place_commander_target_point_1",
        "place_loader_target_point_1"
      ],
      ussr = [
        "transmission_label_2", "transmission_target_point_2",
        "diesel_engine_label_2", "diesel_engine_target_point_2",
        "stowage_area_label_2", "stowage_area_target_point_2", "stowage_area_target_point_3",
        "place_gunner_target_point_2",
        "place_commander_target_point_2",
        "place_loader_target_point_2",
        "throttle_target_point",
        "turn_right_target_point"
      ]
    }
    linkLines = {
      links = [
        {end = "backward_target_point", start = "backward_label"}
        {end = "gear_value", start = "base_hud_param_label"}
        {end = "rpm_value", start = "base_hud_param_label"}
        {end = "real_speed_value", start = "base_hud_param_label"}
        {end = "throttle_target_point", start = "throttle_label"}
        {end = "turn_left_target_point", start = "turn_left_frame"}
        {end = "turn_right_target_point", start = "turn_right_label"}
        {end = "ammo_1_target_point", start = "controller_switching_ammo"}
        {end = "ammo_2_target_point", start = "controller_switching_ammo"}
        {end = "ammo_1_target_point", start = "keyboard_switching_ammo"}
        {end = "ammo_2_target_point", start = "keyboard_switching_ammo"}
        {end = "artillery_target_point", start = "call_artillery_strike_label"}
        {end = "scout_target_point", start = "scout_label"}
        {end = "smoke_grenade_target_point", start = "smoke_grenade_lable"}
        {end = "smoke_screen_target_point", start = "smoke_screen_label"}
        {end = "smoke_screen_target_point", start = "controller_smoke_screen_label"}
        {end = "medicalkit_target_point", start = "medicalkit_label"}
        {end = "medicalkit_target_point", start = "controller_medicalkit_label"}
        {end = "tank_cannon_direction_target_point", start = "tank_sight_label"}
        {end = "tank_cannon_realy_target_point", start = "tank_sight_label"}
        {end = "tank_cursor_target_point", start = "tank_cursor_frame"}
        {end = "place_loader_target_point_1", start = "place_loader_label"}
        {end = "place_loader_target_point_2", start = "place_loader_label"}
        {end = "place_shooter_radio_operator_target_point_2", start = "place_shooter_radio_operator_label"}
        {end = "place_mechanics_driver_target_point", start = "place_mechanics_driver_label"}
        {end = "place_commander_target_point_1", start = "place_commander_label"}
        {end = "place_commander_target_point_2", start = "place_commander_label"}
        {end = "place_gunner_target_point_1", start = "place_gunner_label"}
        {end = "place_gunner_target_point_2", start = "place_gunner_label"}
        {end = "stowage_area_target_point_1", start = "stowage_area_label_1"}
        {end = "stowage_area_target_point_2", start = "stowage_area_label_2"}
        {end = "stowage_area_target_point_3", start = "stowage_area_label_2"}
        {end = "diesel_engine_target_point_1", start = "diesel_engine_label_1"}
        {end = "diesel_engine_target_point_2", start = "diesel_engine_label_2"}
        {end = "transmission_target_point_1", start = "transmission_label_1"}
        {end = "transmission_target_point_2", start = "transmission_label_2"}
        {end = "traversing_target_point_1", start = "traversing_label"}
        {end = "traversing_target_point_2", start = "traversing_label"}
        {end = "main_gun_target_point", start = "main_gun_tube_label"}
      ]
    }
    actionBars = [
      {
        nest  = "action_bar_place"
        unitId = "ussr_t_34_85_zis_53"
        items = [
          {
            type = ::EII_BULLET
            active = true
            id = "ammo_1"
            selected = true
            icon = "#ui/gameuiskin#apcbc_tank"
          }
          {
            type = ::EII_BULLET
            id = "ammo_2"
            icon = "#ui/gameuiskin#he_frag_tank"
          }
          {
            type = ::EII_SCOUT
            id = "scout"
          }
          {
            type = ::EII_ARTILLERY_TARGET
            id = "artillery"
          }
          {
            type = ::EII_SMOKE_GRENADE
            id = "smoke_grenade"
          }
          {
            type = ::EII_SMOKE_SCREEN
            id = "smoke_screen"
          }
          {
            type = ::EII_MEDICALKIT
            id = "medicalkit"
          }
        ]
      }
    ]
  }
  IMAGE_SHIP = {
    subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE

    checkFeature = unitTypes.SHIP.isAvailable
    pageUnitTypeBit = unitTypes.SHIP.bit

    pageBlkName = "gui/help/controlsShip.blk"

    imagePattern = "#ui/images/country_%s_ship_controls_help.jpg?P1"
    defaultValues = { country = "usa" }
    hasImageByCountries = [ "usa" ]
    countryRelatedObjs = {
      usa = [
      ]
    }
    linkLines = {
      links = [
        { start = "throttle_label", end = "throttle_target_point" }
        { start = "backward_label", end = "backward_target_point" }
        { start = "turn_right_label", end = "turn_right_target_point" }
        { start = "turn_left_frame",  end = "turn_left_target_point" }
        { start = "weapon_markers_frame", end = "weapon_markers_1_point" }
        { start = "weapon_markers_frame", end = "weapon_markers_2_point" }
        { start = "CURSOR_controls_frame", end = "cursor_control_point" }
        { start = "crew_count_label", end = "crew_count_point" }
        { start = "ab_extinguisher_label", end = "ab_extinguisher_target_point" }
        { start = "ab_repair_label",       end = "ab_repair_target_point" }
        { start = "ab_breaches_label",     end = "ab_breaches_target_point" }
        { start = "ab_rocket_label",       end = "ab_rocket_target_point" }
        { start = "ab_depth_charge_label", end = "ab_depth_charge_target_point" }
        { start = "ab_torpedo_label",      end = "ab_torpedo_target_point" }
        { start = "torpedo_trail_label", end = "torpedo_trail_point" }
        { start = "torpedo_sight_label", end = "torpedo_sight_point" }
        { start = "torpedo_projection_label", end = "torpedo_projection_point" }
        { start = "manual_target_1_label", end = "manual_target_1_point" }
        { start = "manual_target_2_label", end = "manual_target_2_point" }
        { start = "manual_target_3_label", end = "manual_target_3_point" }
        { start = "ai_shooting_modes_frame", end = "ai_shooting_modes_point" }
      ]
    }

    actionBars = [
      {
        nest  = "action_bar_actions"
        unitId = "us_elco_80ft_pt_boat_mod01"
        items = [
          {
            type = ::EII_EXTINGUISHER
            id = "ab_extinguisher"
          }
          {
            type = ::EII_TOOLKIT
            id = "ab_repair"
          }
          {
            type = ::EII_REPAIR_BREACHES
            id = "ab_breaches"
          }
        ]
      }
      {
        nest  = "action_bar_weapons"
        unitId = "us_elco_80ft_pt_boat_mod01"
        items = [
          {
            type = ::EII_ROCKET
            id = "ab_rocket"
          }
          {
            type = ::EII_DEPTH_CHARGE
            id = "ab_depth_charge"
          }
          {
            type = ::EII_TORPEDO
            id = "ab_torpedo"
          }
        ]
      }
    ]
  }
  IMAGE_HELICOPTER = {
    subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE

    checkFeature = unitTypes.HELICOPTER.isAvailable
    pageUnitTypeBit = unitTypes.HELICOPTER.bit

    pageBlkName = "gui/help/controlsHelicopter.blk"

    imagePattern = "#ui/images/country_%s_helicopter_controls_help.jpg?P1"
    defaultValues = { country = "ussr" }
    hasImageByCountries = ["ussr"]
    countryRelatedObjs = {
      ussr = [
      ]
    }
    linkLines = {
      links = [
        { start = "hud_movement_indicators_label", end = "rpm_value" }
        { start = "hud_movement_indicators_label", end = "throttle_value" }
        { start = "hud_movement_indicators_label", end = "climb_value" }
        { start = "hud_movement_indicators_label", end = "speed_value" }
        { start = "hud_ammo_indicators_label", end = "cannons_value" }
        { start = "hud_ammo_indicators_label", end = "additional_guns_value" }
        { start = "hud_ammo_indicators_label", end = "bombs_value" }
        { start = "hud_ammo_indicators_label", end = "rockets_value" }
        { start = "hud_ammo_indicators_label", end = "missiles_value" }
        { start = "hud_ammo_indicators_label", end = "rate_of_fire_value" }
        { start = "CURSOR_controls_frame", end = "cursor_control_point" }
        { start = "secondary_cannons_aim_marker_label", end = "secondary_cannons_aim_marker_point" }
        { start = "rocket_aim_marker_label", end = "rocket_aim_marker_point" }
        { start = "bombs_aim_marker_label", end = "bombs_aim_marker_point" }
        { start = "attitude_indicator_label", end = "attitude_indicator_point" }
        { start = "velocity_vector_indicator_label", end = "velocity_vector_indicator_point" }
        { start = "altimeter_indicator_label", end = "altimeter_indicator_point" }
        { start = "vertical_speed_indicator_label", end = "vertical_speed_indicator_point" }
      ]
    }
  }
  IMAGE_SUBMARINE = {
    subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE

    checkFeature = @() unitTypes.SHIP.isAvailable() && ::has_feature("SpecialShips")
    pageUnitTypeBit = unitTypes.SHIP.bit
    pageUnitTag = "submarine"

    pageBlkName = "gui/help/controlsSubmarine.blk"

    defaultValues = { country = "ussr" }
    imagePattern = "#ui/images/country_%s_submarine_controls_help.jpg?P1"
    hasImageByCountries = ["ussr"]
    countryRelatedObjs = {
      ussr = [
      ]
    }
    linkLines = {
      links = [
        { start = "sonar_detected_hud_label", end = "sonar_detected_hud_point" }
        { start = "sonar_detected_sonar_label", end = "sonar_detected_sonar_point" }
        { start = "sonar_detected_sonar_label", end = "sonar_detected_map_point" }
        { start = "sonar_detected_direction_label", end = "sonar_detected_direction_point" }
        { start = "depth_current_label", end = "depth_current_point" }
        { start = "depth_selected_label", end = "depth_selected_point" }
        { start = "depth_change_label", end = "depth_change_point" }
        { start = "torpedo_distance_label", end = "torpedo_distance_point" }
        { start = "torpedo_control_mode_label", end = "torpedo_control_mode_point" }
        { start = "torpedo_sonar_mode_label", end = "torpedo_sonar_mode_point" }
        { start = "map_sonar_passive_label", end = "map_sonar_passive_point" }
        { start = "map_sonar_active_label", end = "map_sonar_active_point" }
        { start = "map_acoustic_contermeasures_label", end = "map_acoustic_contermeasures_point" }
      ]
    }
  }
  CONTROLLER_AIRCRAFT = {
    subTabName = helpMarkup.title
    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() ::show_console_buttons
    checkFeature = unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  CONTROLLER_TANK = {
    subTabName = helpMarkup.title

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() ::show_console_buttons
    checkFeature = unitTypes.TANK.isAvailable
    pageUnitTypeBit = unitTypes.TANK.bit

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  CONTROLLER_SHIP = {
    subTabName = helpMarkup.title

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() ::show_console_buttons
    checkFeature = unitTypes.SHIP.isAvailable
    pageUnitTypeBit = unitTypes.SHIP.bit

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  CONTROLLER_HELICOPTER = {
    subTabName = helpMarkup.title

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() ::show_console_buttons
    checkFeature = unitTypes.HELICOPTER.isAvailable
    pageUnitTypeBit = unitTypes.HELICOPTER.bit

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  CONTROLLER_SUBMARINE = {
    subTabName = helpMarkup.title

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() ::show_console_buttons
    checkFeature = @() unitTypes.SHIP.isAvailable() && ::has_feature("SpecialShips")
    pageUnitTypeBit = unitTypes.SHIP.bit
    pageUnitTag = "submarine"

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  KEYBOARD_AIRCRAFT = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = function() {
      if (::is_platform_pc)
        return true

      //!!!FIXME need to rewrite with controllerState module usage
      local basePresets = ::g_controls_manager.getCurPreset().getBasePresetNames()
      return ::is_platform_ps4 && ::u.search(basePresets, @(val) val == "default"|| val == "dualshock4") != null
    }
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = "gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  KEYBOARD_TANK = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = function() {
      if (::is_platform_pc)
        return true

      //!!!FIXME need to rewrite with controllerState module usage
      local basePresets = ::g_controls_manager.getCurPreset().getBasePresetNames()
      return ::is_platform_ps4 && ::u.search(basePresets, @(val) val == "default"|| val == "dualshock4") != null
    }
    checkFeature = unitTypes.TANK.isAvailable
    pageUnitTypeBit = unitTypes.TANK.bit

    pageBlkName = "gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  KEYBOARD_SHIP = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = function() {
      if (::is_platform_pc)
        return true

      //!!!FIXME need to rewrite with controllerState module usage
      local basePresets = ::g_controls_manager.getCurPreset().getBasePresetNames()
      return ::is_platform_ps4 && ::u.search(basePresets, @(val) val == "default"|| val == "dualshock4") != null
    }
    checkFeature = unitTypes.SHIP.isAvailable
    pageUnitTypeBit = unitTypes.SHIP.bit

    pageBlkName = "gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  KEYBOARD_HELICOPTER = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = function() {
      if (::is_platform_pc)
        return true

      //!!!FIXME need to rewrite with controllerState module usage
      local basePresets = ::g_controls_manager.getCurPreset().getBasePresetNames()
      return ::is_platform_ps4 && ::u.search(basePresets, @(val) val == "default"|| val == "dualshock4") != null
    }
    checkFeature = unitTypes.HELICOPTER.isAvailable
    pageUnitTypeBit = unitTypes.HELICOPTER.bit

    pageBlkName = "gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  KEYBOARD_SUBMARINE = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = function() {
      if (::is_platform_pc)
        return true

      //!!!FIXME need to rewrite with controllerState module usage
      local basePresets = ::g_controls_manager.getCurPreset().getBasePresetNames()
      return ::is_platform_ps4 && ::u.search(basePresets, @(val) val == "default"|| val == "dualshock4") != null
    }
    checkFeature = @() unitTypes.SHIP.isAvailable() && ::has_feature("SpecialShips")
    pageUnitTypeBit = unitTypes.SHIP.bit
    pageUnitTag = "submarine"

    pageBlkName = "gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  RADAR_AIRBORNE = {
    subTabName = "#radar"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.RADAR

    specificCheck = @() !::is_in_flight() || isUnitWithRadarOrRwr(::get_player_cur_unit())
    checkFeature = @() unitTypes.AIRCRAFT.isAvailable && ::has_feature("Sensors")
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = "gui/help/radarAircraft.blk"
    imagePattern = "#ui/images/help/help_radar_air_%s.jpg?P1"
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
  RADAR_GROUND = {
    subTabName = "#radar"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.RADAR

    specificCheck = @() !::is_in_flight() || isUnitWithRadarOrRwr(::get_player_cur_unit())
    checkFeature = @() unitTypes.TANK.isAvailable && ::has_feature("Sensors")
    pageUnitTypeBit = unitTypes.TANK.bit

    pageBlkName = "gui/help/radarTank.blk"
    imagePattern = "#ui/images/help/help_radar_tank_%s.jpg?P1"
    defaultValues = { country = "ussr" }
    hasImageByCountries = [ "ussr" ]
    countryRelatedObjs = { ussr = [] }
    linkLines = {
      links = [
        { start = "bscope_target_detected_label", end = "bscope_target_detected_point" }
        { start = "bscope_target_selected_label", end = "bscope_target_selected_point" }
        { start = "bscope_target_tracking_label", end = "bscope_target_tracking_point" }
        { start = "bscope_tracking_beam_label", end = "bscope_tracking_beam_point" }
        { start = "bscope_active_label", end = "bscope_active_value" }
        { start = "bscope_search_beam_label", end = "bscope_search_beam_point" }
        { start = "bscope_tank_turret_direction_label", end = "bscope_tank_turret_direction_point" }
        { start = "bscope_scan_area_label", end = "bscope_scan_area_point" }
        { start = "bscope_target_lock_area_label", end = "bscope_target_lock_area_point" }
        { start = "bscope_range_scale_label", end = "bscope_range_scale_point" }
        { start = "compass_target_detected_label", end = "compass_target_detected_point" }
        { start = "compass_target_selected_label", end = "compass_target_selected_point" }
        { start = "compass_target_tracking_label", end = "compass_target_tracking_point" }
        { start = "marker_target_tracking_label", end = "marker_target_tracking_point" }
        { start = "marker_distance_label", end = "marker_distance_value" }
        { start = "marker_approach_speed_label", end = "marker_approach_speed_value" }
      ]
    }
  }
}, null, "name")

return result