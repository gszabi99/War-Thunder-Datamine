//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let vehicleModel = require("vehicleModel")
let { is_bit_set, number_of_set_bits } = require("%sqstd/math.nut")
let { getCantUseVoiceMessagesReason } = require("%scripts/wheelmenu/voiceMessages.nut")
let memoizeByEvents = require("%scripts/utils/memoizeByEvents.nut")
let { emulateShortcut } = require("controls")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { get_mission_difficulty_int } = require("guiMission")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getUnitPresets } = require("%scripts/weaponry/weaponryPresets.nut")
let { getWeaponryCustomPresets } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { hasRocketsBallisticComputer = @() false , hasCannonsBallisticComputer = @() false } = vehicleModel

let getHandler = @() ::handlersManager.findHandlerClassInScene(::gui_handlers.multifuncMenuHandler)
let toggleShortcut = @(shortcutId)  getHandler()?.toggleShortcut(shortcutId)

let memoizeByMission = @(func, hashFunc = null) memoizeByEvents(func, hashFunc, [ "LoadingStateChange" ])
let memoizeBySpawn = @(func, hashFunc = null) memoizeByEvents(func, hashFunc, [ "LoadingStateChange", "PlayerSpawn" ])

let hasFlaps = memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasFlapsControl ?? false)
let hasGear  = memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasGearControl ?? false)
let hasAirbrake = memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasAirbrake ?? false)
let hasChite = memoize(@(unitId) ::get_full_unit_blk(unitId)?.parachutes != null)
let hasCockpitDoor = memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasCockpitDoorControl ?? false)
let hasBayDoor = memoizeByMission(@(_unitId) vehicleModel.hasBayDoor())
let hasSchraegeMusik = memoize(@(_unitId) vehicleModel.hasSchraegeMusik())
let hasThrustReverse = memoize(@(_unitId) vehicleModel.hasThrustReverse())
let hasExternalFuelTanks = memoizeBySpawn(@(_unitId) vehicleModel?.hasExternalFuelTanks() ?? false)
let hasCountermeasureFlareGuns = memoize(@(_unitId) vehicleModel.hasCountermeasureFlareGuns())
let hasCountermeasureSystemIRCM = memoize(@(_unitId) vehicleModel.hasCountermeasureSystemIRCM())

let hasCollimatorSight = memoize(@(_unitId) vehicleModel.hasCollimatorSight())
let hasSightStabilization = memoize(@(_unitId) vehicleModel.hasSightStabilization())
let hasCCIPSightMode = memoize(@(_unitId) vehicleModel.hasCCIPSightMode())
let hasCCRPSightMode = memoize(@(_unitId) vehicleModel.hasCCRPSightMode())
let hasRocketsBallisticComputer_ = @(_unitId) hasRocketsBallisticComputer()
let hasCannonsBallisticComputer_ = @(_unitId) hasCannonsBallisticComputer()
let hasLaserDesignator = memoize(@(_unitId) vehicleModel.hasLaserDesignator())
let hasNightVision = memoizeByMission(@(_unitId) vehicleModel.hasNightVision())
let hasInfraredProjector = memoize(@(_unitId) vehicleModel.hasInfraredProjector())
let isTerraformAvailable = memoize(@(_unitId) vehicleModel.isTerraformAvailable())
let canUseRangefinder = memoizeByMission(@(_unitId) vehicleModel.canUseRangefinder())
let hasMissileLaunchWarningSystem = memoize(@(_unitId) vehicleModel.hasMissileLaunchWarningSystem())
let getDisplaysWithTogglablePagesBitMask = memoize(@(_unitId) vehicleModel.getDisplaysWithTogglablePagesBitMask())

let hasPrimaryWeapons = memoize(@(_unitId) vehicleModel?.hasPrimaryWeapons() ?? true)
let hasSecondaryWeapons = memoizeBySpawn(@(_unitId) vehicleModel?.hasSecondaryWeapons() ?? true)
let hasAiGunners = memoizeByMission(@(_unitId) vehicleModel.hasAiGunners())
let hasGunStabilizer = memoize(@(_unitId) vehicleModel.hasGunStabilizer())
let hasAlternativeShotFrequency = memoize(@(_unitId) vehicleModel.hasAlternativeShotFrequency())

let getWeapTgMask = memoize(@(_unitId) vehicleModel.getWeaponsTriggerGroupsMask())
let hasMultipleWeaponTriggers = memoize(@(unitId) number_of_set_bits(getWeapTgMask(unitId)) > 1)
let hasWeaponPrimary    = memoize(@(unitId) is_bit_set(getWeapTgMask(unitId), TRIGGER_GROUP_PRIMARY))
let hasWeaponSecondary  = memoize(@(unitId) is_bit_set(getWeapTgMask(unitId), TRIGGER_GROUP_SECONDARY))
let hasWeaponMachinegun = memoize(@(unitId) is_bit_set(getWeapTgMask(unitId), TRIGGER_GROUP_MACHINE_GUN))

let hasCameraCockpit  = memoize(@(_unitId) vehicleModel.hasCockpit())
let hasCameraExternal       = @(_unitId) get_mission_difficulty_int() < DIFFICULTY_HARDCORE
let hasCameraVirtualCockpit = @(_unitId) get_mission_difficulty_int() < DIFFICULTY_HARDCORE
let hasCameraGunner   = memoize(@(_unitId) vehicleModel.hasGunners())
let hasCameraBombview = memoize(@(_unitId) vehicleModel.hasBombview())

let hasMissionBombingZones = memoizeByMission(@(_unitId) vehicleModel.hasMissionBombingZones())

let hasEnginesWithFeatheringControl = memoize(function(_unitId) {
  for (local idx = 0; idx < vehicleModel.getEnginesCount(); idx++)
    if (vehicleModel.hasFeatheringControl(idx))
      return true
  return false
})

local savedManualEngineControlValue = false
let function enableManualEngineControl() {
  savedManualEngineControlValue = vehicleModel.canUseManualEngineControl()
  if (savedManualEngineControlValue == false)
    toggleShortcut("ID_COMPLEX_ENGINE")
}
let function restoreManualEngineControl() {
  if (vehicleModel.canUseManualEngineControl() != savedManualEngineControlValue)
    toggleShortcut("ID_COMPLEX_ENGINE")
}

local savedEngineControlBitMask = 0xFF
let function selectControlEngine(engineNum) {
  savedEngineControlBitMask = vehicleModel.getEngineControlBitMask()
  for (local idx = 0; idx < vehicleModel.getEnginesCount(); idx++)
    if ((idx == engineNum - 1) != is_bit_set(savedEngineControlBitMask, idx))
      toggleShortcut($"ID_TOGGLE_{idx+1}_ENGINE_CONTROL")
}
let function restoreControlEngines() {
  let curMask = vehicleModel.getEngineControlBitMask()
  for (local idx = 0; idx < vehicleModel.getEnginesCount(); idx++)
    if (is_bit_set(curMask, idx) != is_bit_set(savedEngineControlBitMask, idx))
      toggleShortcut($"ID_TOGGLE_{idx+1}_ENGINE_CONTROL")
}

let function resizeSecondaryWeaponSeries() {
  let isAir = getHudUnitType() == HUD_UNIT_TYPE.AIRCRAFT
  emulateShortcut(isAir ? "ID_SWITCH_SHOOTING_CYCLE_SECONDARY" : "ID_SWITCH_SHOOTING_CYCLE_SECONDARY_HELICOPTER")
  emulateShortcut(isAir ? "ID_RESIZE_SECONDARY_WEAPON_SERIES" : "ID_RESIZE_SECONDARY_WEAPON_SERIES_HELICOPTER")
}

let function voiceMessagesMenuFunc() {
  if (!::is_xinput_device())
    return null
  if (getCantUseVoiceMessagesReason(false) != "")
    return null
  let shouldUseSquadMsg = ::is_last_voice_message_list_for_squad()
    && getCantUseVoiceMessagesReason(true) == ""
  return {
    action = Callback(@() ::request_voice_message_list(shouldUseSquadMsg,
      @() emulateShortcut("ID_SHOW_MULTIFUNC_WHEEL_MENU")), this)
    label  = loc(shouldUseSquadMsg
      ? "hotkeys/ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
      : "hotkeys/ID_SHOW_VOICE_MESSAGE_LIST")
  }
}

let function hasRadarInSensorsBlk(sensorsBlk) {
  if (sensorsBlk != null)
    foreach (sensor in (sensorsBlk % "sensor")) {
      let sBlk = blkOptFromPath(sensor?.blk)
      if (sBlk?.type == "radar" && (sBlk?.showOnHud ?? true))
        return true
    }
  return false
}

let hasRadar = memoizeByMission(function hasRadar(unitId, secondaryWeaponId) {
  let unitBlk = ::get_full_unit_blk(unitId)
  if (hasRadarInSensorsBlk(unitBlk?.sensors))
    return true
  if (unitBlk?.WeaponSlots) {
    let predefinedPreset = getUnitPresets(unitBlk).findvalue(@(p) p.name == secondaryWeaponId)
    local weaponsBlk
    if (predefinedPreset != null)
      weaponsBlk = blkOptFromPath(predefinedPreset?.blk)
    else {
      let unit = getAircraftByName(unitId)
      if (unit != null)
        weaponsBlk = getWeaponryCustomPresets(unit).findvalue(@(p) p.name == secondaryWeaponId)?.weaponsBlk
    }
    let weaponBlkList = weaponsBlk != null ? (weaponsBlk % "Weapon") : []
    let ids = weaponBlkList
      .map(@(v) v.preset)
      .reduce(@(acc, v) acc.contains(v) ? acc : acc.append(v), []) //warning disable: -unwanted-modification
    if (ids.len())
      foreach (slot in unitBlk.WeaponSlots % "WeaponSlot") {
        let wPresets = slot % "WeaponPreset"
        let acviteSlotBlk = wPresets.findvalue(@(b) ids.contains(b.name))
        if (hasRadarInSensorsBlk(acviteSlotBlk?.sensors))
          return true
      }
  }
  return false
})

//--------------------------------------------------------------------------------------------------

let cfg = {

  ["root_aircraft"] = {
    title = "hotkeys/ID_SHOW_MULTIFUNC_WHEEL_MENU"
    items = [
      { section = "radar" }
      { section = "mechanization_air" }
      { section = "weapons_air" }
      { section = "camera_air" }
      { section = "engine_air" }
      { section = "cockpit" }
      { section = "displays" }
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
    title = "hotkeys/ID_SENSORS_HEADER"
    enable = memoizeBySpawn(@(unitId) hasRadar(unitId, getLastWeapon(unitId)))
    items = [
      { shortcut = [ "ID_SENSOR_SWITCH", "ID_SENSOR_SWITCH_HELICOPTER",
          "ID_SENSOR_SWITCH_TANK", "ID_SENSOR_SWITCH_SHIP" ] }
      { shortcut = [ "ID_SENSOR_TARGET_SWITCH", "ID_SENSOR_TARGET_SWITCH_HELICOPTER",
          "ID_SENSOR_TARGET_SWITCH_TANK", "ID_SENSOR_TARGET_SWITCH_SHIP" ] }
      { shortcut = [ "ID_SENSOR_TARGET_LOCK", "ID_SENSOR_TARGET_LOCK_HELICOPTER",
          "ID_SENSOR_TARGET_LOCK_TANK", "ID_SENSOR_TARGET_LOCK_SHIP" ] }
      { shortcut = [ "ID_SENSOR_TYPE_SWITCH", "ID_SENSOR_TYPE_SWITCH_HELICOPTER",
          "ID_SENSOR_TYPE_SWITCH_TANK", "ID_SENSOR_TYPE_SWITCH_SHIP" ] }
      { shortcut = [ "ID_SENSOR_MODE_SWITCH", "ID_SENSOR_MODE_SWITCH_HELICOPTER",
          "ID_SENSOR_MODE_SWITCH_TANK", "ID_SENSOR_MODE_SWITCH_SHIP" ] }
      { shortcut = [ "ID_SENSOR_ACM_SWITCH", "ID_SENSOR_ACM_SWITCH_HELICOPTER",
          "ID_SENSOR_ACM_SWITCH_TANK", "ID_SENSOR_ACM_SWITCH_SHIP" ] }
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
      { shortcut = [ "ID_AIR_BRAKE_HELICOPTER" ], enable = hasAirbrake }
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
      { shortcut = [ "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER" ], enable = hasCannonsBallisticComputer_ }
      { shortcut = [ "ID_TOGGLE_ROCKETS_BALLISTIC_COMPUTER" ], enable = hasRocketsBallisticComputer_ }
      { shortcut = [ "ID_FUEL_TANKS" ], enable = hasExternalFuelTanks }
      { shortcut = [ "ID_TOGGLE_GUNNERS" ], enable = hasAiGunners }
      { section = "weapon_selector" }
      { shortcut = [ "ID_BAY_DOOR" ], enable = hasBayDoor }
      { shortcut = [ "ID_SCHRAEGE_MUSIK" ], enable = hasSchraegeMusik }
      { section = "flares" }
      { shortcut = [ "ID_IRCM_SWITCH_PLANE" ], enable = hasCountermeasureSystemIRCM }
    ]
  },

  ["weapons_heli"] = {
    title = "hotkeys/ID_PLANE_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER_HELICOPTER" ], enable = hasCannonsBallisticComputer_ }
      { shortcut = [ "ID_TOGGLE_ROCKETS_BALLISTIC_COMPUTER_HELICOPTER" ], enable = hasRocketsBallisticComputer_ }
      { shortcut = [ "ID_TOGGLE_LASER_DESIGNATOR_HELICOPTER" ], enable = hasLaserDesignator }
      { shortcut = [ "ID_CHANGE_SHOT_FREQ_HELICOPTER" ], enable = hasAlternativeShotFrequency }
      { section = "weapon_selector" }
      null
      { shortcut = [ "ID_IRCM_SWITCH_HELICOPTER" ], enable = hasCountermeasureSystemIRCM }
      { section = "flares" }
    ]
  },

  ["weapon_selector"] = {
    title = "hotkeys/ID_WEAPON_SELECTOR_HEADER"
    enable = @(unitId) hasPrimaryWeapons(unitId) || hasSecondaryWeapons(unitId)
    items = [
      { shortcut = [ "ID_SWITCH_SHOOTING_CYCLE_PRIMARY", "ID_SWITCH_SHOOTING_CYCLE_PRIMARY_HELICOPTER" ],
          enable = hasPrimaryWeapons }
      { shortcut = [ "ID_SWITCH_SHOOTING_CYCLE_SECONDARY", "ID_SWITCH_SHOOTING_CYCLE_SECONDARY_HELICOPTER" ],
          enable = hasSecondaryWeapons }
      null
      { shortcut = [ "ID_JETTISON_SECONDARY", "ID_JETTISON_SECONDARY_HELICOPTER" ],
          enable = hasSecondaryWeapons }
      { action = resizeSecondaryWeaponSeries, label  = loc("hotkeys/ID_RESIZE_SECONDARY_WEAPON_SERIES"),
          enable = hasSecondaryWeapons }
      null
      { shortcut = [ "ID_EXIT_SHOOTING_CYCLE_MODE", "ID_EXIT_SHOOTING_CYCLE_MODE_HELICOPTER" ] }
      null
    ]
  },

  ["flares"] = {
    title = "hotkeys/ID_FLARES_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_PERIODIC_FLARES", "ID_TOGGLE_PERIODIC_FLARES_HELICOPTER" ],
          enable = hasCountermeasureFlareGuns }
      { shortcut = [ "ID_TOGGLE_MLWS_FLARES_SLAVING", "ID_TOGGLE_MLWS_FLARES_SLAVING_HELICOPTER" ],
          enable =  @(unitId) hasCountermeasureFlareGuns(unitId) && hasMissileLaunchWarningSystem(unitId) }
      null
      null
      null
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
      { shortcut = [ "ID_CAMERA_VIRTUAL_TARGET_FPS_HELICOPTER" ] }
      null
      null
    ]
  },

  ["engine_air"] = {
    title = "armor_class/engine"
    enable = @(_unitId) get_mission_difficulty_int() >= DIFFICULTY_REALISTIC
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE", "ID_TOGGLE_ENGINE_HELICOPTER" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ], enable = hasEnginesWithFeatheringControl }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      { shortcut = [ "ID_COMPLEX_ENGINE" ] }
      { section = "control_engines_separately" }
      { shortcut = [ "ID_AIR_REVERSE" ], enable = hasThrustReverse }
      null
      null
    ]
  },

  ["engine_heli"] = {
    title = "armor_class/engine"
    enable = @(_unitId) get_mission_difficulty_int() >= DIFFICULTY_REALISTIC
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
    enable = @(_unitId) vehicleModel.getEnginesCount() > 1
      && get_mission_difficulty_int() >= DIFFICULTY_REALISTIC
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
    getTitle = @() "{0} {1}{2}".subst(loc("armor_class/engine"), loc("ui/number_sign"), 1)
    enable = @(_unitId) vehicleModel.getEnginesCount() >= 1
    onEnter = @() selectControlEngine(1)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = memoize(@(_unitId) vehicleModel.hasFeatheringControl(0), @(unitId) $"{unitId}/0") }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_2"] = {
    getTitle = @() "{0} {1}{2}".subst(loc("armor_class/engine"), loc("ui/number_sign"), 2)
    enable = @(_unitId) vehicleModel.getEnginesCount() >= 2
    onEnter = @() selectControlEngine(2)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = memoize(@(_unitId) vehicleModel.hasFeatheringControl(1), @(unitId) $"{unitId}/1") }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_3"] = {
    getTitle = @() "{0} {1}{2}".subst(loc("armor_class/engine"), loc("ui/number_sign"), 3)
    enable = @(_unitId) vehicleModel.getEnginesCount() >= 3
    onEnter = @() selectControlEngine(3)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = memoize(@(_unitId) vehicleModel.hasFeatheringControl(2), @(unitId) $"{unitId}/2") }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_4"] = {
    getTitle = @() "{0} {1}{2}".subst(loc("armor_class/engine"), loc("ui/number_sign"), 4)
    enable = @(_unitId) vehicleModel.getEnginesCount() >= 4
    onEnter = @() selectControlEngine(4)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = memoize(@(_unitId) vehicleModel.hasFeatheringControl(3), @(unitId) $"{unitId}/3") }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_5"] = {
    getTitle = @() "{0} {1}{2}".subst(loc("armor_class/engine"), loc("ui/number_sign"), 5)
    enable = @(_unitId) vehicleModel.getEnginesCount() >= 5
    onEnter = @() selectControlEngine(5)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = memoize(@(_unitId) vehicleModel.hasFeatheringControl(4), @(unitId) $"{unitId}/4") }
      null // { shortcut = [ "ID_TOGGLE_EXTINGUISHER" ], enable = hasEngineExtinguishers }
      null
      null
      null
      null
      null
    ]
  },

  ["control_engine_6"] = {
    getTitle = @() "{0} {1}{2}".subst(loc("armor_class/engine"), loc("ui/number_sign"), 6)
    enable = @(_unitId) vehicleModel.getEnginesCount() >= 6
    onEnter = @() selectControlEngine(6)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = memoize(@(_unitId) vehicleModel.hasFeatheringControl(5), @(unitId) $"{unitId}/5") }
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
      { shortcut = [ "ID_MFD_1_PAGE_PLANE", "ID_MFD_1_PAGE" ],
        enable = @(unitId) is_bit_set(getDisplaysWithTogglablePagesBitMask(unitId), 0) }
      { shortcut = [ "ID_MFD_2_PAGE_PLANE", "ID_MFD_2_PAGE" ],
        enable = @(unitId) is_bit_set(getDisplaysWithTogglablePagesBitMask(unitId), 1) }
      { shortcut = [ "ID_MFD_3_PAGE_PLANE", "ID_MFD_3_PAGE" ],
        enable = @(unitId) is_bit_set(getDisplaysWithTogglablePagesBitMask(unitId), 2) }
      { shortcut = [ "ID_MFD_ZOOM_PLANE", "ID_MFD_ZOOM" ],
        enable = @(unitId) getDisplaysWithTogglablePagesBitMask(unitId) != 0 }
      { shortcut = [ "ID_HELI_GUNNER_NIGHT_VISION", "ID_PLANE_NIGHT_VISION" ],  enable = hasNightVision }
      { shortcut = [ "ID_THERMAL_WHITE_IS_HOT_HELI" ], enable = hasNightVision }
      null
      null
    ]
  },

  ["cockpit"] = {
    title = "hotkeys/ID_COCKPIT_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_COLLIMATOR", "ID_TOGGLE_COLLIMATOR_HELICOPTER" ], enable = hasCollimatorSight }
      { shortcut = [ "ID_LOCK_TARGETING_AT_POINT", "ID_LOCK_TARGETING_AT_POINT_HELICOPTER" ], enable = hasSightStabilization }
      { shortcut = [ "ID_UNLOCK_TARGETING_AT_POINT", "ID_UNLOCK_TARGETING_AT_POINT_HELICOPTER" ], enable = hasSightStabilization }
      { shortcut = [ "ID_TOGGLE_COCKPIT_LIGHTS", "ID_TOGGLE_COCKPIT_LIGHTS_HELICOPTER" ], enable = hasCameraCockpit }
      { shortcut = [ "ID_TOGGLE_COCKPIT_DOOR", "ID_TOGGLE_COCKPIT_DOOR_HELICOPTER" ], enable = hasCockpitDoor }
      { shortcut = [ "ID_SWITCH_REGISTERED_BOMB_TARGETING_POINT" ], enable = hasMissionBombingZones && hasCCRPSightMode }
      { shortcut = [ "ID_SWITCH_COCKPIT_SIGHT_MODE", "ID_SWITCH_COCKPIT_SIGHT_MODE_HELICOPTER" ], enable = hasCCIPSightMode }
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
      null
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
      { shortcut = [ "ID_ENABLE_GUN_STABILIZER_GM" ], enable = hasGunStabilizer }
      { shortcut = [ "ID_THERMAL_WHITE_IS_HOT" ], enable = hasNightVision }
      { shortcut = [ "ID_IRCM_SWITCH_TANK" ], enable = hasCountermeasureSystemIRCM }
      null
      null
    ]
  },

  ["engine_tank"] = {
    title = "hotkeys/ID_TANK_POWERTRAIN_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_GM_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_TRANSMISSION_MODE_GM" ] }
      { shortcut = [ "ID_GM_TERRAFORM_TOGGLE" ], enable = isTerraformAvailable }
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
      null // TODO: Toggle ::USEROPT_SINGLE_SHOT_BY_TURRET off
      null // TODO: Toggle ::USEROPT_SINGLE_SHOT_BY_TURRET on
      null
      null
      null
    ]
  },

  ["root_human"] = {
    title = "hotkeys/ID_SHOW_MULTIFUNC_WHEEL_MENU"
    items = [
      { section = "radar_human" }
      null
      null
      { section = "targeting_human" }
      null
      null
      null
      voiceMessagesMenuFunc
    ]
  },

  ["targeting_human"] = {
    title = "hotkeys/ID_FIRE_CONTROL_SYSTEM_HEADER"
    items = [
      { shortcut = [ "ID_HUMAN_TOGGLE_RANGEFINDER" ], enable = canUseRangefinder }
      { shortcut = [ "ID_HUMAN_NIGHT_VISION" ], enable = hasNightVision }
      null
      null
      { shortcut = [ "ID_HUMAN_THERMAL_WHITE_IS_HOT" ], enable = hasNightVision }
      null
      null
      null
    ]
  },

  ["radar_human"] = {
    title = "hotkeys/ID_SENSORS_HEADER"
    enable = memoizeBySpawn(@(unitId) hasRadar(unitId, getLastWeapon(unitId)))
    items = [
      { shortcut = [ "ID_SENSOR_SWITCH_HUMAN" ] }
      { shortcut = [ "ID_SENSOR_TARGET_SWITCH_HUMAN" ] }
      { shortcut = [ "ID_SENSOR_TARGET_LOCK_HUMAN" ] }
      null
      null
      null
      null
      null
    ]
  },
}

return cfg
