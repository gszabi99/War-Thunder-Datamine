from "%scripts/dagui_natives.nut" import is_tank_gunner_camera_from_sight_available, is_hdr_enabled, is_compatibility_mode, get_player_unit_name
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import *

let { g_difficulty } = require("%scripts/difficulty.nut")
let safeAreaMenu = require("%scripts/options/safeAreaMenu.nut")
let safeAreaHud = require("%scripts/options/safeAreaHud.nut")
let contentPreset = require("%scripts/customization/contentPreset.nut")
let soundDevice = require("soundDevice")
let { is_stereo_mode } = require("vr")
let { chatStatesCanUseVoice } = require("%scripts/chat/chatStates.nut")
let { onSystemOptionsApply, canUseGraphicsOptions, getSystemOptionInfoView } = require("%scripts/options/systemOptions.nut")
let { isPlatformSony, isPlatformXboxOne, isPlatformXboxScarlett } = require("%scripts/clientState/platform.nut")
let { is_xboxone_X } = require("%sqstd/platform.nut")
//


let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { get_mission_difficulty_int, get_mission_difficulty } = require("guiMission")
let { get_radar_mode_names, get_radar_scan_pattern_names, get_radar_range_values } = require("radarOptions")
let { canSwitchGameLocalization } = require("%scripts/langUtils/language.nut")
let { hasCustomLocalizationFlag } = require("%scripts/langUtils/customLocalization.nut")
let { isInFlight } = require("gameplayBinding")
let { can_add_tank_alt_crosshair, get_user_alt_crosshairs } = require("crosshair")
let { hasCustomSoundMods } = require("%scripts/options/customSoundMods.nut")
let { isCrossNetworkChatEnabled } = require("%scripts/social/crossplay.nut")
let { is_hfr_supported } = require("graphicsOptions")

let getSystemOptions = @() {
  name = "graphicsParameters"
  fillFuncName = "fillSystemOptions"
  isInfoOnTheRight = true
  onApplyHandler = @() onSystemOptionsApply()
  getOptionInfoView = @(id) getSystemOptionInfoView(id)
  options = []
}

local overrideMainOptionsFn = null

function getPrivacyOptionsList() {
  let hasPrivacyFeature = hasFeature("PrivacySettings")
  let hasWishlistFeature = hasFeature("Wishlist")
  return [
    ["options/header/privacy", null, hasPrivacyFeature || hasWishlistFeature],
    [USEROPT_DISPLAY_MY_REAL_NICK, "spinner", hasPrivacyFeature],
    [USEROPT_SHOW_SOCIAL_NOTIFICATIONS, "spinner", hasPrivacyFeature],
    [USEROPT_ALLOW_ADDED_TO_CONTACTS, "spinner", hasPrivacyFeature],
    [USEROPT_ALLOW_SHOW_WISHLIST, "spinner", hasWishlistFeature],
    [USEROPT_ALLOW_SHOW_WISHLIST_COMMENTS, "spinner", hasWishlistFeature],
    [USEROPT_ALLOW_ADDED_TO_LEADERBOARDS, "spinner", hasPrivacyFeature],
    [USEROPT_DISPLAY_REAL_NICKS_PARTICIPANTS, "spinner", hasPrivacyFeature && is_platform_pc]
  ]
}

function hasConsolePresets() {
  return (is_xboxone_X || (isPlatformXboxScarlett && is_hfr_supported()))
    && hasFeature("optionConsolePreset")
}

let otherOptionsList = @() [
  ["options/header/otherOptions"],
  [USEROPT_MENU_SCREEN_SAFE_AREA, "spinner", safeAreaMenu.canChangeValue()],
  [USEROPT_SUBTITLES, "spinner"],
  [USEROPT_HUD_SCREENSHOT_LOGO, "spinner", is_platform_pc],
  [USEROPT_SAVE_ZOOM_CAMERA, "spinner"],
  [USEROPT_HOLIDAYS, "list"]
]

let getMainOptions = function() {
  let unit = getAircraftByName(get_player_unit_name())
  let isShipOrBoat = unit?.isShipOrBoat() ?? false
  let isTank = unit?.isTank() ?? false
  let isAir = unit?.isAir() ?? false
  let isHelicopter = unit?.isHelicopter() ?? false
  let isAllowRadarMode = hasFeature("allowRadarModeOptions") && get_radar_mode_names("", "").len() > 0 && (get_radar_mode_names("", "").len() > 1 || get_radar_scan_pattern_names("", "").len() > 1 || get_radar_range_values("", "").len() > 1)

  if (overrideMainOptionsFn != null)
    return overrideMainOptionsFn()

  let canChangeViewType = getPlayerCurUnit()?.unitType.canChangeViewType ?? false

  return {
    name = isInFlight() ? "main" : "mainParameters"
    isSearchAvaliable = true
    showNav = true
    options = [
      ["options/mainParameters"],
      [USEROPT_LANGUAGE, "spinner", ! isInFlight() && canSwitchGameLocalization()],
      [USEROPT_CUSTOM_LANGUAGE, "spinner", hasCustomLocalizationFlag()],
      [USEROPT_PS4_CROSSPLAY, "spinner", isPlatformSony && hasFeature("PS4CrossNetwork") && !isInFlight()],
      [USEROPT_PS4_ONLY_LEADERBOARD, "spinner", isPlatformSony && hasFeature("ConsoleSeparateLeaderboards")],
      [USEROPT_CLUSTERS, "spinner", ! isInFlight() && isPlatformSony],
      //


      [USEROPT_FONTS_CSS, "spinner"],
      [USEROPT_GAMMA, "slider", !is_hdr_enabled()],
      [USEROPT_AUTOLOGIN, "spinner", ! isInFlight() && !(isPlatformSony || isPlatformXboxOne)],
      [USEROPT_PRELOADER_SETTINGS, "button", hasFeature("LoadingBackgroundFilter") && !isInFlight()],
      [USEROPT_REVEAL_NOTIFICATIONS, "button"],
      [USEROPT_POSTFX_SETTINGS, "button", !is_compatibility_mode()],
      [USEROPT_HDR_SETTINGS, "button", is_hdr_enabled()],
      [USEROPT_CONSOLE_GFX_PRESET, "combobox", hasConsolePresets()],

      ["options/header/commonBattleParameters"],
      [USEROPT_DAMAGE_INDICATOR_SIZE, "slider"],
      [USEROPT_CAMERA_SHAKE_MULTIPLIER, "slider"],
      [USEROPT_VR_CAMERA_SHAKE_MULTIPLIER, "slider", is_stereo_mode()],
      [USEROPT_FPS_CAMERA_PHYSICS, "slider"],
      [USEROPT_FPS_VR_CAMERA_PHYSICS, "slider", is_stereo_mode()],
      [USEROPT_AUTO_SQUAD, "spinner"],
      [USEROPT_QUEUE_JIP, "spinner"],
      [USEROPT_ORDER_AUTO_ACTIVATE, "spinner", hasFeature("OrderAutoActivate")],
      [USEROPT_TANK_ALT_CROSSHAIR, "spinner", can_add_tank_alt_crosshair() && !hasFeature("enableCustomTankSights")
                                                && (hasFeature("TankAltCrosshair")
                                                    || get_user_alt_crosshairs("", "").len()
                                                   )],

      ["options/header/air"],
      [USEROPT_HUE_AIRCRAFT_HUD, "spinner"],
      [USEROPT_HUE_AIRCRAFT_PARAM_HUD, "spinner",  hasFeature("reactivGuiForAircraft")],
      [USEROPT_HUE_AIRCRAFT_HUD_ALERT, "spinner",  hasFeature("reactivGuiForAircraft")],
      [USEROPT_VIEWTYPE, "spinner", ! isInFlight()],
      [USEROPT_GUN_TARGET_DISTANCE, "spinner", ! isInFlight()],
      [USEROPT_GUN_VERTICAL_TARGETING, "spinner", ! isInFlight()],
      [USEROPT_BOMB_ACTIVATION_TIME, "spinner", ! isInFlight()],
      [USEROPT_BOMB_SERIES, "spinner", ! isInFlight()],
      [USEROPT_COUNTERMEASURES_SERIES_PERIODS, "spinner", ! isInFlight()],
      [USEROPT_COUNTERMEASURES_PERIODS, "spinner", ! isInFlight()],
      [USEROPT_COUNTERMEASURES_SERIES, "spinner", ! isInFlight()],
      [USEROPT_SHOW_PILOT, "spinner"],
      [USEROPT_AUTOPILOT_ON_BOMBVIEW, "spinner"],
      [USEROPT_AUTOREARM_ON_AIRFIELD, "spinner"],
      [USEROPT_ENABLE_LASER_DESIGNATOR_ON_LAUNCH, "spinner"],
      [USEROPT_AUTO_AIMLOCK_ON_SHOOT, "spinner"],
      [USEROPT_AUTO_SEEKER_STABILIZATION, "spinner"],
      [USEROPT_ACTIVATE_AIRBORNE_RADAR_ON_SPAWN, "spinner"],
      [USEROPT_USE_RECTANGULAR_RADAR_INDICATOR, "spinner"],
      [USEROPT_RADAR_TARGET_CYCLING, "spinner"],
      [USEROPT_RADAR_AIM_ELEVATION_CONTROL, "spinner"],
      [USEROPT_RWR_SENSITIVITY, "slider"],
      [USEROPT_USE_RADAR_HUD_IN_COCKPIT, "spinner"],
      [USEROPT_USE_TWS_HUD_IN_COCKPIT, "spinner"],
      [USEROPT_ACTIVATE_AIRBORNE_ACTIVE_COUNTER_MEASURES_ON_SPAWN, "spinner"],
      [USEROPT_AIR_RADAR_SIZE, "slider"],
      [USEROPT_CROSSHAIR_TYPE, "combobox"],
      [USEROPT_CROSSHAIR_COLOR, "combobox"],
      [USEROPT_INDICATED_SPEED_TYPE, "spinner"],
      [USEROPT_INDICATED_ALTITUDE_TYPE, "spinner"],
      [USEROPT_RADAR_ALTITUDE_ALERT, "slider"],
      [USEROPT_CROSSHAIR_DEFLECTION, "spinner"],
      [USEROPT_GYRO_SIGHT_DEFLECTION, "spinner", hasFeature("allowShowGyroSightDeflection")],
      [USEROPT_AIR_DAMAGE_DISPLAY, "spinner", ! isInFlight()],
      [USEROPT_GUNNER_FPS_CAMERA, "spinner"],
      [USEROPT_ACTIVATE_AIRBORNE_WEAPON_SELECTION_ON_SPAWN, "spinner"],
      [USEROPT_ACTIVATE_BOMBS_AUTO_RELEASE_ON_SPAWN, "spinner"],
      [USEROPT_AUTOMATIC_EMPTY_CONTAINERS_JETTISON, "spinner"],
      [USEROPT_RADAR_MODE_SELECT, "spinner", isAir && isAllowRadarMode],
      [USEROPT_RADAR_SCAN_PATTERN_SELECT, "spinner", isAir && isAllowRadarMode],
      [USEROPT_RADAR_SCAN_RANGE_SELECT, "spinner", isAir && isAllowRadarMode],
      [USEROPT_SHOW_MESSAGE_MISSILE_EVADE, "spinner"],

      ["options/header/helicopter"],
      [USEROPT_HUE_HELICOPTER_CROSSHAIR, "spinner"],
      [USEROPT_HUE_HELICOPTER_HUD, "spinner"],
      [USEROPT_HUE_HELICOPTER_PARAM_HUD, "spinner"],
      [USEROPT_HUE_HELICOPTER_HUD_ALERT, "spinner"],
      [USEROPT_HUE_HELICOPTER_MFD, "spinner"],
      [USEROPT_HORIZONTAL_SPEED, "spinner"],
      [USEROPT_HELICOPTER_HELMET_AIM, "spinner", !(isPlatformSony || isPlatformXboxOne)],
      [USEROPT_HELICOPTER_AUTOPILOT_ON_GUNNERVIEW, "spinner"],
      [USEROPT_ALTERNATIVE_TPS_CAMERA, "spinner"],
      [USEROPT_HELI_COCKPIT_HUD_DISABLED, "spinner"],
      [USEROPT_LWS_IND_H_RADIUS, "slider"],
      [USEROPT_LWS_IND_H_ALPHA, "slider"],
      [USEROPT_LWS_IND_H_SCALE, "slider"],
      [USEROPT_LWS_IND_H_TIMEOUT, "slider"],
      [USEROPT_LWS_IND_AZIMUTH_H_TIMEOUT, "slider"],
      [USEROPT_RADAR_MODE_SELECT, "spinner", isHelicopter && isAllowRadarMode],
      [USEROPT_RADAR_SCAN_PATTERN_SELECT, "spinner", isHelicopter && isAllowRadarMode],
      [USEROPT_RADAR_SCAN_RANGE_SELECT, "spinner", isHelicopter && isAllowRadarMode],

      ["options/header/tank"],
      [TANK_SIGHT_SETTINGS, "button", hasFeature("enableCustomTankSights")],
      [USEROPT_GRASS_IN_TANK_VISION, "spinner"],
      [USEROPT_XRAY_DEATH, "spinner", hasFeature("XrayDeath")],
      [USEROPT_XRAY_KILL, "spinner", hasFeature("XrayKill")],
      [USEROPT_TANK_GUNNER_CAMERA_FROM_SIGHT, "spinner",
        (!isInFlight() || !is_tank_gunner_camera_from_sight_available())],
      [USEROPT_SHOW_DESTROYED_PARTS, "spinner"],
      [USEROPT_ACTIVATE_GROUND_RADAR_ON_SPAWN, "spinner"],
      [USEROPT_GROUND_RADAR_TARGET_CYCLING, "spinner"],
      [USEROPT_ACTIVATE_GROUND_ACTIVE_COUNTER_MEASURES_ON_SPAWN, "spinner"],
      [USEROPT_TACTICAL_MAP_SIZE, "slider"],
      [USEROPT_MAP_ZOOM_BY_LEVEL, "spinner", !(isPlatformSony || isPlatformXboxOne) && !is_platform_android],
      [USEROPT_SHOW_COMPASS_IN_TANK_HUD, "spinner"],
      [USEROPT_HUE_TANK_THERMOVISION, "spinner"],
      [USEROPT_PITCH_BLOCKER_WHILE_BRACKING, "spinner"],
      [USEROPT_COMMANDER_CAMERA_IN_VIEWS, "spinner"],
      [USEROPT_SAVE_DIR_WHILE_SWITCH_TRIGGER, "spinner"],
      [USEROPT_HUD_SHOW_TANK_GUNS_AMMO, "spinner"],
      [USEROPT_HIT_INDICATOR_SIMPLIFIED, "switchbox", hasFeature("advancedHitIndicator")],
      [USEROPT_HIT_INDICATOR_RADIUS, "slider", hasFeature("advancedHitIndicator")],
      [USEROPT_HIT_INDICATOR_ALPHA, "slider", hasFeature("advancedHitIndicator")],
      [USEROPT_HIT_INDICATOR_SCALE, "slider", hasFeature("advancedHitIndicator")],
      [USEROPT_HIT_INDICATOR_FADE_TIME, "slider", hasFeature("advancedHitIndicator")],
      [USEROPT_LWS_IND_RADIUS, "slider"],
      [USEROPT_LWS_IND_ALPHA, "slider"],
      [USEROPT_LWS_IND_SCALE, "slider"],
      [USEROPT_LWS_IND_TIMEOUT, "slider"],
      [USEROPT_LWS_AZIMUTH_IND_TIMEOUT, "slider"],
      [USEROPT_RADAR_MODE_SELECT, "spinner", isTank && isAllowRadarMode],
      [USEROPT_RADAR_SCAN_PATTERN_SELECT, "spinner", isTank && isAllowRadarMode],
      [USEROPT_RADAR_SCAN_RANGE_SELECT, "spinner", isTank && isAllowRadarMode],

      ["options/header/ship"],
      [USEROPT_DEPTHCHARGE_ACTIVATION_TIME, "spinner", ! isInFlight()],
      [USEROPT_USE_PERFECT_RANGEFINDER, "spinner"],
      [USEROPT_SAVE_AI_TARGET_TYPE, "spinner"],
      [USEROPT_DEFAULT_AI_TARGET_TYPE, "spinner"],
      [USEROPT_TORPEDO_AUTO_SWITCH, "spinner"],
      [USEROPT_DEFAULT_TORPEDO_FORESTALL_ACTIVE, "spinner"],
      [USEROPT_BULLET_FALL_INDICATOR_SHIP, "spinner"],
      [USEROPT_BULLET_FALL_SPOT_SHIP, "spinner"],
      [USEROPT_BULLET_FALL_SOUND_SHIP, "spinner"],
      [USEROPT_AUTO_TARGET_CHANGE_SHIP, "spinner"],
      [USEROPT_REALISTIC_AIMING_SHIP, "spinner",
        (!isInFlight() || get_mission_difficulty() == g_difficulty.ARCADE.gameTypeName)],
      // TODO: separate from tank [USEROPT_TACTICAL_MAP_SIZE, "slider"],
      // TODO: separate from tank [USEROPT_MAP_ZOOM_BY_LEVEL, "spinner"],
      [USEROPT_FOLLOW_BULLET_CAMERA, "spinner", hasFeature("enableFollowBulletCamera")],
      [USEROPT_RADAR_MODE_SELECT, "spinner", isShipOrBoat && isAllowRadarMode],
      [USEROPT_RADAR_SCAN_PATTERN_SELECT, "spinner", isShipOrBoat && isAllowRadarMode],
      [USEROPT_RADAR_SCAN_RANGE_SELECT, "spinner", isShipOrBoat && isAllowRadarMode],

      ["options/header/interface"],
      [USEROPT_HUD_SCREEN_SAFE_AREA, "spinner", safeAreaHud.canChangeValue()],
      [USEROPT_GAME_HUD, "spinner"],
      [USEROPT_HUD_INDICATORS, "spinner", "get_option_hud_indicators" in getroottable()],
      [USEROPT_HUE_SQUAD, "spinner"],
      [USEROPT_HUE_ALLY, "spinner"],
      [USEROPT_HUE_ENEMY, "spinner"],
      [USEROPT_HUE_RELOAD, "spinner"],
      [USEROPT_HUE_RELOAD_DONE, "spinner"],
      [USEROPT_HUE_ARBITER_HUD, "spinner", hasFeature("reactivGuiForArbitrer")],
      [USEROPT_STROBE_ALLY, "spinner"],
      [USEROPT_STROBE_ENEMY, "spinner"],
      [USEROPT_HUD_SHOW_FUEL, "spinner"],
      [USEROPT_HUD_SHOW_AMMO, "spinner"],
      [USEROPT_HUD_SHOW_TEMPERATURE, "spinner"],
      [USEROPT_INGAME_VIEWTYPE, "spinner", isInFlight() && canChangeViewType],
      [USEROPT_HUD_VISIBLE_ORDERS, "switchbox"],
      [USEROPT_HUD_VISIBLE_REWARDS_MSG, "switchbox"],
      [USEROPT_HUD_VISIBLE_KILLLOG, "switchbox"],
      [USEROPT_HUD_SHOW_NAMES_IN_KILLLOG, "switchbox"],
      [USEROPT_HUD_SHOW_AMMO_TYPE_IN_KILLLOG, "switchbox"],
      [USEROPT_HUD_SHOW_SQUADRON_NAMES_IN_KILLLOG, "switchbox"],
      [USEROPT_HUD_SHOW_DEATH_REASON_IN_SHIP_KILLLOG, "switchbox"],
      [USEROPT_HUD_VISIBLE_STREAKS, "switchbox"],
      [USEROPT_HUD_VISIBLE_CHAT_PLACE, "switchbox"],
      [USEROPT_SHOW_ACTION_BAR, "switchbox"],

      ["options/header/measureUnits"],
      [USEROPT_MEASUREUNITS_SPEED, "spinner"],
      [USEROPT_MEASUREUNITS_ALT, "spinner"],
      [USEROPT_MEASUREUNITS_DIST, "spinner"],
      [USEROPT_MEASUREUNITS_CLIMBSPEED, "spinner"],
      [USEROPT_MEASUREUNITS_TEMPERATURE, "spinner"],
      [USEROPT_MEASUREUNITS_WING_LOADING, "spinner", hasFeature("CardAirplaneWingLoadingParameter")],
      [USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO, "spinner", hasFeature("CardAirplanePowerParameter")],
      [USEROPT_MEASUREUNITS_RADIAL_SPEED, "spinner"],

      ["options/header/playersMarkers"],
      [USEROPT_SHOW_INDICATORS, "spinner"],
      [USEROPT_SHOW_INDICATORS_TYPE, "spinner"],
      [USEROPT_SHOW_INDICATORS_NICK, "spinner"],
      [USEROPT_SHOW_INDICATORS_AIRCRAFT, "spinner"],
      [USEROPT_SHOW_INDICATORS_TITLE, "spinner"],
      [USEROPT_SHOW_INDICATORS_DIST, "spinner"],

      ["options/header/chatAndVoiceChat"],
      [USEROPT_PS4_CROSSNETWORK_CHAT, "spinner", isPlatformSony && hasFeature("PS4CrossNetwork")],
      [USEROPT_ONLY_FRIENDLIST_CONTACT, "spinner", ! isInFlight()],
      [USEROPT_AUTO_SHOW_CHAT, "spinner"],
      [USEROPT_CHAT_MESSAGES_FILTER, "spinner"],
      [USEROPT_CHAT_FILTER, "spinner"],
      [USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL, "spinner"],

      ["options/header/gamepad"],
      [USEROPT_ENABLE_CONSOLE_MODE, "spinner", !::get_is_console_mode_force_enabled()],
      [USEROPT_GAMEPAD_CURSOR_CONTROLLER, "spinner", ::g_gamepad_cursor_controls.canChangeValue()],
      [USEROPT_XCHG_STICKS, "spinner"],
      [USEROPT_VIBRATION, "spinner"],
      [USEROPT_GAMEPAD_VIBRATION_ENGINE, "spinner", !isPlatformSony],
      [USEROPT_JOY_MIN_VIBRATION, "slider"],
      [USEROPT_GAMEPAD_ENGINE_DEADZONE, "spinner"],
      [USEROPT_GAMEPAD_GYRO_TILT_CORRECTION, "spinner", isPlatformSony],
      [USEROPT_USE_CONTROLLER_LIGHT, "spinner", isPlatformSony && hasFeature("ControllerLight")],

      ["options/header/replaysAndSpectatorMode", null, hasFeature("ClientReplay") || hasFeature("ServerReplay") || hasFeature("Spectator")],
      [USEROPT_AUTOSAVE_REPLAYS, "spinner", !isInFlight() && hasFeature("ClientReplay")],
      [USEROPT_HUE_SPECTATOR_ALLY, "spinner", hasFeature("ClientReplay") || hasFeature("ServerReplay") || hasFeature("Spectator")],
      [USEROPT_HUE_SPECTATOR_ENEMY, "spinner", hasFeature("ClientReplay") || hasFeature("ServerReplay") || hasFeature("Spectator")],
      [USEROPT_REPLAY_ALL_INDICATORS, "spinner", hasFeature("ClientReplay") || hasFeature("ServerReplay") || hasFeature("Spectator")],
      [USEROPT_REPLAY_LOAD_COCKPIT, "spinner", hasFeature("ClientReplay") || hasFeature("ServerReplay") || hasFeature("Spectator")],
      [USEROPT_HIDE_MOUSE_SPECTATOR, "spinner", hasFeature("ClientReplay") || hasFeature("ServerReplay") || hasFeature("Spectator")],
      [USEROPT_REPLAY_SNAPSHOT_ENABLED, "spinner", hasFeature("ClientReplay") && hasFeature("replayRewind")],
      [USEROPT_RECORD_SNAPSHOT_PERIOD, "spinner", hasFeature("ClientReplay") && hasFeature("replayRewind")],
      [USEROPT_REPLAY_FOV, "slider", hasFeature("ClientReplay") || hasFeature("ServerReplay") || hasFeature("Spectator")],

      ["options/header/userGeneratedContent"],
      [USEROPT_SHOW_OTHERS_DECALS, "spinner"],
      [USEROPT_CONTENT_ALLOWED_PRESET_ARCADE,    "combobox", contentPreset.getContentPresets().len()],
      [USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC, "combobox", contentPreset.getContentPresets().len()],
      [USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR, "combobox",
        contentPreset.getContentPresets().len() &&
        g_difficulty.SIMULATOR.isAvailable(GM_DOMINATION)],
      [USEROPT_DELAYED_DOWNLOAD_CONTENT, "spinner", hasFeature("delayedDownloadContent")]
    ].extend(getPrivacyOptionsList(), otherOptionsList())
  }
}

local overrideSoundOptionsFn = null

function getSoundOptions() {
  let needShowVoiceOptions = chatStatesCanUseVoice() && (isCrossNetworkChatEnabled() || isPlatformXboxOne)
  return overrideSoundOptionsFn?() ?? {
    name = "sound"
    fillFuncName = "fillSoundOptions"
    isInfoOnTheRight = true
    options = [
      ["options/sound"],
      [USEROPT_SOUND_ENABLE, "switchbox", is_platform_pc],
      [USEROPT_CUSTOM_SOUND_MODS, "switchbox", is_platform_pc && hasCustomSoundMods()],
      [USEROPT_SOUND_DEVICE_OUT, "combobox", is_platform_pc && soundDevice.get_out_devices().len() > 0],
      [USEROPT_SOUND_SPEAKERS_MODE, "combobox", is_platform_pc],
      [USEROPT_VOICE_MESSAGE_VOICE, "spinner"],
      [USEROPT_SPEECH_TYPE, "spinner", ! isInFlight()],
      ["options/volume_master"],
      [USEROPT_VOLUME_MASTER, "slider"],
      [USEROPT_VOLUME_MUSIC, "slider"],
      [USEROPT_VOLUME_MENU_MUSIC, "slider"],
      [USEROPT_VOLUME_SFX, "slider"],
      [USEROPT_VOLUME_ENGINE, "slider"],
      [USEROPT_VOLUME_MY_ENGINE, "slider"],
      [USEROPT_VOLUME_GUNS, "slider"],
      [USEROPT_VOLUME_RADIO, "slider"],
      [USEROPT_VOLUME_DIALOGS, "slider"],
      [USEROPT_VOLUME_VWS, "slider"],
      [USEROPT_VOLUME_RWR, "slider"],
      [USEROPT_VOLUME_TINNITUS, "slider"],
      [USEROPT_HANGAR_SOUND, "spinner"],
      [USEROPT_PLAY_INACTIVE_WINDOW_SOUND, "spinner", is_platform_pc],
      [USEROPT_ENABLE_SOUND_SPEED, "spinner", (!isInFlight()) || (get_mission_difficulty_int() != DIFFICULTY_HARDCORE) ],
      [USEROPT_VWS_ONLY_IN_COCKPIT, "button"],
      [USEROPT_SOUND_RESET_VOLUMES, "button"],
      ["options/voicechat"],
      [USEROPT_VOICE_CHAT, "spinner", needShowVoiceOptions],
      [USEROPT_VOICE_DEVICE_IN, "combobox", needShowVoiceOptions
        && !isPlatformSony && soundDevice.get_record_devices().len() > 0],
      [USEROPT_VOLUME_VOICE_IN, "slider", needShowVoiceOptions],
      [USEROPT_VOLUME_VOICE_OUT, "slider", needShowVoiceOptions],
      [USEROPT_PTT, "spinner", needShowVoiceOptions],
    ]
  }
}

let getInternetRadioOptions = @() {
  name = "internet_radio"
  fillFuncName = "fillInternetRadioOptions"
  isInfoOnTheRight = true
  options = [
    ["options/internet_radio"],
    [USEROPT_INTERNET_RADIO_ACTIVE, "spinner"],
    [USEROPT_INTERNET_RADIO_STATION, "combobox"],
  ]
}

let getOptionsList = function() {
  let options = [ getMainOptions() ]

  if (canUseGraphicsOptions())
    options.append(getSystemOptions())

  options.append(getSoundOptions())

  if (hasFeature("Radio"))
    options.append(getInternetRadioOptions())

  return options
}

return {
  getOptionsList = getOptionsList
  overrideMainOptions = @(fn) overrideMainOptionsFn = fn
  overrideSoundOptions = @(fn) overrideSoundOptionsFn = fn
}
