local flightModel = require_native("flightModel")
local { is_bit_set } = require("std/math.nut")

local getHandler = @() ::handlersManager.findHandlerClassInScene(::gui_handlers.multifuncMenuHandler)
local toggleShortcut = @(shortcutId)  getHandler()?.toggleShortcut(shortcutId)

local savedManualEngineControlValue = false
local function enableManualEngineControl() {
  savedManualEngineControlValue = flightModel.isManualEngineControlEnabled()
  if (savedManualEngineControlValue == false)
    toggleShortcut("ID_COMPLEX_ENGINE")
}
local function restoreManualEngineControl() {
  if (flightModel.isManualEngineControlEnabled() != savedManualEngineControlValue)
    toggleShortcut("ID_COMPLEX_ENGINE")
}

local savedEngineControlBitMask = 0xFF
local function selectControlEngine(engineNum) {
  savedEngineControlBitMask = flightModel.getEngineControlBitMask()
  for (local idx = 0; idx < flightModel.getEnginesCount(); idx++)
    if ((idx == engineNum-1) != is_bit_set(savedEngineControlBitMask, idx))
      toggleShortcut($"ID_TOGGLE_{idx+1}_ENGINE_CONTROL")
}
local function restoreControlEngines() {
  local curMask = flightModel.getEngineControlBitMask()
  for (local idx = 0; idx < flightModel.getEnginesCount(); idx++)
    if (is_bit_set(curMask, idx) != is_bit_set(savedEngineControlBitMask, idx))
      toggleShortcut($"ID_TOGGLE_{idx+1}_ENGINE_CONTROL")
}

//--------------------------------------------------------------------------------------------------

local cfg = {

  ["root_air"] = {
    title = "hotkeys/ID_SHOW_MULTIFUNC_WHEEL_MENU"
    items = [
      { section = "radar" }
      { section = "mechanization_air" }
      { section = "weapons_air" }
      { section = "camera_air" }
      { section = "engine_air" }
      { section = "cockpit" }
      null // TODO: { section = "displays" }
      null
    ]
  },

  ["root_helicopter"] = {
    title = "hotkeys/ID_SHOW_MULTIFUNC_WHEEL_MENU"
    items = [
      { section = "radar" }
      { section = "mechanization_heli" }
      { section = "weapons_heli" }
      { section = "camera_heli" }
      { section = "engine_heli" }
      { section = "cockpit" }
      { section = "displays" }
      null
    ]
  },

  ["root_tank"] = {
    title = "hotkeys/ID_SHOW_MULTIFUNC_WHEEL_MENU"
    items = [
      { section = "radar" }
      { section = "weapons_tank" }
      null
      { section = "targeting_tank" }
      { section = "engine_tank" }
      null
      null
      null
    ]
  },

  ["root_ship"] = {
    title = "hotkeys/ID_SHOW_MULTIFUNC_WHEEL_MENU"
    items = [
      { section = "radar" }
      { section = "gunners_ship" }
      null
      { section = "weapons_ship" }
      null
      null
      null
      null
    ]
  },

  ["radar"] = {
    title = "radar"
    enableFunc = ::memoize(function(unit) {
      local unitBlk = ::get_full_unit_blk(unit.name)
      if (unitBlk?.sensors)
        foreach (sensor in (unitBlk.sensors % "sensor"))
          if (::DataBlock(sensor?.blk ?? "")?.type == "radar")
            return true
      return false
    })
    items = [
      { shortcut = [ "ID_SENSOR_SWITCH", "ID_SENSOR_SWITCH_HELICOPTER",
          "ID_SENSOR_SWITCH_TANK", "ID_SENSOR_SWITCH_SHIP" ] }
      { shortcut = [ "ID_SENSOR_TARGET_SWITCH", "ID_SENSOR_TARGET_SWITCH_HELICOPTER",
          "ID_SENSOR_TARGET_SWITCH_TANK", "ID_SENSOR_TARGET_SWITCH_SHIP" ] }
      { shortcut = [ "ID_SENSOR_TARGET_LOCK", "ID_SENSOR_TARGET_LOCK_HELICOPTER",
          "ID_SENSOR_TARGET_LOCK_TANK", "ID_SENSOR_TARGET_LOCK_SHIP" ] }
      { shortcut = [ "ID_SENSOR_MODE_SWITCH", "ID_SENSOR_MODE_SWITCH_HELICOPTER",
          "ID_SENSOR_MODE_SWITCH_TANK", "ID_SENSOR_MODE_SWITCH_SHIP" ] }
      { shortcut = [ "ID_SENSOR_SCAN_PATTERN_SWITCH", "ID_SENSOR_SCAN_PATTERN_SWITCH_HELICOPTER",
          "ID_SENSOR_SCAN_PATTERN_SWITCH_TANK", "ID_SENSOR_SCAN_PATTERN_SWITCH_SHIP" ] }
      { shortcut = [ "ID_SENSOR_RANGE_SWITCH", "ID_SENSOR_RANGE_SWITCH_HELICOPTER",
          "ID_SENSOR_RANGE_SWITCH_TANK", "ID_SENSOR_RANGE_SWITCH_SHIP" ] }
      null
      null
    ]
  },

  ["mechanization_air"] = {
    title = "hotkeys/ID_PLANE_MECHANIZATION_HEADER"
    items = [
      { shortcut = [ "ID_FLAPS_DOWN", "ID_FLAPS_DOWN_HELICOPTER" ] }
      { shortcut = [ "ID_FLAPS", "ID_FLAPS_HELICOPTER" ] }
      { shortcut = [ "ID_FLAPS_UP", "ID_FLAPS_UP_HELICOPTER" ] }
      { shortcut = [ "ID_GEAR", "ID_GEAR_HELICOPTER" ] }
      { shortcut = [ "ID_AIR_BRAKE" ] }
      { shortcut = [ "ID_CHUTE" ] }
      null
      null
    ]
  },

  ["mechanization_heli"] = {
    title = "hotkeys/ID_PLANE_MECHANIZATION_HEADER"
    items = [
      { shortcut = [ "ID_FLAPS_DOWN", "ID_FLAPS_DOWN_HELICOPTER" ] }
      { shortcut = [ "ID_FLAPS", "ID_FLAPS_HELICOPTER" ] }
      { shortcut = [ "ID_FLAPS_UP", "ID_FLAPS_UP_HELICOPTER" ] }
      { shortcut = [ "ID_GEAR", "ID_GEAR_HELICOPTER" ] }
      { shortcut = [ "ID_MOUSE_AIM_OVERRIDE_ROLL_HELICOPTER" ] }
      null
      null
      null
    ]
  },

  ["weapons_air"] = {
    title = "hotkeys/ID_PLANE_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_COLLIMATOR", "ID_TOGGLE_COLLIMATOR_HELICOPTER" ] }
      { shortcut = [ "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER" ] }
      null
      { shortcut = [ "ID_TOGGLE_GUNNERS" ] }
      { shortcut = [ "ID_BAY_DOOR" ] }
      { shortcut = [ "ID_SCHRAEGE_MUSIK" ] }
      null
      null
    ]
  },

  ["weapons_heli"] = {
    title = "hotkeys/ID_PLANE_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_COLLIMATOR", "ID_TOGGLE_COLLIMATOR_HELICOPTER" ] }
      { shortcut = [ "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER_HELICOPTER" ] }
      { shortcut = [ "ID_TOGGLE_LASER_DESIGNATOR_HELICOPTER" ] }
      { shortcut = [ "ID_CHANGE_SHOT_FREQ_HELICOPTER" ] }
      null // TODO: Flares shooting mode
      null
      null
      null
    ]
  },

  ["camera_air"] = {
    title = "hotkeys/ID_PLANE_VIEW_HEADER"
    items = [
      { shortcut = [ "ID_CAMERA_FPS", "ID_CAMERA_FPS_HELICOPTER" ] }
      { shortcut = [ "ID_CAMERA_TPS", "ID_CAMERA_TPS_HELICOPTER" ] }
      { shortcut = [ "ID_CAMERA_VIRTUAL_FPS", "ID_CAMERA_VIRTUAL_FPS_HELICOPTER" ] }
      { shortcut = [ "ID_CAMERA_GUNNER", "ID_CAMERA_GUNNER_HELICOPTER" ] }
      { shortcut = [ "ID_CAMERA_BOMBVIEW" ] }
      null
      null
    ]
  },

  ["camera_heli"] = {
    title = "hotkeys/ID_PLANE_VIEW_HEADER"
    items = [
      { shortcut = [ "ID_CAMERA_FPS", "ID_CAMERA_FPS_HELICOPTER" ] }
      { shortcut = [ "ID_CAMERA_TPS", "ID_CAMERA_TPS_HELICOPTER" ] }
      { shortcut = [ "ID_CAMERA_VIRTUAL_FPS", "ID_CAMERA_VIRTUAL_FPS_HELICOPTER" ] }
      { shortcut = [ "ID_CAMERA_GUNNER", "ID_CAMERA_GUNNER_HELICOPTER" ] }
      { shortcut = [ "ID_CAMERA_VIRTUAL_TARGET_FPS_HELICOPTER" ] }
      null
      null
    ]
  },

  ["engine_air"] = {
    title = "armor_class/engine"
    enableFunc = @(unit) ::get_mission_difficulty_int() >= ::DIFFICULTY_REALISTIC
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE", "ID_TOGGLE_ENGINE_HELICOPTER" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ] }
      { shortcut = [ "ID_COMPLEX_ENGINE" ] }
      { section = "control_engines_separately" }
      null // { shortcut = [ "ID_FUEL_TANKS" ] }
      null
      null
    ]
  },

  ["engine_heli"] = {
    title = "armor_class/engine"
    enableFunc = @(unit) ::get_mission_difficulty_int() >= ::DIFFICULTY_REALISTIC
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE", "ID_TOGGLE_ENGINE_HELICOPTER" ] }
      { shortcut = [ "ID_FBW_MODE", "ID_FBW_MODE_HELICOPTER" ] }
      null
      null
      null
      null
      null
      null
    ]
  },

  ["control_engines_separately"] = {
    title = "hotkeys/ID_SEPARATE_ENGINE_CONTROL_HEADER"
    enableFunc = @(unit) flightModel.getEnginesCount() > 1
      && ::get_mission_difficulty_int() >= ::DIFFICULTY_REALISTIC
    onEnter = enableManualEngineControl
    onExit  = restoreManualEngineControl
    items = [
      { section = "control_engine_1" }
      { section = "control_engine_2" }
      { section = "control_engine_3" }
      { section = "control_engine_4" }
      { section = "control_engine_5" }
      { section = "control_engine_6" }
      null
      null
    ]
  },

  ["control_engine_1"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 1)
    enableFunc = @(unit) flightModel.getEnginesCount() >= 1
    onEnter = @() selectControlEngine(1)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ] }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_2"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 2)
    enableFunc = @(unit) flightModel.getEnginesCount() >= 2
    onEnter = @() selectControlEngine(2)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ] }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_3"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 3)
    enableFunc = @(unit) flightModel.getEnginesCount() >= 3
    onEnter = @() selectControlEngine(3)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ] }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_4"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 4)
    enableFunc = @(unit) flightModel.getEnginesCount() >= 4
    onEnter = @() selectControlEngine(4)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ] }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_5"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 5)
    enableFunc = @(unit) flightModel.getEnginesCount() >= 5
    onEnter = @() selectControlEngine(5)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ] }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_6"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 6)
    enableFunc = @(unit) flightModel.getEnginesCount() >= 6
    onEnter = @() selectControlEngine(6)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ] }
      null
      null
      null
      null
      null
    ]
  },

  ["displays"] = {
    title = "hotkeys/ID_MFD_AND_NVD_DISPLAYS_HEADER"
    enableFunc = @(unit) unit.esUnitType == ::ES_UNIT_TYPE_HELICOPTER
    items = [
      { shortcut = [ "ID_MFD_1_PAGE" ] }
      { shortcut = [ "ID_MFD_2_PAGE" ] }
      { shortcut = [ "ID_MFD_3_PAGE" ] }
      { shortcut = [ "ID_MFD_ZOOM" ] }
      { shortcut = [ "ID_HELI_GUNNER_NIGHT_VISION" ] }
      { shortcut = [ "ID_THERMAL_WHITE_IS_HOT", "ID_THERMAL_WHITE_IS_HOT_HELI" ] }
      null
      null
    ]
  },

  ["cockpit"] = {
    title = "hotkeys/ID_COCKPIT_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_COCKPIT_DOOR", "ID_TOGGLE_COCKPIT_DOOR_HELICOPTER" ] }
      { shortcut = [ "ID_TOGGLE_COCKPIT_LIGHTS", "ID_TOGGLE_COCKPIT_LIGHTS_HELICOPTER" ] }
      null
      null
      null
      null
      null
      null
    ]
  },

  ["weapons_tank"] = {
    title = "hotkeys/ID_TANK_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_SELECT_GM_GUN_PRIMARY" ] }
      { shortcut = [ "ID_SELECT_GM_GUN_SECONDARY" ] }
      { shortcut = [ "ID_SELECT_GM_GUN_MACHINEGUN" ] }
      { shortcut = [ "ID_SELECT_GM_GUN_RESET" ] }
      { shortcut = [ "ID_CHANGE_SHOT_FREQ" ] }
      { shortcut = [ "ID_WEAPON_LOCK_TANK" ] }
      null
      null
    ]
  },

  ["targeting_tank"] = {
    title = "hotkeys/ID_FIRE_CONTROL_SYSTEM_HEADER"
    items = [
      { shortcut = [ "ID_RANGEFINDER" ] }
      { shortcut = [ "ID_TANK_NIGHT_VISION" ] }
      { shortcut = [ "ID_IR_PROJECTOR" ] }
      { shortcut = [ "ID_TARGETING_HOLD_GM" ] }
      { shortcut = [ "ID_ENABLE_GUN_STABILIZER_GM" ] }
      { shortcut = [ "ID_THERMAL_WHITE_IS_HOT", "ID_THERMAL_WHITE_IS_HOT_HELI" ] }
      null
      null
    ]
  },

  ["engine_tank"] = {
    title = "hotkeys/ID_TANK_POWERTRAIN_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_GM_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_TRANSMISSION_MODE_GM" ] }
      null
      null
      null
      null
      null
      null
    ]
  },

  ["gunners_ship"] = {
    title = "hotkeys/ID_PLANE_GUNNERS_HEADER"
    items = [
      { shortcut = [ "ID_SHIP_TOGGLE_GUNNERS" ] }
      null
      null
      { shortcut = [ "ID_SHIP_SELECT_TARGET_AI_PRIM" ] }
      { shortcut = [ "ID_SHIP_SELECT_TARGET_AI_SEC" ] }
      { shortcut = [ "ID_SHIP_SELECT_TARGET_AI_MGUN" ] }
      null
      null
    ]
  },

  ["weapons_ship"] = {
    title = "hotkeys/ID_SHIP_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_SHIP_WEAPON_PRIMARY" ] }
      { shortcut = [ "ID_SHIP_WEAPON_SECONDARY" ] }
      { shortcut = [ "ID_SHIP_WEAPON_MACHINEGUN" ] }
      null // TODO: Toggle USEROPT_SINGLE_SHOT_BY_TURRET off
      null // TODO: Toggle USEROPT_SINGLE_SHOT_BY_TURRET on
      null
      null
      null
    ]
  },

}

return cfg
