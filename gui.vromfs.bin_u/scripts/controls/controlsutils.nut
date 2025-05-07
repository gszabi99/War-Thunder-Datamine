from "%scripts/dagui_natives.nut" import fill_joysticks_desc, get_cur_unit_weapon_preset, get_axis_index
from "%scripts/dagui_library.nut" import *
from "modules" import on_module_unload

let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let { startsWith } = require("%sqstd/string.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isXInputDevice, hasXInputDevice } = require("controls")
let time = require("%scripts/time.nut")
let controllerState = require("controllerState")
let { isPlatformSony, isPlatformXboxOne, isPlatformSteamDeck } = require("%scripts/clientState/platform.nut")
let { get_gui_option, get_unit_option } = require("guiOptions")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { eventbus_subscribe } = require("eventbus")
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let {  OPTIONS_MODE_GAMEPLAY, USEROPT_MOUSE_USAGE,
  USEROPT_MOUSE_USAGE_NO_AIM, USEROPT_INSTRUCTOR_GEAR_CONTROL, USEROPT_SEPERATED_ENGINE_CONTROL_SHIP,
  USEROPT_BULLET_COUNT0, USEROPT_HELPERS_MODE
} = require("%scripts/options/optionsExtNames.nut")
let { add_msg_box } = require("%sqDagui/framework/msgBox.nut")
let { gui_start_controls_type_choice } = require("%scripts/controls/startControls.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { is_xbox } = require("%sqstd/platform.nut")
let { getAircraftHelpersOptionValue } = require("%scripts/controls/aircraftHelpers.nut")
let { parseControlsPresetName, getHighestVersionControlsPreset
} = require("%scripts/controls/controlsPresets.nut")
let { get_option, get_option_in_mode } = require("%scripts/options/optionsExt.nut")
let DataBlock  = require("DataBlock")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { TRIGGER_TYPE, getLastWeapon, getCommonWeapons, getLastPrimaryWeapon
} = require("%scripts/weaponry/weaponryInfo.nut")
let { isInFlight } = require("gameplayBinding")
let { getPresetWeapons } = require("%scripts/weaponry/weaponryPresets.nut")
let { blkOptFromPath, blkFromPath } = require("%sqstd/datablock.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { get_meta_missions_info_by_chapters, get_mission_difficulty_int, get_mission_difficulty } = require("guiMission")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { hasMappedSecondaryWeaponSelector, isShortcutMapped } = require("%scripts/controls/shortcutsUtils.nut")
let { shopIsModificationEnabled } = require("chardResearch")
let { get_game_params_blk } = require("blkGetters")
let { isBulletGroupActive } = require("%scripts/weaponry/bulletsInfo.nut")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let globalEnv = require("globalEnv")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { joystickGetCurSettings, getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let vehicleModel = require("vehicleModel")
let { getCurrentShopDifficulty } = require("%scripts/gameModes/gameModeManagerState.nut")
let { is_benchmark_game_mode, get_game_mode } = require("mission")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { currentCampaignMission } = require("%scripts/missions/missionsStates.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")

const CLASSIC_PRESET = "classic"
const SHOOTER_PRESET = "shooter"
const THRUSTMASTER_HOTAS_ONE_PERESET = "thrustmaster_hotas_one"

let recommendedControlPresets = [
  CLASSIC_PRESET
  SHOOTER_PRESET
]
if (isPlatformXboxOne)
  recommendedControlPresets.append(THRUSTMASTER_HOTAS_ONE_PERESET)

let presetsNamesByTypes =
  isPlatformSony ? {
    [CLASSIC_PRESET] = "default",
    [SHOOTER_PRESET] = "dualshock4"
  }
  : is_platform_xbox ? {
    [CLASSIC_PRESET] = "xboxone_simulator",
    [SHOOTER_PRESET] = "xboxone_ma",
    [THRUSTMASTER_HOTAS_ONE_PERESET] = "xboxone_thrustmaster_hotas_one"
  }
  : isPlatformSteamDeck ? {
    [CLASSIC_PRESET] = "steamdeck_simulator",
    [SHOOTER_PRESET] = "steamdeck_ma"
  }
  : {
    [CLASSIC_PRESET] = "keyboard",
    [SHOOTER_PRESET] = "keyboard_shooter"
  }

function getMouseUsageMask() {
  let usage = getAircraftHelpersOptionValue(USEROPT_MOUSE_USAGE)
  let usageNoAim = getAircraftHelpersOptionValue(USEROPT_MOUSE_USAGE_NO_AIM)
  return (usage ?? 0) | (usageNoAim ?? 0)
}

function checkOptionValue(optName, checkValue) {
  let val = get_gui_option(optName)
  if (val != null)
    return val == checkValue
  return get_option(optName).value == checkValue
}

function getControlsList(unitType, unitTags = []) {
  local isHeaderPassed = true
  local isSectionPassed = true
  let controlsList = ::shortcutsList.filter(function(sc) {
    if (sc.type != CONTROL_TYPE.HEADER && sc.type != CONTROL_TYPE.SECTION) {
      if (isHeaderPassed && isSectionPassed && "showFunc" in sc)
        return sc.showFunc()

      return isHeaderPassed && isSectionPassed
    }

    if (sc.type == CONTROL_TYPE.HEADER) { 
      isHeaderPassed = sc?.unitTypes.contains(unitType) ?? true
      isSectionPassed = true 

      if (isHeaderPassed)
        isHeaderPassed = unitTags.len() == 0 || sc?.unitTag == null || isInArray(sc.unitTag, unitTags)
    }
    else if (sc.type == CONTROL_TYPE.SECTION)
      isSectionPassed = isHeaderPassed

    if ("showFunc" in sc) {
      if (sc.type == CONTROL_TYPE.HEADER && isHeaderPassed)
        isHeaderPassed = sc.showFunc()
      else if (sc.type == CONTROL_TYPE.SECTION && isSectionPassed)
        isSectionPassed = sc.showFunc()
    }

    return isHeaderPassed && isSectionPassed
  })

  return controlsList
}

function onJoystickConnected() {
  updateExtWatched({ haveXinputDevice = hasXInputDevice() })
  if (!isInMenu() || !hasFeature("ControlsDeviceChoice") || !isLoggedIn.get())
    return
  let action = function() { gui_start_controls_type_choice() }
  let buttons = [{
      id = "change_preset",
      text = loc("msgbox/btn_yes"),
      func = action
    },
    { id = "cancel",
      text = loc("msgbox/btn_no"),
      func = null
    }]

  addPopup(
    loc("popup/newcontroller"),
    loc("popup/newcontroller/message"),
    action,
    buttons,
    null,
    null,
    time.secondsToMilliseconds(time.minutesToSeconds(10))
  )
}

local isKeyboardOrMouseConnectedBefore = false

function onControllerEvent() {
  if (!hasFeature("ControlsDeviceChoice") || !hasFeature("ControlsPresets"))
    return
  let isKeyboardOrMouseConnected = controllerState.is_keyboard_connected()
    || controllerState.is_mouse_connected()
  if (isKeyboardOrMouseConnectedBefore == isKeyboardOrMouseConnected)
    return
  isKeyboardOrMouseConnectedBefore = isKeyboardOrMouseConnected
  if (!isKeyboardOrMouseConnected || !isInMenu())
    return
  let action = function() { ::gui_modal_controlsWizard() }
  let buttons = [{
      id = "change_preset",
      text = loc("msgbox/btn_yes"),
      func = action
    },
    { id = "cancel",
      text = loc("msgbox/btn_no"),
      func = null
    }]

  addPopup(
    loc("popup/keyboard_or_mouse_connected"),
    loc("popup/keyboard_or_mouse_connected/message"),
    action,
    buttons,
    null,
    null,
    time.secondsToMilliseconds(time.minutesToSeconds(10))
  )
}

function getControlsPresetBySelectedType(cType) {
  local preset = ""
  if (cType in presetsNamesByTypes) {
    preset = presetsNamesByTypes[cType]
  }
  else {
    script_net_assert_once("wrong controls type", "Passed wrong controls type")
  }

  preset = parseControlsPresetName(preset)
  preset = getHighestVersionControlsPreset(preset)
  return preset
}

function onJoystickDisconnected() {
  updateExtWatched({ haveXinputDevice = hasXInputDevice() })
  add_msg_box("cannot_session", loc("pl1/lostController"), [["ok", function() {}]], "ok")
}

function isDeviceConnected(devId = null) {
  if (!devId)
    return false

  let blk = DataBlock()
  fill_joysticks_desc(blk)

  for (local i = 0; i < blk.blockCount(); i++) {
    let device = blk.getBlock(i)
    if (device?.disconnected)
      continue

    if (device?.devId && device.devId.tolower() == devId.tolower())
      return true
  }

  return false
}

let needRequireEngineControl = @() !CONTROLS_ALLOW_ENGINE_AUTOSTART
  && (get_mission_difficulty_int() == g_difficulty.SIMULATOR.diffCode) 

function getWeaponFeatures(weaponsList) {
  let res = {
    gotMachineGuns = false
    gotCannons = false
    gotAdditionalGuns = false
    gotBombs = false
    gotTorpedoes = false
    gotMines = false
    gotRockets = false
    gotAGM = false 
    gotAAM = false 
    gotGuidedBombs = false
    gotGunnerTurrets = false
    gotSchraegeMusik = false
  }

  foreach (weaponSet in weaponsList)
    foreach (w in weaponSet) {
      if (!w?.blk || w?.dummy)
        continue

      if (w?.trigger == TRIGGER_TYPE.MACHINE_GUN)
        res.gotMachineGuns = true
      if (w?.trigger == TRIGGER_TYPE.CANNON)
        res.gotCannons = true
      if (w?.trigger == TRIGGER_TYPE.ADD_GUN)
        res.gotAdditionalGuns = true
      if (w?.trigger == TRIGGER_TYPE.BOMBS)
        res.gotBombs = true
      if (w?.trigger == TRIGGER_TYPE.TORPEDOES)
        res.gotTorpedoes = true
      if (w?.trigger == TRIGGER_TYPE.MINES)
        res.gotMines = true
      if (w?.trigger == TRIGGER_TYPE.ROCKETS)
        res.gotRockets = true
      if (w?.trigger == TRIGGER_TYPE.AGM || w?.trigger == TRIGGER_TYPE.ATGM)
        res.gotAGM = true
      if (w?.trigger == TRIGGER_TYPE.AAM)
        res.gotAAM = true
      if (w?.trigger == TRIGGER_TYPE.GUIDED_BOMBS)
        res.gotGuidedBombs = true
      if (startsWith(w?.trigger ?? "", "gunner"))
        res.gotGunnerTurrets = true
      if (is_platform_pc && w?.schraegeMusikAngle != null)
        res.gotSchraegeMusik = true
    }

  return res
}

function getRequiredControlsForUnit(unit, helpersMode) {
  local controls = []
  if (!unit || useTouchscreen)
    return controls

  let unitId = unit.name
  let unitType = unit.unitType

  let preset = getCurControlsPreset()
  local actionBarShortcutFormat = null

  let unitBlk = getFullUnitBlk(unitId)
  let commonWeapons = getCommonWeapons(unitBlk, getLastPrimaryWeapon(unit))
  local weaponPreset = []

  let curWeaponPresetId = isInFlight() ? get_cur_unit_weapon_preset() : getLastWeapon(unitId)

  let unitWeapons = unit.getWeapons()
  let curWeapon = unitWeapons.findvalue(@(w) w.name == curWeaponPresetId) ?? unitWeapons?[0]
  weaponPreset = getPresetWeapons(unitBlk, curWeapon)

  local hasControllableRadar = false
  if (unitBlk?.sensors)
    foreach (sensor in (unitBlk.sensors % "sensor"))
      hasControllableRadar = hasControllableRadar || blkOptFromPath(sensor?.blk)?.type == "radar"

  let isMouseAimMode = helpersMode == globalEnv.EM_MOUSE_AIM

  if (unitType == unitTypes.AIRCRAFT) {
    let fmBlk = ::get_fm_file(unitId, unitBlk)
    let unitControls = fmBlk?.AvailableControls || DataBlock()

    let gotInstructor = isMouseAimMode || helpersMode == globalEnv.EM_INSTRUCTOR
    let option = get_option_in_mode(USEROPT_INSTRUCTOR_GEAR_CONTROL, OPTIONS_MODE_GAMEPLAY)
    let instructorGearControl = gotInstructor && option.value

    controls = [ "throttle" ]

    if (needRequireEngineControl())
      controls.append("ID_TOGGLE_ENGINE")

    if (isMouseAimMode)
      controls.append("mouse_aim_x", "mouse_aim_y")
    else {
      if (unitControls?.hasAileronControl)
        controls.append("ailerons")
      if (unitControls?.hasElevatorControl)
        controls.append("elevator")
      if (unitControls?.hasRudderControl)
        controls.append("rudder")
    }

    if (unitControls?.hasGearControl && !instructorGearControl)
      controls.append("ID_GEAR")
    if (unitControls?.hasAirbrake)
      controls.append("ID_AIR_BRAKE")
    if (unitControls?.hasFlapsControl) {
      let shortcuts = getShortcuts([ "ID_FLAPS", "ID_FLAPS_UP", "ID_FLAPS_DOWN" ])
      let flaps   = isShortcutMapped(shortcuts[0])
      let flapsUp = isShortcutMapped(shortcuts[1])
      let flapsDn = isShortcutMapped(shortcuts[2])

      if (!flaps && !flapsUp && !flapsDn)
        controls.append("ID_FLAPS")
      else if (!flaps && !flapsUp && flapsDn)
        controls.append("ID_FLAPS_UP")
      else if (!flaps && flapsUp && !flapsDn)
        controls.append("ID_FLAPS_DOWN")
    }

    if (vehicleModel.hasEngineVtolControl())
      controls.append("vtol")

    if (unitBlk?.parachutes)
      controls.append("ID_CHUTE")

    let w = getWeaponFeatures([ commonWeapons, weaponPreset ])

    if (preset.getAxis("fire").axisId == -1) {
      if (w.gotMachineGuns || (!w.gotCannons && (w.gotGunnerTurrets || w.gotSchraegeMusik))) 
        controls.append("ID_FIRE_MGUNS")
      if (w.gotCannons)
        controls.append("ID_FIRE_CANNONS")
      if (w.gotAdditionalGuns)
        controls.append("ID_FIRE_ADDITIONAL_GUNS")
    }
    if (w.gotSchraegeMusik)
      controls.append("ID_SCHRAEGE_MUSIK")

    if (!hasMappedSecondaryWeaponSelector(unitType)) {
      if (w.gotBombs || w.gotTorpedoes)
        controls.append("ID_BOMBS")
      if (w.gotRockets)
        controls.append("ID_ROCKETS")
      if (w.gotAGM)
        controls.append("ID_AGM")
      if (w.gotAAM)
        controls.append("ID_AAM")
      if (w.gotGuidedBombs)
        controls.append("ID_GUIDED_BOMBS")
    }

    if (hasControllableRadar && !isXInputDevice()) {
      controls.append("ID_SENSOR_SWITCH")
      controls.append("ID_SENSOR_TARGET_SWITCH")
      controls.append("ID_SENSOR_TARGET_LOCK")
    }
  }
  else if (unitType == unitTypes.HELICOPTER) {
    controls = [ "helicopter_collective", "helicopter_climb", "helicopter_cyclic_roll" ]

    if (isXInputDevice())
      controls.append("helicopter_mouse_aim_x", "helicopter_mouse_aim_y")

    let w = getWeaponFeatures([ commonWeapons, weaponPreset ])

    if (preset.getAxis("fire").axisId == -1) {
      if (w.gotMachineGuns || (!w.gotCannons && w.gotGunnerTurrets)) 
        controls.append("ID_FIRE_MGUNS_HELICOPTER")
      if (w.gotCannons)
        controls.append("ID_FIRE_CANNONS_HELICOPTER")
      if (w.gotAdditionalGuns)
        controls.append("ID_FIRE_ADDITIONAL_GUNS_HELICOPTER")
    }

    if (!hasMappedSecondaryWeaponSelector(unitType)) {
      if (w.gotBombs || w.gotTorpedoes)
        controls.append("ID_BOMBS_HELICOPTER")
      if (w.gotRockets)
        controls.append("ID_ROCKETS_HELICOPTER")
      if (w.gotAGM)
        controls.append("ID_ATGM_HELICOPTER")
      if (w.gotAAM)
        controls.append("ID_AAM_HELICOPTER")
      if (w.gotGuidedBombs)
        controls.append("ID_GUIDED_BOMBS_HELICOPTER")
    }
  }
  





  else if (unitType == unitTypes.TANK) {
    controls = [ "gm_throttle", "gm_steering", "gm_mouse_aim_x", "gm_mouse_aim_y", "ID_TOGGLE_VIEW_GM", "ID_FIRE_GM", "ID_REPAIR_TANK" ]

    if (is_platform_pc && !isXInputDevice()) {
      if (shopIsModificationEnabled(unitId, "manual_extinguisher"))
        controls.append("ID_ACTION_BAR_ITEM_6")
      if (shopIsModificationEnabled(unitId, "art_support")) {
        controls.append("ID_ACTION_BAR_ITEM_5")
        controls.append("ID_SHOOT_ARTILLERY")
      }
    }

    if (hasControllableRadar && !isXInputDevice()) {
      controls.append("ID_SENSOR_TARGET_SWITCH_TANK")
      controls.append("ID_SENSOR_TARGET_LOCK_TANK")
    }

    let gameParams = get_game_params_blk()
    let missionDifficulty = get_mission_difficulty()
    let difficultyName = g_difficulty.getDifficultyByName(missionDifficulty).settingsName
    let difficultySettings = gameParams?.difficulty_settings?.baseDifficulty?[difficultyName]

    let tags = unit?.tags || []
    let scoutPresetId = difficultySettings?.scoutPreset ?? ""
    if (hasFeature("ActiveScouting") && tags.indexof("scout") != null
      && gameParams?.scoutPresets?[scoutPresetId]?.enabled)
      controls.append("ID_SCOUT")

    actionBarShortcutFormat = "ID_ACTION_BAR_ITEM_%d"
  }
  else if (unitType == unitTypes.SHIP || unitType == unitTypes.BOAT) {
    controls = ["ship_steering", "ID_TOGGLE_VIEW_SHIP"]

    let isSeperatedEngineControl =
      get_gui_option_in_mode(USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, OPTIONS_MODE_GAMEPLAY)
    if (isSeperatedEngineControl)
      controls.append("ship_port_engine", "ship_star_engine")
    else
      controls.append("ship_main_engine")

    let weaponGroups = [
      {
        triggerGroup = "primary"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_PRIMARY"]
      }
      {
        triggerGroup = "secondary"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_SECONDARY"]
      }
      {
        triggerGroup = "machinegun"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_MACHINEGUN"]
      }
      {
        triggerGroup = "torpedoes"
        shortcuts = ["ID_SHIP_WEAPON_TORPEDOES"]
      }
      {
        triggerGroup = "depth_charge"
        shortcuts = ["ID_SHIP_WEAPON_DEPTH_CHARGE"]
      }
      {
        triggerGroup = "mortar"
        shortcuts = ["ID_SHIP_WEAPON_MORTAR"]
      }
      {
        triggerGroup = "rockets"
        shortcuts = ["ID_SHIP_WEAPON_ROCKETS"]
      }
    ]

    foreach (weaponSet in [ commonWeapons, weaponPreset ]) {
      foreach (weapon in weaponSet) {
        if (!weapon?.blk || weapon?.dummy)
          continue

        foreach (group in weaponGroups) {
          if (group?.isRequired || group.triggerGroup != weapon?.triggerGroup)
            continue

          group.isRequired <- true
          break
        }
      }
    }

    foreach (group in weaponGroups)
      if (group?.isRequired) {
        local isMapped = false
        foreach (shortcut in group.shortcuts)
          if (preset.getHotkey(shortcut).len() > 0) {
            isMapped = true
            break
          }
        if (!isMapped)
          foreach (shortcut in group.shortcuts)
            if (controls.indexof(shortcut) == null)
              controls.append(shortcut)
      }

    actionBarShortcutFormat = "ID_SHIP_ACTION_BAR_ITEM_%d"
  }

  if (actionBarShortcutFormat) {
    if (is_platform_pc && !isXInputDevice()) {
      local bulletsChoice = 0
      for (local groupIndex = 0; groupIndex < unitType.bulletSetsQuantity; groupIndex++) {
        if (isBulletGroupActive(unit, groupIndex)) {
          let bullets = get_unit_option(unitId, USEROPT_BULLET_COUNT0 + groupIndex)
          if (bullets != null && bullets > 0)
            bulletsChoice++
        }
      }
      if (bulletsChoice > 1)
        for (local i = 0; i < bulletsChoice; i++)
          controls.append(format(actionBarShortcutFormat, i + 1))
    }
  }

  if (unitType.wheelmenuAxis.len()) {
    controls.append("ID_SHOW_MULTIFUNC_WHEEL_MENU")
    if (isXInputDevice())
      controls.extend(unitType.wheelmenuAxis)
  }

  return controls
}

function getCurrentHelpersMode() {
  let difficulty = isInFlight() ? get_mission_difficulty_int() : getCurrentShopDifficulty().diffCode
  if (difficulty == 2)
    return (is_platform_pc ? globalEnv.EM_FULL_REAL : globalEnv.EM_REALISTIC)
  let option = get_option_in_mode(USEROPT_HELPERS_MODE, OPTIONS_MODE_GAMEPLAY)
  return option.values[option.value]
}

function getUnmappedControls(controls, helpersMode, getLocNames = true, shouldCheckRequirements = false) {
  let unmapped = []

  let joyParams = joystickGetCurSettings()
  foreach (item in ::shortcutsList) {
    if (isInArray(item.id, controls)) {
      if ((("filterHide" in item) && isInArray(helpersMode, item.filterHide))
        || (("filterShow" in item) && !isInArray(helpersMode, item.filterShow))
        || (("showFunc" not in item) || !item.showFunc())
        || (shouldCheckRequirements && helpersMode == globalEnv.EM_MOUSE_AIM && !item.reqInMouseAim))
        continue

      if (item.type == CONTROL_TYPE.SHORTCUT) {
        let shortcuts = getShortcuts([ item.id ])
        if (!shortcuts.len() || isShortcutMapped(shortcuts[0]))
          continue

        let altIds = item?.alternativeIds ?? []
        foreach (otherItem in ::shortcutsList)
          if ((otherItem?.alternativeIds ?? []).indexof(item.id) != null)
            u.appendOnce(otherItem.id, altIds)
        local isMapped = false
        foreach (s in getShortcuts(altIds))
          if (isShortcutMapped(s)) {
            isMapped = true
            break
          }
        if (isMapped)
          continue

        unmapped.append("".concat(getLocNames ? "hotkeys/" : "", item.id))
      }
      else if (item.type == CONTROL_TYPE.AXIS) {
        if (::is_axis_mapped_on_mouse(item.id, helpersMode, joyParams))
          continue

        let axisIndex = get_axis_index(item.id)
        let axisId = axisIndex >= 0
          ? joyParams.getAxis(axisIndex).axisId : -1
        if (axisId == -1) {
          let modifiers = ["rangeMin", "rangeMax"]
          local shortcutsCount = 0
          foreach (modifier in modifiers) {
            if (!("hideAxisOptions" in item) || !isInArray(modifier, item.hideAxisOptions)) {
              let shortcuts = getShortcuts([ $"{item.id}_{modifier}" ])
              if (shortcuts.len() && isShortcutMapped(shortcuts[0]))
                shortcutsCount++
            }
          }
          if (shortcutsCount < modifiers.len())
            unmapped.append("".concat(getLocNames ? "controls/" : "", item.axisName))
        }
      }
    }
  }

  return unmapped
}

let tutorialControlAliases = {
  ["ANY"]                = null,
  ["ID_CONTINUE"]        = null,
  ["ID_SKIP_CUTSCENE"]   = null,
  ["ID_FIRE"]            = "ID_FIRE_MGUNS",
  ["ID_TRANS_GEAR_UP"]   = "gm_throttle",
  ["ID_TRANS_GEAR_DOWN"] = "gm_throttle",
}

let tutorialSkipControl = {
  ["ID_TOGGLE_ENGINE"] = @() !needRequireEngineControl()
}

function getUnmappedControlsForTutorial(missionId, helpersMode) {
  local res = []

  local mis_file = null
  let chapters = get_meta_missions_info_by_chapters(GM_TRAINING)
  foreach (chapter in chapters)
    foreach (m in chapter)
      if (m.name == missionId) {
        mis_file = m.mis_file
        break
      }
  if (mis_file == null)
    return res
  let missionBlk = blkFromPath(mis_file)
  if (!missionBlk?.triggers)
    return res

  let isXinput = isXInputDevice()
  let isAllowedCondition = @(condition) condition?.gamepadControls == null || condition.gamepadControls == isXinput

  let conditionsList = []
  foreach (trigger in missionBlk.triggers) {
    if (type(trigger) != "instance")
      continue

    let condition = (trigger?.props.conditionsType != "ANY") ? "ALL" : "ANY"

    let shortcuts = []
    if (trigger?.conditions) {
      foreach (playerShortcutPressed in trigger.conditions % "playerShortcutPressed")
        if (playerShortcutPressed?.control && isAllowedCondition(playerShortcutPressed)) {
          let id = playerShortcutPressed.control
          if (tutorialSkipControl?[id]() ?? false)
            continue
          let alias = (id in tutorialControlAliases) ? tutorialControlAliases[id] : id
          if (alias && !isInArray(alias, shortcuts))
            shortcuts.append(alias)
        }

      foreach (playerWhenOptions in trigger.conditions % "playerWhenOptions")
        if (playerWhenOptions?.currentView)
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_TOGGLE_VIEW" ] })

      foreach (unitWhenInArea in trigger.conditions % "unitWhenInArea")
        if (unitWhenInArea?.target == "gears_area")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_GEAR" ] })

      foreach (unitWhenStatus in trigger.conditions % "unitWhenStatus")
        if (unitWhenStatus?.object_type == "isTargetedByPlayer")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_LOCK_TARGET" ] })

      foreach (playerWhenCameraState in trigger.conditions % "playerWhenCameraState")
        if (playerWhenCameraState?.state == "fov")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_ZOOM_TOGGLE" ] })
    }

    if (shortcuts.len())
      conditionsList.append({ condition = condition, shortcuts = shortcuts })
  }

  foreach (cond in conditionsList)
    if (cond.shortcuts.len() == 1)
      cond.condition = "ALL"

  for (local i = conditionsList.len() - 1; i >= 0; i--) {
    local duplicate = false
    for (local j = i - 1; j >= 0; j--)
      if (u.isEqual(conditionsList[i], conditionsList[j])) {
        duplicate = true
        break
      }
    if (duplicate)
      conditionsList.remove(i)
  }

  let controlsList = []
  foreach (cond in conditionsList)
    foreach (id in cond.shortcuts)
      if (!isInArray(id, controlsList))
        controlsList.append(id)
  let unmapped = getUnmappedControls(controlsList, helpersMode, false, false)

  foreach (cond in conditionsList) {
    if (cond.condition == "ALL")
      foreach (id in cond.shortcuts)
        if (isInArray(id, unmapped) && !isInArray(id, res))
          res.append(id)
  }

  foreach (cond in conditionsList) {
    if (cond.condition == "ANY" || cond.condition == "ONE") {
      local allUnmapped = true
      foreach (id in cond.shortcuts)
        if (!isInArray(id, unmapped) || isInArray(id, res)) {
          allUnmapped = false
          break
        }
      if (allUnmapped)
        foreach (id in cond.shortcuts)
          if (!isInArray(id, res)) {
            res.append(id)
            if (cond.condition == "ONE")
              break
          }
    }
  }

  res = getUnmappedControls(res, helpersMode, true, false)
  return res
}

function getUnmappedControlsForCurrentMission() {
  let gm = get_game_mode()
  if (is_benchmark_game_mode())
    return []

  let unit = getPlayerCurUnit()
  let helpersMode = getCurrentHelpersMode()
  let required = getRequiredControlsForUnit(unit, helpersMode)

  let unmapped = getUnmappedControls(required, helpersMode, true, false)
  if (isInFlight() && gm == GM_TRAINING) {
    let tutorialUnmapped = getUnmappedControlsForTutorial(currentCampaignMission.get(), helpersMode)
    foreach (id in tutorialUnmapped)
      u.appendOnce(id, unmapped)
  }
  return unmapped
}

eventbus_subscribe("controls.joystickDisconnected", @(_) onJoystickDisconnected())
eventbus_subscribe("controls.joystickConnected", @(_) onJoystickConnected())

local xboxInputDevicesData = persist("xboxInputDevicesData", @() { gamepads = 0, keyboards = 0, user_notified = false })

if (is_xbox) {
  let { DeviceType, register_for_devices_change } = require("%gdkLib/impl/input.nut")

  register_for_devices_change(function(device_type, count) {
    if (device_type == DeviceType.Gamepad)
      xboxInputDevicesData.gamepads = count
    if (device_type == DeviceType.Keyboard)
      xboxInputDevicesData.keyboards = count

    let shouldNotify = xboxInputDevicesData.gamepads == 0 && xboxInputDevicesData.keyboards == 0
    if (shouldNotify && !xboxInputDevicesData.user_notified) {
      xboxInputDevicesData.user_notified = true
      add_msg_box("no_input_devices", loc("pl1/lostController"),
        [
          ["ok", @() xboxInputDevicesData.user_notified = false]
        ], "ok")
    }
  })
}

updateExtWatched({ haveXinputDevice = hasXInputDevice() })

on_module_unload(@(_) controllerState.remove_event_handler(onControllerEvent))

if (isLoggedIn.get())
  controllerState.add_event_handler(onControllerEvent)

addListenersWithoutEnv({
  LoginComplete = @(_) controllerState.add_event_handler(onControllerEvent)
})

return {
  getControlsList
  getMouseUsageMask
  recommendedControlPresets
  checkOptionValue
  getControlsPresetBySelectedType
  isDeviceConnected
  needRequireEngineControl
  getRequiredControlsForUnit
  getCurrentHelpersMode
  getUnmappedControlsForCurrentMission
}