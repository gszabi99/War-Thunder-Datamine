from "%scripts/dagui_natives.nut" import request_voice_message_list, is_last_voice_message_list_for_squad
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { blkOptFromPath } = require("%sqstd/datablock.nut")
let { is_bit_set, number_of_set_bits } = require("%sqstd/math.nut")
let { getCantUseVoiceMessagesReason } = require("%scripts/wheelmenu/voiceMessages.nut")
let memoizeByEvents = require("%scripts/utils/memoizeByEvents.nut")
let { emulateShortcut, isXInputDevice } = require("controls")
let { getHudUnitType } = require("hudState")
let { HUD_UNIT_TYPE } = require("%scripts/hud/hudUnitType.nut")
let { get_mission_difficulty_int } = require("guiMission")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getUnitPresets } = require("%scripts/weaponry/weaponryPresets.nut")
let { getWeaponryCustomPresets } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { eventbus_subscribe, eventbus_unsubscribe } = require("eventbus")
let { hasBayDoor, hasSchraegeMusik, hasThrustReverse, hasExternalFuelTanks, hasCountermeasureFlareGuns,
  hasCountermeasureSystemIRCM, hasCollimatorSight, hasSightStabilization, hasCCIPSightMode, hasCCRPSightMode,
  hasRocketsBallisticComputer, hasCannonsBallisticComputer, hasLaserDesignator, hasNightVision, hasHelmetDesignator,
  hasInfraredProjector, isTerraformAvailable, canUseRangefinder, hasMissileLaunchWarningSystem,
  getDisplaysWithTogglablePagesBitMask, hasPrimaryWeapons, hasAiGunners, hasGunStabilizer,
  hasAlternativeShotFrequency, getWeaponsTriggerGroupsMask, hasCockpit, hasGunners, hasBombview,
  hasMissionBombingZones, getEnginesCount, hasFeatheringControl, canUseManualEngineControl, getEngineControlBitMask,
  hasSpecialWeaponAdditionalSight, isGearsExtended, isMouseAimRollOverride
} = require("vehicleModel")
let { deferOnce } = require("dagor.workcycle")
let getHandler = @() handlersManager.findHandlerClassInScene(gui_handlers.multifuncMenuHandler)
let toggleShortcut = @(shortcutId)  getHandler()?.toggleShortcut(shortcutId)
let { has_secondary_weapons } = require("weaponSelector")

let memoizeByMission = @(func, hashFunc = null) memoizeByEvents(func, hashFunc, [ "LoadingStateChange" ])

let hasFlaps = memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasFlapsControl ?? false)
let hasGear  = memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasGearControl ?? false)
let hasAirbrake = memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasAirbrake ?? false)
let hasChute = @(unitId) ::get_full_unit_blk(unitId)?.parachutes != null
let hasCockpitDoor = memoize(@(unitId) ::get_fm_file(unitId)?.AvailableControls.hasCockpitDoorControl ?? false)

let hasMultipleWeaponTriggers = @(_unitId) number_of_set_bits(getWeaponsTriggerGroupsMask()) > 1
let hasWeaponPrimary    = @(_unitId) is_bit_set(getWeaponsTriggerGroupsMask(), TRIGGER_GROUP_PRIMARY)
let hasWeaponSecondary  = @(_unitId) is_bit_set(getWeaponsTriggerGroupsMask(), TRIGGER_GROUP_SECONDARY)
let hasWeaponMachinegun = @(_unitId) is_bit_set(getWeaponsTriggerGroupsMask(), TRIGGER_GROUP_MACHINE_GUN)

let hasCameraExternal       = @(_unitId) get_mission_difficulty_int() < DIFFICULTY_HARDCORE
let hasCameraVirtualCockpit = @(_unitId) get_mission_difficulty_int() < DIFFICULTY_HARDCORE


let currentMenuItemsAndHandlers = {}

function getGearText() {
  return isGearsExtended() ? loc("RETRACT_GEARS") : loc("EXTEND_GEARS")
}

function getMouseAimOverrideRollText() {
  return isMouseAimRollOverride() ? loc("TURN_OFF_AIM_OVERRIDE_ROLL_HELICOPTER") : loc("TURN_ON_AIM_OVERRIDE_ROLL_HELICOPTER")
}

function updateButtonLabel( data, getTextFunc ) {
  if (!data || !data.handler)
    return

  let button = data.handler.scene.findObject(data.item.itemId)
  if (button == null)
    return
  let nameObj = button.findObject("name")
  nameObj.setValue(colorize(data.item.color, getTextFunc()))
}

function subscribeMenuItem(menuItem, handler) {
  currentMenuItemsAndHandlers[menuItem.itemName] <- {
    item = menuItem,
    handler = handler.weakref()
  }
  eventbus_subscribe(menuItem.eventName, menuItem.onUpdate)
}

function unsubscribeMenuItem(menuItem, _handler) {
  let cache = currentMenuItemsAndHandlers[menuItem.itemName]
  cache.item = null
  cache.handler = null
  eventbus_unsubscribe(menuItem.eventName, menuItem.onUpdate)
}


function updateToggleGearsBtn() {
  updateButtonLabel(currentMenuItemsAndHandlers["gearsAir"], getGearText)
}

function onGearStateChange(_params) {
  deferOnce(updateToggleGearsBtn)
}

function updateMouseAimOverrideRollBtn() {
  updateButtonLabel(currentMenuItemsAndHandlers["mouseAimRollOverride"], getMouseAimOverrideRollText)
}

function onMouseAimRollOverrideChange(_params) {
  deferOnce(updateMouseAimOverrideRollBtn)
}

let hasEnginesWithFeatheringControl = function(_unitId) {
  for (local idx = 0; idx < getEnginesCount(); idx++)
    if (hasFeatheringControl(idx))
      return true
  return false
}

local savedManualEngineControlValue = false
function enableManualEngineControl() {
  savedManualEngineControlValue = canUseManualEngineControl()
  if (savedManualEngineControlValue == false)
    toggleShortcut("ID_COMPLEX_ENGINE")
}

function restoreManualEngineControl() {
  if (canUseManualEngineControl() != savedManualEngineControlValue)
    toggleShortcut("ID_COMPLEX_ENGINE")
}

local savedEngineControlBitMask = 0xFF
function selectControlEngine(engineNum) {
  savedEngineControlBitMask = getEngineControlBitMask()
  for (local idx = 0; idx < getEnginesCount(); idx++)
    if ((idx == engineNum - 1) != is_bit_set(savedEngineControlBitMask, idx))
      toggleShortcut($"ID_TOGGLE_{idx+1}_ENGINE_CONTROL")
}
function restoreControlEngines() {
  let curMask = getEngineControlBitMask()
  for (local idx = 0; idx < getEnginesCount(); idx++)
    if (is_bit_set(curMask, idx) != is_bit_set(savedEngineControlBitMask, idx))
      toggleShortcut($"ID_TOGGLE_{idx+1}_ENGINE_CONTROL")
}

function resizeSecondaryWeaponSeries() {
  let isAir = getHudUnitType() == HUD_UNIT_TYPE.AIRCRAFT
  emulateShortcut(isAir ? "ID_SWITCH_SHOOTING_CYCLE_SECONDARY" : "ID_SWITCH_SHOOTING_CYCLE_SECONDARY_HELICOPTER")
  emulateShortcut(isAir ? "ID_RESIZE_SECONDARY_WEAPON_SERIES" : "ID_RESIZE_SECONDARY_WEAPON_SERIES_HELICOPTER")
}

function voiceMessagesMenuFunc() {
  if (!isXInputDevice())
    return null
  if (getCantUseVoiceMessagesReason(false) != "")
    return null
  let shouldUseSquadMsg = is_last_voice_message_list_for_squad()
    && getCantUseVoiceMessagesReason(true) == ""
  return {
    action = Callback(@() request_voice_message_list(shouldUseSquadMsg,
      @() emulateShortcut("ID_SHOW_MULTIFUNC_WHEEL_MENU")), this)
    label  = loc(shouldUseSquadMsg
      ? "hotkeys/ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
      : "hotkeys/ID_SHOW_VOICE_MESSAGE_LIST")
  }
}

function hasRadarInSensorsBlk(sensorsBlk) {
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
      { shortcut = [ "ID_SHIP_ACTION_BAR_ITEM_10" ] }
      null
      null
      voiceMessagesMenuFunc
    ]
  },

  ["radar"] = {
    title = "hotkeys/ID_SENSORS_HEADER"
    enable = @(unitId) hasRadar(unitId, getLastWeapon(unitId))
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
      { shortcut = [ "ID_GEAR" ], enable = hasGear,
        getText = getGearText, onCreate = subscribeMenuItem, eventName = "onGearStateChange",
        onDestroy = unsubscribeMenuItem, onUpdate = onGearStateChange, itemName = "gearsAir"
      }
      { shortcut = [ "ID_AIR_BRAKE" ], enable = hasAirbrake }
      { shortcut = [ "ID_CHUTE" ], enable = hasChute }
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
      { shortcut = [ "ID_GEAR_HELICOPTER" ],  enable = hasGear,
        getText = getGearText, onCreate = subscribeMenuItem, eventName = "onGearStateChange",
        onDestroy = unsubscribeMenuItem, onUpdate = onGearStateChange, itemName = "gearsAir"
      }
      { shortcut = [ "ID_MOUSE_AIM_OVERRIDE_ROLL_HELICOPTER" ],
        getText = getMouseAimOverrideRollText, onCreate = subscribeMenuItem, eventName = "onChangeMouseAimRollOverride",
        onDestroy = unsubscribeMenuItem, onUpdate = onMouseAimRollOverrideChange, itemName = "mouseAimRollOverride"
      }
      null
      null
      null
    ]
  },

  ["weapons_air"] = {
    title = "hotkeys/ID_PLANE_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER" ], enable = @(_unitId) hasCannonsBallisticComputer() }
      { shortcut = [ "ID_TOGGLE_ROCKETS_BALLISTIC_COMPUTER" ], enable = @(_unitId) hasRocketsBallisticComputer() }
      { shortcut = [ "ID_FUEL_TANKS" ], enable = @(_unitId) hasExternalFuelTanks() }
      { shortcut = [ "ID_TOGGLE_GUNNERS" ], enable = @(_unitId) hasAiGunners() }
      { section = "weapon_selector" }
      { shortcut = [ "ID_BAY_DOOR" ], enable = @(_unitId) hasBayDoor() }
      { shortcut = [ "ID_SCHRAEGE_MUSIK" ], enable = @(_unitId) hasSchraegeMusik() }
      { section = "flares" }
      { shortcut = [ "ID_IRCM_SWITCH_PLANE" ], enable = @(_unitId) hasCountermeasureSystemIRCM() }
    ]
  },

  ["weapons_heli"] = {
    title = "hotkeys/ID_PLANE_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_CANNONS_AND_ROCKETS_BALLISTIC_COMPUTER_HELICOPTER" ], enable = @(_unitId) hasCannonsBallisticComputer() }
      { shortcut = [ "ID_TOGGLE_ROCKETS_BALLISTIC_COMPUTER_HELICOPTER" ], enable = @(_unitId) hasRocketsBallisticComputer() }
      { shortcut = [ "ID_TOGGLE_LASER_DESIGNATOR_HELICOPTER" ], enable = @(_unitId) hasLaserDesignator() }
      { shortcut = [ "ID_CHANGE_SHOT_FREQ_HELICOPTER" ], enable = @(_unitId) hasAlternativeShotFrequency() }
      { section = "weapon_selector" }
      null
      { shortcut = [ "ID_IRCM_SWITCH_HELICOPTER" ], enable = @(_unitId) hasCountermeasureSystemIRCM() }
      { section = "flares" }
    ]
  },

  ["weapon_selector"] = {
    title = "hotkeys/ID_WEAPON_SELECTOR_HEADER"
    enable = @(_unitId) hasPrimaryWeapons() || has_secondary_weapons()
    items = [
      { shortcut = [ "ID_SWITCH_SHOOTING_CYCLE_PRIMARY", "ID_SWITCH_SHOOTING_CYCLE_PRIMARY_HELICOPTER" ],
          enable = @(_unitId) hasPrimaryWeapons() }
      { shortcut = [ "ID_SWITCH_SHOOTING_CYCLE_SECONDARY", "ID_SWITCH_SHOOTING_CYCLE_SECONDARY_HELICOPTER" ],
          enable = @(_unitId) has_secondary_weapons() }
      { shortcut = [ "ID_OPEN_VISUAL_WEAPON_SELECTOR" ], enable = @(_unitId) has_secondary_weapons() }
      { shortcut = [ "ID_JETTISON_SECONDARY", "ID_JETTISON_SECONDARY_HELICOPTER" ],
          enable = @(_unitId) has_secondary_weapons() }
      { action = resizeSecondaryWeaponSeries, label  = loc("hotkeys/ID_RESIZE_SECONDARY_WEAPON_SERIES"),
          enable = @(_unitId) has_secondary_weapons() }
      null
      { shortcut = [ "ID_EXIT_SHOOTING_CYCLE_MODE", "ID_EXIT_SHOOTING_CYCLE_MODE_HELICOPTER" ] }
      null
    ]
  },

  ["flares"] = {
    title = "hotkeys/ID_FLARES_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_PERIODIC_FLARES", "ID_TOGGLE_PERIODIC_FLARES_HELICOPTER" ],
          enable = @(_unitId) hasCountermeasureFlareGuns() }
      { shortcut = [ "ID_TOGGLE_MLWS_FLARES_SLAVING", "ID_TOGGLE_MLWS_FLARES_SLAVING_HELICOPTER" ],
          enable = @(_unitId) hasCountermeasureFlareGuns() && hasMissileLaunchWarningSystem() }
      null
      { shortcut = [ "ID_SWITCH_SHOOTING_CYCLE_COUNTER_MEASURE", "ID_SWITCH_SHOOTING_CYCLE_COUNTER_MEASURE_HELICOPTER" ],
          enable = @(_unitId) hasCountermeasureFlareGuns() }
      null
      null
      null
      null
    ]
  },

  ["camera_air"] = {
    title = "hotkeys/ID_PLANE_VIEW_HEADER"
    items = [
      { shortcut = [ "ID_CAMERA_FPS" ], enable = @(_unitId) hasCockpit() }
      { shortcut = [ "ID_CAMERA_TPS" ], enable = hasCameraExternal }
      { shortcut = [ "ID_CAMERA_VIRTUAL_FPS" ], enable = hasCameraVirtualCockpit }
      { shortcut = [ "ID_CAMERA_GUNNER" ], enable = @(_unitId) hasGunners() }
      { shortcut = [ "ID_CAMERA_BOMBVIEW" ], enable = @(_unitId) hasBombview() }
      { shortcut = [ "ID_CAMERA_OPTICS" ], enable = @(_unitId) hasBombview() }
      { shortcut = [ "ID_CAMERA_SEEKER" ], enable = @(_unitId) hasBombview() }
      null
      null
    ]
  },

  ["camera_heli"] = {
    title = "hotkeys/ID_PLANE_VIEW_HEADER"
    items = [
      { shortcut = [ "ID_CAMERA_FPS_HELICOPTER" ], enable = @(_unitId) hasCockpit() }
      { shortcut = [ "ID_CAMERA_TPS_HELICOPTER" ], enable = hasCameraExternal }
      { shortcut = [ "ID_CAMERA_VIRTUAL_FPS_HELICOPTER" ], enable = hasCameraVirtualCockpit }
      { shortcut = [ "ID_CAMERA_GUNNER_HELICOPTER" ], enable = @(_unitId) hasGunners() }
      { shortcut = [ "ID_CAMERA_OPTICS_HELICOPTER" ] }
      { shortcut = [ "ID_CAMERA_SEEKER_HELICOPTER" ] }
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
      { shortcut = [ "ID_AIR_REVERSE" ], enable = @(_unitId) hasThrustReverse() }
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
    enable = @(_unitId) getEnginesCount() > 1
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
    enable = @(_unitId) getEnginesCount() >= 1
    onEnter = @() selectControlEngine(1)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = @(_unitId) hasFeatheringControl(0) }
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
    enable = @(_unitId) getEnginesCount() >= 2
    onEnter = @() selectControlEngine(2)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = @(_unitId) hasFeatheringControl(1) }
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
    enable = @(_unitId) getEnginesCount() >= 3
    onEnter = @() selectControlEngine(3)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = @(_unitId) hasFeatheringControl(2) }
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
    enable = @(_unitId) getEnginesCount() >= 4
    onEnter = @() selectControlEngine(4)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = @(_unitId) hasFeatheringControl(3) }
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
    enable = @(_unitId) getEnginesCount() >= 5
    onEnter = @() selectControlEngine(5)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = @(_unitId) hasFeatheringControl(4) }
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
    enable = @(_unitId) getEnginesCount() >= 6
    onEnter = @() selectControlEngine(6)
    onExit  = restoreControlEngines
    items = [
      { shortcut = [ "ID_TOGGLE_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_PROP_FEATHERING" ],
        enable = @(_unitId) hasFeatheringControl(5) }
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
        enable = @(_unitId) is_bit_set(getDisplaysWithTogglablePagesBitMask(), 0) }
      { shortcut = [ "ID_MFD_2_PAGE_PLANE", "ID_MFD_2_PAGE" ],
        enable = @(_unitId) is_bit_set(getDisplaysWithTogglablePagesBitMask(), 1) }
      { shortcut = [ "ID_MFD_3_PAGE_PLANE", "ID_MFD_3_PAGE" ],
        enable = @(_unitId) is_bit_set(getDisplaysWithTogglablePagesBitMask(), 2) }
      { shortcut = [ "ID_MFD_ZOOM_PLANE", "ID_MFD_ZOOM" ],
        enable = @(_unitId) getDisplaysWithTogglablePagesBitMask() != 0 }
      { shortcut = [ "ID_HELI_GUNNER_NIGHT_VISION", "ID_PLANE_NIGHT_VISION" ],  enable = @(_unitId) hasNightVision() }
      { shortcut = [ "ID_THERMAL_WHITE_IS_HOT_HELI" ], enable = @(_unitId) hasNightVision() }
      { shortcut = [ "ID_MFD_4_PAGE" ],
        enable = @(_unitId) is_bit_set(getDisplaysWithTogglablePagesBitMask(), 3) }
      null
    ]
  },

  ["cockpit"] = {
    title = "hotkeys/ID_COCKPIT_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_COLLIMATOR", "ID_TOGGLE_COLLIMATOR_HELICOPTER" ], enable = @(_unitId) hasCollimatorSight() }
      { shortcut = [ "ID_LOCK_TARGETING_AT_POINT", "ID_LOCK_TARGETING_AT_POINT_HELICOPTER" ], enable = @(_unitId) hasSightStabilization() }
      { shortcut = [ "ID_UNLOCK_TARGETING_AT_POINT", "ID_UNLOCK_TARGETING_AT_POINT_HELICOPTER" ], enable = @(_unitId) hasSightStabilization() }
      { shortcut = [ "ID_TOGGLE_COCKPIT_LIGHTS", "ID_TOGGLE_COCKPIT_LIGHTS_HELICOPTER" ], enable = @(_unitId) hasCockpit() }
      { shortcut = [ "ID_TOGGLE_COCKPIT_DOOR", "ID_TOGGLE_COCKPIT_DOOR_HELICOPTER" ], enable = hasCockpitDoor }
      { shortcut = [ "ID_SWITCH_REGISTERED_BOMB_TARGETING_POINT" ], enable = @(_unitId) hasMissionBombingZones() && hasCCRPSightMode() }
      { shortcut = [ "ID_SWITCH_COCKPIT_SIGHT_MODE", "ID_SWITCH_COCKPIT_SIGHT_MODE_HELICOPTER" ], enable = @(_unitId) hasCCIPSightMode() }
      { shortcut = [ "ID_TOGGLE_HMD", "ID_TOGGLE_HMD_HELI" ], enable = @(_unitId) hasHelmetDesignator() }
      { shortcut = [ "ID_INC_HMD_BRIGHTNESS", "ID_INC_HMD_BRIGHTNESS_HELI" ], enable = @(_unitId) hasHelmetDesignator() }
      { shortcut = [ "ID_DEC_HMD_BRIGHTNESS", "ID_DEC_HMD_BRIGHTNESS_HELI" ], enable = @(_unitId) hasHelmetDesignator() }
    ]
  },

  ["weapons_tank"] = {
    title = "hotkeys/ID_TANK_FIRE_HEADER"
    items = [
      { shortcut = [ "ID_SELECT_GM_GUN_PRIMARY" ],    enable = hasWeaponPrimary    }
      { shortcut = [ "ID_SELECT_GM_GUN_SECONDARY" ],  enable = hasWeaponSecondary  }
      { shortcut = [ "ID_SELECT_GM_GUN_MACHINEGUN" ], enable = hasWeaponMachinegun }
      { shortcut = [ "ID_SELECT_GM_GUN_RESET" ], enable = hasMultipleWeaponTriggers }
      { shortcut = [ "ID_CHANGE_SHOT_FREQ" ], enable = @(_unitId) hasAlternativeShotFrequency() }
      { shortcut = [ "ID_SELECT_GM_GUN_SPECIAL" ],  enable = @(_unitId) hasSpecialWeaponAdditionalSight() }
      null
      null
    ]
  },

  ["targeting_tank"] = {
    title = "hotkeys/ID_FIRE_CONTROL_SYSTEM_HEADER"
    items = [
      { shortcut = [ "ID_RANGEFINDER" ], enable = @(_unitId) canUseRangefinder() }
      { shortcut = [ "ID_TANK_NIGHT_VISION" ], enable = @(_unitId) hasNightVision() }
      { shortcut = [ "ID_IR_PROJECTOR" ], enable = @(_unitId) hasInfraredProjector() }
      { shortcut = [ "ID_ENABLE_GUN_STABILIZER_GM" ], enable = @(_unitId) hasGunStabilizer() }
      { shortcut = [ "ID_THERMAL_WHITE_IS_HOT" ], enable = @(_unitId) hasNightVision() }
      { shortcut = [ "ID_IRCM_SWITCH_TANK" ], enable = @(_unitId) hasCountermeasureSystemIRCM() }
      null
      null
    ]
  },

  ["engine_tank"] = {
    title = "hotkeys/ID_TANK_POWERTRAIN_HEADER"
    items = [
      { shortcut = [ "ID_TOGGLE_GM_ENGINE" ] }
      { shortcut = [ "ID_TOGGLE_TRANSMISSION_MODE_GM" ] }
      { shortcut = [ "ID_GM_TERRAFORM_TOGGLE" ], enable = @(_unitId) isTerraformAvailable() }
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
      { shortcut = [ "ID_SHIP_TOGGLE_GUNNERS" ], enable = @(_unitId) hasAiGunners() }
      null
      null
      { shortcut = [ "ID_SHIP_SELECT_TARGET_AI_PRIM" ], enable = @(_unitId) hasAiGunners() }
      { shortcut = [ "ID_SHIP_SELECT_TARGET_AI_SEC" ],  enable = @(_unitId) hasAiGunners() }
      { shortcut = [ "ID_SHIP_SELECT_TARGET_AI_MGUN" ], enable = @(_unitId) hasAiGunners() }
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
      { shortcut = [ "ID_HUMAN_TOGGLE_RANGEFINDER" ], enable = @(_unitId) canUseRangefinder() }
      { shortcut = [ "ID_HUMAN_NIGHT_VISION" ], enable = @(_unitId) hasNightVision() }
      null
      null
      { shortcut = [ "ID_HUMAN_THERMAL_WHITE_IS_HOT" ], enable = @(_unitId) hasNightVision() }
      null
      null
      null
    ]
  },

  ["radar_human"] = {
    title = "hotkeys/ID_SENSORS_HEADER"
    enable = @(unitId) hasRadar(unitId, getLastWeapon(unitId))
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
