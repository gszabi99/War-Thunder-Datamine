local vehicleModel = require_native("vehicleModel")
local { is_bit_set, number_of_set_bits } = require("std/math.nut")
local { getCantUseVoiceMessagesReason } = require("scripts/wheelmenu/voiceMessages.nut")
local memoizeByEvents = require("scripts/utils/memoizeByEvents.nut")

local getHandler = @() ::handlersManager.findHandlerClassInScene(::gui_handlers.multifuncMenuHandler)
local toggleShortcut = @(shortcutId)  getHandler()?.toggleShortcut(shortcutId)

local function memoizeByMission(func, hashFunc = null) {
  return memoizeByEvents(func, hashFunc, [ "LoadingStateChange" ])
}

local hasFlaps = ::memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasFlapsControl ?? false)
local hasGear  = ::memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasGearControl ?? false)
local hasAirbrake = ::memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasAirbrake ?? false)
local hasChite = ::memoize(@(unitId) ::get_full_unit_blk(unitId)?.parachutes != null)
local hasBayDoor = memoizeByMission(@(unitId) vehicleModel.hasBayDoor())
local hasSchraegeMusik = ::memoize(@(unitId) vehicleModel.hasSchraegeMusik())

local hasCollimatorSight = ::memoize(@(unitId) vehicleModel.hasCollimatorSight())
local hasBallisticComputer = ::memoize(@(unitId) vehicleModel.hasBallisticComputer())
local hasLaserDesignator = ::memoize(@(unitId) vehicleModel.hasLaserDesignator())
local hasNightVision = ::memoize(@(unitId) vehicleModel.hasNightVision())
local hasInfraredProjector = ::memoize(@(unitId) vehicleModel.hasInfraredProjector())
local canUseRangefinder = memoizeByMission(@(unitId) vehicleModel.canUseRangefinder())
local canUseTargetTracking = memoizeByMission(@(unitId) vehicleModel.canUseTargetTracking())
local hasCockpitDoor = ::memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasCockpitDoorControl ?? false)
local getCockpitDisplaysCount = ::memoize(@(unitId) vehicleModel.getCockpitDisplaysCount())

local hasAiGunners = memoizeByMission(@(unitId) vehicleModel.hasAiGunners())
local hasGunStabilizer = ::memoize(@(unitId) vehicleModel.hasGunStabilizer())
local hasAlternativeShotFrequency = ::memoize(@(unitId) vehicleModel.hasAlternativeShotFrequency())

local getWeapTgMask = ::memoize(@(unitId) vehicleModel.getWeaponsTriggerGroupsMask())
local hasMultipleWeaponTriggers = ::memoize(@(unitId) number_of_set_bits(getWeapTgMask(unitId)) > 1)
local hasWeaponPrimary    = ::memoize(@(unitId) is_bit_set(getWeapTgMask(unitId), TRIGGER_GROUP_PRIMARY))
local hasWeaponSecondary  = ::memoize(@(unitId) is_bit_set(getWeapTgMask(unitId), TRIGGER_GROUP_SECONDARY))
local hasWeaponMachinegun = ::memoize(@(unitId) is_bit_set(getWeapTgMask(unitId), TRIGGER_GROUP_MACHINE_GUN))

local hasCameraCockpit  = ::memoize(@(unitId) vehicleModel.hasCockpit())
local hasCameraExternal       = @(unitId) ::get_mission_difficulty_int() < ::DIFFICULTY_HARDCORE
local hasCameraVirtualCockpit = @(unitId) ::get_mission_difficulty_int() < ::DIFFICULTY_HARDCORE
local hasCameraGunner   = ::memoize(@(unitId) vehicleModel.hasGunners())
local hasCameraBombview = ::memoize(@(unitId) vehicleModel.hasBombview())

local savedManualEngineControlValue = false
local function enableManualEngineControl() {
  savedManualEngineControlValue = vehicleModel.canUseManualEngineControl()
  if (savedManualEngineControlValue == false)
    toggleShortcut("ID_COMPLEX_ENGINE")
}
local function restoreManualEngineControl() {
  if (vehicleModel.canUseManualEngineControl() != savedManualEngineControlValue)
    toggleShortcut("ID_COMPLEX_ENGINE")
}

local savedEngineControlBitMask = 0xFF
local function selectControlEngine(engineNum) {
  savedEngineControlBitMask = vehicleModel.getEngineControlBitMask()
  for (local idx = 0; idx < vehicleModel.getEnginesCount(); idx++)
    if ((idx == engineNum-1) != is_bit_set(savedEngineControlBitMask, idx))
      toggleShortcut($"ID_TOGGLE_{idx+1}_ENGINE_CONTROL")
}
local function restoreControlEngines() {
  local curMask = vehicleModel.getEngineControlBitMask()
  for (local idx = 0; idx < vehicleModel.getEnginesCount(); idx++)
    if (is_bit_set(curMask, idx) != is_bit_set(savedEngineControlBitMask, idx))
      toggleShortcut($"ID_TOGGLE_{idx+1}_ENGINE_CONTROL")
}

local function voiceMessagesMenuFunc() {
  if (!::is_xinput_device())
    return null
  if (getCantUseVoiceMessagesReason(false) != "")
    return null
  local shouldUseSquadMsg = ::is_last_voice_message_list_for_squad()
    && getCantUseVoiceMessagesReason(true) == ""
  return {
    action = ::Callback(@() ::request_voice_message_list(shouldUseSquadMsg,
      @() ::emulate_shortcut("ID_SHOW_MULTIFUNC_WHEEL_MENU")), this)
    label  = ::loc(shouldUseSquadMsg
      ? "hotkeys/ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
      : "hotkeys/ID_SHOW_VOICE_MESSAGE_LIST")
  }
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
      voiceMessagesMenuFunc
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
      voiceMessagesMenuFunc
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
      voiceMessagesMenuFunc
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
      voiceMessagesMenuFunc
    ]
  },

  ["radar"] = {
    title = "radar"
    enable = ::memoize(function(unitId) {
      local unitBlk = ::get_full_unit_blk(unitId)
      if (unitBlk?.sensors)
        foreach (sensor in (unitBlk.sensors % "sensor")) {
          local sensorBlk = ::DataBlock(sensor?.blk ?? "")
          if (sensorBlk?.type == "radar" && (sensorBlk?.showOnHud ?? true))
            return true
        }
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
      { shortcut = [ "ID_FLAPS_DOWN" ], enable = hasFlaps }
      { shortcut = [ "ID_FLAPS" ], enable = hasFlaps }
      { shortcut = [ "ID_FLAPS_UP" ], enable = hasFlaps }
      { shortcut = [ "ID_GEAR" ], enable = hasGear }
      { shortcut = [ "ID_AIR_BRAKE" ], enable = hasAirbrake }
      { shortcut = [ "ID_CHUTE" ], enable = hasChite }
      null
      null
    ]
  },

  ["mechanization_heli"] = {
    title = "hotkeys/ID_PLANE_MECHANIZATION_HEADER"
    items = [
      { shortcut = [ "ID_FLAPS_DOWN_HELICOPTER" ], enable = hasFlaps }
      { shortcut = [ "ID_FLAPS_HELICOPTER" ], enable = hasFlaps }
      { shortcut = [ "ID_FLAPS_UP_HELICOPTER" ], enable = hasFlaps }
      { shortcut = [ "ID_GEAR_HELICOPTER" ], enable = hasGear }
      { shortcut = [ "ID_MOUSE_AIM_OVERRIDE_ROLL_HELICOPTER" ] }
      null
      null
      null
    ]
  },

  ["weapons_air"] = {
    title = "hotkeys/ID_PLANE_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_COLLIMATOR" ], enable = hasCollimatorSight }
      { shortcut = [ "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER" ], enable = hasBallisticComputer }
      null
      { shortcut = [ "ID_TOGGLE_GUNNERS" ], enable = hasAiGunners }
      { shortcut = [ "ID_BAY_DOOR" ], enable = hasBayDoor }
      { shortcut = [ "ID_SCHRAEGE_MUSIK" ], enable = hasSchraegeMusik }
      null
      null
    ]
  },

  ["weapons_heli"] = {
    title = "hotkeys/ID_PLANE_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_COLLIMATOR_HELICOPTER" ], enable = hasCollimatorSight }
      { shortcut = [ "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER_HELICOPTER" ], enable = hasBallisticComputer }
      { shortcut = [ "ID_TOGGLE_LASER_DESIGNATOR_HELICOPTER" ], enable = hasLaserDesignator }
      { shortcut = [ "ID_CHANGE_SHOT_FREQ_HELICOPTER" ], enable = hasAlternativeShotFrequency }
      null // TODO: Flares shooting mode
      null
      null
      null
    ]
  },

  ["camera_air"] = {
    title = "hotkeys/ID_PLANE_VIEW_HEADER"
    items = [
      { shortcut = [ "ID_CAMERA_FPS" ], enable = hasCameraCockpit }
      { shortcut = [ "ID_CAMERA_TPS" ], enable = hasCameraExternal }
      { shortcut = [ "ID_CAMERA_VIRTUAL_FPS" ], enable = hasCameraVirtualCockpit }
      { shortcut = [ "ID_CAMERA_GUNNER" ], enable = hasCameraGunner }
      { shortcut = [ "ID_CAMERA_BOMBVIEW" ], enable = hasCameraBombview }
      null
      null
    ]
  },

  ["camera_heli"] = {
    title = "hotkeys/ID_PLANE_VIEW_HEADER"
    items = [
      { shortcut = [ "ID_CAMERA_FPS_HELICOPTER" ], enable = hasCameraCockpit }
      { shortcut = [ "ID_CAMERA_TPS_HELICOPTER" ], enable = hasCameraExternal }
      { shortcut = [ "ID_CAMERA_VIRTUAL_FPS_HELICOPTER" ], enable = hasCameraVirtualCockpit }
      { shortcut = [ "ID_CAMERA_GUNNER_HELICOPTER" ], enable = hasCameraGunner }
      { shortcut = [ "ID_CAMERA_VIRTUAL_TARGET_FPS_HELICOPTER" ], enable = hasCameraGunner }
      null
      null
    ]
  },

  ["engine_air"] = {
    title = "armor_class/engine"
    enable = @(unitId) ::get_mission_difficulty_int() >= ::DIFFICULTY_REALISTIC
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE", "ID_TOGGLE_ENGINE_HELICOPTER" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      { shortcut = [ "ID_COMPLEX_ENGINE" ] }
      { section = "control_engines_separately" }
      null // { shortcut = [ "ID_FUEL_TANKS" ] }
      null
      null
    ]
  },

  ["engine_heli"] = {
    title = "armor_class/engine"
    enable = @(unitId) ::get_mission_difficulty_int() >= ::DIFFICULTY_REALISTIC
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
    enable = @(unitId) vehicleModel.getEnginesCount() > 1
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
    enable = @(unitId) vehicleModel.getEnginesCount() >= 1
    onEnter = @() selectControlEngine(1)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_2"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 2)
    enable = @(unitId) vehicleModel.getEnginesCount() >= 2
    onEnter = @() selectControlEngine(2)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_3"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 3)
    enable = @(unitId) vehicleModel.getEnginesCount() >= 3
    onEnter = @() selectControlEngine(3)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_4"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 4)
    enable = @(unitId) vehicleModel.getEnginesCount() >= 4
    onEnter = @() selectControlEngine(4)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_5"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 5)
    enable = @(unitId) vehicleModel.getEnginesCount() >= 5
    onEnter = @() selectControlEngine(5)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_6"] = {
    getTitle = @() "{0} {1}{2}".subst(::loc("armor_class/engine"), ::loc("ui/number_sign"), 6)
    enable = @(unitId) vehicleModel.getEnginesCount() >= 6
    onEnter = @() selectControlEngine(6)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ] }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["displays"] = {
    title = "hotkeys/ID_MFD_AND_NVD_DISPLAYS_HEADER"
    items = [
      { shortcut = [ "ID_MFD_1_PAGE" ], enable = @(unitId) getCockpitDisplaysCount(unitId) >= 1 }
      { shortcut = [ "ID_MFD_2_PAGE" ], enable = @(unitId) getCockpitDisplaysCount(unitId) >= 2 }
      { shortcut = [ "ID_MFD_3_PAGE" ], enable = @(unitId) getCockpitDisplaysCount(unitId) >= 3 }
      { shortcut = [ "ID_MFD_ZOOM" ],   enable = @(unitId) getCockpitDisplaysCount(unitId) >  0 }
      { shortcut = [ "ID_HELI_GUNNER_NIGHT_VISION" ],  enable = hasNightVision }
      { shortcut = [ "ID_THERMAL_WHITE_IS_HOT_HELI" ], enable = hasNightVision }
      null
      null
    ]
  },

  ["cockpit"] = {
    title = "hotkeys/ID_COCKPIT_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_COCKPIT_DOOR", "ID_TOGGLE_COCKPIT_DOOR_HELICOPTER" ], enable = hasCockpitDoor }
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
      { shortcut = [ "ID_SELECT_GM_GUN_PRIMARY" ],    enable = hasWeaponPrimary    }
      { shortcut = [ "ID_SELECT_GM_GUN_SECONDARY" ],  enable = hasWeaponSecondary  }
      { shortcut = [ "ID_SELECT_GM_GUN_MACHINEGUN" ], enable = hasWeaponMachinegun }
      { shortcut = [ "ID_SELECT_GM_GUN_RESET" ], enable = hasMultipleWeaponTriggers }
      { shortcut = [ "ID_CHANGE_SHOT_FREQ" ], enable = hasAlternativeShotFrequency }
      { shortcut = [ "ID_WEAPON_LOCK_TANK" ] }
      null
      null
    ]
  },

  ["targeting_tank"] = {
    title = "hotkeys/ID_FIRE_CONTROL_SYSTEM_HEADER"
    items = [
      { shortcut = [ "ID_RANGEFINDER" ], enable = canUseRangefinder }
      { shortcut = [ "ID_TANK_NIGHT_VISION" ], enable = hasNightVision }
      { shortcut = [ "ID_IR_PROJECTOR" ], enable = hasInfraredProjector }
      { shortcut = [ "ID_TARGETING_HOLD_GM" ], enable = canUseTargetTracking }
      { shortcut = [ "ID_ENABLE_GUN_STABILIZER_GM" ], enable = hasGunStabilizer }
      { shortcut = [ "ID_THERMAL_WHITE_IS_HOT" ], enable = hasNightVision }
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
      { shortcut = [ "ID_SHIP_TOGGLE_GUNNERS" ], enable = hasAiGunners }
      null
      null
      { shortcut = [ "ID_SHIP_SELECT_TARGET_AI_PRIM" ], enable = hasAiGunners }
      { shortcut = [ "ID_SHIP_SELECT_TARGET_AI_SEC" ],  enable = hasAiGunners }
      { shortcut = [ "ID_SHIP_SELECT_TARGET_AI_MGUN" ], enable = hasAiGunners }
      null
      null
    ]
  },

  ["weapons_ship"] = {
    title = "hotkeys/ID_SHIP_FIRE_HEADER"
    enable = hasMultipleWeaponTriggers
    items = [
      { shortcut = [ "ID_SHIP_WEAPON_PRIMARY" ],    enable = hasWeaponPrimary    }
      { shortcut = [ "ID_SHIP_WEAPON_SECONDARY" ],  enable = hasWeaponSecondary  }
      { shortcut = [ "ID_SHIP_WEAPON_MACHINEGUN" ], enable = hasWeaponMachinegun }
      null // TODO: Toggle USEROPT_SINGLE_SHOT_BY_TURRET off
      null // TODO: Toggle USEROPT_SINGLE_SHOT_BY_TURRET on
      null
      null
      null
    ]
  },

}

return cfg
