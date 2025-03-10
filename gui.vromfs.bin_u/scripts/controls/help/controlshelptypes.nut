from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET
from "app" import is_dev_version

let { g_mission_type } = require("%scripts/missions/missionType.nut")
let { hasXInputDevice } = require("controls")
let { abs, round } = require("math")
let DataBlock  = require("DataBlock")
let enums = require("%sqStdLibs/helpers/enums.nut")
let helpMarkup = require("%scripts/controls/help/controlsHelpMarkup.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { checkJoystickThustmasterHotas } = require("%scripts/controls/hotas.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { is_keyboard_connected, is_mouse_connected } = require("controllerState")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { EII_EXTINGUISHER, EII_TOOLKIT, EII_TORPEDO, EII_DEPTH_CHARGE, EII_ROCKET,
  EII_REPAIR_BREACHES, EII_SUPPORT_PLANE_ORBITING, EII_NIGHT_VISION, EII_SIGHT_STABILIZATION
} = require("hudActionBarConst")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { get_game_mode, get_game_type_by_mode } = require("mission")
let { CONTROL_HELP_PATTERN } = require("%scripts/controls/controlsConsts.nut")
let { isInFlight } = require("gameplayBinding")
let generateSubmarineActionBars = require("%scripts/controls/help/generateControlsHelpSubmarineActionBarItems.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")
let { getTankRankForHelp } = require("%scripts/controls/help/controlsHelpUnitRankGetters.nut")
let aircraftControls = require("%scripts/controls/help/aircraftControls.nut")
let { isUnitWithRadar } = require("%scripts/unit/unitWeaponryInfo.nut")
let { getEventConditionControlHelp } = require("%scripts/hud/maybeOfferControlsHelp.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")

const UNIT_WITH_PERISCOPE_DEPTH = "germ_sub_type_7"
const DEF_PERESCOPE_DEPTH_VALUE = 10

let isKeyboardOrMouseConnected = @() is_keyboard_connected() || is_mouse_connected()

let result = {
  types = []

  template = {
    subTabName = ""
    imagePattern = ""
    helpPattern = CONTROL_HELP_PATTERN.NONE

    pageUnitTypeBit = 0 
    pageUnitTag = null

    showInSets = []
    checkFeature = @() true
    specificCheck = @() true
    showBySet = @(contentSet) this.showInSets.indexof(contentSet) != null
    showByUnit = @(unit, unitTag) this.pageUnitTag == unitTag && (this.pageUnitTypeBit & (unit?.unitType.bit ?? 0))
    needShow = @(contentSet) this.showBySet(contentSet)
                             && this.specificCheck()
                             && this.checkFeature()
  }
}

let baseImageTankType = {
  subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"

  showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
  helpPattern = CONTROL_HELP_PATTERN.IMAGE

  checkFeature = unitTypes.TANK.isAvailable
  pageUnitTypeBit = unitTypes.TANK.bit

  pageBlkName = "%gui/help/controlsTank.blk"

  linkLines = {
    links = [
      { end = "night_vision_endpoint", start = "night_vision_controls" }
      { end = "sniper_vision_endpoint", start = "sniper_vision_controls" }
      { end = "gear_value", start = "hud_param_gear_label" }
      { end = "rpm_value", start = "hud_param_rpm_label" }
      { end = "real_speed_value", start = "hud_param_speed_label" }
      { end = "ammo_1_target_point", start = "controller_switching_ammo" }
      { end = "ammo_1_target_point", start = "keyboard_switching_ammo" }
      { end = "artillery_target_point", start = "call_artillery_strike_label" }
      { end = "scout_target_point", start = "scout_label" }
      { end = "smoke_grenade_target_point", start = "smoke_grenade_label" }
      { end = "smoke_screen_target_point", start = "smoke_screen_label" }
      { end = "smoke_screen_target_point", start = "controller_smoke_screen_label" }
      { end = "medicalkit_target_point", start = "medicalkit_label" }
      { end = "medicalkit_target_point", start = "controller_medicalkit_label" }
      { end = "tank_cannon_direction_target_point", start = "tank_sight_label" }
      { end = "tank_cannon_realy_target_point", start = "tank_sight_label" }
      { end = "tank_cursor_target_point", start = "tank_cursor_frame" }
      { end = "machine_gun_ammo_point", start = "machine_gun_ammo_label" }
      { end = "crew_state_point", start = "crew_state_label" }
      { end = "modules_state_point", start = "modules_state_label" }
      { end = "first_stage_stowage_point", start = "first_stage_stowage_label" }
    ]
  }
}

enums.addTypes(result, {
  MISSION_OBJECTIVES = {
    showInSets = [
      HELP_CONTENT_SET.MISSION,
      HELP_CONTENT_SET.LOADING,
      HELP_CONTENT_SET.MISSION_WINDOW
    ]
    helpPattern = CONTROL_HELP_PATTERN.MISSION

    showByUnit = @(_unit, unitTag)
      unitTag == null && (!isMeNewbie() || getEventConditionControlHelp() != null)

    specificCheck = @() (get_game_type_by_mode(get_game_mode()) & GT_VERSUS)
      ? g_mission_type.getHelpPathForCurrentMission() != null || g_mission_type.getControlHelpName() != null
      : false

    needShow = @(contentSet) (contentSet == HELP_CONTENT_SET.MISSION_WINDOW)
      || (this.showBySet(contentSet)
        && this.specificCheck()
        && this.checkFeature())
    pageFillfuncName = "fillMissionObjectivesTexts"
  }
  HOTAS4_COMMON = {
    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.HOTAS4

    specificCheck = @() checkJoystickThustmasterHotas(false)
    checkFeature = unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageFillfuncName = "fillHotas4Image"
    pageBlkName = "%gui/help/internalHelp.blk"
  }

  IMAGE_AIRCRAFT_NORMAL = aircraftControls.NORMAL
  IMAGE_AIRCRAFT_AAM = aircraftControls.AAM
  IMAGE_AIRCRAFT_ATGM = aircraftControls.ATGM

  IMAGE_TANK_OLD = baseImageTankType.__merge({
    specificCheck = @() getTankRankForHelp() <= 4

    imagePattern = "#ui/images/help/country_%s_old_tank_controls_help?P1"
    defaultValues = { country = "ussr" }
    hasImageByCountries = ["ussr"]

    linkLines = baseImageTankType.linkLines.__merge({
      links = [].extend(baseImageTankType.linkLines.links, [
        { end = "radio_station_point_old", start = "radio_station_label" }
        { end = "optic_point_old", start = "optic_label" }
        { end = "crew_point_old", start = "crew_label" }
        { end = "fuel_tank_point_old", start = "fuel_tank_label" }
        { end = "engine_point_old", start = "engine_label" }
        { end = "transmission_point_old", start = "transmission_label" }
        { end = "drive_turret_point_old", start = "drive_turret_label" }
        { end = "weaponry_point_old", start = "weaponry_label" }
        { end = "stowage_point_old", start = "stowage_label" }
        { end = "traversing_point_old", start = "traversing_label" }
        { end = "radiator_point_old", start = "radiator_label" }
      ])
    })
  })

  IMAGE_TANK_MODERN = baseImageTankType.__merge({
    specificCheck = @() getTankRankForHelp() >= 5

    imagePattern = "#ui/images/help/country_%s_modern_tank_controls_help?P1"
    defaultValues = { country = "usa" }
    hasImageByCountries = ["usa"]

    linkLines = baseImageTankType.linkLines.__merge({
      links = [].extend(baseImageTankType.linkLines.links,[
        { end = "radio_station_point_modern", start = "radio_station_label" }
        { end = "optic_point_modern", start = "optic_label" }
        { end = "crew_point_modern", start = "crew_label" }
        { end = "fuel_tank_point_modern", start = "fuel_tank_label" }
        { end = "engine_point_modern", start = "engine_label" }
        { end = "transmission_point_modern", start = "transmission_label" }
        { end = "drive_turret_point_modern", start = "drive_turret_label" }
        { end = "weaponry_point_modern", start = "weaponry_label" }
        { end = "stowage_point_modern", start = "stowage_label" }
        { end = "traversing_point_modern", start = "traversing_label" }
        { end = "radiator_point_modern", start = "radiator_label" }
      ])
    })
  })

  IMAGE_SHIP = {
    subTabName = "#hotkeys/ID_COMMON_CONTROL_HEADER"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE

    checkFeature = unitTypes.SHIP.isAvailable
    pageUnitTypeBit = unitTypes.SHIP.bit | unitTypes.BOAT.bit

    pageBlkName = "%gui/help/controlsShip.blk"

    imagePattern = "#ui/images/country_%s_ship_controls_help?P1"
    defaultValues = { country = "usa" }
    hasImageByCountries = [ "usa" ]
    countryRelatedObjs = {
      usa = [
      ]
    }
    linkLines = {
      links = [
        { start = "weapon_is_active_label", end = "weapon_is_active_point" }
        { start = "weapon_is_not_active_label", end = "weapon_is_not_active_point" }
        { start = "weapon_is_destroyed_label", end = "weapon_is_destroyed_point" }
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
        hudUnitType = HUD_UNIT_TYPE.SHIP
        items = [
          {
            type = EII_EXTINGUISHER
            id = "ab_extinguisher"
          }
          {
            type = EII_TOOLKIT
            id = "ab_repair"
          }
          {
            type = EII_REPAIR_BREACHES
            id = "ab_breaches"
          }
        ]
      }
      {
        nest  = "action_bar_weapons"
        unitId = "us_elco_80ft_pt_boat_mod01"
        hudUnitType = HUD_UNIT_TYPE.SHIP
        items = [
          {
            type = EII_ROCKET
            id = "ab_rocket"
          }
          {
            type = EII_DEPTH_CHARGE
            id = "ab_depth_charge"
          }
          {
            type = EII_TORPEDO
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

    pageBlkName = "%gui/help/controlsHelicopter.blk"

    imagePattern = "#ui/images/country_%s_helicopter_controls_help?P1"
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

    checkFeature = @() unitTypes.SHIP.isAvailable() && hasFeature("SpecialShips")
    pageUnitTypeBit = unitTypes.SHIP.bit
    pageUnitTag = "submarine"

    pageBlkName = "%gui/help/controlsSubmarine.blk"

    defaultValues = { country = "ussr" }
    imagePattern = "#ui/images/help/country_%s_submarine_controls_help?P1"
    hasImageByCountries = ["ussr"]
    countryRelatedObjs = {
      ussr = [
      ]
    }
    linkLines = {
      obstacles = [
        "emergency_surfacing_text"
        "depth_indicator_help"
        "hud_2_calculating"
        "submorine_hull_obstacle"
        "mines_line_obstacle"
        "distance_line_obstacle"
      ]
      links = [
        { start = "mines_label", end = "bar_item_mine_1" }
        { start = "torpedo_launch_label", end = "bar_item_torpedo_1" }
        { start = "periscope_label", end = "bar_item_periscope_1" }
        { start = "emergency_surfacing_label", end = "bar_item_emergency_surfacing_1" }
        { start = "depth_indicator_label", end = "depth_indicator_point" }
        { start = "periscope_usage_label", end = "periscope_usage_point" }
        { start = "ship_target_label", end = "ship_target_point" }
        { start = "attack_bearing_label", end = "attack_bearing_point_1" }
        { start = "attack_bearing_label", end = "attack_bearing_point_2" }
        { start = "distance_label", end = "distance_point" }
        { start = "urgently_surfacing_label", end = "urgently_surfacing_point_1" }
        { start = "urgently_surfacing_label", end = "urgently_surfacing_point_2" }
      ]
    }

    actionBars = generateSubmarineActionBars(2)

    customUpdateSheetFunc = function(obj) {
      let { periscopeDepth = DEF_PERESCOPE_DEPTH_VALUE } = getFullUnitBlk(UNIT_WITH_PERISCOPE_DEPTH)

      obj.findObject("periscope_usage_label")
        .setValue(loc("controls/help/submarine/periscope_usage_depth", { meters = periscopeDepth}))
    }
  }
  IMAGE_UCAV = {
    subTabName = "#hotkeys/ID_UCAV_CONTROL_HEADER"
    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.IMAGE
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit
    pageUnitTag = "ucav"
    pageBlkName = "%gui/help/controlsUcav.blk"
    imagePattern = "#ui/images/help/help_controls_ucav?P1"
    linkLines = {
      links = [
        { start = "target_tracking_mode_label", end = "target_tracking_mode_point" }
        { start = "permitted_launch_area_label", end = "permitted_launch_area_point" }
        { start = "target_distance_label", end = "target_distance_point" }
        { start = "allowed_distances_range_label", end = "allowed_distances_range_a_point" }
        { start = "allowed_distances_range_a_point", end = "allowed_distances_range_z_point" }
        { start = "ab_orbiting_label", end = "ab_orbiting_target_point" }
        { start = "ab_night_vision_label", end = "ab_night_vision_target_point" }
        { start = "ab_sight_stabilization_label", end = "ab_sight_stabilization_target_point" }
      ]
    }
    actionBars = [
      {
        nest  = "action_bar_actions"
        unitId = "ucav_wing_loong_i"
        hudUnitType = HUD_UNIT_TYPE.AIRCRAFT
        items = [
          { type = EII_SUPPORT_PLANE_ORBITING, id = "ab_orbiting" }
          { type = EII_NIGHT_VISION, id = "ab_night_vision" }
          { type = EII_SIGHT_STABILIZATION, id = "ab_sight_stabilization" }
        ]
      }
    ]
  }
  IMAGE_WARFARE2077 = {
    subTabName = "#event/war2077"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.SPECIAL_EVENT

    specificCheck = @() is_dev_version()
    showByUnit = @(unit, _unitTag)
      [ "sdi_minotaur", "sdi_harpy", "sdi_hydra", "ucav_assault", "ucav_scout" ].contains(unit?.name)

    pageBlkName = "%gui/help/controlsWarfare2077.blk"

    defaultValues = { country = "usa" }
    imagePattern = "#ui/images/help/help_warfare2077?P1"
    hasImageByCountries = ["usa"]
    countryRelatedObjs = { usa = [] }
    linkLines = {
      links = [
        { start = "action_autoturret_label", end = "action_autoturret_point" }
        { start = "target_locked_a_label", end = "target_locked_aa_point" }
        { start = "target_locked_a_label", end = "target_locked_ag_point" }
        { start = "target_locked_gg_label", end = "target_locked_gg_point" }
        { start = "target_locked_ga_label", end = "target_locked_ga_point" }
      ]
    }
  }
  IMAGE_ARACHIS = {
    subTabName = "#missions/arachis_Dom"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.SPECIAL_EVENT

    specificCheck = @() is_dev_version()
    showByUnit = @(unit, _unitTag) [ "combat_track_a", "combat_track_h", "combat_tank_a", "combat_tank_h",
      "mlrs_tank_a", "mlrs_tank_h", "acoustic_heavy_tank_a", "destroyer_heavy_tank_h",
      "dragonfly_a", "dragonfly_h" ].contains(unit?.name)

    pageBlkName = "%gui/help/controlsArachis.blk"

    defaultValues = { country = "usa" }
    imagePattern = "#ui/images/help/help_arachis?P1"
    hasImageByCountries = ["usa"]
    countryRelatedObjs = { usa = [] }
    linkLines = {
      links = [
        { start = "worm_label", end = "worm_point" }
        { start = "sonicwave_label", end = "sonicwave_point" }
        { start = "target_search_label", end = "target_search_point" }
        { start = "target_locked_label", end = "target_locked_point" }
        { start = "cannon_aim_label", end = "cannon_aim_point" }
      ]
    }
    customUpdateSheetFunc = function(obj) {
      let wBlk = DataBlock()
      if (!wBlk.tryLoad("gameData/weapons/groundModels_weapons/acoustic_heavy_user_cannon.blk"))
        return
      let sdBlk = wBlk?.sonic_wave.bullet.sonicDamage ?? wBlk?.bullet.sonicDamage
      let soundwaveDescTextObj = obj.findObject("soundwave_txt")
      if (soundwaveDescTextObj?.isValid())
        soundwaveDescTextObj.setValue(loc("controls/help/arachis/soundwave", {
        unitName = colorize("userlogColoredText", loc("acoustic_heavy_tank_a_shop"))
        angles = colorize("activeTextColor",
          "".concat("±", abs(round(sdBlk?.horAngles.y ?? 3.0)), loc("measureUnits/deg")))
        speed = colorize("activeTextColor",
          " ".concat(round(sdBlk?.speed ?? 300.0), loc("measureUnits/metersPerSecond_climbSpeed")))
        distance = colorize("activeTextColor",
          " ".concat(round(sdBlk?.distance ?? 1000.0), loc("measureUnits/meters_alt")))
      }))
    }
  }
  CONTROLLER_AIRCRAFT = {
    subTabName = helpMarkup.title
    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() hasXInputDevice()
    checkFeature = unitTypes.AIRCRAFT.isAvailable
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  CONTROLLER_TANK = {
    subTabName = helpMarkup.title

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() hasXInputDevice()
    checkFeature = unitTypes.TANK.isAvailable
    pageUnitTypeBit = unitTypes.TANK.bit

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  CONTROLLER_SHIP = {
    subTabName = helpMarkup.title

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() hasXInputDevice()
    checkFeature = unitTypes.SHIP.isAvailable
    pageUnitTypeBit = unitTypes.SHIP.bit

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  CONTROLLER_HELICOPTER = {
    subTabName = helpMarkup.title

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() hasXInputDevice()
    checkFeature = unitTypes.HELICOPTER.isAvailable
    pageUnitTypeBit = unitTypes.HELICOPTER.bit

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  CONTROLLER_SUBMARINE = {
    subTabName = helpMarkup.title

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.GAMEPAD

    specificCheck = @() hasXInputDevice()
    checkFeature = @() unitTypes.SHIP.isAvailable() && hasFeature("SpecialShips")
    pageUnitTypeBit = unitTypes.SHIP.bit
    pageUnitTag = "submarine"

    pageBlkName = helpMarkup.blk
    pageFillfuncName = "initGamepadPage"
  }
  KEYBOARD_AIRCRAFT = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = @() isPlatformSony || isKeyboardOrMouseConnected()
    pageUnitTypeBit = unitTypes.AIRCRAFT.bit

    pageBlkName = "%gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  KEYBOARD_TANK = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = @() isPlatformSony || isKeyboardOrMouseConnected()
    checkFeature = unitTypes.TANK.isAvailable
    pageUnitTypeBit = unitTypes.TANK.bit

    pageBlkName = "%gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  KEYBOARD_SHIP = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = @() isPlatformSony || isKeyboardOrMouseConnected()
    checkFeature = unitTypes.SHIP.isAvailable
    pageUnitTypeBit = unitTypes.SHIP.bit

    pageBlkName = "%gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  KEYBOARD_HELICOPTER = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = @() isPlatformSony || isKeyboardOrMouseConnected()
    checkFeature = unitTypes.HELICOPTER.isAvailable
    pageUnitTypeBit = unitTypes.HELICOPTER.bit

    pageBlkName = "%gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  KEYBOARD_SUBMARINE = {
    subTabName = "#controlType/mouse"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.KEYBOARD_MOUSE

    specificCheck = @() isPlatformSony || isKeyboardOrMouseConnected()
    checkFeature = @() unitTypes.SHIP.isAvailable() && hasFeature("SpecialShips")
    pageUnitTypeBit = unitTypes.SHIP.bit
    pageUnitTag = "submarine"

    pageBlkName = "%gui/help/controllerKeyboard.blk"
    pageFillfuncName = "fillAllTexts"
  }
  RADAR_AIRCRAFT = aircraftControls.RADAR_AIRCRAFT
  RADAR_HELICOPTER = aircraftControls.RADAR_AIRCRAFT.__merge({
    checkFeature = unitTypes.HELICOPTER.isAvailable
    pageUnitTypeBit = unitTypes.HELICOPTER.bit
  })
  RADAR_GROUND = {
    subTabName = "#radar"

    showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
    helpPattern = CONTROL_HELP_PATTERN.RADAR

    specificCheck = @() !isInFlight() || isUnitWithRadar(getPlayerCurUnit())
    checkFeature = @() unitTypes.TANK.isAvailable
    pageUnitTypeBit = unitTypes.TANK.bit

    pageBlkName = "%gui/help/radarTank.blk"
    imagePattern = "#ui/images/help/help_radar_tank_%s?P1"
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
  RWR_AIRCRAFT = aircraftControls.RWR_AIRCRAFT
  RWR_HELICOPTER = aircraftControls.RWR_AIRCRAFT.__merge({
    checkFeature = unitTypes.HELICOPTER.isAvailable
    pageUnitTypeBit = unitTypes.HELICOPTER.bit
  })
}, null, "name")

return result
