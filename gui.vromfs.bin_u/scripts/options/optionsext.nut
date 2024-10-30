//-file:similar-function

from "%scripts/dagui_natives.nut" import get_option_default_ai_target_type, set_activate_ground_radar_on_spawn, set_enable_laser_designatior_before_launch, set_option_use_radar_hud_in_cockpit, set_option_depthcharge_activation_time, get_cur_rank_info, set_option_countermeasures_series, get_option_autopilot_on_bombview, apply_current_view_type, set_option_countermeasures_series_periods, set_activate_ground_active_counter_measures_on_spawn, get_option_subs_radio, get_option_ground_radar_target_cycling, get_commander_camera_in_views, set_option_bomb_activation_time, set_option_camera_invertY, get_option_gunVerticalTargeting, get_option_gun_target_dist, set_option_radar_target_cycling, get_activate_ground_radar_on_spawn, get_option_save_zoom_camera, set_internet_radio_options, set_option_save_zoom_camera, get_option_rocket_fuse_dist, set_option_use_oculus_to_aim_helicopter, get_option_showPilot, save_online_single_job, get_dgs_tex_quality, set_option_use_perfect_rangefinder, set_option_activate_airborne_active_counter_measures_on_spawn, set_option_subs, get_option_hud_show_fuel, myself_can_devoice, set_option_autopilot_on_bombview, set_option_combine_pri_sec_triggers, get_option_grass_in_tank_vision, get_strobe_enemy, get_option_countermeasures_periods, get_option_hud_screenshot_logo, set_option_grass_in_tank_vision, set_option_indicatedSpeedType, set_option_indicatedAltitudeType, set_option_radarAltitudeAlert, get_option_camera_invertY, get_option_bombs_series, set_option_hud, get_bomb_activation_auto_time, get_option_ai_target_type, get_option_use_rectangular_radar_indicator, set_option_default_ai_target_type, set_option_gain, get_option_vibration, set_option_tank_gunner_camera_from_sight, get_option_xray_death, set_option_gamma, set_option_use_rectangular_radar_indicator, get_option_invertY, get_option_tank_gunner_camera_from_sight, get_option_indicatedSpeedType, get_option_indicatedAltitudeType, get_option_radarAltitudeAlert, ps4_headtrack_get_enable, get_hue, get_option_autorearm_on_airfield, get_option_gamma, get_options_torpedo_dive_depth, set_option_deflection, set_option_zoom_turret, get_option_radar_target_cycling, get_option_countermeasures_series, set_option_hud_indicators, get_option_view_type, set_option_xray_death, get_option_delayed_download_content, get_aircraft_fuel_consumption, set_option_activate_airborne_radar_on_spawn, get_option_gain, get_option_subs, set_option_speech_country_type, get_option_use_radar_hud_in_cockpit, get_option_deflection, set_option_invertX, get_option_hud_show_ammo, set_option_bombs_series, get_internet_radio_stations, set_option_subs_radio, get_option_bomb_activation_type, set_profile_pilot, set_commander_camera_in_views, get_option_ai_gunner_time, set_hue, get_option_auto_pilot_on_gunner_view_helicopter, get_show_destroyed_parts, myself_can_ban, get_option_countermeasures_series_periods, get_option_aerobatics_smoke_color, get_allow_to_be_added_to_lb, get_current_view_type, set_option_autorearm_on_airfield, set_option_hud_screenshot_logo, set_option_view_type, ps4_headtrack_set_xscale, set_option_auto_pilot_on_gunner_view_helicopter, get_option_zoom_turret, set_option_horizontal_speed, set_option_showPilot, get_option_invertX, set_option_hud_show_fuel, get_option_use_oculus_to_aim_helicopter, set_option_bomb_activation_type, set_strobe_ally, set_option_ground_radar_target_cycling, get_activate_ground_active_counter_measures_on_spawn, get_strobe_ally, set_option_aerobatics_smoke_color, get_option_use_perfect_rangefinder, get_option_hud_indicators, set_option_ai_target_type, set_option_rocket_fuse_dist, set_option_gunVerticalTargeting, get_option_horizontal_speed, set_option_controller_light, set_option_hud_color, get_option_controller_light, set_show_destroyed_parts, set_option_hud_show_temperature, get_option_depthcharge_activation_time, get_enable_laser_designatior_before_launch, set_option_xray_kill, set_option_unit_type, set_option_gun_target_dist, get_option_speech_country_type, get_option_xchg_sticks, get_option_bomb_activation_time, get_option_mouse_smooth, set_option_hud_show_ammo, get_option_hud_color, set_option_torpedo_dive_depth, set_option_mouse_smooth, set_allow_to_be_added_to_lb, get_option_xray_kill, get_internet_radio_path, get_option_hud_show_temperature, get_option_autosave_replays, ps4_headtrack_set_enable, set_strobe_enemy, set_option_autosave_replays, get_option_aerobatics_smoke_type, get_internet_radio_options, get_option_hud, get_option_activate_airborne_active_counter_measures_on_spawn, get_option_indicators_mode, set_option_aerobatics_smoke_type, ps4_headtrack_get_yscale, set_option_delayed_download_content, ps4_headtrack_set_yscale, is_unlocked, set_option_ai_gunner_time, set_option_countermeasures_periods, set_option_vibration, set_option_xchg_sticks, get_aircraft_max_fuel, ps4_headtrack_get_xscale, get_option_activate_airborne_radar_on_spawn, set_option_indicators_mode, set_option_invertY, get_option_torpedo_dive_depth, set_option_console_preset, get_option_console_preset
from "%scripts/dagui_library.nut" import *
from "gameOptions" import *
from "soundOptions" import *
from "radarOptions" import get_radar_mode_names, get_option_radar_name, get_radar_scan_pattern_names, get_option_radar_scan_pattern_name, get_radar_range_values, get_option_radar_range_value, set_option_radar_name, set_option_radar_scan_pattern_name, set_option_radar_range_value
from "%scripts/options/optionsExtNames.nut" import *
from "%scripts/controls/controlsConsts.nut" import AIR_MOUSE_USAGE, optionControlType
from "%scripts/options/optionsConsts.nut" import misCountries, SAVE_ONLINE_JOB_DIGIT
from "%scripts/customization/customizationConsts.nut" import TANK_CAMO_SCALE_SLIDER_FACTOR, TANK_CAMO_ROTATION_SLIDER_FACTOR
from "%scripts/options/optionsConsts.nut" import TANK_ALT_CROSSHAIR_ADD_NEW
from "%scripts/gameModes/gameModeConsts.nut" import BATTLE_TYPES
from "%scripts/mainConsts.nut" import SEEN

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { g_team } = require("%scripts/teams.nut")
let { g_hud_vis_mode } =  require("%scripts/hud/hudVisMode.nut")
let { g_difficulty, get_difficulty_by_ediff } = require("%scripts/difficulty.nut")
let { getLocalLanguage } = require("language")
let u = require("%sqStdLibs/helpers/u.nut")
let { color4ToDaguiString } = require("%sqDagui/daguiUtil.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_unit_option, set_unit_option, set_gui_option, get_gui_option,
  setGuiOptionsMode, getGuiOptionsMode, setCdOption, getCdOption, getCdBaseDifficulty
} = require("guiOptions")
let { abs } = require("math")
let { rnd } = require("dagor.random")
let { format, split_by_chars } = require("string")
let time = require("%scripts/time.nut")
let { TARGET_HUE_ALLY, TARGET_HUE_ENEMY, TARGET_HUE_SQUAD, TARGET_HUE_SPECTATOR_ALLY,
  TARGET_HUE_SPECTATOR_ENEMY, TARGET_HUE_RELOAD, TARGET_HUE_RELOAD_DONE, TARGET_HUE_AIRCRAFT_HUD,
  TARGET_HUE_AIRCRAFT_PARAM_HUD, TARGET_HUE_HELICOPTER_CROSSHAIR, TARGET_HUE_HELICOPTER_HUD,
  TARGET_HUE_HELICOPTER_PARAM_HUD, TARGET_HUE_HELICOPTER_HUD_ALERT_HIGH,
  TARGET_HUE_HELICOPTER_MFD, TARGET_HUE_ARBITER_HUD, setHsb, getAlertAircraftHues,
  setAlertAircraftHues, getAlertHelicopterHues, setAlertHelicopterHues,
  getRgbStrFromHsv } = require("colorCorrector")
let safeAreaMenu = require("%scripts/options/safeAreaMenu.nut")
let safeAreaHud = require("%scripts/options/safeAreaHud.nut")
let globalEnv = require("globalEnv")
let avatars = require("%scripts/user/avatars.nut")
let contentPreset = require("%scripts/customization/contentPreset.nut")
let { checkArgument, createDefaultOption, fillBoolOption,
  fillHueSaturationBrightnessOption, fillHueOption, fillMultipleHueOption,
  fillDynMapOption, setHSVOption_ThermovisionColor,
  fillHSVOption_ThermovisionColor } = require("%scripts/options/optionsUtils.nut")
let optionsMeasureUnits = require("%scripts/options/optionsMeasureUnits.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let soundDevice = require("soundDevice")
let holidays = require("holidays")
let { getBulletsListHeader } = require("%scripts/weaponry/weaponryDescription.nut")
let { setUnitLastBullets, getOptionsBulletsList } = require("%scripts/weaponry/bulletsInfo.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { bombNbr } = require("%scripts/unit/unitWeaponryInfo.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { checkUnitSpeechLangPackWatch } = require("%scripts/options/optionsManager.nut")
let { isPlatformSony, isPlatformXboxOne, isPlatformXboxScarlett, isPlatformPS5 } = require("%scripts/clientState/platform.nut")
let { is_xboxone_X } = require("%sqstd/platform.nut")
let { aeroSmokesList } = require("%scripts/unlocks/unlockSmoke.nut")
let { has_forced_crosshair, set_hud_crosshair_color, get_hud_crosshair_color, set_option_tank_alt_crosshair, get_user_alt_crosshairs,
  set_hud_crosshair_type, get_hud_crosshair_type, get_option_tank_alt_crosshair } = require("crosshair")
//


let { getSlotbarOverrideCountriesByMissionName } = require("%scripts/slotbar/slotbarOverride.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isUnitSpecial, get_mission_mode, getMaxEconomicRank, calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let {
  get_option_radar_aim_elevation_control,
  set_option_radar_aim_elevation_control,
  get_option_rwr_sensitivity = @() 100,
  set_option_rwr_sensitivity = @(_value) null,
  get_option_seeker_auto_stabilization,
  set_option_seeker_auto_stabilization,
  get_gyro_sight_deflection,
  set_gyro_sight_deflection,
  get_option_use_tws_hud_in_cockpit = @() true,
  set_option_use_tws_hud_in_cockpit = @(_value) null
  get_activate_bombs_auto_release_on_spawn = @() true,
  set_activate_bombs_auto_release_on_spawn = @(_value) null
} = require("controlsOptions")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { getFullUnlockDesc } = require("%scripts/unlocks/unlocksViewModule.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { debug_dump_stack } = require("dagor.debug")
let { isUnlockVisible, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { is_bit_set } = require("%sqstd/math.nut")
let { dynamicGetZones } = require("dynamicMission")
let { get_option_auto_show_chat, get_option_ptt, set_option_ptt,
  get_option_chat_filter, set_option_chat_filter,
  set_option_auto_show_chat, get_option_voicechat,
  set_option_voicechat, get_option_chat_messages_filter,
  set_option_chat_messages_filter } = require("chat")
let { get_game_mode } = require("mission")
let { get_mp_session_info, get_mission_set_difficulty_int } = require("guiMission")
let { color4ToInt } = require("%scripts/utils/colorUtil.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { get_tank_skin_condition, get_tank_camo_scale, get_tank_camo_rotation
} = require("unitCustomization")
let { setLastSkin, getSkinsOption, getCurUnitUserSkins, getUserSkinCondition, getUserSkinRotation, getUserSkinScale } = require("%scripts/customization/skins.nut")
let { stripTags } = require("%sqstd/string.nut")
let { getUrlOrFileMissionMetaInfo, getMissionTimeText, getWeatherLocName, getGameModeMaps
} = require("%scripts/missions/missionsUtils.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getCountryFlagsPresetName, getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getGameLocalizationInfo, setGameLocalization, isChineseHarmonized } = require("%scripts/langUtils/language.nut")
let { get_game_params_blk, get_user_skins_profile_blk } = require("blkGetters")
let { getClustersList, getClusterShortName } = require("%scripts/onlineInfo/clustersManagement.nut")
let { isEnabledCustomLocalization, setCustomLocalization,
  getLocalization, hasWarningIcon } = require("%scripts/langUtils/customLocalization.nut")
let { isInFlight } = require("gameplayBinding")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { isMeAllowedToBeAddedToContacts, setAbilityToBeAddedToContacts } = require("%scripts/contacts/contactsState.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { isCountryAvailable } = require("%scripts/firstChoice/firstChoice.nut")
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { getCurrentGameMode, getCurrentShopDifficulty
} = require("%scripts/gameModes/gameModeManagerState.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { measureType } = require("%scripts/measureType.nut")
let { getCurrentCampaignMission } = require("%scripts/missions/startMissionsList.nut")
let { complaintCategories } = require("%scripts/penitentiary/tribunal.nut")

let { isWishlistEnabledForFriends, isWishlistCommentsEnabledForFriends,
  enableShowWishlistForFriends, enableShowWishlistCommentsForFriends } = require("chard")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { isEnabledCustomSoundMods, setCustomSoundMods
} = require("%scripts/options/customSoundMods.nut")
let { set_xray_parts_filter } = require("hangar")
let { getTankXrayFilter, getShipXrayFilter } = require("%scripts/weaponry/dmgModel.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { has_console_120_hz } = require("graphicsOptions")
let { g_mislist_type } = require("%scripts/missions/misListType.nut")
let { getMissionName } = require("%scripts/missions/missionsUtilsModule.nut")

function mkUseroptHardWatched(id, defValue = null) {
  let opt = hardPersistWatched(id, defValue)
  opt.subscribe(@(v) updateExtWatched({ [id] = v }))
  return opt
}

let crosshairColorOpt = mkUseroptHardWatched("crosshairColorOpt", 0xFFFFFFFF)
let isHeliPilotHudDisabled = mkUseroptHardWatched("heliPilotHudDisabled", false)
let isVisibleTankGunsAmmoIndicator = mkUseroptHardWatched("isVisibleTankGunsAmmoIndicator", false)

let crosshair_colors = persist("crosshair_colors", @() [])

local get_option

function getCrosshairColor() {
  let opt = get_option(USEROPT_CROSSHAIR_COLOR)
  let colorIdx = opt.values[opt.value]
  return color4ToInt(crosshair_colors[colorIdx].color)
}

let getHeliPilotHudDisabled = @() get_option(USEROPT_HELI_COCKPIT_HUD_DISABLED)

function getIsVisibleTankGunsAmmoIndicatorValue() {
  return ::get_gui_option_in_mode(USEROPT_HUD_SHOW_TANK_GUNS_AMMO, OPTIONS_MODE_GAMEPLAY, false)
}

function initOptions() {
  crosshairColorOpt(getCrosshairColor())
  isHeliPilotHudDisabled(getHeliPilotHudDisabled().value)
  isVisibleTankGunsAmmoIndicator(getIsVisibleTankGunsAmmoIndicatorValue())
}

addListenersWithoutEnv({
  InitConfigs = @(_) initOptions()
})

function getConsolePresets() {
  if (is_xboxone_X)
    return ["#options/quality", "#options/performance"]
  else if (isPlatformXboxScarlett)
    return has_console_120_hz() ? ["#options/quality", "#options/balanced", "#options/performance", "#options/raytraced"] : ["#options/quality", "#options/raytraced"];
  else if (isPlatformPS5)
    return has_console_120_hz() ? ["#options/quality", "#options/balanced", "#options/performance"] : ["#options/quality"];
  return ["#options/quality"];
}

function getConsolePresetsValues() {
  if (is_xboxone_X)
    return [0, 1]
  else if (isPlatformXboxScarlett)
    return has_console_120_hz() ? [0, 1, 2, 3] : [0, 3]
  else if (isPlatformPS5)
    return has_console_120_hz() ? [0, 1, 2] : [0];
  return [0];
}

const BOMB_ASSAULT_FUSE_TIME_OPT_VALUE = -1
const SPEECH_COUNTRY_UNIT_VALUE = 2

const BOMB_ACT_TIME = 0
const BOMB_ACT_ASSAULT = 1

setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

::aircraft_for_weapons <- null
::cur_aircraft_name <- null
::bullets_locId_by_caliber <- []
::modifications_locId_by_caliber <- []
::crosshair_icons <- []
::thermovision_colors <- []

let clanRequirementsRankDescId = {
  [USEROPT_CLAN_REQUIREMENTS_MIN_AIR_RANK] = "rankReqAircraft",
  [USEROPT_CLAN_REQUIREMENTS_MIN_TANK_RANK] = "rankReqTank",
  [USEROPT_CLAN_REQUIREMENTS_MIN_BLUEWATER_SHIP_RANK] = "rankReqBluewaterShip",
  [USEROPT_CLAN_REQUIREMENTS_MIN_COASTAL_SHIP_RANK] = "rankReqCoastalShip"
}

function image_for_air(air) {
  if (type(air) == "string")
    air = getAircraftByName(air)
  if (!air)
    return ""
  return air.customImage ?? ::get_unit_icon_by_unit(air, air.name)
}

::image_for_air <- image_for_air

::mission_name_for_takeoff <- ""

registerPersistentData("OptionsExtGlobals", getroottable(),
  [
    "bullets_locId_by_caliber", "modifications_locId_by_caliber",
    "crosshair_icons", "thermovision_colors"
  ])

::check_aircraft_tags <- function(airtags, filtertags) {
  local isNotFound = false
  for (local j = 0; j < filtertags.len(); j++) {
    if (u.find_in_array(airtags, filtertags[j]) < 0) {
      isNotFound = true
      break
    }
  }
  return !isNotFound
}

local isWaitMeasureEvent = false

function create_option_list(id, items, value, cb, isFull, spinnerType = null, optionTag = null, params = null) {
  if (!checkArgument(id, items, "array"))
    return ""

  if (!checkArgument(id, value, "integer"))
    return ""

  let view = {
    id = id
    optionTag = optionTag || "option"
    options = []
  }
  if (params)
    view.__update(params)
  if (cb)
    view.cb <- cb

  foreach (idx, item in items) {
    let opt = type(item) == "string" ? { text = item } : clone item
    opt.selected <- idx == value
    if ("hue" in item)
      opt.hueColor <- getRgbStrFromHsv(item.hue, item?.sat ?? 0.7, item?.val ?? 0.7)
    if ("hues" in item)
      opt.smallHueColor <- item.hues.map(@(hue) { color = getRgbStrFromHsv(hue, 1.0, 1.0) })

    if ("rgb" in item)
      opt.hueColor <- item.rgb

    if ("name" in item)
      opt.optName <- item.name

    if (type(item?.image) == "string") {
      opt.images <- [{ image = item.image }]
      opt.$rawdelete("image")
    }

    opt.enabled <- opt?.enabled ?? true
    if (!opt.enabled)
      spinnerType = "ComboBox" //disabled options can be only in dropright or combobox

    view.options.append(opt)
  }

  if (isFull) {
    let controlTag = spinnerType || "ComboBox"
    view.controlTag <- controlTag
    if (controlTag == "dropright")
      view.isDropright <- true
    if (controlTag == "ComboBox")
      view.isCombobox <- true
  }

  return handyman.renderCached(("%gui/options/spinnerOptions.tpl"), view)
}

::create_option_dropright <- function create_option_dropright(id, items, value, cb, isFull) {
  return create_option_list(id, items, value, cb, isFull, "dropright")
}

function create_option_combobox(id, items, value, cb, isFull, params = null) {
  return create_option_list(id, items, value, cb, isFull, "ComboBox", null, params)
}

::create_option_combobox <- create_option_combobox

::create_option_editbox <- kwarg(function create_option_editbox(id, value = "", password = false, maxlength = 16, charMask = null) {
  return "EditBox { id:t='{id}'; text:t='{text}'; width:t='0.2@sf'; max-len:t='{len}';{type}{charMask}}".subst({
    id = id,
    text = ::locOrStrip(value.tostring()),
    len = maxlength,
    type = password ? "type:t='password'; password-smb:t='{0}';".subst(loc("password_mask_char", "*")) : "",
    charMask = charMask ? $"char-mask:t='{charMask}';" : ""
  })
})

let create_option_switchbox = @(config) handyman.renderCached(("%gui/options/optionSwitchbox.tpl"), config)

::create_option_row_listbox <- function create_option_row_listbox(id, items, value, cb, isFull, listClass = "options") {
  if (!checkArgument(id, items, "array"))
    return ""
  if (!checkArgument(id, value, "integer"))
    return ""

  local data = "".concat(
    $"id:t = '{id}'; ",
    (cb != null ? $"on_select:t = '{cb}'; " : ""),
    $"on_dbl_click:t = 'onOptionsListboxDblClick'; class:t='{listClass}'; ",
  )

  let view = { items = [] }
  foreach (idx, item in items) {
    let selected = idx == value
    if (u.isString(item))
      view.items.append({ text = item, selected = selected })
    else
      view.items.append({
        text = getTblValue("text", item, "")
        image = getTblValue("image", item)
        disabled = getTblValue("enabled", item) || false
        selected = selected
        tooltip = getTblValue("tooltip", item, "")
      })
  }
  data = "".concat(data, handyman.renderCached("%gui/commonParts/shopFilter.tpl", view))

  if (isFull)
    data = "".concat(
      "HorizontalListBox { height:t='ph-6'; pos:t = 'pw-0.5p.p.w-0.5w, 0.5(ph-h)'; position:t = 'absolute'; ",
      data, "}")
  return data
}

::create_option_row_multiselect <- function create_option_row_multiselect(params) {
  let option = params?.option
  if (option == null
      || !checkArgument(option?.id, option?.items, "array")
      || !checkArgument(option?.id, option?.value, "integer"))
    return ""

  let view = {
    listClass = params?.listClass ?? "options"
    isFull = params?.isFull ?? true
    items = []
  }
  foreach (key in [ "id", "showTitle", "value", "cb" ])
    if ((option?[key] ?? "") != "")
      view[key] <- option[key]
  foreach (key in [ "textAfter" ])
    if ((option?[key] ?? "") != "")
      view[key] <- ::locOrStrip(option[key])

  foreach (v in option.items) {
    let item = type(v) == "string" ? { text = v, image = "" } : v
    let viewItem = {}
    foreach (key in [ "enabled", "isVisible" ])
      viewItem[key] <- item?[key] ?? true
    foreach (key in [ "id", "image" ])
      if ((item?[key] ?? "") != "")
        viewItem[key] <- item[key]
    foreach (key in [ "text", "tooltip" ])
      if ((item?[key] ?? "") != "")
        viewItem[key] <- ::locOrStrip(item[key])
    view.items.append(viewItem)
  }

  return handyman.renderCached(("%gui/options/optionMultiselect.tpl"), view)
}

function create_option_vlistbox(id, items, value, cb, isFull) {
  if (!checkArgument(id, items, "array"))
    return ""

  if (!checkArgument(id, value, "integer"))
    return ""

  local data = ""
  local itemNo = 0
  foreach (item in items) {
    data = "".concat(data, "option { text:t = '", item, "'; ", itemNo == value ? "selected:t = 'yes';" : "", " }")
    ++itemNo
  }

  data = "".concat($"id:t = '{id}'; ", cb != null ? $"on_select:t = '{cb}'; " : "", data)

  if (isFull)
    data = "".concat("VericalListBox { ", data, " }")
  return data
}

::create_option_slider <- function create_option_slider(id, value, cb, isFull, sliderType, params = {}) {
  if (!checkArgument(id, value, "integer"))
    return ""

  let minVal = params?.min ?? 0
  let maxVal = params?.max ?? 100
  let step = params?.step ?? 5
  let clickByPoints = abs(maxVal - minVal) == 1 ? "yes" : "no"
  local data = "".concat(
    $"id:t = '{id}'; min:t='{minVal}'; max:t='{maxVal}'; step:t = '{step}'; value:t = '{value}'; ",
    $"clicks-by-points:t='{clickByPoints}'; fullWidth:t={!params?.needShowValueText  ? "yes" : "no"};",
    cb == null ? "" : $"on_change_value:t = '{cb}'; "
  )
  if (isFull)
    data = "{0} { {1} focus_border{} tdiv{} }".subst(sliderType, data) //tdiv need to focus border not count as slider button

  return data
}

let fillSoundDescr = @(descr, sndType, id, title = null) descr.__update(
  {
    id
    controlType = optionControlType.SLIDER
    title
    value = (get_sound_volume(sndType) * 100).tointeger()
    optionCb = "onVolumeChange"
  },
  get_volume_limits(sndType))


::get_current_wnd_difficulty <- function get_current_wnd_difficulty() {
  let diffCode = loadLocalByAccount("wnd/diffMode", getCurrentShopDifficulty().diffCode)
  local diff = g_difficulty.getDifficultyByDiffCode(diffCode)
  if (!diff.isAvailable())
    diff = g_difficulty.ARCADE
  return diff.diffCode
}

::set_current_wnd_difficulty <- function set_current_wnd_difficulty(mode = 0) {
  saveLocalByAccount("wnd/diffMode", mode)
}

function create_options_container(name, options, is_centered, columnsRatio = 0.5, absolutePos = true, context = null, hasTitle = true) {
  local selectedRow = 0
  local iRow = 0
  let resDescr = {
    name = name
    data = []
  }

  columnsRatio = clamp(columnsRatio, 0.1, 0.9)
  let wLeft  = format("%.2fpw", columnsRatio)
  let wRight = format("%.2fpw", 1.0 - columnsRatio)

  let rowsView = []
  local headerHaveContent = false
  for (local i = options.len() - 1; i >= 0; i--) {
    let opt = options[i]
    if (!(opt?[2] ?? true))
      continue

    let optionData = get_option(opt[0], context)
    if (optionData == null)
      continue

    let isHeader = optionData.controlType == optionControlType.HEADER
    if (isHeader) {
      if (!headerHaveContent)
        continue
      else
        headerHaveContent = false
    }
    else
      headerHaveContent = true

    if (optionData?.controlName == null)
      optionData.controlName <- opt?[1] ?? "spinner"

    local isVlist = false
    local haveOptText = true
    local elemTxt = ""
    let {controlName} = optionData

    if ( controlName== "list" || controlName == "spinner")
      elemTxt = create_option_list(optionData.id, optionData.items, optionData.value, optionData.cb, true)

    else if ( controlName == "dropright" )
      elemTxt = ::create_option_dropright(optionData.id, optionData.items, optionData.value, optionData.cb, true)

    else if ( controlName == "combobox" )
      elemTxt = ::create_option_combobox(optionData.id, optionData.items, optionData.value, optionData.cb, true)

    else if ( controlName == "switchbox" )
      elemTxt = create_option_switchbox(optionData)

    else if ( controlName == "editbox" ){
      elemTxt = ::create_option_editbox({
        id = optionData.id
        value = optionData?.value ?? ""
        password = optionData?.password ?? false
        maxlength = optionData?.maxlength ?? 16
        charMask = optionData?.charMask
      })
    }
    else if ( controlName == "listbox") {
      let listClass = ("listClass" in optionData) ? optionData.listClass : "options"
      elemTxt = ::create_option_row_listbox(optionData.id, optionData.items, optionData.value, optionData.cb, true, listClass)
      haveOptText = false
    }

    else if ( controlName == "multiselect") {
      let listClass = ("listClass" in optionData) ? optionData.listClass : "options"
      elemTxt = ::create_option_row_multiselect({ option = optionData, isFull = true, listClass = listClass })
      haveOptText = optionData?.showTitle ?? false
    }

    else if ( controlName == "slider")
      elemTxt = ::create_option_slider(optionData.id, optionData.value, optionData.cb, true, "slider", optionData)

    else if ( controlName == "vlist") {
      elemTxt = create_option_vlistbox(optionData.id, optionData.items, optionData.value, optionData.cb, true)
      isVlist = true
    }

    else if ( controlName == "button") {
      elemTxt = handyman.renderCached(("%gui/commonParts/button.tpl"), optionData)
      haveOptText = optionData?.showTitle ?? false
    }

    let cell = []
    if (elemTxt != null) {
      if (isVlist || !hasTitle)
        cell.append({ params = {
          width = 0
        } })
      else {
        local tdText = ""
        if (haveOptText)
          tdText = stripTags(optionData.getTitle())

        if (optionData.needShowValueText)
          elemTxt = "".concat(
            elemTxt,
            format("optionValueText { id:t='%s'; text:t='%s' }",
              $"value_{optionData.id}", optionData.getValueLocText(optionData.value)),
          )

        let optionTitleStyle = isHeader ? "optionBlockHeader" : "optiontext"
        let title = "".concat(optionTitleStyle, " { id:t = 'lbl_", optionData.id,
          "'; text:t ='", tdText, "'; }")

        local rawParam = ""
        if(optionData.hasWarningIcon)
          rawParam = " ".concat("warningDiv {", "warningLangIcon{}", title, "}")
        else
          rawParam = title

        cell.append({ params = {
          cellType = "left"
          width = wLeft
          autoScrollText = "yes"
          rawParam = rawParam
        } })
      }

      let cellSeparator = !isHeader && hasTitle
        ? "cellSeparator{}"
        : ""

      cell.append({ params = {
        cellType = "right"
        width = wRight
        rawParam =  !hasTitle ? elemTxt : $"{cellSeparator} {elemTxt}"
      } })

      let rowParams = ["optContainer:t='yes'"]

      if (!isHeader) {
        if (context?.onHoverFnName)
          rowParams.append($"on_hover:t='{context.onHoverFnName}'")
        if (context?.onUnhoverFnName)
          rowParams.append($"on_unhover:t='{context.onUnhoverFnName}'")
      }
      if (isHeader)
        rowParams.append("inactive:t='yes'; headerRow:t='yes'")
      if ("enabled" in optionData)
        rowParams.append($"enable:t='{optionData.enabled ? "yes" : "no"}';")
      if (!u.isEmpty(optionData.hint))
        rowParams.append($"tooltip:t='{stripTags(optionData.hint)}';")
      if (optionData.controlName == "listbox") {
        if ("trListParams" in optionData)
          rowParams.append(optionData.trListParams)
      }
      else if ("trParams" in optionData)
        rowParams.append(optionData.trParams)

      rowsView.insert(0, {
        row_id = optionData.getTrId()
        trParams = "\n".join(rowParams)
        cell = cell
        hasHeaderLine = isHeader
      })

      if (iRow == 0)
        selectedRow = iRow
      ++iRow
    }

    resDescr.data.insert(0, optionData)
  }

  return {
    tbl = handyman.renderCached("%gui/options/optionsContainer.tpl", {
      id = name
      topPos = is_centered ? "(ph-h)/2" : "0"
      position = absolutePos ? "absolute" : "relative"
      value = selectedRow
      onClick = context?.onTblClick
      row = rowsView
    })
    descr = resDescr
  }
}

local unitsImgPreset = null
::get_unit_preset_img <- function get_unit_preset_img(unitNameOrUnitGroupName ) {
  if (unitsImgPreset == null) {
    unitsImgPreset = {}
    let guiBlk = GUI.get()
    let blk = guiBlk?.units_presets?[getCountryFlagsPresetName()]
    if (blk)
      for (local i = 0; i < blk.paramCount(); i++)
        unitsImgPreset[blk.getParamName(i)] <- blk.getParamValue(i)
  }

  return unitsImgPreset?[unitNameOrUnitGroupName]
}

::is_harmonized_unit_image_reqired <- function is_harmonized_unit_image_reqired(unit) {
  return unit.shopCountry == "country_japan" && unit.unitType == unitTypes.AIRCRAFT
    && isChineseHarmonized()
}

function useropt_mouse_usage(optionId, descr, _context) {
  let ignoreAim = optionId == USEROPT_MOUSE_USAGE_NO_AIM
  descr.id = ignoreAim ? "mouse_usage_no_aim" : "mouse_usage"
  descr.items = [
    "#options/nothing"
    "#options/mouse_aim"
    "#options/mouse_joystick"
    "#options/mouse_relative"
    "#options/mouse_view"
  ]
  descr.values = [
    AIR_MOUSE_USAGE.NOT_USED
    AIR_MOUSE_USAGE.AIM
    AIR_MOUSE_USAGE.JOYSTICK
    AIR_MOUSE_USAGE.RELATIVE
    AIR_MOUSE_USAGE.VIEW
  ]

  if (ignoreAim) {
    let aimIdx = descr.values.indexof(AIR_MOUSE_USAGE.AIM)
    descr.values.remove(aimIdx)
    descr.items.remove(aimIdx)
  }

  descr.defaultValue = descr.values.indexof(
    ::g_aircraft_helpers.getOptionValue(optionId))
}

function useropt_aerobatics_smoke_left_color(optionId, descr, _context) {
  let optIndex = u.find_in_array(
    [USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, USEROPT_AEROBATICS_SMOKE_TAIL_COLOR],
    optionId)

  descr.id = ["aerobatics_smoke_left_color", "aerobatics_smoke_right_color", "aerobatics_smoke_tail_color"][optIndex]

  descr.items = ["#options/aerobaticsSmokeColor1", "#options/aerobaticsSmokeColor2", "#options/aerobaticsSmokeColor3",
                 "#options/aerobaticsSmokeColor4", "#options/aerobaticsSmokeColor5", "#options/aerobaticsSmokeColor6",
                 "#options/aerobaticsSmokeColor7"]

  descr.values = [1, 2, 3, 4, 5, 6, 7]
  descr.value = u.find_in_array(descr.values, get_option_aerobatics_smoke_color(optIndex))
}

function useropt_measureunits_speed(optionId, descr, _context) {
  let mesureUnitsOption = optionsMeasureUnits.getOption(optionId)
  descr.id      = mesureUnitsOption.id
  descr.items   = mesureUnitsOption.items
  descr.values  = mesureUnitsOption.values
  descr.value   = mesureUnitsOption.value
}

function useropt_takeoff_mode(optionId, descr, _context) {
  descr.id = (optionId == USEROPT_TAKEOFF_MODE) ? "takeoff_mode" : "landing_mode"

  if (optionId == USEROPT_TAKEOFF_MODE &&
    (::mission_name_for_takeoff == "dynamic_free_flight01" ||
     ::mission_name_for_takeoff == "dynamic_free_flight02")) {
    descr.items = ["#options/takeoffmode/no", "#options/takeoffmode/real"]
    descr.values = [0, 2]
    descr.defaultValue = 0
  }
  else {
    descr.items = ["#options/takeoffmode/no", "#options/takeoffmode/teleport", "#options/takeoffmode/real"]
    descr.values = [0, 1, 2]
    descr.defaultValue = 1
  }
}

function useropt_bullets0(optionId, descr, _context) {
  let aircraft = ::aircraft_for_weapons
  let groupIndex = optionId - USEROPT_BULLETS0
  descr.id = $"bullets{groupIndex}"
  descr.items = []
  descr.values = []
  descr.trParams <- "optionWidthInc:t='double';"
  if (type(aircraft) == "string") {
    let air = getAircraftByName(aircraft)
    if (air) {
      let bullets = getOptionsBulletsList(air, groupIndex, true)
      descr.title = getBulletsListHeader(air, bullets)

      descr.items = bullets.items
      descr.values = bullets.values
      descr.value = bullets.value
    }
    descr.optionCb = "onMyWeaponOptionUpdate"
  }
  else {
    debugTableData(::aircraft_for_weapons)
    debug_dump_stack()
    logerr($"Options: USEROPT_BULLET{groupIndex}: get: Wrong 'aircraft_for_weapons' type")
  }
}

function useropt_content_allowed_preset_arcade(optionId, descr, _context) {
  let difficulty = contentPreset.getDifficultyByOptionId(optionId)
  descr.defaultValue = difficulty.contentAllowedPresetOptionDefVal
  descr.id = "content_allowed_preset"
  descr.title = loc("options/content_allowed_preset")
  if (difficulty != g_difficulty.UNKNOWN) {
    descr.id = $"{descr.id}{difficulty.diffCode}"
    descr.title = "".concat(descr.title, loc("ui/parentheses/space", { text = loc(difficulty.locId) }))
  }
  descr.hint  = loc("guiHints/content_allowed_preset")
  descr.controlType = optionControlType.LIST
  descr.controlName <- "combobox"
  descr.items = []
  descr.values = []
  foreach (value in contentPreset.getContentPresets()) {
    descr.items.append(loc($"content/tag/{value}"))
    descr.values.append(value)
  }
}

function useropt_bit_countries_team_a(optionId, descr, context) {
  let team = optionId == USEROPT_BIT_COUNTRIES_TEAM_A ? g_team.A : g_team.B
  descr.id =$"countries_team_{team.id}"
  descr.sideTag <- team == g_team.A ? "country_allies" : "country_axis"
  descr.controlType = optionControlType.BIT_LIST
  descr.controlName <- "multiselect"
  descr.optionCb = "onInstantOptionApply"

  descr.items = []
  descr.values = []
  descr.trParams <- "iconType:t='listbox_country';"
  descr.listClass <- "countries"

  local allowedMask = (1 << shopCountriesList.len()) - 1
  if (getTblValue("isEventRoom", context, false)) {
    let allowedList = context?.countries[team.name]
    if (allowedList)
      allowedMask = ::get_bit_value_by_array(allowedList, shopCountriesList)
                    || allowedMask
  }
  else if ("missionName" in context) {
    let countries = getSlotbarOverrideCountriesByMissionName(context.missionName)
    if (countries.len())
      allowedMask = ::get_bit_value_by_array(countries, shopCountriesList)
  }
  descr.allowedMask <- allowedMask

  for (local nc = 0; nc < shopCountriesList.len(); nc++) {
    let country = shopCountriesList[nc]
    let isEnabled = (allowedMask & (1 << nc)) != 0
    descr.items.append({
      text = $"#{country}"
      image = getCountryIcon(country, true)
      enabled = isEnabled
      isVisible = isEnabled
    })
    descr.values.append(country)
  }

  if (isInSessionRoom.get()) {
    let cList = ::SessionLobby.getPublicParam(descr.sideTag, null)
    if (cList)
      descr.prevValue = ::get_bit_value_by_array(cList, shopCountriesList)
  }
  descr.value = descr.prevValue || get_gui_option(optionId)
  if (!descr.value || !u.isInteger(descr.value))
    descr.value = allowedMask
  else
    descr.value = descr.value & allowedMask

}

function useropt_br_min(optionId, descr, _context) {
  let isMin = optionId == USEROPT_BR_MIN
  descr.id = isMin ? "battle_rating_min" : "battle_rating_max"
  descr.controlName <- "combobox"
  descr.optionCb = "onInstantOptionApply"
  descr.items = []
  descr.values = []

  let maxEconomicRank = getMaxEconomicRank()
  for (local mrank = 0; mrank <= maxEconomicRank; mrank++) {
    let br = calcBattleRatingFromRank(mrank)
    descr.values.append(mrank)
    descr.items.append(format("%.1f", br))
  }

  descr.defaultValue = isMin && descr.items.len() ? 0 : (descr.values.len() - 1)
}

function useropt_mp_team_country_rand(optionId, descr, _context) {
  descr.id = "mp_team"
  descr.items <- []
  if (optionId == USEROPT_MP_TEAM_COUNTRY_RAND)
    descr.values = [0, 1, 2]
  else
    descr.values = [1, 2]

  descr.prevValue = get_gui_option(USEROPT_MP_TEAM)

  local countries = null
  let sessionInfo = get_mp_session_info()
  if (sessionInfo)
    countries = [$"country_{sessionInfo.alliesCountry}",
                 $"country_{sessionInfo.axisCountry}"]
  else if (::mission_settings && ::mission_settings.layout)
    countries = ::get_mission_team_countries(::mission_settings.layout)

  if (countries) {
    descr.trParams <- "iconType:t='country';"
    descr.trListParams <- "iconType:t='listbox_country';"
    descr.listClass <- "countries"
    local selValue = -1
    for (local i = 0; i < descr.values.len(); i++) {
      let c = getTblValue(descr.values[i] - 1, countries, "country_0")
      if (!c) {
        descr.values.remove(i)
        continue
      }

      local text = $"#{c}"
      local image = getCountryIcon(c, true)
      local enabled = false
      local tooltip = ""

      if (get_game_mode() == GM_DYNAMIC && ::current_campaign) {
        let countryId = $"{::current_campaign.id}_{::current_campaign.countries[i]}"
        let unlock = getUnlockById(countryId)
        if (unlock == null)
          assert(false, ($"Not found unlock {countryId}"))
        else {
          text = $"#country_{::current_campaign.countries[i]}"
          image = getCountryIcon($"country_{::current_campaign.countries[i]}", true)
          enabled = isUnlockOpened(countryId, UNLOCKABLE_DYNCAMPAIGN)
          tooltip = enabled ? "" : getFullUnlockDesc(::build_conditions_config(unlock))
        }
      }

      descr.items.append({
        text = text
        image = image
        enabled = enabled
        tooltip = tooltip
      })

      if (enabled && (selValue < 0 || descr.prevValue == descr.values[i]))
        selValue = i
    }
    if (selValue >= 0)
      descr.value = selValue
  }

  if (descr.items.len() == 0) {
    let itemsList = ["#multiplayer/teamRandom", "#multiplayer/teamA", "#multiplayer/teamB"]
    for (local v = 0; v < descr.values.len(); v++)
      descr.items.append(itemsList[descr.values[v]])
    descr.value = u.find_in_array(descr.values, descr.prevValue, 0)
  }

  descr.optionCb = "onLayoutChange"
}

function useropt_friendly_skill(optionId, descr, _context) {
  descr.id = (optionId == USEROPT_FRIENDLY_SKILL) ? "friendly_skill" : "enemy_skill"
  descr.items = ["#options/skill0", "#options/skill1", "#options/skill2"]
  descr.values = [0, 1, 2]
  descr.defaultValue = 2
}

function useropt_clusters(optionId, descr, _context) {
  descr.id = "cluster"
  descr.controlType = optionId == USEROPT_RANDB_CLUSTERS
    ? optionControlType.BIT_LIST
    : optionControlType.LIST

  if (getClustersList().len() > 0) {
    descr.items = getClustersList().map(@(c) {
      text = getClusterShortName(c.name)
      name = c.name
      image = c.isUnstable ? "#ui/gameuiskin#urgent_warning.svg" : null
      tooltip = c.isUnstable ? loc("multiplayer/cluster_connection_unstable") : null
      isUnstable = c.isUnstable
      isDefault = c.isDefault
      isAuto = false
      isVisible = c.name != "SA"
    }).append({
      text = loc("options/auto")
      name = "auto"
      image = null
      tooltip = loc("options/auto/tooltip", {
        clusters = ", ".join(getClustersList().map(@(c) getClusterShortName(c.name)))
      })
      isUnstable = false
      isDefault = false
      isAuto = true
      isVisible = true
    })
    if (optionId == USEROPT_CLUSTERS)
      descr.items = descr.items.filter(@(i) i.isVisible)
    descr.values = descr.items.map(@(i) i.name)
    descr.defaultValue = "auto"
  }
  else {
    // only in dev mode (otherwise would be logout)
    descr.items = [{
      text = "---"
      name = "---"
      image = null
      tooltip = null
      isUnstable = false
      isDefault = false
      isAuto = false
      isVisible = true
    }]
    descr.values = [""]
    descr.value = descr.controlType == optionControlType.BIT_LIST ? 1 : ""
    descr.defaultValue = ""
    return
  }

  descr.prevValue = ::get_gui_option_in_mode(optionId, OPTIONS_MODE_MP_DOMINATION)
  if (optionId == USEROPT_CLUSTERS) {
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getPublicParam("cluster", null)
  }
  else if (optionId == USEROPT_RANDB_CLUSTERS) {
    descr.value = 0
    if (u.isString(descr.prevValue)) {
      local selectedValues = split_by_chars(descr.prevValue, ";")
      let isAuto = selectedValues.contains("auto")
      if (isAuto)
        selectedValues = [descr.defaultValue]
      descr.value = ::get_bit_value_by_array(selectedValues, descr.values)
    }
    if (descr.value == 0)
      descr.value = ::get_bit_value_by_array([descr.defaultValue], descr.values) || 1
  }
}

function useropt_clan_requirements_min_air_rank(optionId, descr, _context) {
  descr.id = clanRequirementsRankDescId?[optionId] ?? ""
  descr.title = loc($"clan/{descr.id}")
  descr.optionCb = "onRankReqChange"
  descr.items = []
  descr.values = []
  for (local rank = 0; rank <= MAX_COUNTRY_RANK; ++rank) {
    descr.values.append(format("option_%s", rank.tostring()))
    descr.items.append({
      text = (rank == 0 ? loc("clan/membRequirementsRankAny") : get_roman_numeral(rank))
    })
  }
  descr.value = u.find_in_array(descr.values, "option_0")
}

function useropt_clan_requirements_min_arcade_battles(optionId, descr, _context) {
  if (optionId == USEROPT_CLAN_REQUIREMENTS_MIN_ARCADE_BATTLES) {
    descr.id = "battles_arcade"
    descr.title = loc("clan/battlesSelect_arcade")
  }
  else if (optionId == USEROPT_CLAN_REQUIREMENTS_MIN_SYM_BATTLES) {
    descr.id = "battles_simulation"
    descr.title = loc("clan/battlesSelect_simulation")
  }
  else if (optionId == USEROPT_CLAN_REQUIREMENTS_MIN_REAL_BATTLES) {
    descr.id = "battles_historical"
    descr.title = loc("clan/battlesSelect_historical")
  }
  descr.items = []
  descr.values = [0, 1, 3, 5, 8, 10, 20, 30, 40, 50, 75, 100, 200, 300, 400, 500, 750, 1000 ]
  for (local i = 0; i < descr.values.len(); i++)
    descr.items.append(descr.values[i] == 0 ? loc("clan/membRequirementsRankAny") : descr.values[i].tostring())
  descr.value = 0
}

function fillXrayFilterDescr(optionId, descr, filters) {
  descr.controlType <- optionControlType.BIT_LIST
  let prevValue = get_gui_option(optionId) ?? 0
  local value = prevValue
  descr.items = []
  descr.values = []
  foreach (filter in filters) {
    let { name, bit } = filter
    descr.items.append(loc($"xray/filter/{name}"))
    descr.values.append(bit)
    if ((value & bit) != 0)
      value = value & ~bit
  }
  descr.value = value > 0 ? 0 : prevValue
}

function getFuelParams(aircraftName) {
  if(!aircraftName)
    return { maxFuel = 1.0, fuelConsumptionPerHour = 100.0 }

  let maxFuel = get_aircraft_max_fuel(aircraftName)
  let difOpt = get_option(USEROPT_DIFFICULTY)
  local difficulty = isInSessionRoom.get() ? ::SessionLobby.getMissionParam("difficulty", difOpt.values[0]) : difOpt.values[difOpt.value]
  if (difficulty == "custom")
    difficulty = g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty()).name
  let modOpt = get_option(USEROPT_MODIFICATIONS)
  let useModifications = get_game_mode() == GM_TEST_FLIGHT || get_game_mode() == GM_BUILDER ? modOpt.values[modOpt.value] : true
  let fuelConsumptionPerHour = get_aircraft_fuel_consumption(aircraftName, difficulty, useModifications)
  return { maxFuel, fuelConsumptionPerHour }
}

let optionsMap = {
  [USEROPT_LANGUAGE] = function(_optionId, descr, _context) {
    let titleCommon = loc("profile/language")
    let titleEn = loc("profile/language/en")
    descr.title = "".concat(titleCommon, (titleCommon == titleEn ? "" : loc("ui/parentheses/space", { text = titleEn })))
    descr.id = "language"
    descr.items = []
    descr.values = []
    descr.trParams <- "iconType:t='small';"
    let info = getGameLocalizationInfo()
    for (local i = 0; i < info.len(); i++) {
      let lang = info[i]
      descr.values.append(lang.id)
      descr.items.append({
        text = lang.title
        image = lang.icon
      })
    }
    descr.value = u.find_in_array(descr.values, getLocalLanguage())
  },
  [USEROPT_CUSTOM_LANGUAGE] = function(_optionId, descr, _context) {
    descr.id = "customLang"
    descr.title = getLocalization("options/customLang")
    descr.hint = getLocalization("guiHints/customLang")
    descr.hasWarningIcon = hasWarningIcon()
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.needRestartClient = true
    descr.value = isEnabledCustomLocalization()
  },
  [USEROPT_SPEECH_TYPE] = function(_optionId, descr, _context) {
    descr.id = "speech_country_type"
    descr.items = ["#options/speech_country_auto", "#options/speech_country_player", "#options/speech_country_unit"]
    descr.values = [0, 1, 2]
    descr.value = u.find_in_array(descr.values, get_option_speech_country_type())
  },
  [USEROPT_MOUSE_USAGE] = useropt_mouse_usage,
  [USEROPT_MOUSE_USAGE_NO_AIM] = useropt_mouse_usage,
  [USEROPT_INSTRUCTOR_ENABLED] = function(optionId, descr, _context) {
    descr.id = "instructor_enabled"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = ::g_aircraft_helpers.getOptionValue(optionId)
  },
  [USEROPT_AUTOTRIM] = function(optionId, descr, _context) {
    descr.id = "autotrim"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = ::g_aircraft_helpers.getOptionValue(optionId)
  },
  [USEROPT_INSTRUCTOR_GROUND_AVOIDANCE] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "instructorGroundAvoidance", OPTION_INSTRUCTOR_GROUND_AVOIDANCE)
  },
  [USEROPT_INSTRUCTOR_GEAR_CONTROL] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "instructorGearControl", OPTION_INSTRUCTOR_GEAR_CONTROL)
  },
  [USEROPT_INSTRUCTOR_FLAPS_CONTROL] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "instructorFlapsControl", OPTION_INSTRUCTOR_FLAPS_CONTROL)
  },
  [USEROPT_INSTRUCTOR_ENGINE_CONTROL] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "instructorEngineControl", OPTION_INSTRUCTOR_ENGINE_CONTROL)
  },
  [USEROPT_INSTRUCTOR_SIMPLE_JOY] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "instructorSimpleJoy", OPTION_INSTRUCTOR_SIMPLE_JOY)
  },
  [USEROPT_MAP_ZOOM_BY_LEVEL] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "storeMapZoomByLevel", OPTION_MAP_ZOOM_BY_LEVEL)
  },
  [USEROPT_HIDE_MOUSE_SPECTATOR] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "hideMouseInSpectator", OPTION_HIDE_MOUSE_SPECTATOR)
  },
  [USEROPT_SHOW_COMPASS_IN_TANK_HUD] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "showCompassInTankHud", OPTION_SHOW_COMPASS_IN_TANK_HUD)
  },
  [USEROPT_FIX_GUN_IN_MOUSE_LOOK] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "fixGunInMouseLook", OPTION_FIX_GUN_IN_MOUSE_LOOK)
  },
  [USEROPT_ENABLE_SOUND_SPEED] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "enableSoundSpeed", OPTION_ENABLE_SOUND_SPEED)
  },
  [USEROPT_VWS_ONLY_IN_COCKPIT] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "vwsOnlyInCockpit", OPTION_VWS_ONLY_IN_COCKPIT)
  },
  [USEROPT_PITCH_BLOCKER_WHILE_BRACKING] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "pitchBlockerWhileBraking", OPTION_PITCH_BLOCKER_WHILE_BRACKING)
  },
  [USEROPT_SAVE_DIR_WHILE_SWITCH_TRIGGER] = function(_optionId, descr, _context) {
    fillBoolOption(descr, "saveDirWhileSwitchTrigger", OPTION_SAVE_DIR_WHILE_SWITCH_TRIGGER)
  },
  [USEROPT_SOUND_RESET_VOLUMES] = function(_optionId, descr, _context) {
    descr.id = "sound_reset_volumes"
    descr.controlType = optionControlType.BUTTON
    descr.funcName <- "resetVolumes"
    descr.delayed <- true
    descr.text <- loc("mainmenu/resetVolumes")
    descr.showTitle <- false
  },
  [USEROPT_COMMANDER_CAMERA_IN_VIEWS] = function(_optionId, descr, _context) {
    descr.id = "commander_camera_in_views"
    descr.items = [
      "#options/commander_not_in_views",
      "#options/commander_in_gunner_views",
      "#options/commander_in_binocular_views" ]
    descr.values = [0, 1, 2]
    descr.value = get_commander_camera_in_views()
    descr.trParams <- "optionWidthInc:t='half';"
  },
  [USEROPT_VIEWTYPE] = function(_optionId, descr, _context) {
    descr.id = "viewtype"
    descr.items = ["#options/viewTps", "#options/viewCockpit", "#options/viewVirtual"]
    descr.value = get_option_view_type()
  },
  [USEROPT_GUN_TARGET_DISTANCE] = function(_optionId, descr, _context) {
    descr.id = "gun_target_dist"
    descr.items = ["#options/no", "50", "100", "150", "200", "250", "300", "400", "500", "600", "700", "800"]
    descr.values = [-1, 50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800]
    descr.value = u.find_in_array(descr.values, get_option_gun_target_dist())
    descr.defaultValue = 300
  },
  [USEROPT_BOMB_ACTIVATION_TIME] = function(_optionId, descr, context) {
    let diffCode = context?.diffCode ?? get_difficulty_by_ediff(get_mission_mode()).diffCode
    let bombActivationType = loadLocalAccountSettings($"useropt/bomb_activation_type/{diffCode}",
      get_option_bomb_activation_type())
    let isBombActivationAssault = bombActivationType == BOMB_ACT_ASSAULT
    let assaultFuseTime = get_bomb_activation_auto_time()
    let bombActivationTime = max(loadLocalAccountSettings(
      $"useropt/bomb_activation_time/{diffCode}",
        get_option_bomb_activation_time()), assaultFuseTime)

    descr.diffCode = diffCode
    descr.id = "bomb_activation_type"
    descr.values = [BOMB_ASSAULT_FUSE_TIME_OPT_VALUE]
    let activationTimeArray = [0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    let nearestFuseValue = ::find_nearest(assaultFuseTime, activationTimeArray)
    if (nearestFuseValue >= 0)
      descr.values.extend(activationTimeArray.slice(nearestFuseValue))

    descr.value = ::find_nearest(isBombActivationAssault ? BOMB_ASSAULT_FUSE_TIME_OPT_VALUE : bombActivationTime, descr.values)
    descr.items = []
    for (local i = 0; i < descr.values.len(); i++) {
      let assaultFuse = descr.values[i] == BOMB_ASSAULT_FUSE_TIME_OPT_VALUE
      let text = assaultFuse ? "#options/bomb_activation_type/assault"
        : time.secondsToString(descr.values[i], true, true, 1)
      let tooltipLoc = assaultFuse ? "guiHints/bomb_activation_type/assault" : "guiHints/bomb_activation_type/timer"

      descr.items.append({
        text = text
        tooltip = loc(tooltipLoc, { sec = assaultFuse ? assaultFuseTime : descr.values[i] })
      })
    }
    let curValue = isBombActivationAssault ? assaultFuseTime : descr.values[descr.value]
    if (get_option_bomb_activation_time() != curValue) {
      set_option_bomb_activation_type(isBombActivationAssault ? BOMB_ACT_ASSAULT : BOMB_ACT_TIME)
      set_option_bomb_activation_time(curValue)
    }
  },
  [USEROPT_BOMB_SERIES] = function(_optionId, descr, _context) {
    descr.id = "bomb_series"
    descr.values = [0]
    descr.items = [ { text = "#options/disabled" } ]
    let unit = getAircraftByName(::aircraft_for_weapons)
    let bombSeries = [0, 4, 6, 12, 24, 48]
    let nbrBomb = unit != null ? bombNbr(unit) : bombSeries.top()
    for (local i = 1; i < bombSeries.len(); ++i) {
      if (bombSeries[i] >= nbrBomb) // max = -1
        break

      descr.values.append(bombSeries[i])
      let text = descr.values[i].tostring()
      descr.items.append({
        text = text
        tooltip = loc("guiHints/bomb_series_num", { num = descr.values[i] })
      })
    }

    descr.values.append(nbrBomb)
    descr.items.append({
      text = loc("options/bomb_series_all", { num = nbrBomb })
      tooltip = loc("guiHints/bomb_series_all")
    })

    descr.value = u.find_in_array(descr.values, get_option_bombs_series())
    descr.defaultValue = bombSeries[0]
  },
  [USEROPT_COUNTERMEASURES_PERIODS] = function(_optionId, descr, _context) {
     descr.id = "countermeasures_periods"
     descr.values = [0.1, 0.2, 0.5, 1.0]
     descr.items = []
     for (local i = 0; i < descr.values.len(); ++i) {
       let text = time.secondsToString(descr.values[i], true, true, 2)
       let tooltipLoc = "guiHints/countermeasures_periods/periods"
       descr.items.append({
        text = text
        tooltip = loc(tooltipLoc, { sec = descr.values[i] })
        })
     }
     descr.value = u.find_in_array(descr.values, get_option_countermeasures_periods())
     descr.defaultValue = 0.1
  },
  [USEROPT_COUNTERMEASURES_SERIES_PERIODS] = function(_optionId, descr, _context) {
     descr.id = "countermeasures_series_periods"
     descr.items = []
     descr.values = [1, 2, 5, 10]
     for (local i = 0; i < descr.values.len(); ++i) {
        let text = time.secondsToString(descr.values[i], true, true, 2)
        let tooltipLoc = "guiHints/countermeasures_periods/series_periods"
       descr.items.append({
        text = text
        tooltip = loc(tooltipLoc, { sec = descr.values[i] })
        })
     }
     descr.value = u.find_in_array(descr.values, get_option_countermeasures_series_periods())
     descr.defaultValue = 1
  },
  [USEROPT_COUNTERMEASURES_SERIES] = function(_optionId, descr, _context) {
     descr.id = "countermeasures_series"
     descr.items = []
     descr.values = [1, 2, 3, 4]
     for (local i = 0; i < descr.values.len(); ++i) {
        let text = descr.values[i].tostring()
        let tooltipLoc = "guiHints/countermeasures_periods/series"
       descr.items.append({
        text = text
        tooltip = loc(tooltipLoc, { num = descr.values[i] })
        })
     }

     descr.value = u.find_in_array(descr.values, get_option_countermeasures_series())
     descr.defaultValue = 1
  },
  [USEROPT_DEPTHCHARGE_ACTIVATION_TIME] = function(_optionId, descr, _context) {
    descr.id = "depthcharge_activation_time"
    descr.items = []
    descr.values = []
    for (local i = 3; i <= 10; i++) {
      descr.items.append(time.secondsToString(i, true, true))
      descr.values.append(i)
    }
    descr.value = u.find_in_array(descr.values, get_option_depthcharge_activation_time())
  },
  [USEROPT_USE_PERFECT_RANGEFINDER] = function(_optionId, descr, _context) {
    descr.id = "use_perfect_rangefinder"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_use_perfect_rangefinder()
  },
  [USEROPT_ROCKET_FUSE_DIST] = function(_optionId, descr, _context) {
    descr.id = "rocket_fuse_dist"
    descr.items = ["#options/rocketFuseImpact", "200", "300", "400", "500", "600", "700", "800", "900", "1000"]
    descr.values = [0, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
    if (::aircraft_for_weapons)
      descr.value = u.find_in_array(descr.values, get_unit_option(::aircraft_for_weapons, USEROPT_ROCKET_FUSE_DIST), null)
    if (!is_numeric(descr.value))
      descr.value = u.find_in_array(descr.values, get_option_rocket_fuse_dist(), null)
    descr.defaultValue = 0
  },
  [USEROPT_TORPEDO_DIVE_DEPTH] = function(_optionId, descr, _context) {
    descr.id = "torpedo_dive_depth"
    let items = get_options_torpedo_dive_depth()
    descr.items = []
    descr.values = []
    foreach (val in items) {
      descr.items.append(val.tostring())
      descr.values.append(val)
    }
    if (::aircraft_for_weapons)
      descr.value = u.find_in_array(descr.values, get_unit_option(::aircraft_for_weapons, USEROPT_TORPEDO_DIVE_DEPTH), null)
    if (!is_numeric(descr.value))
      descr.value = u.find_in_array(descr.values, get_option_torpedo_dive_depth(), null)
    descr.defaultValue = 0
  },
  [USEROPT_AEROBATICS_SMOKE_TYPE] = function(_optionId, descr, _context) {
    descr.id = "aerobatics_smoke_type"
    descr.optionCb = "onTripleAerobaticsSmokeSelected"

    descr.items = []
    descr.values = []
    descr.unlocks <- []

    let localSmokeType = get_option_aerobatics_smoke_type()
    foreach (inst in aeroSmokesList.value) {
      let { id, unlockId = "", locId = "" } = inst
      if ((id == TRICOLOR_INDEX) && !hasFeature("AerobaticTricolorSmoke")) //not triple color
        continue

      if (unlockId != "" && !(getUnlockById(unlockId) && is_unlocked(-1, unlockId)))
        continue

      descr.items.append(loc(locId))
      descr.values.append(id)
      descr.unlocks.append(unlockId)
    }

    descr.value = descr.values.findindex(@(v) v == localSmokeType) ?? 1
  },
  [USEROPT_AEROBATICS_SMOKE_LEFT_COLOR] = useropt_aerobatics_smoke_left_color,
  [USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR] = useropt_aerobatics_smoke_left_color,
  [USEROPT_AEROBATICS_SMOKE_TAIL_COLOR] = useropt_aerobatics_smoke_left_color,
  [USEROPT_INGAME_VIEWTYPE] = function(_optionId, descr, _context) {
    descr.id = "ingame_viewtype"
    descr.items = ["#options/viewTps", "#options/viewCockpit", "#options/viewVirtual"]
    descr.value = get_current_view_type()
  },
  [USEROPT_GAME_HUD] = function(_optionId, descr, _context) {
    descr.id = "hud"
    descr.items = []
    descr.values = []
    let diffCode = get_mission_set_difficulty_int()
    let total = g_hud_vis_mode.types.len()
    for (local i = 0; i < total; i++) {
      let visType = g_hud_vis_mode.types[i]
      if (!visType.isAvailable(diffCode))
        continue
      descr.items.append(visType.getName())
      descr.values.append(visType.hudGm)
    }

    descr.value = u.find_in_array(descr.values, get_option_hud())
  },
  [USEROPT_FONTS_CSS] = function(_optionId, descr, _context) {
    descr.id = "fonts_type"
    descr.controlName <- "combobox"

    descr.items = []
    descr.values = ::g_font.getAvailableFonts()
    for (local i = 0; i < descr.values.len(); i++) {
      let font = descr.values[i]
      descr.items.append({
        text = font.getOptionText()
        fontOverride = font.getFontExample()
      })
    }
    descr.value = u.find_in_array(descr.values, ::g_font.getCurrent(), 0)
    descr.enabled <- descr.values.len() > 1
  },
  [USEROPT_ENABLE_CONSOLE_MODE] = function(_optionId, descr, _context) {
    descr.id = "console_mode"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = ::get_is_console_mode_force_enabled()
  },
  [USEROPT_GAMEPAD_GYRO_TILT_CORRECTION] = function(_optionId, descr, _context) {
    descr.id = "gamepadGyroTiltCorrection"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_GAMEPAD_ENGINE_DEADZONE] = function(_optionId, descr, _context) {
    descr.id = "gamepadEngDeadZone"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_GAMEPAD_VIBRATION_ENGINE] = function(_optionId, descr, _context) {
    descr.id = "gamepadVibrationForEngine"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
  },
  [USEROPT_JOY_MIN_VIBRATION] = function(_optionId, descr, _context) {
    descr.id = "gamepadMinVibration"
    descr.controlType = optionControlType.SLIDER
    descr.value = (100.0 * get_option_multiplier(OPTION_JOY_MIN_VIBRATION)).tointeger()
    descr.defaultValue = 5
  },
  [USEROPT_INVERTY] = function(_optionId, descr, _context) {
    descr.id = "invertY"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_invertY(AxisInvertOption.INVERT_Y) != 0
  },
  [USEROPT_INVERTX] = function(_optionId, descr, _context) {
    descr.id = "invertX"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_invertX() == 0 ? 0 : 1
  },
  [USEROPT_JOYFX] = function(_optionId, descr, _context) {
    descr.id = "joyFX"
    descr.hint = loc("options/joyFX")
    descr.needRestartClient = true
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_INVERT_THROTTLE] = function(_optionId, descr, _context) {
    descr.id = "invertT"
    descr.items = ["#options/no", "#options/yes"]
    descr.value = get_option_invertY(AxisInvertOption.INVERT_THROTTLE) == 0 ? 0 : 1
  },
  [USEROPT_GUNNER_INVERTY] = function(_optionId, descr, _context) {
    descr.id = "invertY_gunner"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_invertY(AxisInvertOption.INVERT_GUNNER_Y) != 0
  },
  [USEROPT_INVERTY_TANK] = function(_optionId, descr, _context) {
    descr.id = "invertY_tank"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_invertY(AxisInvertOption.INVERT_TANK_Y) != 0
  },
  [USEROPT_INVERTY_SHIP] = function(_optionId, descr, _context) {
    descr.id = "invertY_ship"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_invertY(AxisInvertOption.INVERT_SHIP_Y) != 0
  },
  [USEROPT_INVERTY_HELICOPTER] = function(_optionId, descr, _context) {
    descr.id = "invertY_helicopter"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_invertY(AxisInvertOption.INVERT_HELICOPTER_Y) != 0
  },
  [USEROPT_INVERTY_HELICOPTER_GUNNER] = function(_optionId, descr, _context) {
    descr.id = "invertY_helicopter_gunner"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_invertY(AxisInvertOption.INVERT_HELICOPTER_GUNNER_Y) != 0
  },
  [USEROPT_INVERTY_SUBMARINE] = function(_optionId, descr, _context) {
    descr.id = "invertY_submarine"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_invertY(AxisInvertOption.INVERT_SUBMARINE_Y) != 0
  },
  [USEROPT_INVERTY_SPECTATOR] = function(_optionId, descr, _context) {
    descr.id = "invertY_spectator"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_invertY(AxisInvertOption.INVERT_SPECTATOR_Y) != 0
  },
  [USEROPT_AUTOMATIC_TRANSMISSION_TANK] = function(_optionId, descr, _context) {
    descr.id = "automaticTransmissionTank"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_WHEEL_CONTROL_SHIP] = function(_optionId, descr, _context) {
    descr.id = "selectWheelShipEnable"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
  },
  [USEROPT_SEPERATED_ENGINE_CONTROL_SHIP] = function(_optionId, descr, _context) {
    descr.id = "seperatedEngineControlShip"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
  },
  [USEROPT_BULLET_FALL_INDICATOR_SHIP] = function(_optionId, descr, _context) {
    descr.id = "bulletFallIndicatorShip"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true

    let blk = get_game_params_blk()
    let minCaliber  = blk?.shipsShootingTracking?.minCaliber ?? 0.1
    let minDrawDist = blk?.shipsShootingTracking?.minDrawDist ?? 3500
    descr.hint = loc("guiHints/bulletFallIndicatorShip", {
      minCaliber  = measureType.MM.getMeasureUnitsText(minCaliber * 1000),
      minDistance = measureType.DISTANCE.getMeasureUnitsText(minDrawDist)
    })
  },
  [USEROPT_BULLET_FALL_SPOT_SHIP] = function(_optionId, descr, _context) {
    descr.id = "bulletFallSpotShip"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_BULLET_FALL_SOUND_SHIP] = function(_optionId, descr, _context) {
    descr.id = "bulletFallSoundShip"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true

    let blk = get_game_params_blk()
    let minCaliber  = blk?.shipsShootingTracking?.minCaliber ?? 0.1
    let minDrawDist = blk?.shipsShootingTracking?.minDrawDist ?? 3500
    descr.hint = loc("guiHints/bulletFallSoundShip", {
      minCaliber  = measureType.MM.getMeasureUnitsText(minCaliber * 1000),
      minDistance = measureType.DISTANCE.getMeasureUnitsText(minDrawDist)
    })
  },
  [USEROPT_SINGLE_SHOT_BY_TURRET] = function(_optionId, descr, _context) {
    descr.id = "singleShotByTurret"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_SHIP_COMBINE_PRI_SEC_TRIGGERS] = function(_optionId, descr, _context) {
    descr.id = "shipCombinePriSecTriggers"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_FOLLOW_BULLET_CAMERA] = function(_optionId, descr, _context) {
    descr.id = "followBulletCamera"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_AUTO_TARGET_CHANGE_SHIP] = function(_optionId, descr, _context) {
    descr.id = "automaticTargetChangeShip"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_REALISTIC_AIMING_SHIP] = function(_optionId, descr, _context) {
    descr.id = "realAimingShip"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
  },
  [USEROPT_TORPEDO_AUTO_SWITCH] = function(_optionId, descr, _context) {
    descr.id = "torpedo_auto_switch"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_DEFAULT_TORPEDO_FORESTALL_ACTIVE] = function(_optionId, descr, _context) {
    descr.id = "default_torpedo_forestall_active"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_ALTERNATIVE_TPS_CAMERA] = function(_optionId, descr, _context) {
    descr.id = "alternative_tps_camera"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
  },
  [USEROPT_INDICATED_SPEED_TYPE] = function(_optionId, descr, _context) {
    descr.id = "indicatedSpeed"
    descr.items = ["#options/speed_tas", "#options/speed_ias", "#options/speed_tas_ias"]
    descr.values = [0, 1, 2]
    descr.value = get_option_indicatedSpeedType()
    descr.trParams <- "optionWidthInc:t='half';"
  },
  [USEROPT_INDICATED_ALTITUDE_TYPE] = function(_optionId, descr, _context) {
    descr.id = "indicatedAltitude"
    descr.items = ["#options/altitude_baro", "#options/altitude_radar", "#options/altitude_baro_radar"]
    descr.values = [0, 1, 2]
    descr.value = get_option_indicatedAltitudeType()
    descr.trParams <- "optionWidthInc:t='half';"
  },
  [USEROPT_RADAR_ALTITUDE_ALERT] = function(_optionId, descr, _context) {
    descr.id = "radarAltitudeAlert"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 1
    descr.max <- 200
    descr.step <- 1
    descr.value = get_option_radarAltitudeAlert()
    descr.defaultValue = 60
    descr.getValueLocText = @(val) measureType.ALTITUDE.getMeasureUnitsText(val)
  },
  [USEROPT_INVERTCAMERAY] = function(_optionId, descr, _context) {
    descr.id = "invertCameraY"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_camera_invertY() ? 1 : 0
  },
  [USEROPT_ZOOM_FOR_TURRET] = function(_optionId, descr, _context) {
    descr.id = "zoomForTurret"
    descr.items = ["#options/no", "#options/yes"]
    descr.value = get_option_zoom_turret()
  },
  [USEROPT_XCHG_STICKS] = function(_optionId, descr, _context) {
    descr.id = "xchangeSticks"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = !!get_option_xchg_sticks(0)
  },
  [USEROPT_AUTOSAVE_REPLAYS] = function(_optionId, descr, _context) {
    descr.id = "autosave_replays"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_autosave_replays()
  },
  [USEROPT_XRAY_DEATH] = function(_optionId, descr, _context) {
    descr.id = "xray_death"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_xray_death()
  },
  [USEROPT_XRAY_KILL] = function(_optionId, descr, _context) {
    descr.id = "xray_kill"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_xray_kill()
  },
  [USEROPT_USE_CONTROLLER_LIGHT] = function(_optionId, descr, _context) {
    descr.id = "controller_light"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_controller_light()
  },
  [USEROPT_SUBTITLES] = function(_optionId, descr, _context) {
    descr.id = "subtitles"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_subs() > 0
  },
  [USEROPT_SUBTITLES_RADIO] = function(_optionId, descr, _context) {
    descr.id = "subtitles_radio"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_subs_radio() > 0
  },
  [USEROPT_PTT] = function(_optionId, descr, _context) {
    descr.id = "ptt"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_ptt()
    descr.optionCb = "onPTTChange"
  },
  [USEROPT_VOICE_CHAT] = function(_optionId, descr, _context) {
    descr.id = "voice_chat"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_voicechat()
    descr.optionCb = "onVoicechatChange"
  },
  [USEROPT_VOICE_DEVICE_IN] = function(_optionId, descr, _context) {
    descr.id = "voice_device_in"
    descr.items = []
    descr.values = []
    descr.value = 0
    descr.optionCb = "onInstantOptionApply"
    descr.trParams <- "optionWidthInc:t='double';"
    let lastSoundDevice = soundDevice.get_last_voice_device_in()
    foreach (device in soundDevice.get_record_devices()) {
      descr.items.append(device.name)
      descr.values.append(device.name)
      if (device.name == lastSoundDevice)
        descr.value = descr.values.len() - 1
    }
  },
  [USEROPT_SOUND_DEVICE_OUT] = function(_optionId, descr, _context) {
    descr.id = "sound_device_out"
    descr.items = []
    descr.values = []
    descr.value = 0
    descr.optionCb = "onInstantOptionApply"
    descr.trParams <- "optionWidthInc:t='double';"
    let lastSoundDevice = soundDevice.get_last_sound_device_out()
    foreach (device in soundDevice.get_out_devices()) {
      descr.items.append(device.name)
      descr.values.append(device.name)
      if (device.name == lastSoundDevice)
        descr.value = descr.values.len() - 1
    }

  },
  [USEROPT_SOUND_ENABLE] = function(_optionId, descr, _context) {
    descr.id = "sound_switch"
    descr.title = loc("options/sound")
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.textChecked <- loc("options/enabled")
    descr.textUnchecked <- loc("#options/disabled")
    descr.hint = loc("options/sound")
    if (!is_sound_inited())
      descr.needRestartClient = true
    descr.value = getSystemConfigOption("sound/fmod_sound_enable", true)
  },
  [USEROPT_CUSTOM_SOUND_MODS] = function(_optionId, descr, _context) {
    descr.id = "customSoundMods"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.needRestartClient = true
    descr.value = isEnabledCustomSoundMods()
  },
  [USEROPT_SOUND_SPEAKERS_MODE] = function(_optionId, descr, _context) {
    descr.id = "sound_speakers"
    descr.hint = loc("options/sound_speakers")
    descr.needRestartClient = true
    descr.items  = ["#controls/AUTO", "#options/sound_speakers/stereo", "5.1", "7.1"]
    descr.values = ["auto", "stereo", "speakers5.1", "speakers7.1"]
    descr.value = u.find_in_array(descr.values, getSystemConfigOption("sound/speakerMode", "auto"), 0)
  },
  [USEROPT_VOICE_MESSAGE_VOICE] = function(_optionId, descr, _context) {
    descr.id = "voice_message_voice"
    descr.items = ["#options/voice_message_voice1", "#options/voice_message_voice2",
     "#options/voice_message_voice3", "#options/voice_message_voice4"]
    descr.value = get_option_voice_message_voice() - 1 //1-based
  },
  [USEROPT_MEASUREUNITS_SPEED] = useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_ALT] = useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_DIST] = useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_CLIMBSPEED] = useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_TEMPERATURE] = useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_WING_LOADING] = useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO] = useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_RADIAL_SPEED] = useropt_measureunits_speed,
  [USEROPT_VIBRATION] = function(_optionId, descr, _context) {
    descr.id = "vibration"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_vibration()
  },
  [USEROPT_GRASS_IN_TANK_VISION] = function(_optionId, descr, _context) {
    descr.id = "grass_in_tank_vision"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_grass_in_tank_vision()
  },
  [USEROPT_AILERONS_MULTIPLIER] = function(_optionId, descr, _context) {
    descr.id = "multiplier_ailerons"
    descr.value = (get_option_multiplier(OPTION_AILERONS_MULTIPLIER) * 100).tointeger()
    if (descr.value < 0)
      descr.value = 0
    else if (descr.value > 100)
      descr.value = 100
  },
  [USEROPT_ELEVATOR_MULTIPLIER] = function(_optionId, descr, _context) {
    descr.id = "multiplier_elevator"
    descr.value = (get_option_multiplier(OPTION_ELEVATOR_MULTIPLIER) * 100).tointeger()
    if (descr.value < 0)
      descr.value = 0
    else if (descr.value > 100)
      descr.value = 100
  },
  [USEROPT_RUDDER_MULTIPLIER] = function(_optionId, descr, _context) {
    descr.id = "multiplier_rudder"
    descr.value = (get_option_multiplier(OPTION_RUDDER_MULTIPLIER) * 100).tointeger()
    if (descr.value < 0)
      descr.value = 0
    else if (descr.value > 100)
      descr.value = 100
  },
  [USEROPT_ZOOM_SENSE] = function(_optionId, descr, _context) {
    descr.id = "multiplier_zoom"
    descr.value = (get_option_multiplier(OPTION_ZOOM_SENSE) * 100).tointeger()
    if (descr.value < 0)
      descr.value = 0
    else if (descr.value > 100)
      descr.value = 100
    descr.value = 100 - descr.value
  },
  [USEROPT_MOUSE_SENSE] = function(_optionId, descr, _context) {
    descr.id = "multiplier_mouse"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 5
    descr.max <- 100
    descr.value = (get_option_multiplier(OPTION_MOUSE_SENSE) * 50.0).tointeger()
    descr.value = clamp(descr.value, descr.min, descr.max)
  },
  [USEROPT_MOUSE_AIM_SENSE] = function(_optionId, descr, _context) {
    descr.id = "multiplier_joy_camera_view"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 5
    descr.max <- 100
    descr.value = (get_option_multiplier(OPTION_MOUSE_AIM_SENSE) * 50.0).tointeger()
    descr.value = clamp(descr.value, descr.min, descr.max)
  },
  [USEROPT_GUNNER_VIEW_SENSE] = function(_optionId, descr, _context) {
    descr.id = "multiplier_gunner_view"
    descr.value = (get_option_multiplier(OPTION_GUNNER_VIEW_SENSE) * 100.0).tointeger()
  },
  [USEROPT_GUNNER_VIEW_ZOOM_SENS] = function(_optionId, descr, _context) {
    descr.id = "multiplier_gunner_view_zoom"
    descr.value = (get_option_multiplier(OPTION_GUNNER_VIEW_ZOOM_SENS) * 100.0).tointeger()
  },
  [USEROPT_ATGM_AIM_SENS_HELICOPTER] = function(_optionId, descr, _context) {
    descr.id = "atgm_aim_sens_helicopter"
    descr.value = (get_option_multiplier(OPTION_ATGM_AIM_SENS_HELICOPTER) * 100.0).tointeger()
  },
  [USEROPT_ATGM_AIM_ZOOM_SENS_HELICOPTER] = function(_optionId, descr, _context) {
    descr.id = "atgm_aim_zoom_sens_helicopter"
    descr.value = (get_option_multiplier(OPTION_ATGM_AIM_ZOOM_SENS_HELICOPTER) * 100.0).tointeger()
  },
  [USEROPT_MOUSE_SMOOTH] = function(_optionId, descr, _context) {
    descr.id = "mouse_smooth"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_mouse_smooth() != 0
  },
  [USEROPT_FORCE_GAIN] = function(_optionId, descr, _context) {
    descr.id = "multiplier_force_gain"
    descr.value = (get_option_gain() * 50).tointeger()
  },
  [USEROPT_CAMERA_SHAKE_MULTIPLIER] = function(_optionId, descr, _context) {
    descr.id = "camera_shake_gain"
    descr.value = (get_option_multiplier(OPTION_CAMERA_SHAKE) * 50.0).tointeger()
    descr.controlType = optionControlType.SLIDER
  },
  [USEROPT_VR_CAMERA_SHAKE_MULTIPLIER] = function(_optionId, descr, _context) {
    descr.id = "vr_camera_shake_gain"
    descr.value = (get_option_multiplier(OPTION_VR_CAMERA_SHAKE) * 50.0).tointeger()
    descr.controlType = optionControlType.SLIDER
  },
  [USEROPT_GAMMA] = function(_optionId, descr, _context) {
    descr.id = "video_gamma"
    descr.value = (get_option_gamma() * 100).tointeger()
    descr.optionCb = "onGammaChange"
  },
  [USEROPT_CONSOLE_GFX_PRESET] = function(_optionId, descr, _context) {
    descr.id = "console_gfx_preset"
    descr.items = getConsolePresets()
    descr.values = getConsolePresetsValues()
    descr.defaultValue = get_option_console_preset()
    descr.optionCb = "onConsolePresetChange"
  },
  [USEROPT_VOLUME_MASTER] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_MASTER, "volume_master")
  },
  [USEROPT_VOLUME_MUSIC] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_MUSIC, "volume_music",
      loc(hasFeature("Radio") ? "options/volume_music/and_radio" : "options/volume_music"))
  },
  [USEROPT_VOLUME_MENU_MUSIC] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_MENU_MUSIC, "volume_menu_music")
  },
  [USEROPT_VOLUME_SFX] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_SFX, "volume_sfx")
  },
  [USEROPT_VOLUME_GUNS] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_GUNS, "volume_guns")
  },
  [USEROPT_VOLUME_VWS] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_VWS, "volume_vws")
  },
  [USEROPT_VOLUME_RWR] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_RWR, "volume_rwr")
  },
  [USEROPT_VOLUME_TINNITUS] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_TINNITUS, "volume_tinnitus")
  },
  [USEROPT_HANGAR_SOUND] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_TINNITUS, "volume_tinnitus")
    descr.id = "hangar_sound"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_hangar_sound()
  },
  [USEROPT_VOLUME_RADIO] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_RADIO, "volume_radio")
  },
  [USEROPT_VOLUME_ENGINE] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_ENGINE, "volume_engine")
  },
  [USEROPT_VOLUME_MY_ENGINE] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_MY_ENGINE, "volume_my_engine")
  },
  [USEROPT_VOLUME_DIALOGS] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_DIALOGS, "volume_dialogs")
  },
  [USEROPT_VOLUME_VOICE_IN] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_VOICE_IN, "volume_voice_in")
  },
  [USEROPT_VOLUME_VOICE_OUT] = function(_optionId, descr, _context) {
    fillSoundDescr(descr, SND_TYPE_VOICE_OUT, "volume_voice_out")
  },
  [USEROPT_CONTROLS_PRESET] = function(_optionId, descr, _context) {
    descr.id = "controls_preset"
    descr.items = []
    descr.values = ::g_controls_presets.getControlsPresetsList()
    descr.trParams <- "optionWidthInc:t='double';"

    if (!isPlatformSony && !isPlatformXboxOne)
      descr.values.insert(0, "") //custom preset
    let p = ::g_controls_manager.getCurPreset()?.getBasePresetInfo()
      ?? ::g_controls_presets.getNullPresetInfo()
    for (local k = 0; k < descr.values.len(); k++) {
      local name = descr.values[k]
      local suffix = isPlatformSony ? "ps4/" : ""
      let vPresetData = ::g_controls_presets.parsePresetName(name)
      if (p.name == vPresetData.name && p.version == vPresetData.version)
        descr.value = k
      local imageName = "preset_joystick.svg"
      if (name.indexof("keyboard") != null)
        imageName = "preset_mouse_keyboard.svg"
      else if (name.indexof("xinput") != null || name.indexof("xboxone") != null)
        imageName = "preset_gamepad.svg"
      else if (name.indexof("default") != null || name.indexof("dualshock4") != null)
        imageName = "preset_ps4.svg"
      else if (name == "") {
        name = "custom"
        imageName = "preset_custom"
        suffix = ""
      }

      descr.items.append({
                          text = $"#presets/{suffix}{name}"
                          image = $"#ui/gameuiskin#{imageName}"
                        })
    }
    descr.optionCb = "onSelectPreset"
  },
  [USEROPT_ROUNDS] = function(_optionId, descr, _context) {
    descr.id = "rounds"
    descr.items = ["#options/rounds0", "#options/rounds1", "#options/rounds3", "#options/rounds5", "#options/rounds7"]
    descr.values = [0, 1, 3, 5, 7]
    descr.defaultValue = 5
  },
  [USEROPT_AAA_TYPE] = function(_optionId, descr, _context) {
    descr.id = "aaa_type"
    descr.items = ["#options/aaaNone", "#options/aaaFriendly", "#options/aaaEnemy", "#options/aaaBoth"]
    descr.values = [0, 1, 2, 3]
    descr.defaultValue = 3
  },
  [USEROPT_SITUATION] = function(_optionId, descr, _context) {
    descr.id = "situation"
    descr.items = ["#options/situationCommon", "#options/situationAltAdv", "#options/situationAltDisAdv"]
    descr.values = [0, 1, 2]
  },
  [USEROPT_CLIME] = function(_optionId, descr, _context) {
    descr.id = "weather"
    descr.values = ["clear", "good", "hazy", "mist", "thin_clouds", "cloudy_windy", "cloudy",
      "overcast", "poor", "blind",
      //"shower",
      "rain", "thunder"]
    descr.items = descr.values.map(getWeatherLocName)
    descr.defaultValue = "cloudy"
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("weather", null)
  },
  [USEROPT_TIME] = function(_optionId, descr, _context) {
    descr.id = "time"
    descr.values = ["Dawn", "Morning", "Noon", "Day", "Evening", "Dusk", "Night",
                    "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18"]
    descr.items = descr.values.map(getMissionTimeText)
    descr.defaultValue = "Day"
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("environment", null)
  },
  [USEROPT_ALTITUDE] = function(_optionId, descr, _context) {
    descr.id = "altitude"
    descr.items = ["#options/altitude400", "#options/altitude1000", "#options/altitude2000", "#options/altitude3000",
      "#options/altitude5000", "#options/altitude7500", "#options/altitude9000"]
    descr.values = [400.0, 1000.0, 2000.0, 3000.0, 5000.0, 7500.0, 9000.0]
  },
  [USEROPT_FRIENDS_ONLY] = function(_optionId, descr, _context) {
    descr.id = "friends_only"
    descr.items = ["#options/no", "#options/yes"]
    descr.values = [0, 1]
  },
  [USEROPT_DISABLE_AIRFIELDS] = function(_optionId, descr, _context) {
    descr.id = "disable_airfields"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("disableAirfields", false)
  },
  [USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS] = function(_optionId, descr, _context) {
    descr.id = "spawn_ai_tank_on_tank_maps"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("spawnAiTankOnTankMaps", true)
  },
  [USEROPT_COOP_MODE] = function(_optionId, descr, _context) {
    descr.id = "coop_mode"
    descr.items = ["#options/create", "#options/private", "#options/single"]
    descr.values = [0, 1, 2]
    descr.defaultValue = 0
  },
  [USEROPT_DEDICATED_REPLAY] = function(_optionId, descr, _context) {
    descr.id = "dedicatedReplay"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("dedicatedReplay", false)
  },
  [USEROPT_SESSION_PASSWORD] = function(_optionId, descr, _context) {
    descr.id = "session_password"
    descr.controlType = optionControlType.EDITBOX
    descr.controlName <- "editbox"
    descr.value = ::SessionLobby.getPassword()
    descr.getValueLocText = function(val) {
      if (val == true)
        return loc("options/yes")
      return loc("options/no")
    }
  },
  [USEROPT_TAKEOFF_MODE] = useropt_takeoff_mode,
  [USEROPT_LANDING_MODE] = useropt_takeoff_mode,
  [USEROPT_IS_BOTS_ALLOWED] = function(_optionId, descr, _context) {
    descr.id = "isBotsAllowed"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
    descr.optionCb = "onOptionBotsAllowed"
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("isBotsAllowed", null)
  },
  [USEROPT_USE_TANK_BOTS] = function(_optionId, descr, _context) {
    descr.id = "useTankBots"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("useTankBots", null)
  },
  [USEROPT_USE_SHIP_BOTS] = function(_optionId, descr, _context) {
    descr.id = "useShipBots"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("useShipBots", null)
  },
  [USEROPT_KEEP_DEAD] = function(_optionId, descr, _context) {
    descr.id = "keepDead"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("keepDead", null)
  },
  [USEROPT_AUTOBALANCE] = function(_optionId, descr, _context) {
    descr.id = "autoBalance"
    descr.items = ["#options/no", "#options/yes"]
    descr.values = [false, true]
    descr.defaultValue = true
  },
  [USEROPT_MAX_PLAYERS] = function(_optionId, descr, _context) {
    descr.id = "maxPlayers"
    descr.items = []
    descr.values = []

    for (local i = 2; i <= ::global_max_players_versus; i += 2) {
      descr.items.append(i.tostring())
      descr.values.append(i)
    }
    descr.defaultValue = ::global_max_players_versus
  },
  [USEROPT_MIN_PLAYERS] = function(_optionId, descr, _context) {
    descr.id = "minPlayers"
    descr.items = []
    descr.values = []
    for (local i = 0; i <= ::global_max_players_versus; i += 2) {
      descr.items.append(i.tostring())
      descr.values.append(i)
    }
  },
  [USEROPT_COMPLAINT_CATEGORY] = function(_optionId, descr, _context) {
    descr.id = "complaint_category"
    descr.values = complaintCategories
    descr.items = []
    for (local i = 0; i < descr.values.len(); i++)
      descr.items.append($"#charServer/ban/reason/{descr.values[i]}")
  },
  [USEROPT_BAN_PENALTY] = function(_optionId, descr, _context) {
    descr.id = "ban_penalty"
    descr.values = []
    if (myself_can_devoice()) {
      descr.values.append("DEVOICE")
      descr.values.append("SILENT_DEVOICE")
    }
    if (myself_can_ban())
      descr.values.append("BAN")
    descr.items = []
    for (local i = 0; i < descr.values.len(); i++)
      descr.items.append($"#charServer/penalty/{descr.values[i]}")
  },
  [USEROPT_BAN_TIME] = function(_optionId, descr, _context) {
    descr.id = "ban_time"
    descr.values = myself_can_ban() ? [1, 2, 4, 7, 14] : [1]
    descr.items = []
    let dayVal = time.daysToSeconds(1)
    for (local i = 0; i < descr.values.len(); i++) {
      descr.items.append($"{descr.values[i]}{loc("measureUnits/days")}")
      descr.values[i] *= dayVal
    }
  },
  [USEROPT_OFFLINE_MISSION] = function(_optionId, descr, _context) {
    descr.id = "OfflineMission"
    descr.items = ["#options/disabled", "#options/enabled"]
    descr.values = [false, true]
    descr.defaultValue = false
  },
  [USEROPT_VERSUS_NO_RESPAWN] = function(_optionId, descr, _context) {
    descr.id = "noRespawns"
    descr.items = ["#options/disabled", "#options/enabled"]
    descr.values = [true, false]
    descr.defaultValue = false
  },
  [USEROPT_VERSUS_RESPAWN] = function(_optionId, descr, _context) {
    descr.id = "maxRespawns"
    descr.items = ["#options/resp_unlimited", "#options/resp_all", "#options/resp_none"]
    descr.values = [-2, -1,  1]
    for (local i = 2; i <= 3; i++) {
      descr.items.append(loc("options/resp_limited/value", { amount = i }))
      descr.values.append(i)
    }
    descr.defaultValue = -1
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("maxRespawns", null)
  },
  [USEROPT_ALLOW_EMPTY_TEAMS] = function(_optionId, descr, _context) {
    descr.id = "allowEmptyTeams"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("allowEmptyTeams", null)
  },
  [USEROPT_ALLOW_JIP] = function(_optionId, descr, _context) {
    descr.id = "allow_jip"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getPublicParam("allowJIP", null)
  },
  [USEROPT_QUEUE_JIP] = function(_optionId, descr, _context) {
    descr.id = "queue_jip"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_AUTO_SQUAD] = function(_optionId, descr, _context) {
    descr.id = "auto_squad"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_ORDER_AUTO_ACTIVATE] = function(_optionId, descr, _context) {
    descr.id = "order_auto_activate"
    descr.hint = ::g_orders.getAutoActivateHint()
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_QUEUE_EVENT_CUSTOM_MODE] = function(_optionId, descr, context) {
    descr.id = "queue_event_custom_mode"
    descr.title = loc("events/playersRooms")
    descr.hint = loc("events/playersRooms/tooltip")
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.textChecked <- loc("options/enabled")
    descr.textUnchecked <- loc("#options/disabled")
    descr.value = ::queue_classes.Event.getShouldQueueCustomMode(getTblValue("eventName", context, ""))
  },
  [USEROPT_AUTO_SHOW_CHAT] = function(_optionId, descr, _context) {
    descr.id = "auto_show_chat"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_auto_show_chat() != 0
  },
  [USEROPT_CHAT_MESSAGES_FILTER] = function(_optionId, descr, _context) {
    descr.id = "chat_messages"
    descr.items = ["#options/chat_messages_all", "#options/chat_messages_team_and_squad", "#options/chat_messages_squad",
      "#options/chat_messages_system", "#options/chat_messages_nothing"]
    descr.values = [0, 1, 2, 3, 4]
    descr.value = get_option_chat_messages_filter()
  },
  [USEROPT_CHAT_FILTER] = function(_optionId, descr, _context) {
    descr.id = "chat_filter"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_chat_filter() != 0
  },
  [USEROPT_DAMAGE_INDICATOR_SIZE] = function(optionId, descr, _context) {
    descr.id = "damage_indicator_scale"
    descr.controlType = optionControlType.SLIDER
    descr.min <- -2
    descr.max <- 2
    descr.step <- 1
    descr.value = ::get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY)
    descr.defaultValue = 0
    descr.getValueLocText = @(val) $"{(100 + 33.3 * val / descr.max).tointeger()}%"
  },
  [USEROPT_TACTICAL_MAP_SIZE] = function(optionId, descr, _context) {
    descr.id = "tactical_map_scale"
    descr.controlType = optionControlType.SLIDER
    descr.min <- -2
    descr.max <- 2
    descr.step <- 1
    descr.value = ::get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY)
    descr.defaultValue = 0
    descr.getValueLocText = @(val) $"{(100 + 33.3 * val / descr.max).tointeger()}%"
  },
  [USEROPT_AIR_RADAR_SIZE] = function(optionId, descr, _context) {
    descr.id = "air_radar_scale"
    descr.controlType = optionControlType.SLIDER
    descr.min <- -2
    descr.max <- 2
    descr.step <- 1
    descr.value = ::get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY)
    descr.defaultValue = 0
    descr.getValueLocText = @(val) $"{(100 + 33.3 * val / descr.max).tointeger()}%"
  },
  [USEROPT_SHOW_PILOT] = function(_optionId, descr, _context) {
    descr.id = "show_pilot"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_showPilot() != 0
    if (get_dgs_tex_quality() > 0)
      descr.enabled <- false
  },
  [USEROPT_GUN_VERTICAL_TARGETING] = function(_optionId, descr, _context) {
    descr.id = "gun_vertical_targeting"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_gunVerticalTargeting() != 0
  },
  [USEROPT_AUTOLOGIN] = function(_optionId, descr, _context) {
    descr.id = "auto_login"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = ::is_autologin_enabled()
  },
  [USEROPT_ONLY_FRIENDLIST_CONTACT] = function(_optionId, descr, _context) {
    descr.id = "only_friendlist_contact"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.textChecked <- loc("options/enabled")
    descr.textUnchecked <- loc("options/disabled")
    descr.defaultValue = false
  },
  [USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL] = function(_optionId, descr, _context) {
    descr.id = "mark_direct_messages_as_personal"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.textChecked <- loc("options/enabled")
    descr.textUnchecked <- loc("options/disabled")
    descr.defaultValue = true
  },
  [USEROPT_CROSSHAIR_DEFLECTION] = function(_optionId, descr, _context) {
    descr.id = "crosshair_deflection"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_deflection()
  },
  [USEROPT_GYRO_SIGHT_DEFLECTION] = function(_optionId, descr, _context) {
    descr.id = "gyro_sight_deflection"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_gyro_sight_deflection()
  },
  [USEROPT_SHOW_INDICATORS] = function(_optionId, descr, _context) {
    descr.id = "show_indicators"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = (get_option_indicators_mode() & HUD_INDICATORS_SHOW) != 0
  },
  [USEROPT_REPLAY_ALL_INDICATORS] = function(_optionId, descr, _context) {
    descr.id = "replay_all_indicators"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_REPLAY_LOAD_COCKPIT] = function(_optionId, descr, _context) {
    descr.id = "replay_load_cockpit"
    descr.controlName <- "combobox"
    descr.items = [
      loc("options/replay_load_cockpit_no_one")
      loc("options/replay_load_cockpit_author")
      loc("options/replay_load_cockpit_all")
    ]
    descr.values = [
      REPLAY_LOAD_COCKPIT_NO_ONE
      REPLAY_LOAD_COCKPIT_AUTHOR
      REPLAY_LOAD_COCKPIT_ALL
    ]
    descr.defaultValue = REPLAY_LOAD_COCKPIT_AUTHOR
  },
  [USEROPT_HUD_VISIBLE_STREAKS] = function(_optionId, descr, _context) {
    descr.id = "hud_vis_part_streaks"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb <- "onChangedPartHudVisible"
    descr.defaultValue = true
  },
  [USEROPT_HUD_VISIBLE_ORDERS] = function(_optionId, descr, _context) {
    descr.id = "hud_vis_part_orders"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb <- "onChangedPartHudVisible"
    descr.defaultValue = true
  },
  [USEROPT_HUD_VISIBLE_REWARDS_MSG] = function(_optionId, descr, _context) {
    descr.id = "hud_vis_part_reward_msg"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb <- "onChangedPartHudVisible"
    descr.defaultValue = true
  },
  [USEROPT_HUD_VISIBLE_KILLLOG] = function(_optionId, descr, _context) {
    descr.id = "hud_vis_part_killlog"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb <- "onChangedPartHudVisible"
    descr.defaultValue = true
  },
  [USEROPT_HUD_SHOW_NAMES_IN_KILLLOG] = function(_optionId, descr, _context) {
    descr.id = "hud_show_names_in_killlog"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_HUD_SHOW_AMMO_TYPE_IN_KILLLOG] = function(_optionId, descr, _context) {
    descr.id = "hud_show_ammo_type_in_killlog"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_HUD_SHOW_SQUADRON_NAMES_IN_KILLLOG] = function(_optionId, descr, _context) {
    descr.id = "hud_show_squadron_names_in_killlog"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_HUD_SHOW_DEATH_REASON_IN_SHIP_KILLLOG] = function(_optionId, descr, _context) {
    descr.id = "hud_show_death_reason_in_ship_killlog"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_HUD_VISIBLE_CHAT_PLACE] = function(_optionId, descr, _context) {
    descr.id = "hud_vis_part_chat_place"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb <- "onChangedPartHudVisible"
    descr.defaultValue = true
  },
  [USEROPT_SHOW_ACTION_BAR] = function(optionId, descr, _context) {
    descr.id = "hud_show_action_bar"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb <- "onChangedShowActionBar"
    descr.defaultValue = true
    descr.value = get_gui_option(optionId)
  },
  [USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES] = function(_optionId, descr, _context) {
    descr.id = "can_queue_to_night_battles"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
  },
  [USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES] = function(_optionId, descr, _context) {
    descr.id = "can_queue_to_small_teams"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
  },
  [USEROPT_HUD_SCREENSHOT_LOGO] = function(_optionId, descr, _context) {
    descr.id = "hud_screenshot_logo"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_hud_screenshot_logo()
  },
  [USEROPT_SAVE_ZOOM_CAMERA] = function(_optionId, descr, _context) {
    descr.id = "save_zoom_camera"
    descr.items = ["#options/zoom/dont_save", "#options/zoom/save_only_tps", "#options/zoom/save"]
    descr.values = [0, 1, 2]
    descr.value = get_option_save_zoom_camera() ?? 0
    descr.defaultValue = 0
  },
  [USEROPT_HUD_SHOW_FUEL] = function(_optionId, descr, _context) {
    descr.id = "hud_show_fuel"
    descr.items = ["#options/auto", "#options/always"]
    descr.values = [0, 2]

    if (g_difficulty.SIMULATOR.isAvailable()) {
      descr.items.insert(1, "#options/inhardcore")
      descr.values.insert(1, 1)
    }

    descr.value = u.find_in_array(descr.values, get_option_hud_show_fuel(), 0)
    descr.trParams <- "optionWidthInc:t='half';"
  },
  [USEROPT_HUD_SHOW_AMMO] = function(_optionId, descr, _context) {
    descr.id = "hud_show_ammo"
    descr.items = ["#options/auto", "#options/always"]
    descr.values = [0, 2]

    if (g_difficulty.SIMULATOR.isAvailable()) {
      descr.items.insert(1, "#options/inhardcore")
      descr.values.insert(1, 1)
    }

    descr.value = u.find_in_array(descr.values, get_option_hud_show_ammo(), 0)
    descr.trParams <- "optionWidthInc:t='half';"
  },
  [USEROPT_HUD_SHOW_TANK_GUNS_AMMO] = function(_optionId, descr, _context) {
    descr.id = "hud_show_tank_guns_ammo"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_HUD_SHOW_TEMPERATURE] = function(_optionId, descr, _context) {
    descr.id = "hud_show_temperature"
    descr.items = ["#options/auto", "#options/always"]
    descr.values = [0, 2]

    if (g_difficulty.SIMULATOR.isAvailable()) {
      descr.items.insert(1, "#options/inhardcore")
      descr.values.insert(1, 1)
    }

    descr.value = u.find_in_array(descr.values, get_option_hud_show_temperature(), 0)
    descr.trParams <- "optionWidthInc:t='half';"
  },
  [USEROPT_MENU_SCREEN_SAFE_AREA] = function(_optionId, descr, _context) {
    descr.id = "menu_screen_safe_area"
    descr.items  = safeAreaMenu.items
    descr.values = safeAreaMenu.values
    descr.value  = safeAreaMenu.getValueOptionIndex()
    descr.defaultValue = safeAreaMenu.defValue
  },
  [USEROPT_HUD_SCREEN_SAFE_AREA] = function(_optionId, descr, _context) {
    descr.id = "hud_screen_safe_area"
    descr.items  = safeAreaHud.items
    descr.values = safeAreaHud.values
    descr.value  = safeAreaHud.getValueOptionIndex()
    descr.defaultValue = safeAreaHud.defValue
  },
  [USEROPT_AUTOPILOT_ON_BOMBVIEW] = function(_optionId, descr, _context) {
    descr.id = "autopilot_on_bombview"
    descr.items = ["#options/no", "#options/inmouseaim", "#options/always"]
    descr.values = [0, 1, 2]
    descr.value = get_option_autopilot_on_bombview()
    descr.trParams <- "optionWidthInc:t='half';"
  },
  [USEROPT_AUTOREARM_ON_AIRFIELD] = function(_optionId, descr, _context) {
    descr.id = "autorearm_on_airfield"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_autorearm_on_airfield()
  },
  [USEROPT_ENABLE_LASER_DESIGNATOR_ON_LAUNCH] = function(_optionId, descr, _context) {
    descr.id = "enable_laser_designatior_before_launch"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_enable_laser_designatior_before_launch()
  },
  [USEROPT_AUTO_AIMLOCK_ON_SHOOT] = function(_optionId, descr, _context) {
    descr.id = "auto_aimlock_on_shoot"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_AUTO_SEEKER_STABILIZATION] = function(_optionId, descr, _context) {
    descr.id = "auto_seeker_stabilization"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_seeker_auto_stabilization()
  },
  [USEROPT_ACTIVATE_AIRBORNE_RADAR_ON_SPAWN] = function(_optionId, descr, _context) {
    descr.id = "activate_airborne_radar_on_spawn"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_activate_airborne_radar_on_spawn()
  },
  [USEROPT_USE_RECTANGULAR_RADAR_INDICATOR] = function(_optionId, descr, _context) {
    descr.id = "use_rectangular_radar_indicator"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_use_rectangular_radar_indicator()
  },
  [USEROPT_RADAR_TARGET_CYCLING] = function(_optionId, descr, _context) {
    descr.id = "radar_target_cycling"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_radar_target_cycling()
  },
  [USEROPT_RADAR_AIM_ELEVATION_CONTROL] = function(_optionId, descr, _context) {
    descr.id = "radar_aim_elevation_control"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_radar_aim_elevation_control()
  },
  [USEROPT_RWR_SENSITIVITY] = function(_optionId, descr, _context) {
    descr.id = "rwr_sensitivity_control"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 1
    descr.max <- 100
    descr.step <- 1
    descr.value = get_option_rwr_sensitivity()
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_ACTIVATE_AIRBORNE_WEAPON_SELECTION_ON_SPAWN] = function(optionId, descr, _context) {
    descr.id = "activate_airborne_weapon_selection_on_spawn"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_gui_option(optionId)
  },
  [USEROPT_ACTIVATE_BOMBS_AUTO_RELEASE_ON_SPAWN] = function(_optionId, descr, _context) {
    descr.id = "activate_bombs_auto_release_on_spawn"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_activate_bombs_auto_release_on_spawn()
  },
  [USEROPT_AUTOMATIC_EMPTY_CONTAINERS_JETTISON] = function(optionId, descr, _context) {
    descr.id = "automatic_empty_containers_jettison"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_gui_option(optionId)
  },
  [USEROPT_RADAR_MODE_SELECT] = function(_optionId, descr, _context) {
    descr.id = "select_radar_mode"
    descr.items = get_radar_mode_names()
    descr.value = get_option_radar_name()
    descr.optionCb = "onChangeRadarMode"
  },
  [USEROPT_RADAR_SCAN_PATTERN_SELECT] = function(_optionId, descr, _context) {
    descr.id = "select_radar_scan_pattern"
    descr.items = get_radar_scan_pattern_names()
    descr.value = get_option_radar_scan_pattern_name()
    descr.optionCb = "onChangeRadarScanRange"
  },
  [USEROPT_RADAR_SCAN_RANGE_SELECT] = function(_optionId, descr, _context) {
    descr.id = "select_radar_scan_range"
    descr.items = get_radar_range_values()
    descr.value = get_option_radar_range_value()
  },
  [USEROPT_USE_RADAR_HUD_IN_COCKPIT] = function(_optionId, descr, _context) {
    descr.id = "use_radar_hud_in_cockpit"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_use_radar_hud_in_cockpit()
  },
  [USEROPT_USE_TWS_HUD_IN_COCKPIT] = function(_optionId, descr, _context) {
    descr.id = "use_tws_hud_in_cockpit"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_use_tws_hud_in_cockpit()
  },
  [USEROPT_ACTIVATE_AIRBORNE_ACTIVE_COUNTER_MEASURES_ON_SPAWN] = function(_optionId, descr, _context) {
    descr.id = "activate_airborne_active_counter_measures_on_spawn"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_activate_airborne_active_counter_measures_on_spawn()
  },
  [USEROPT_SAVE_AI_TARGET_TYPE] = function(_optionId, descr, _context) {
    descr.id = "save_ai_target_type"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_ai_target_type()
  },
  [USEROPT_DEFAULT_AI_TARGET_TYPE] = function(_optionId, descr, _context) {
    descr.id = "default_ai_target_type"
    descr.items = ["#options/ai_gunner_disabled", "#options/ai_gunner_all", "#options/ai_gunner_air", "#options/ai_gunner_ground"]
    descr.values = [0, 1, 2, 3]
    descr.value = get_option_default_ai_target_type()
  },
  [USEROPT_SHOW_INDICATORS_TYPE] = function(_optionId, descr, _context) {
    descr.id = "show_indicators_type"
    descr.items = ["#options/selected", "#options/centered", "#options/all"]
    descr.values = [0, 1, 2]
    let val = get_option_indicators_mode()
    descr.value = (val & HUD_INDICATORS_SELECT) ? 0 : ((val & HUD_INDICATORS_CENTER) ? 1 : 2)
  },
  [USEROPT_SHOW_INDICATORS_NICK] = function(_optionId, descr, _context) {
    descr.id = "show_indicators_nick"
    descr.items = ["#options/show_indicators_nick_all", "#options/show_indicators_nick_squad", "#options/show_indicators_nick_none"]
    descr.values = [HUD_INDICATORS_TEXT_NICK_ALL, HUD_INDICATORS_TEXT_NICK_SQUAD, 0]
    descr.defaultValue = HUD_INDICATORS_TEXT_NICK_ALL
    let val = get_option_indicators_mode() & (HUD_INDICATORS_TEXT_NICK_ALL | HUD_INDICATORS_TEXT_NICK_SQUAD)
    descr.value = descr.values.indexof(val)
  },
  [USEROPT_SHOW_INDICATORS_TITLE] = function(_optionId, descr, _context) {
    descr.id = "show_indicators_title"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = (get_option_indicators_mode() & HUD_INDICATORS_TEXT_TITLE) != 0
  },
  [USEROPT_SHOW_INDICATORS_AIRCRAFT] = function(_optionId, descr, _context) {
    descr.id = "show_indicators_aircraft"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = (get_option_indicators_mode() & HUD_INDICATORS_TEXT_AIRCRAFT) != 0
  },
  [USEROPT_SHOW_INDICATORS_DIST] = function(_optionId, descr, _context) {
    descr.id = "show_indicators_dist"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = (get_option_indicators_mode() & HUD_INDICATORS_TEXT_DIST) != 0
  },
  [USEROPT_HELPERS_MODE] = function(optionId, descr, _context) {
    descr.id = "helpers_mode"
    descr.items = []
    let types = ["mouse_aim", "virtual_instructor", "simplified_controls", "full_real"]
    for (local t = 0; t < types.len(); t++)
      descr.items.append({
        text = $"#options/{types[t]}"
        tooltip = $"#options/{types[t]}/tooltip"
      })
    descr.values = [
      globalEnv.EM_MOUSE_AIM,
      globalEnv.EM_INSTRUCTOR,
      globalEnv.EM_REALISTIC,
      globalEnv.EM_FULL_REAL
    ]
    descr.optionCb = "onHelpersModeChange"
    descr.defaultValue = ::g_aircraft_helpers.getOptionValue(optionId)
  },
  [USEROPT_HELPERS_MODE_GM] = function(_optionId, descr, _context) {
    descr.id = "helpers_mode"
    descr.items = []
    let types = ["mouse_aim", "virtual_instructor", "simplified_controls", "full_real"]
    for (local t = 0; t < types.len(); t++)
      descr.items.append({
        text = $"#options/{types[t]}/tank"
        tooltip = $"#options/{types[t]}/tank/tooltip"
      })
    descr.values = [
      globalEnv.EM_MOUSE_AIM,
      globalEnv.EM_INSTRUCTOR,
      globalEnv.EM_REALISTIC,
      globalEnv.EM_FULL_REAL
    ]
    descr.optionCb = "onHelpersModeChange"
    descr.defaultValue = get_option(USEROPT_HELPERS_MODE).value
  },
  [USEROPT_HUD_COLOR] = function(_optionId, descr, _context) {
    descr.id = "hud_color"
    descr.items = [
      "#hud_presets/preset1",
      "#hud_presets/preset2",
      "#hud_presets/preset10",
      "#hud_presets/preset3",
      "#hud_presets/preset4",
      "#hud_presets/preset5",
      "#hud_presets/preset6",
      "#hud_presets/preset7",
      "#hud_presets/preset9"
    ]
    descr.value = get_option_hud_color()
  },
  [USEROPT_HUD_INDICATORS] = function(_optionId, descr, _context) {
    descr.id = "hud_indicators"
    descr.items = [
      "#hud_indicators_presets/preset1",
      "#hud_indicators_presets/preset2",
    ]
    descr.value = get_option_hud_indicators?() ?? 0
  },
  [USEROPT_AI_GUNNER_TIME] = function(_optionId, descr, _context) {
    descr.id = "ai_gunner_time"
    descr.items = ["#options/disabled", "4", "8", "12", "16"]
    descr.value = get_option_ai_gunner_time()
  },
  [USEROPT_BULLETS0] = useropt_bullets0,
  [USEROPT_BULLETS1] = useropt_bullets0,
  [USEROPT_BULLETS2] = useropt_bullets0,
  [USEROPT_BULLETS3] = useropt_bullets0,
  [USEROPT_BULLETS4] = useropt_bullets0,
  [USEROPT_BULLETS5] = useropt_bullets0,
  [USEROPT_MODIFICATIONS] = function(_optionId, descr, _context) {
    let unit = getAircraftByName(::aircraft_for_weapons)
    let showFullList = unit?.isBought() || !isUnitSpecial(unit)
    descr.id = "enable_modifications"
    descr.items = showFullList
      ? ["#options/reference_aircraft", "#options/modified_aircraft"]
      : ["#options/reference_aircraft"]
    descr.values = showFullList
      ? [false, true]
      : [false]
    descr.optionCb = "onUserModificationsUpdate"
    descr.controlType = optionControlType.LIST
    descr.defaultValue = false
  },
  [USEROPT_SKIN] = function(_optionId, descr, _context) {
    descr.id = "skin"
    descr.trParams <- "optionWidthInc:t='double';"
    if (type(::aircraft_for_weapons) == "string") {
      let skins = getSkinsOption(::aircraft_for_weapons)
      descr.items = skins.items
      descr.values = skins.values
      descr.value = skins.value
      descr.access <- skins.access
    }
    else {
      descr.items = []
      descr.values = []
    }
  },
  [USEROPT_USER_SKIN] = function(_optionId, descr, _context) {
    descr.id = "user_skins"
    descr.items = [{
                     text = "#options/disabled"
                     tooltip = "#userSkin/disabled/tooltip"
                  }]
    descr.values = [""]
    descr.defaultValue = ""

    assert(::cur_aircraft_name != null, "ERROR: variable cur_aircraft_name is null")

    if (is_platform_pc && hasFeature("UserSkins") && ::cur_aircraft_name) {
      let skinsBlock = getCurUnitUserSkins()
      let cdb = get_user_skins_profile_blk()
      let setValue = cdb?[::cur_aircraft_name]

      if (skinsBlock) {
        for (local i = 0; i < skinsBlock.blockCount(); i++) {
          let table = skinsBlock.getBlock(i)
          descr.items.append({
            text = table.name
            tooltip = "".concat(loc("userSkin/custom/desc"), " \"", colorize("userlogColoredText", table.name)
              "\"\n", loc("userSkin/custom/note"))
          })

          descr.values.append(table.name)
          if (setValue != null && setValue == table.name)
            descr.value = i + 1
        }
      }
      if (descr.value == null) {
        descr.value = 0
        if (setValue)
          cdb[::cur_aircraft_name] = descr.defaultValue
      }
    }
  },
  [USEROPT_SHOW_OTHERS_DECALS] = function(_optionId, descr, _context) {
    descr.id = "show_others_decals"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
  },
  [USEROPT_CONTENT_ALLOWED_PRESET_ARCADE] = useropt_content_allowed_preset_arcade,
  [USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC] = useropt_content_allowed_preset_arcade,
  [USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR] = useropt_content_allowed_preset_arcade,
  [USEROPT_CONTENT_ALLOWED_PRESET] = useropt_content_allowed_preset_arcade,
  [USEROPT_TANK_SKIN_CONDITION] = function(_optionId, descr, _context) {
    descr.id = "skin_condition"
    descr.controlType = optionControlType.SLIDER
    descr.min <- -100
    descr.max <- 100
    descr.step <- 1
    descr.defVal <- getUserSkinCondition() ?? 0
    descr.value = get_tank_skin_condition().tointeger()
    descr.optionCb = "onChangeTankSkinCondition"
    descr.needCommonCallback = false
  },
  [USEROPT_DELAYED_DOWNLOAD_CONTENT] = function(_optionId, descr, _context) {
    descr.id = "delayed_download_content"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_delayed_download_content()
  },
  [USEROPT_REPLAY_SNAPSHOT_ENABLED] = function(optionId, descr, _context) {
    descr.id = "replay_snapshot_enabled"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_gui_option(optionId)
  },
  [USEROPT_RECORD_SNAPSHOT_PERIOD] = function(optionId, descr, _context) {
    descr.id = "record_snapshot_period"
    descr.items = ["120", "60", "30", "10"]
    descr.values = [120, 60, 30, 10]
    descr.value = u.find_in_array(descr.values, get_gui_option(optionId))
    descr.defaultValue = 60
  },
  [USEROPT_TANK_CAMO_SCALE] = function(_optionId, descr, _context) {
    descr.id = "camo_scale"
    descr.controlType = optionControlType.SLIDER
    descr.min <- (-100 * TANK_CAMO_SCALE_SLIDER_FACTOR).tointeger()
    descr.max <- (100 * TANK_CAMO_SCALE_SLIDER_FACTOR).tointeger()
    descr.step <- 1
    descr.defVal <- getUserSkinScale() ?? 0
    descr.value = (get_tank_camo_scale() * TANK_CAMO_SCALE_SLIDER_FACTOR).tointeger()
    descr.optionCb = "onChangeTankCamoScale"
    descr.needCommonCallback = false
  },
  [USEROPT_TANK_CAMO_ROTATION] = function(_optionId, descr, _context) {
    descr.id = "camo_rotation"
    descr.controlType = optionControlType.SLIDER
    descr.min <- (-100 * TANK_CAMO_ROTATION_SLIDER_FACTOR).tointeger()
    descr.max <- (100 * TANK_CAMO_ROTATION_SLIDER_FACTOR).tointeger()
    descr.step <- 1
    descr.defVal <- getUserSkinRotation() ?? 0
    descr.value = (get_tank_camo_rotation() * TANK_CAMO_ROTATION_SLIDER_FACTOR).tointeger()
    descr.optionCb = "onChangeTankCamoRotation"
    descr.needCommonCallback = false
  },
  [USEROPT_DIFFICULTY] = function(_optionId, descr, context) {
    descr.id = "difficulty"
    descr.title = loc("multiplayer/difficultyShort")
    descr.items = []
    descr.values = []
    descr.diffCode <- []
    descr.optionCb = "onDifficultyChange"

    for (local i = 0; i < g_difficulty.types.len(); i++) {
      let diff = g_difficulty.types[i]
      if (!diff.isAvailable())
        continue

      if (context?.forbiddenDifficulty.split(",").contains(diff.name))
        continue

      descr.items.append(diff.getLocName())
      descr.values.append(diff.name)
      descr.diffCode.append(diff.diffCode)
    }

    if (get_game_mode() != GM_TRAINING && context?.gm != GM_TRAINING) {
      descr.items.append("#difficulty3")
      descr.values.append("custom")
      descr.diffCode.append(DIFFICULTY_CUSTOM)
    }

    descr.defaultValue = "arcade"

    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("difficulty", null)
  },
  [USEROPT_SEARCH_DIFFICULTY] = function(_optionId, descr, _context) {
    descr.id = "difficulty"
    descr.items = []
    descr.values = []
    descr.idxValues <- []
    descr.optionCb = "onDifficultyChange"

    foreach (_idx, diff in g_difficulty.types)
      if (diff.isAvailable()) {
        descr.items.append($"#{diff.locId}")
        descr.values.append(diff.name)
        descr.idxValues.append(diff.diffCode)
      }

    if (descr.items.len() > 1) {
      descr.items.insert(0, "#options/any")
      descr.values.insert(0, "any")
      descr.idxValues.insert(0, -1)
      descr.defaultValue = "any"
    }

  },
  [USEROPT_SEARCH_GAMEMODE] = function(_optionId, descr, _context) {
    descr.id = "mp_mode"
    descr.items = [ "#options/any", "#mainmenu/btnDynamic", "#mainmenu/btnBuilder", "#mainmenu/btnCoop" ]
    descr.values = [ -1, GM_DYNAMIC, GM_BUILDER, GM_SINGLE_MISSION ]
    descr.optionCb = "onGamemodeChange"
  },
  [USEROPT_SEARCH_GAMEMODE_CUSTOM] = function(_optionId, descr, _context) {
    descr.id = "mp_mode"
    descr.items = [ "#options/any", "#multiplayer/teamBattleMode", "#multiplayer/dominationMode", "#multiplayer/tournamentMode" ]
    descr.values = [ -1, GM_TEAMBATTLE, GM_DOMINATION, GM_TOURNAMENT ]
  },
  [USEROPT_SEARCH_PLAYERMODE] = function(_optionId, descr, _context) {
    descr.id = "mp_mode"
    descr.optionCb = "onPlayerModeChange"
    descr.items = ["#options/any", "#lb/pve", "#lb/pvp"]
    descr.values = [0, 1, 2]
  },
  [USEROPT_LB_TYPE] = function(_optionId, descr, _context) {
    descr.id = "lb_type"
    descr.items = ["#lb/timePlayed", "#lb/targetsDestroyed", "#lb/missionsCompleted", "#lb/killRatio", "#lb/flawlessMissions"]
    descr.values = [0, 1, 2, 3, 4]
  },
  [USEROPT_LB_MODE] = function(_optionId, descr, _context) {
    descr.id = "lb_mode"
    descr.items = ["#lb/pve", "#lb/pvp"]
    descr.values = [false, true]
  },
  [USEROPT_NUM_FRIENDLIES] = function(_optionId, descr, _context) {
    descr.id = "num_friendlies"
    descr.items = []
    descr.values = []
    for (local i = 0; i < 16; i++) {
      descr.items.append(i.tostring())
      descr.values.append(i)
    }
  },
  [USEROPT_NUM_ENEMIES] = function(_optionId, descr, _context) {
    descr.id = "num_enemies"
    descr.items = []
    descr.values = []
    for (local i = 0; i <= 16; i++) {
      descr.items.append(i.tostring())
      descr.values.append(i)
    }
  },
  [USEROPT_TIME_LIMIT] = function(_optionId, descr, _context) {
    descr.id = "time_limit"
    descr.values = [3, 5, 10, 15, 20, 25, 30, 60, 120, 360]
    descr.items = []
    for (local i = 0; i < descr.values.len(); i++)
      descr.items.append(time.hoursToString(time.secondsToMinutes(descr.values[i]), false))
    descr.defaultValue = 10
    descr.getValueLocText = function(val) {
      if (val < 0)
        return loc("options/timeLimitAuto")
      if (val > 10000)
        return loc("options/timeUnlimited")
      let result = getTblValue(this.values.indexof(val), this.items)
      if (result != null)
        return result
      return time.hoursToString(time.secondsToMinutes(val), false)
    }
  },
  [USEROPT_KILL_LIMIT] = function(_optionId, descr, _context) {
    descr.id = "scoreLimit"
    descr.values = [3, 5, 7, 10, 20]
    descr.items = []
    for (local i = 0; i < descr.values.len(); i++)
      descr.items.append(descr.values[i].tostring())
    descr.defaultValue = descr.values[descr.values.len() / 2]
  },
  [USEROPT_MISSION_COUNTRIES_TYPE] = function(_optionId, descr, _context) {
    descr.id = "mission_countries_type"
    descr.items = ["#options/countryArcade", "#options/countryReal", "#options/countrySymmetric", "#options/countryCustom"]
    descr.values = [misCountries.ALL, misCountries.BY_MISSION, misCountries.SYMMETRIC, misCountries.CUSTOM]
    descr.defaultValue = misCountries.ALL
    descr.optionCb = "onMissionCountriesType"

    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getPublicParam("countriesType", null)
  },
  [USEROPT_BIT_COUNTRIES_TEAM_A] = useropt_bit_countries_team_a,
  [USEROPT_BIT_COUNTRIES_TEAM_B] = useropt_bit_countries_team_a,
  [USEROPT_COUNTRIES_SET] = function(optionId, descr, context) {
    descr.id = "countries_set"
    descr.items = []
    descr.values = []
    descr.optionCb = "onInstantOptionApply"
    descr.trParams <- "iconType:t='small'; optionWidthInc:t='double';"

    foreach (idx, countriesSet in (context?.countriesSetList ?? [])) {
      descr.items.append({
        text = loc("country/VS")
        images = countriesSet.countries[0].map(@(c) { image = getCountryIcon(c) })
        imagesAfterText = countriesSet.countries[1].map(@(c) { image = getCountryIcon(c) })
        textStyle = "margin:t='3@blockInterval, 0';"
      })
      descr.values.append(idx)
    }

    descr.prevValue = get_gui_option(optionId)
    descr.defaultValue = 0
    descr.value = (descr.prevValue in descr.values) ? descr.prevValue : descr.defaultValue

  },
  [USEROPT_USE_KILLSTREAKS] = function(_optionId, descr, _context) {
    descr.id = "use_killstreaks"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onUseKillStreaks"
    descr.defaultValue = false
  },
  [USEROPT_BIT_UNIT_TYPES] = function(optionId, descr, context) {
    descr.id = "allowed_unit_types"
    descr.title = loc("events/allowed_crafts_no_colon")
    descr.controlType = optionControlType.BIT_LIST
    descr.controlName <- "multiselect"
    descr.showTitle <- true
    descr.optionCb = "onInstantOptionApply"
    descr.items = []
    descr.values = []
    descr.hint = descr.title

    descr.defaultValue = unitTypes.types.reduce(@(res, v) res | v.bit, 0)
    descr.prevValue = get_gui_option(optionId) ?? descr.defaultValue

    let missionBlk = getUrlOrFileMissionMetaInfo(context?.missionName ?? "")
    let isKillStreaksOptionAvailable = missionBlk && ::is_skirmish_with_killstreaks(missionBlk)
    let useKillStreaks = isKillStreaksOptionAvailable
      && (get_gui_option(USEROPT_USE_KILLSTREAKS) ?? false)
    let availableUnitTypesMask = ::get_mission_allowed_unittypes_mask(missionBlk, useKillStreaks)

    descr.availableUnitTypesMask <- availableUnitTypesMask

    foreach (unitType in unitTypes.types) {
      if (unitType == unitTypes.INVALID || !unitType.isPresentOnMatching)
        continue
      let isVisible = !!(availableUnitTypesMask & unitType.bit)
      let armyLocName = (unitType == unitTypes.SHIP) ? loc("mainmenu/fleet") : unitType.getArmyLocName()
      descr.values.append(unitType.esUnitType)
      descr.items.append({
        id =$"bit_{unitType.tag}"
        text = $"{unitType.fontIcon} {armyLocName}"
        enabled = isVisible
        isVisible = isVisible
      })
    }

    if (isKillStreaksOptionAvailable) {
      let killStreaksOptionLocName = loc("options/use_killstreaks")
      descr.textAfter <- colorize("fadedTextColor",$"+ {killStreaksOptionLocName}")
      descr.hint = "\n".concat(descr.hint, loc("options/advice/disable_option_to_have_more_choices",
        { name = colorize("userlogColoredText", killStreaksOptionLocName) }))
    }
  },
  [USEROPT_BR_MIN] = useropt_br_min,
  [USEROPT_BR_MAX] = useropt_br_min,
  [USEROPT_RACE_LAPS] = function(_optionId, descr, _context) {
    descr.id = "race_laps"
    descr.values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    descr.defaultValue = 1
    descr.items = []
    for (local i = 0; i < descr.values.len(); i++)
      descr.items.append(descr.values[i].tostring())
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("raceLaps", null)
  },
  [USEROPT_RACE_WINNERS] = function(_optionId, descr, _context) {
    descr.id = "race_winners"
    descr.values = [1, 2, 3]
    descr.defaultValue = 1
    descr.items = []
    for (local i = 0; i < descr.values.len(); i++)
      descr.items.append(descr.values[i].tostring())
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("raceWinners", null)
  },
  [USEROPT_RACE_CAN_SHOOT] = function(_optionId, descr, _context) {
    descr.id = "race_can_shoot"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    if (isInSessionRoom.get()) {
      let cannotShoot = ::SessionLobby.getMissionParam("raceForceCannotShoot", null)
      if (cannotShoot != null)
        descr.prevValue = !cannotShoot
    }
  },
  [USEROPT_RANK] = function(_optionId, descr, context) {
    descr.id = "rank"
    descr.title = loc("shop/age")
    descr.controlName <- "combobox"
    descr.optionCb = "onInstantOptionApply"

    descr.items = []
    descr.values = []
    if (getTblValue("isEventRoom", context, false)) {
      descr.title = loc("guiHints/chooseUnitsMMRank")
      let brRanges = getTblValue("brRanges", context, [])
      for (local i = 0; i < brRanges.len(); i++) {
        let range = brRanges[i]
        let minBR = calcBattleRatingFromRank(getTblValue(0, range, 0))
        let maxBR = calcBattleRatingFromRank(getTblValue(1, range, MAX_COUNTRY_RANK))
        let tier = events.getTierByMaxBr(maxBR)
        let brText = "".concat(format("%.1f", minBR),
          (minBR != maxBR) ? "".concat(" - ", format("%.1f", maxBR)) : "")
        let text = brText
        descr.values.append(tier)
        descr.items.append(text)
      }
    }

    if (!descr.values.len())
      for (local i = 1; i <= MAX_COUNTRY_RANK; i++) {
        descr.items.append(loc("shop/age/num", { num = get_roman_numeral(i) }))
        descr.values.append(i)
      }
  },
  [USEROPT_BIT_CHOOSE_UNITS_TYPE] = function(_optionId, descr, _context) {
    descr.id = "chooseUnitsType"
    descr.controlType = optionControlType.BIT_LIST
    descr.items = []
    descr.values = []
    for (local i = 0; i < unitTypes.types.len(); i++) {
      let unitType = unitTypes.types[i]
      if (!unitType.isAvailable())
        continue
      descr.items.append(unitType.getArmyLocName())
      descr.values.append(unitType.esUnitType)
    }
  },
  [USEROPT_BIT_CHOOSE_UNITS_RANK] = function(_optionId, descr, _context) {
    descr.id = "chooseUnitsRank"
    descr.controlType = optionControlType.BIT_LIST
    descr.items = []
    descr.values = []
    for (local i = 1; i <= MAX_COUNTRY_RANK; i++) {
      descr.items.append(get_roman_numeral(i))
      descr.values.append(i)
    }
  },
  [USEROPT_BIT_CHOOSE_UNITS_OTHER] = function(_optionId, descr, _context) {
    descr.id = "chooseUnitsOther"
    descr.items = ["#options/chooseUnitsOther/studied", "#options/chooseUnitsOther/unstudied"]
    descr.values = []
    descr.controlType = optionControlType.BIT_LIST
  },
  [USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE] = function(_optionId, descr, _context) {
    descr.id = "chooseUnitsShowUnsupported"
    descr.items = ["#options/chooseUnitsShowUnsupported/show_unsupported",
                   "#options/chooseUnitsShowUnsupported/show_supported"
                  ]
    descr.defaultValue = 3
    descr.singleOption <- true
    descr.hideTitle <- true
    descr.controlType = optionControlType.BIT_LIST
    descr.optionCb = "onSelectedOptionChooseUnsapportedUnit"
  },
  [USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST] = function(_optionId, descr, _context) {
    descr.id = "chooseUnitsNotInCustomList"
    descr.items = ["#options/chooseUnitsNotInCustomList/show_unsupported",
                   "#options/chooseUnitsNotInCustomList/show_supported"
                  ]
    descr.defaultValue = 3
    descr.singleOption <- true
    descr.hideTitle <- true
    descr.controlType = optionControlType.BIT_LIST
  },
  [USEROPT_TIME_BETWEEN_RESPAWNS] = function(_optionId, descr, _context) {
    descr.id = "timeBetweenRespawns"
    descr.items = ["30", "40", "50", "60", "120", "180"]
    descr.values = [30, 40, 50, 60, 120, 180]
  },
  [USEROPT_YEAR] = function(_optionId, descr, _context) {
    descr.id = "year"
    //filled by onLayoutChange()
    descr.trParams <- "optionWidthInc:t='double';"
    let isKoreanWarDC = get_game_mode() == GM_DYNAMIC && ::current_campaign?.id == "korea_dynamic"
    let yearsArray = !isKoreanWarDC
      ? [ 1940, 1941, 1942, 1943, 1944, 1945 ]
      : [ 1950, 1951, 1952, 1953 ]
    descr.valuesInt <- yearsArray
    descr.items <- yearsArray.map(@(yyyy) yyyy.tostring())
    descr.values = yearsArray.map(@(yyyy) $"year{yyyy}")
    if (get_game_mode() == GM_DYNAMIC && ::current_campaign) {
      let teamOption = get_option(USEROPT_MP_TEAM_COUNTRY)
      let teamIdx = max(teamOption.values[teamOption.value] - 1, 0)
      descr.items = []
      for (local i = 0; i < descr.values.len(); i++) {
        local enabled = true
        local tooltip = ""
        let yearId = $"country_{::current_campaign.countries[teamIdx]}_{descr.values[i]}"
        let blk = getUnlockById(yearId)
        if (blk) {
          enabled = isUnlockOpened(yearId, UNLOCKABLE_YEAR)
          tooltip = enabled ? "" : getFullUnlockDesc(::build_conditions_config(blk))
        }
        descr.items.append({
          text = yearsArray[i].tostring()
          enabled = enabled
          tooltip = tooltip
        })
      }
    }
    descr.defaultValue = descr.values[0]
    descr.prevValue = get_gui_option(USEROPT_YEAR)
    descr.value = u.find_in_array(descr.values, descr.prevValue, 0)
    descr.optionCb = "onYearChange"
  },
  [USEROPT_TIME_SPAWN] = function(_optionId, descr, _context) {
    descr.id = "spawnTime"
    descr.items = ["5", "10", "15"]
    descr.values = [5.0, 10.0, 15.0]
  },
  [USEROPT_MP_TEAM] = function(_optionId, descr, _context) {
    descr.id = "mp_team"
    descr.items = ["#multiplayer/teamA", "#multiplayer/teamB"]
    descr.values = [1, 2]
    descr.optionCb = "onLayoutChange"
  },
  [USEROPT_MP_TEAM_COUNTRY_RAND] = useropt_mp_team_country_rand,
  [USEROPT_MP_TEAM_COUNTRY] = useropt_mp_team_country_rand,
  [USEROPT_DMP_MAP] = function(_optionId, descr, _context) {
    descr.id = "dyn_mp_map"
    let modeNo = get_game_mode()
    descr.values = []
    descr.items = []
    let gameModeMaps = getGameModeMaps()
    if (modeNo >= 0 && modeNo < gameModeMaps.len()) {
      for (local i = 0; i < gameModeMaps[modeNo].items.len(); i++) {
        if ((modeNo == GM_SINGLE_MISSION) || (modeNo == GM_EVENT))
          if (!gameModeMaps[modeNo].coop[i])
            continue;

        descr.items.append(gameModeMaps[modeNo].items[i])
        descr.values.append(gameModeMaps[modeNo].values[i])
      }
    }
    descr.optionCb = "onMissionChange"
  },
  [USEROPT_DYN_MAP] = function(_optionId, descr, _context) {
    descr.id = "dyn_map"
    descr.values = []
    descr.items = []
    descr.optionCb = "onLayoutChange"
    fillDynMapOption(descr)
  },
  [USEROPT_DYN_ZONE] = function(_optionId, descr, _context) {
    descr.id = "dyn_zone"
    descr.values = []
    descr.items = []
    descr.optionCb = "onSectorChange"
    let dynamic_zones = dynamicGetZones()
    for (local i = 0; i < dynamic_zones.len(); i++) {
      descr.items.append($"{::mission_settings.layoutName}/{dynamic_zones[i]}")
      descr.values.append(dynamic_zones[i])
    }
  },
  [USEROPT_DYN_ALLIES] = function(_optionId, descr, _context) {
    descr.id = "dyn_allies"
    descr.items = ["#options/dyncount/few", "#options/dyncount/normal", "#options/dyncount/many"]
    descr.values = [1, 2, 3]
    descr.defaultValue = 2
  },
  [USEROPT_DYN_ENEMIES] = function(_optionId, descr, _context) {
    descr.id = "dyn_enemies"
    descr.items = ["#options/dyncount/few", "#options/dyncount/normal", "#options/dyncount/many"]
    descr.values = [1, 2, 3]
    descr.defaultValue = 2
  },
  [USEROPT_DYN_FL_ADVANTAGE] = function(_optionId, descr, _context) {
    descr.id = "dyn_fl_advantage"
    descr.items = ["#options/dyn_fl_enemy", "#options/dyn_fl_equal", "#options/dyn_fl_ally"]
    descr.values = [0, 1, 2]
    descr.defaultValue = 1
  },
  [USEROPT_DYN_SURROUND] = function(_optionId, descr, _context) {
    descr.id = "dyn_surround"
    descr.items = ["#options/dyncount/front_enemy", "#options/dyncount/front_ally",
                   "#options/dyncount/ally_around_ally", "#options/dyncount/ally_around_enemy",
                   "#options/dyncount/enemy_around_ally", "#options/dyncount/enemy_around_enemy", ]
    descr.values = [0, 1, 2, 3, 4, 5]
    descr.optionCb = "onSectorChange"
  },
  [USEROPT_DYN_WINS_TO_COMPLETE] = function(_optionId, descr, _context) {
    descr.id = "wins_to_complete"
    descr.items = ["#options/dyncount/capture_all_sectors",
                     "#options/dyncount/need_3_wins",   //temporary disabled 3 wins for anniversary event
                   "#options/dyncount/need_5_wins", ]
    descr.values = [-1,
      // 3,
      5] //temporary disabled 3 wins for anniversary event
    descr.defaultValue = -1
  },
  [USEROPT_OPTIONAL_TAKEOFF] = function(_optionId, descr, _context) {
    descr.id = "optional_takeoff"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("optionalTakeOff", null)
  },
  [USEROPT_LOAD_FUEL_AMOUNT] = function(_optionId, descr, _context) {
    descr.id = "fuel_amount"
    descr.items = []
    descr.values = []
    descr.value = null
    descr.defaultValue = -1
    descr.optionCb = "onLoadFuelChange"

    let { maxFuel, fuelConsumptionPerHour } = getFuelParams(::cur_aircraft_name)
    local minutes = [0, 20.0, 30.0, 45.0, 60.0, 1000000.0]
    local isFuelFixed = false
    if (::cur_aircraft_name) {
      descr.prevValue = get_unit_option(::cur_aircraft_name, USEROPT_LOAD_FUEL_AMOUNT)
      if (fuelConsumptionPerHour > 0 && isInFlight()) {
        let fixedPercent = getCurMissionRules().getUnitFuelPercent(::cur_aircraft_name)
        if (fixedPercent > 0) {
          isFuelFixed = true
          minutes = [fixedPercent * maxFuel / time.minutesToSeconds(fuelConsumptionPerHour)]
          let value = (fixedPercent * 1000000 + 0.5).tointeger()
          if (value != descr.prevValue) {
            descr.prevValue = value
            set_gui_option(USEROPT_LOAD_FUEL_AMOUNT, value)
          }
        }
      }
    }

    if (!is_numeric(descr.prevValue)) {
      descr.prevValue = get_gui_option(USEROPT_LOAD_FUEL_AMOUNT)
      if (!is_numeric(descr.prevValue))
        descr.prevValue = -1
    }

    let minFuelPercent = 0.3
    local foundMax = false

    for (local ind = 0; ind < minutes.len(); ind++) {
      let m = minutes[ind]
      local timeInHours = time.secondsToMinutes(m)
      let fuelReq = fuelConsumptionPerHour * timeInHours
      local percent = maxFuel > 0.0 ? fuelReq / maxFuel : 0.0
      local text = ""
      if (percent <= minFuelPercent) { //minFuel
        if (!isFuelFixed) { //we allow to custom rules set fuel below max, but show it as min_tank
          if (descr.values.len() > 0 || m) //only 0 show as minFuelPercent
            continue
          percent = minFuelPercent
          timeInHours = fuelConsumptionPerHour > 0.0 ? maxFuel * percent / fuelConsumptionPerHour : 0.0
        }
        text = loc("options/min_tank")
      }
      else if (fuelReq > maxFuel * 0.95) { //maxFuel
        if (!isFuelFixed) {
          percent = 1.0
          timeInHours = fuelConsumptionPerHour > 0.0 ? maxFuel * percent / fuelConsumptionPerHour : 0.0
        }
        text = loc("options/full_tank")
        foundMax = true
      }

      let timeStr = time.hoursToString(timeInHours)
      if (text.len())
        text = "".concat(text, loc("ui/parentheses/space", { text = timeStr }))
      else
        text = timeStr
      descr.items.append(text)
      let value = (percent * 1000000 + 0.5).tointeger()
      descr.values.append(value)
      if (descr.value == null || value <= descr.prevValue)
        descr.value = descr.values.len() - 1

      if (foundMax)
        break
    }

    descr.items.append(loc("options/customizable_quantity"))
    let custom_amount = get_unit_option(::aircraft_for_weapons, USEROPT_FUEL_AMOUNT_CUSTOM)
    descr.values.append(custom_amount ?? (minFuelPercent * 1000000).tointeger())
    descr.value = descr.values.findindex(@(v) v == descr.prevValue) ?? descr.value
  },
  [USEROPT_FUEL_AMOUNT_CUSTOM] = function(_optionId, descr, _context) {
    descr.id = "adjustable_fuel_quantity"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 30 * 10000
    descr.max <- 100 * 10000
    descr.step <- 1 * 10000
    descr.defValue <- 50 * 10000
    descr.optionCb = "onLoadFuelCustomChange"
    descr.value = get_unit_option(::aircraft_for_weapons, USEROPT_FUEL_AMOUNT_CUSTOM)
    let { maxFuel, fuelConsumptionPerHour } = getFuelParams(::cur_aircraft_name)

    descr.getValueLocText = function(val) {
      let timeInHours = fuelConsumptionPerHour > 0.0 ? maxFuel * (val / 1000000.0) / fuelConsumptionPerHour : 0.0
      let timeStr = time.hoursToString(timeInHours)
      return $"{val / 10000}% ({timeStr})"
    }
  },
  [USEROPT_NUM_ATTEMPTS] = function(_optionId, descr, _context) {
    descr.id = "attempts"
    descr.items = [
      "#options/attemptsNone",
      "#options/attempts1",
      "#options/attempts2",
      "#options/attempts3",
      "#options/attempts4",
      "#options/attempts5",
      "#options/attemptsUnlimited"
      ]
    descr.values = [0, 1, 2, 3, 4, 5, -1]
    descr.defaultValue = -1
  },
  [USEROPT_TICKETS] = function(_optionId, descr, _context) {
    descr.id = "tickets"
    descr.items = ["300", "500", "700", "900", "1200"]
    descr.values = [300, 500, 700, 900, 1200]
    descr.defaultValue = 500
  },
  [USEROPT_LIMITED_FUEL] = function(_optionId, descr, _context) {
    descr.id = "limitedFuel"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("isLimitedFuel", false)
  },
  [USEROPT_LIMITED_AMMO] = function(_optionId, descr, _context) {
    descr.id = "limitedAmmo"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    if (isInSessionRoom.get())
      descr.prevValue = ::SessionLobby.getMissionParam("isLimitedAmmo", false)
  },
  [USEROPT_MISSION_NAME_POSTFIX] = function(_optionId, descr, _context) {
    descr.id = "mission_name_postfix"
    descr.items = []
    descr.values = []
    local index = 0
    let currentCampaignMission = getCurrentCampaignMission()
    if (currentCampaignMission != null) {
      let metaInfo = getUrlOrFileMissionMetaInfo(currentCampaignMission)
      let values = ::get_mission_types_from_meta_mission_info(metaInfo)
      for (index = 0; index < values.len(); index++) {
        descr.items.append($"#options/{values[index]}")
        descr.values.append(values[index])
      }
    }
    descr.items.append("#options/random")
    descr.values.append("")
  },
  [USEROPT_FRIENDLY_SKILL] = useropt_friendly_skill,
  [USEROPT_ENEMY_SKILL] = useropt_friendly_skill,
  [USEROPT_COUNTRY] = function(_optionId, descr, _context) {
    descr.id = "profileCountry"
    descr.items = []
    descr.values = []
    descr.trParams <- "iconType:t='country';"
    descr.trListParams <- "iconType:t='listbox_country';"
    descr.listClass <- "countries"

    let start = 0 //skip country_0
    let isDominationMode = getGuiOptionsMode() == OPTIONS_MODE_MP_DOMINATION
    let dMode = getCurrentGameMode()
    let event = isDominationMode && dMode && dMode.getEvent()

    for (local nc = start; nc < shopCountriesList.len(); nc++) {
      if (::mission_settings.battleMode == BATTLE_TYPES.TANK && nc < 0)
        continue

      let country = (nc < 0) ? "country_0" : shopCountriesList[nc]
      let enabled = (country == "country_0" || isCountryAvailable(country))
                      && (!event || events.isCountryAvailable(event, country))
      descr.items.append({
        text = $"#{country}"
        image = getCountryIcon(country, true, !enabled)
        enabled = enabled
      })
      descr.values.append(country)
    }
    descr.value = 0
    let c = profileCountrySq.value
    for (local nc = 0; nc < descr.values.len(); nc++)
      if (c == descr.values[nc]) {
        descr.value = nc
      }
    descr.optionCb = "onProfileChange"
  },
  [USEROPT_CLUSTERS] = useropt_clusters,
  [USEROPT_RANDB_CLUSTERS] = useropt_clusters,
  [USEROPT_PLAY_INACTIVE_WINDOW_SOUND] = function(optionId, descr, _context) {
    descr.id = "playInactiveWindowSound"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_gui_option(optionId)
  },
  [USEROPT_PILOT] = function(_optionId, descr, _context) {
    descr.id = "profilePilot"
    descr.items = []
    descr.values = []
    descr.trParams <- "iconType:t='pilot';"
    let curPilotImgId = get_cur_rank_info().pilotId
    let icons = avatars.getIcons()
    let marketplaceItemdefIds = []
    for (local nc = 0; nc < icons.len(); nc++) {
      let unlockId = icons[nc]
      let unlockItem = getUnlockById(unlockId)
      let isShown = isUnlockOpened(unlockId, UNLOCKABLE_PILOT) || isUnlockVisible(unlockItem)
        || (unlockItem?.hideFeature != null && !hasFeature(unlockItem.hideFeature))
      let marketplaceItemdefId = unlockItem?.marketplaceItemdefId
      if (marketplaceItemdefId != null)
        marketplaceItemdefIds.append(marketplaceItemdefId)
      let item = {
        idx = nc
        unlockId
        image = $"#ui/images/avatars/{unlockId}"
        show = isShown
        enabled = isUnlockOpened(unlockId, UNLOCKABLE_PILOT)
        tooltipId = getTooltipType("UNLOCK").getTooltipId(unlockId, { showProgress = true })
        marketplaceItemdefId
      }
      if (item.show && item.enabled) {
        item.seenListId <- SEEN.AVATARS
        item.seenEntity <- unlockId
      }
      descr.items.append(item)
      descr.values.append(nc)
      if (curPilotImgId == nc)
        descr.value = descr.values.len() - 1
    }
    if (marketplaceItemdefIds.len() > 0)
      inventoryClient.requestItemdefsByIds(marketplaceItemdefIds)
    descr.optionCb = "onProfileChange"
  },
  [USEROPT_CROSSHAIR_TYPE] = function(_optionId, descr, _context) {
    descr.id = "crosshairType"
    descr.items = []
    descr.values = []
    descr.trParams <- "iconType:t='crosshair';"
    let c = get_hud_crosshair_type()
    for (local nc = 0; nc < ::crosshair_icons.len(); nc++) {
      descr.items.append({
        image = $"#ui/gameuiskin#{::crosshair_icons[nc]}"
      })
      descr.values.append(nc)
      if (c == nc)
        descr.value = descr.values.len() - 1
    }
  },
  [USEROPT_CROSSHAIR_COLOR] = function(_optionId, descr, _context) {
    descr.id = "crosshairColor"
    descr.items = []
    descr.values = []
    let c = get_hud_crosshair_color()
    for (local nc = 0; nc < crosshair_colors.len(); nc++) {
      descr.values.append(nc)
      let config = crosshair_colors[nc]
      let item = { text = $"#crosshairColor/{config.name}" }
      if (config.color)
        item.hueColor <- color4ToDaguiString(config.color)
      descr.items.append(item)
      if (c == nc)
        descr.value = descr.values.len() - 1
    }
  },
  [USEROPT_CD_ENGINE] = function(_optionId, descr, _context) {
    descr.id = "engineControl"
    descr.items = []
    descr.values = []

    foreach (_idx, diff in g_difficulty.types)
      if (diff.isAvailable()) {
        descr.items.append($"#{diff.locId}")
        descr.values.append(diff.diffCode)
      }

    descr.optionCb = "onCDChange"
    descr.value = getCdOption(USEROPT_CD_ENGINE)
  },
  [USEROPT_CD_GUNNERY] = function(_optionId, descr, _context) {
    descr.id = "realGunnery"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_GUNNERY)
  },
  [USEROPT_CD_DAMAGE] = function(_optionId, descr, _context) {
    descr.id = "realDamageModels"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_DAMAGE)
  },
  [USEROPT_CD_FLUTTER] = function(_optionId, descr, _context) {
    descr.id = "flutter"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_FLUTTER)
  },
  [USEROPT_CD_STALLS] = function(_optionId, descr, _context) {
    descr.id = "stallsAndSpins"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_STALLS)
  },
  [USEROPT_CD_REDOUT] = function(_optionId, descr, _context) {
    descr.id = "redOuts"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_REDOUT)
  },
  [USEROPT_CD_MORTALPILOT] = function(_optionId, descr, _context) {
    descr.id = "mortalPilots"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_MORTALPILOT)
  },
  [USEROPT_CD_BOMBS] = function(_optionId, descr, _context) {
    descr.id = "limitedArmament"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_BOMBS)
  },
  [USEROPT_CD_BOOST] = function(_optionId, descr, _context) {
    descr.id = "noArcadeBoost"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_BOOST)
  },
  [USEROPT_CD_TPS] = function(_optionId, descr, _context) {
    descr.id = "disableTpsViews"
    descr.items = ["#options/limitViewTps", "#options/limitViewFps", "#options/limitViewCockpit"]
    descr.values = [0, 1, 2]
    descr.optionCb = "onCDChange"
    descr.value = getCdOption(USEROPT_CD_TPS)
  },
  [USEROPT_CD_AIM_PRED] = function(_optionId, descr, _context) {
    descr.id = "hudAimPrediction"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_AIM_PRED)
  },
  [USEROPT_CD_MARKERS] = function(_optionId, descr, _context) {
    let teamAirSb = "".concat(loc("options/ally"), loc("ui/parentheses/space", { text = loc("missions/air_event_simulator") }))
    descr.id = "hudMarkers"
    descr.items = ["#options/no", "#options/ally", "#options/all", teamAirSb]
    descr.values = [0, 1, 2, 3]
    descr.optionCb = "onCDChange"
    descr.value = getCdOption(USEROPT_CD_MARKERS)
  },
  [USEROPT_CD_ARROWS] = function(_optionId, descr, _context) {
    descr.id = "hudMarkerArrows"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_ARROWS)
  },
  [USEROPT_CD_AIRCRAFT_MARKERS_MAX_DIST] = function(_optionId, descr, _context) {
    descr.id = "hudAircraftMarkersMaxDist"
    descr.items = ["#options/near", "#options/normal", "#options/far", "#options/quality_max"]
    descr.values = [0, 1, 2, 3]
    descr.optionCb = "onCDChange"
    descr.value = getCdOption(USEROPT_CD_AIRCRAFT_MARKERS_MAX_DIST)
  },
  [USEROPT_CD_INDICATORS] = function(_optionId, descr, _context) {
    descr.id = "hudIndicators"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_INDICATORS)
  },
  [USEROPT_CD_SPEED_VECTOR] = function(_optionId, descr, _context) {
    descr.id = "hudShowSpeedVector"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_SPEED_VECTOR)
  },
  [USEROPT_CD_TANK_DISTANCE] = function(_optionId, descr, _context) {
    descr.id = "hudShowTankDistance"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_TANK_DISTANCE)
  },
  [USEROPT_CD_MAP_AIRCRAFT_MARKERS] = function(_optionId, descr, _context) {
    descr.id = "hudMapAircraftMarkers"
    descr.items = ["#options/no", "#options/ally", "#options/all", "#options/player"]
    descr.values = [0, 1, 2, 3]
    descr.optionCb = "onCDChange"
    descr.value = getCdOption(USEROPT_CD_MAP_AIRCRAFT_MARKERS)
  },
  [USEROPT_CD_MAP_GROUND_MARKERS] = function(_optionId, descr, _context) {
    descr.id = "hudMapGroundMarkers"
    descr.items = ["#options/no", "#options/ally", "#options/all"]
    descr.values = [0, 1, 2]
    descr.optionCb = "onCDChange"
    descr.value = getCdOption(USEROPT_CD_MAP_GROUND_MARKERS)
  },
  [USEROPT_CD_MARKERS_BLINK] = function(_optionId, descr, _context) {
    descr.id = "hudMarkersBlink"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_MARKERS_BLINK)
  },
  [USEROPT_CD_RADAR] = function(_optionId, descr, _context) {
    descr.id = "hudRadar"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_RADAR)
  },
  [USEROPT_CD_DAMAGE_IND] = function(_optionId, descr, _context) {
    descr.id = "hudDamageIndicator"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_DAMAGE_IND)
  },
  [USEROPT_CD_LARGE_AWARD_MESSAGES] = function(_optionId, descr, _context) {
    descr.id = "hudLargeAwardMessages"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_LARGE_AWARD_MESSAGES)
  },
  [USEROPT_CD_WARNINGS] = function(_optionId, descr, _context) {
    descr.id = "hudWarnings"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_WARNINGS)
  },
  [USEROPT_CD_AIR_HELPERS] = function(_optionId, descr, _context) {
    descr.id = "aircraftHelpers"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_AIR_HELPERS)
  },
  [USEROPT_CD_COLLECTIVE_DETECTION] = function(_optionId, descr, _context) {
    descr.id = "collectiveDetection"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_COLLECTIVE_DETECTION)
  },
  [USEROPT_CD_DISTANCE_DETECTION] = function(_optionId, descr, _context) {
    descr.id = "distanceDetection"
    descr.items = ["#options/near", "#options/normal", "#options/far"]
    descr.values = [0, 1, 2]
    descr.optionCb = "onCDChange"
    descr.value = getCdOption(USEROPT_CD_DISTANCE_DETECTION)
  },
  [USEROPT_CD_ALLOW_CONTROL_HELPERS] = function(_optionId, descr, _context) {
    descr.id = "allowControlHelpers"
    descr.items = ["#options/allHelpers", "#options/Instructor", "#options/Realistic", "#options/no"]
    descr.values = [0, 1, 2, 3]
    descr.optionCb = "onCDChange"
    descr.value = getCdOption(USEROPT_CD_ALLOW_CONTROL_HELPERS)
  },
  [USEROPT_CD_FORCE_INSTRUCTOR] = function(_optionId, descr, _context) {
    descr.id = "forceInstructor"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onCDChange"
    descr.value = !!getCdOption(USEROPT_CD_FORCE_INSTRUCTOR)
  },
  [USEROPT_INTERNET_RADIO_ACTIVE] = function(_optionId, descr, _context) {
    descr.id = "internet_radio_active"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_internet_radio_options()?.active ?? false
    descr.optionCb = "update_internet_radio"
  },
  [USEROPT_INTERNET_RADIO_STATION] = function(_optionId, descr, _context) {
    descr.id = "internet_radio_station"
    descr.items = []
    descr.values = get_internet_radio_stations()
    for (local i = 0; i < descr.values.len(); i++) {
      let str = $"InternetRadio/{descr.values[i]}"
      let url_radio = get_internet_radio_path(descr.values[i])
      if (loc(str, "") == "")
        descr.items.append({
          text = descr.values[i],
          tooltip = url_radio
        })
      else
        descr.items.append({
          text = $"#{str}",
          tooltip = url_radio
        })
    }
    if (!descr.values.len()) {
      descr.values.append("")
      descr.items.append("#options/no_internet_radio_stations")
    }
    descr.value = u.find_in_array(descr.values, get_internet_radio_options()?.station ?? "", 0)
    descr.optionCb = "update_internet_radio"
  },
  [USEROPT_HEADTRACK_ENABLE] = function(_optionId, descr, _context) {
    descr.id = "headtrack_enable"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = ps4_headtrack_get_enable()
    descr.optionCb = "onHeadtrackEnableChange"
  },
  [USEROPT_HEADTRACK_SCALE_X] = function(_optionId, descr, _context) {
    descr.id = "headtrack_scale_x"
    descr.controlType = optionControlType.SLIDER
    descr.value = clamp(ps4_headtrack_get_xscale(), 5, 200)
    descr.min <- 5
    descr.max <- 200
  },
  [USEROPT_HEADTRACK_SCALE_Y] = function(_optionId, descr, _context) {
    descr.id = "headtrack_scale_y"
    descr.controlType = optionControlType.SLIDER
    descr.value = clamp(ps4_headtrack_get_yscale(), 5, 200)
    descr.min <- 5
    descr.max <- 200
  },
  [USEROPT_HUE_ALLY] = function(_optionId, descr, _context) {
    fillHueOption(descr, "color_picker_hue_ally", get_hue(TARGET_HUE_ALLY), 226)
  },
  [USEROPT_HUE_ENEMY] = function(_optionId, descr, _context) {
    fillHueOption(descr, "color_picker_hue_enemy", get_hue(TARGET_HUE_ENEMY), 3)
  },
  [USEROPT_STROBE_ALLY] = function(_optionId, descr, _context) {
    descr.id = "strobe_ally"
    descr.items = ["#options/no", "#options/one_smooth_flash", "#options/two_smooth_flashes", "#options/two_sharp_flashes"]
    descr.values = [0, 1, 2, 3]
    descr.value = get_strobe_ally()
  },
  [USEROPT_STROBE_ENEMY] = function(_optionId, descr, _context) {
    descr.id = "strobe_enemy"
    descr.items = ["#options/no", "#options/one_smooth_flash", "#options/two_smooth_flashes", "#options/two_sharp_flashes"]
    descr.values = [0, 1, 2, 3]
    descr.value = get_strobe_enemy()
  },
  [USEROPT_HUE_SQUAD] = function(_optionId, descr, _context) {
    fillHueOption(descr, "color_picker_hue_squad", get_hue(TARGET_HUE_SQUAD), 472)
  },
  [USEROPT_HUE_SPECTATOR_ALLY] = function(_optionId, descr, _context) {
    fillHueOption(descr, "color_picker_hue_spectator_ally", get_hue(TARGET_HUE_SPECTATOR_ALLY), 112)
  },
  [USEROPT_HUE_SPECTATOR_ENEMY] = function(_optionId, descr, _context) {
    fillHueOption(descr, "color_picker_hue_spectator_enemy", get_hue(TARGET_HUE_SPECTATOR_ENEMY), 292)
  },
  [USEROPT_HUE_RELOAD] = function(_optionId, descr, _context) {
    fillHueOption(descr, "color_picker_hue_reload", get_hue(TARGET_HUE_RELOAD), 3)
  },
  [USEROPT_HUE_RELOAD_DONE] = function(_optionId, descr, _context) {
    fillHueOption(descr, "color_picker_hue_reload_done", get_hue(TARGET_HUE_RELOAD_DONE), 472)
  },
  [USEROPT_AIR_DAMAGE_DISPLAY] = function(_optionId, descr, _context) {
    descr.id = "air_damage_display"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_GUNNER_FPS_CAMERA] = function(_optionId, descr, _context) {
    descr.id = "gunner_fps_camera"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
  },
  [USEROPT_HUE_AIRCRAFT_PARAM_HUD] = function(_optionId, descr, _context) {
    fillHueSaturationBrightnessOption(descr, "color_picker_hue_aircraft_param_hud",
      10, 0.0, 0.9, get_hue(TARGET_HUE_AIRCRAFT_PARAM_HUD))
  },
  [USEROPT_HUE_AIRCRAFT_HUD_ALERT] = function(_optionId, descr, _context) {
    fillMultipleHueOption(descr, "color_picker_hue_aircraft_hud_alert", getAlertAircraftHues())
  },
  [USEROPT_HUE_AIRCRAFT_HUD] = function(_optionId, descr, _context) {
    fillHueSaturationBrightnessOption(descr, "color_picker_hue_aircraft_hud",
      122, 1.0, 1.0, get_hue(TARGET_HUE_AIRCRAFT_HUD))
  },
  [USEROPT_HUE_HELICOPTER_CROSSHAIR] = function(_optionId, descr, _context) {
    fillHueSaturationBrightnessOption(descr, "color_picker_hue_helicopter_crosshair",
      122, 1.0, 1.0, get_hue(TARGET_HUE_HELICOPTER_CROSSHAIR))
  },
  [USEROPT_HUE_HELICOPTER_HUD] = function(_optionId, descr, _context) {
    fillHueSaturationBrightnessOption(descr, "color_picker_hue_helicopter_hud",
      122, 1.0, 1.0, get_hue(TARGET_HUE_HELICOPTER_HUD))
  },
  [USEROPT_HUE_HELICOPTER_PARAM_HUD] = function(_optionId, descr, _context) {
    fillHueSaturationBrightnessOption(descr, "color_picker_hue_helicopter_param_hud",
      122, 1.0, 1.0, get_hue(TARGET_HUE_HELICOPTER_PARAM_HUD))
  },
  [USEROPT_HUE_HELICOPTER_HUD_ALERT] = function(_optionId, descr, _context) {
    if (hasFeature("reactivGuiForAircraft"))
      fillMultipleHueOption(descr, "color_picker_hue_helicopter_hud_alert", getAlertHelicopterHues())
    else
      fillHueOption(descr, "color_picker_hue_helicopter_hud_alert", get_hue(TARGET_HUE_HELICOPTER_HUD_ALERT_HIGH), 0)
  },
  [USEROPT_HUE_ARBITER_HUD] = function(_optionId, descr, _context) {
    fillHueSaturationBrightnessOption(descr, "color_picker_hue_arbiter_hud",
      64, 0.0, 1.0, get_hue(TARGET_HUE_ARBITER_HUD)) // white default
  },
  [USEROPT_HUE_HELICOPTER_MFD] = function(_optionId, descr, _context) {
    fillHueOption(descr, "color_picker_hue_helicopter_mfd", get_hue(TARGET_HUE_HELICOPTER_MFD), 112, 1.0, 1.0)
  },
  [USEROPT_HUE_TANK_THERMOVISION] = function(_optionId, descr, _context) {
    fillHSVOption_ThermovisionColor(descr)
  },
  [USEROPT_HORIZONTAL_SPEED] = function(_optionId, descr, _context) {
    descr.id = "horizontalSpeed"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_horizontal_speed() != 0
  },
  [USEROPT_HELICOPTER_HELMET_AIM] = function(_optionId, descr, _context) {
    descr.id = "helicopterHelmetAim"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_use_oculus_to_aim_helicopter() != 0
  },
  [USEROPT_HELICOPTER_AUTOPILOT_ON_GUNNERVIEW] = function(_optionId, descr, _context) {
    descr.id = "helicopter_autopilot_on_gunnerview"
    descr.items = ["#options/no", "#options/inmouseaim", "#options/always", "#options/always_damping"]
    descr.values = [0, 1, 2, 3]
    descr.value = get_option_auto_pilot_on_gunner_view_helicopter()
    descr.trParams <- "optionWidthInc:t='half';"
  },
  [USEROPT_SHOW_DESTROYED_PARTS] = function(_optionId, descr, _context) {
    descr.id = "show_destroyed_parts"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_show_destroyed_parts()
  },
  [USEROPT_ACTIVATE_GROUND_RADAR_ON_SPAWN] = function(_optionId, descr, _context) {
    descr.id = "activate_ground_radar_on_spawn"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_activate_ground_radar_on_spawn()
  },
  [USEROPT_GROUND_RADAR_TARGET_CYCLING] = function(_optionId, descr, _context) {
    descr.id = "ground_radar_target_cycling"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_ground_radar_target_cycling()
  },
  [USEROPT_ACTIVATE_GROUND_ACTIVE_COUNTER_MEASURES_ON_SPAWN] = function(_optionId, descr, _context) {
    descr.id = "activate_ground_active_counter_measures_on_spawn"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_activate_ground_active_counter_measures_on_spawn()
  },
  [USEROPT_FPS_CAMERA_PHYSICS] = function(_optionId, descr, _context) {
    descr.id = "fps_camera_physics"
    descr.value = clamp((get_option_multiplier(OPTION_FPS_CAMERA_PHYS) * 100.0).tointeger(), 0, 100)
    descr.controlType = optionControlType.SLIDER
  },
  [USEROPT_FPS_VR_CAMERA_PHYSICS] = function(_optionId, descr, _context) {
    descr.id = "fps_vr_camera_physics"
    descr.value = clamp((get_option_multiplier(OPTION_FPS_VR_CAMERA_PHYS) * 100.0).tointeger(), 0, 100)
    descr.controlType = optionControlType.SLIDER
  },
  [USEROPT_FREE_CAMERA_INERTIA] = function(_optionId, descr, _context) {
    descr.id = "free_camera_inertia"
    descr.value = clamp((get_option_multiplier(OPTION_FREE_CAMERA_INERTIA) * 100.0).tointeger(), 0, 100)
  },
  [USEROPT_REPLAY_CAMERA_WIGGLE] = function(_optionId, descr, _context) {
    descr.id = "replay_camera_wiggle"
    descr.value = clamp((get_option_multiplier(OPTION_REPLAY_CAMERA_WIGGLE) * 100.0).tointeger(), 0, 100)
  },
  [USEROPT_CLAN_REQUIREMENTS_MIN_AIR_RANK] = useropt_clan_requirements_min_air_rank,
  [USEROPT_CLAN_REQUIREMENTS_MIN_TANK_RANK] = useropt_clan_requirements_min_air_rank,
  [USEROPT_CLAN_REQUIREMENTS_MIN_BLUEWATER_SHIP_RANK] = useropt_clan_requirements_min_air_rank,
  [USEROPT_CLAN_REQUIREMENTS_MIN_COASTAL_SHIP_RANK] = useropt_clan_requirements_min_air_rank,
  [USEROPT_CLAN_REQUIREMENTS_ALL_MIN_RANKS] = function(_optionId, descr, _context) {
    descr.id = "clan_req_all_min_ranks"
    descr.title = loc("clan/rankConditionType")
    descr.textUnchecked <- loc("clan/minRankCondType_or")
    descr.textChecked <- loc("clan/minRankCondType_and")
  },
  [USEROPT_CLAN_REQUIREMENTS_MIN_ARCADE_BATTLES] = useropt_clan_requirements_min_arcade_battles,
  [USEROPT_CLAN_REQUIREMENTS_MIN_SYM_BATTLES] = useropt_clan_requirements_min_arcade_battles,
  [USEROPT_CLAN_REQUIREMENTS_MIN_REAL_BATTLES] = useropt_clan_requirements_min_arcade_battles,
  [USEROPT_CLAN_REQUIREMENTS_AUTO_ACCEPT_MEMBERSHIP] = function(_optionId, descr, _context) {
    descr.id = "clan_req_auto_accept_membership"
    descr.title = loc("clan/autoAcceptMembershipOn")
  },
  [USEROPT_TANK_GUNNER_CAMERA_FROM_SIGHT] = function(_optionId, descr, _context) {
    descr.id = "tank_gunner_camera_from_sight"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_option_tank_gunner_camera_from_sight()
    descr.defaultValue = false
  },
  [USEROPT_TANK_ALT_CROSSHAIR] = function(_optionId, descr, _context) {
    descr.id = "tank_alt_crosshair"
    descr.optionCb = "onTankAltCrosshair"

    descr.items = []
    descr.values = []

    if (!has_forced_crosshair()) {
      descr.items.append(loc("options/defaultSight"))
      descr.values.append("")
    }

    let presets = get_user_alt_crosshairs("", "")
    for (local i = 0; i < presets.len(); i++) {
      descr.items.append(presets[i])
      descr.values.append(presets[i])
    }

    if (hasFeature("TankAltCrosshair")) {
      descr.items.append(loc("options/addUserSight"))
      descr.values.append(TANK_ALT_CROSSHAIR_ADD_NEW)
    }

    let unit = getPlayerCurUnit()
    descr.value = unit ? u.find_in_array(descr.values, get_option_tank_alt_crosshair(unit.name), 0) : 0
  },
  [USEROPT_GAMEPAD_CURSOR_CONTROLLER] = function(_optionId, descr, _context) {
    descr.id = "gamepad_cursor_controller"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = ::g_gamepad_cursor_controls.getValue()
  },
  [USEROPT_PS4_CROSSPLAY] = function(_optionId, descr, _context) {
    descr.id = "ps4_crossplay"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.optionCb = "onChangeCrossPlay"
    descr.value = crossplayModule.isCrossPlayEnabled()
    descr.enabled <- !::checkIsInQueue()
  },
  //







  [USEROPT_PS4_CROSSNETWORK_CHAT] = function(_optionId, descr, _context) {
    descr.id = "ps4_crossnetwork_chat"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = crossplayModule.isCrossNetworkChatEnabled()
    descr.optionCb = "onChangeCrossNetworkChat"
  },
  [USEROPT_DISPLAY_MY_REAL_NICK] = function(optionId, descr, _context) {
    descr.id = "display_my_real_nick"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = ::get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY, true)
    descr.defaultValue = true
    descr.defVal <- descr.defaultValue
    descr.optionCb <- "onChangeDisplayRealNick"
    if (!havePremium.get()) {
      descr.hint = "".concat(
        loc("guiHints/display_my_real_nick"),
        "\n",
        colorize("warningTextColor", loc("mainmenu/onlyWithPremium"))
      )
      descr.trParams <- "disabledColor:t='yes';"
    }
  },
  [USEROPT_DISPLAY_REAL_NICKS_PARTICIPANTS] = function(optionId, descr, _context) {
    descr.id = "display_real_nicks_participants"
    descr.items = ["#options/display_real_nicks_participants/nochange", "#options/display_real_nicks_participants/userid", "#options/display_real_nicks_participants/namebots"]
    descr.values = [0, 1, 2]
    descr.value = get_gui_option(optionId)
    descr.defaultValue = 0
  },
  [USEROPT_SHOW_SOCIAL_NOTIFICATIONS] = function(_optionId, descr, _context) {
    descr.id = "show_social_notifications"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = true
    descr.defVal <- descr.defaultValue
  },
  [USEROPT_ALLOW_ADDED_TO_CONTACTS] = function(_optionId, descr, _context) {
    descr.id = "allow_added_to_contacts"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = isMeAllowedToBeAddedToContacts.get()
    descr.defaultValue = true
    descr.defVal <- descr.defaultValue
  },
  [USEROPT_ALLOW_SHOW_WISHLIST] = function(_optionId, descr, _context) {
    descr.id = "allow_show_wishlist"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = isWishlistEnabledForFriends()
    descr.defaultValue = true
    descr.defVal <- descr.defaultValue
  },
  [USEROPT_ALLOW_SHOW_WISHLIST_COMMENTS] = function(_optionId, descr, _context) {
    descr.id = "allow_show_wishlist_comments"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = isWishlistCommentsEnabledForFriends()
    descr.defaultValue = true
    descr.defVal <- descr.defaultValue
  },
  [USEROPT_ALLOW_ADDED_TO_LEADERBOARDS] = function(_optionId, descr, _context) {
    descr.id = "allow_added_to_leaderboards"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.value = get_allow_to_be_added_to_lb()
    descr.defaultValue = true
    descr.defVal <- descr.defaultValue
  },
  [USEROPT_PS4_ONLY_LEADERBOARD] = function(_optionId, descr, _context) {
    descr.id = "ps4_only_leaderboards"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.enabled <- crossplayModule.isCrossPlayEnabled()
    descr.defaultValue = false
  },
  [USEROPT_PRELOADER_SETTINGS] = function(_optionId, descr, _context) {
    descr.id = "preloader_settings"
    descr.controlType = optionControlType.BUTTON
    descr.funcName <- "onPreloaderSettings"
    descr.delayed <- true
    descr.shortcut <- "R3"
    descr.text <- loc("preloaderSettings/title")
    descr.title = descr.text
    descr.showTitle <- false
  },
  [TANK_SIGHT_SETTINGS] = function(_optionId, descr, _context) {
    descr.id = "tank_sight_settings"
    descr.controlType = optionControlType.BUTTON
    descr.funcName <- "onTankSightSettings"
    descr.delayed <- true
    descr.shortcut <- "R3"
    descr.text <- loc("tankSight/tankSightSettings")
    descr.title = descr.text
    descr.showTitle <- false
  },
  [USEROPT_REVEAL_NOTIFICATIONS] = function(_optionId, descr, _context) {
    descr.id = "reveal_notifications"
    descr.controlType = optionControlType.BUTTON
    descr.funcName <- "onRevealNotifications"
    descr.delayed <- true
    descr.shortcut <- "LB"
    descr.text <- loc("mainmenu/btnRevealNotifications")
    descr.title = descr.text
    descr.showTitle <- false
  },
  [USEROPT_HDR_SETTINGS] = function(_optionId, descr, _context) {
    descr.id = "hdr_settings"
    descr.controlType = optionControlType.BUTTON
    descr.funcName <- "onHdrSettings"
    descr.delayed <- true
    descr.shortcut <- "RB"
    descr.text <- loc("mainmenu/btnHdrSettings")
    descr.title = descr.text
    descr.showTitle <- false
  },
  [USEROPT_POSTFX_SETTINGS] = function(_optionId, descr, _context) {
    descr.id = "postfx_setting"
    descr.controlType = optionControlType.BUTTON
    descr.funcName <- "onPostFxSettings"
    descr.delayed <- true
    descr.shortcut <- "X"
    descr.text <- loc("mainmenu/btnPostFxSettings")
    descr.title = descr.text
    descr.showTitle <- false
  },
  [USEROPT_HOLIDAYS] = function(_optionId, descr, _context) {
    descr.defaultValue = holidays.get_default_culture()
    descr.defVal <- descr.defaultValue
    descr.id = "holidays"
    descr.items = []
    descr.values = []
    let cultures = holidays.list_cultures()
    for (local i = 0; i < cultures.len(); i++) {
      descr.values.append(cultures[i])
      descr.items.append(loc($"options/holidays_{cultures[i]}", cultures[i]))
    }
  },
  //








  [USEROPT_HIT_INDICATOR_RADIUS] = function(_optionId, descr, _context) {
    descr.id = "hit_indicator_radius"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 50
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_HIT_INDICATOR_SIMPLIFIED] = function(_optionId, descr, _context) {
    descr.id = "hit_indicator_simplified"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = false
  },
  [USEROPT_HIT_INDICATOR_ALPHA] = function(_optionId, descr, _context) {
    descr.id = "hit_indicator_alpha"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 50
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_HIT_INDICATOR_SCALE] = function(_optionId, descr, _context) {
    descr.id = "hit_indicator_scale"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 50
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_HIT_INDICATOR_FADE_TIME] = function(_optionId, descr, _context) {
    descr.id = "hit_indicator_timeout"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 1
    descr.max <- 10
    descr.step <- 1
    descr.defaultValue = 2
    descr.getValueLocText = @(val) $"{val}s"
  },
  [USEROPT_LWS_IND_RADIUS] = function(_optionId, descr, _context) {
    descr.id = "lws_indicator_radius"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 50
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_LWS_IND_ALPHA] = function(_optionId, descr, _context) {
    descr.id = "lws_indicator_alpha"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 50
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_LWS_IND_SCALE] = function(_optionId, descr, _context) {
    descr.id = "lws_indicator_scale"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 50
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_LWS_IND_TIMEOUT] = function(_optionId, descr, _context) {
    descr.id = "lws_indicator_timeout"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 1
    descr.max <- 10
    descr.step <- 1
    descr.defaultValue = 2
    descr.getValueLocText = @(val) $"{val}s"
  },
  [USEROPT_LWS_AZIMUTH_IND_TIMEOUT] = function(_optionId, descr, _context) {
    descr.id = "lws_azimuth_indicator_timeout"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 1
    descr.max <- 10
    descr.step <- 1
    descr.defaultValue = 2
    descr.getValueLocText = @(val) $"{val}s"
  },
  [USEROPT_LWS_IND_H_RADIUS] = function(_optionId, descr, _context) {
    descr.id = "lws_indicator_radius_helicopter"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 50
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_LWS_IND_H_ALPHA] = function(_optionId, descr, _context) {
    descr.id = "lws_indicator_alpha_helicopter"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 50
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_LWS_IND_H_SCALE] = function(_optionId, descr, _context) {
    descr.id = "lws_indicator_scale_helicopter"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 50
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 100
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_LWS_IND_H_TIMEOUT] = function(_optionId, descr, _context) {
    descr.id = "lws_indicator_helicopter_timeout"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 1
    descr.max <- 10
    descr.step <- 1
    descr.defaultValue = 2
    descr.getValueLocText = @(val) $"{val}s"
  },
  [USEROPT_LWS_IND_AZIMUTH_H_TIMEOUT] = function(_optionId, descr, _context) {
    descr.id = "lws_azimuth_indicator_helicopter_timeout"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 1
    descr.max <- 10
    descr.step <- 1
    descr.defaultValue = 2
    descr.getValueLocText = @(val) $"{val}s"
  },
  [USEROPT_FREE_CAMERA_ZOOM_SPEED] = function(_optionId, descr, _context) {
    descr.id = "free_camera_zoom_speed"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 2
    descr.max <- 200
    descr.step <- 10
    descr.defaultValue = 50
    descr.getValueLocText = @(val) $"{val}x"
  },
  [USEROPT_REPLAY_FOV] = function(_optionId, descr, _context) {
    descr.id = "replay_fov"
    descr.controlType = optionControlType.SLIDER
    descr.min <- 30
    descr.max <- 150
    descr.step <- 10
    descr.defaultValue = 90
    descr.getValueLocText = @(val) $"{val}%"
  },
  [USEROPT_HELI_COCKPIT_HUD_DISABLED] = function(optionId, descr, _context) {
    descr.id = "hudDisableInPilotView"
    descr.controlType = optionControlType.CHECKBOX
    descr.controlName <- "switchbox"
    descr.defaultValue = ::get_gui_option_in_mode(optionId, OPTIONS_MODE_GAMEPLAY)
  },
  [USEROPT_XRAY_FILTER_TANK] = function(optionId, descr, context) {
    descr.id = "xray_filter"
    let filters = getTankXrayFilter(context?.unitName)
    fillXrayFilterDescr(optionId, descr, filters)
  },
  [USEROPT_XRAY_FILTER_SHIP] = function(optionId, descr, context) {
    descr.id = "xray_filter_ship"
    let filters = getShipXrayFilter(context?.unitName)
    fillXrayFilterDescr(optionId, descr, filters)
  },
  [USEROPT_TEST_FLIGHT_NAME] = function(optionId, descr, _context) {
    descr.id = "test_flight_name"
    descr.items = []
    descr.values = []
    descr.value = get_gui_option(optionId)
    local missionsList = []
    let cb = @(res) missionsList = res
    g_mislist_type.BASE.requestMissionsList(false, cb, "test_flights_universal")
    foreach (mission in missionsList) {
      let misBlk = mission.blk
      descr.values.append(misBlk.name)
      descr.items.append(getMissionName(misBlk.name, misBlk))
    }
  },
  [USEROPT_AIR_SPAWN_POINT] = function(optionId, descr, _context) {
    descr.id = "air_spawn_point"
    descr.values = [0, 1, 2, 3, 4, 5]
    descr.value = get_gui_option(optionId)
    let measure = loc("measureUnits/km_dist")
    descr.items = [loc("multiplayer/airfieldName"), $"1 {measure}", $"2 {measure}", $"3 {measure}",
      $"5 {measure}", $"7 {measure}"]
  },
  [USEROPT_TARGET_RANK] = function(optionId, descr, _context) {
    descr.id = "target_rank"
    descr.values = ["high", "low"]
    descr.value = get_gui_option(optionId)
    descr.items = descr.values.map(@(v) loc($"chance_to_met/{v}"))
  },
}

get_option = function(optionId, context=null) {
  local descr = createDefaultOption()
  descr.type = optionId
  descr.context = context

  if (u.isString(optionId)) {
    descr.controlType = optionControlType.HEADER
    descr.controlName <- ""
    descr.id = $"header_{::gen_rnd_password(10)}"
    descr.title = loc(descr.type)
    return descr
  }

  if (optionId in optionsMap) {
    optionsMap[optionId](optionId, descr, context)
  }
  else {
    let optionName = userOptionNameByIdx?[optionId] ?? ""
    assert(false, $"[ERROR] Options: Get: Unsupported type {optionId} ({optionName})")
  }

  if ("onChangeCb" in context)
    descr.onChangeCb = context.onChangeCb

  if (!descr.hint)
    descr.hint = loc($"guiHints/{descr.id}", "")

  if (descr.needRestartClient)
    descr.hint = "\n".concat(descr.hint, colorize("warningTextColor", loc("guiHints/restart_required")))

  let defaultValue = descr?.defaultValue ?? 0
  local prevValue = descr?.prevValue

  local valueToSet = defaultValue
  if (prevValue == null)
    prevValue = get_gui_option(optionId)
  if (prevValue != null)
    valueToSet = prevValue

  descr.needShowValueText = descr.needShowValueText || descr.controlType == optionControlType.SLIDER

  let optionCb = descr.needShowValueText && descr.optionCb != null ? "updateOptionValueCallback"
    : descr.needShowValueText ? "updateOptionValueTextByObj"
    : descr.optionCb
  descr.cb <- context?.containerCb ?? (descr.needCommonCallback ? optionCb : descr.optionCb)

  if(descr.needShowValueText && descr.optionCb == null)
    descr.optionCb = "updateOptionValueTextByObj"

  if (descr.controlType == optionControlType.SLIDER) {
    if (descr.value == null)
      descr.value = clamp(valueToSet || 0, descr?.min ?? 0, descr?.max ?? 1)
    return descr
  }

  if (descr.controlType == optionControlType.CHECKBOX) {
    if (descr.value == null)
      descr.value = !!valueToSet
    return descr
  }

  if (descr.controlType == optionControlType.EDITBOX) {
    if (!u.isString(descr.value))
      descr.value = u.isString(valueToSet) ? valueToSet : ""
    return descr
  }

  if (!descr.values && descr.items) {
    descr.values = []
    for (local i = 0; i < descr.items.len(); i++)
      descr.values.append(i)
  }

  if (descr.controlType == optionControlType.BIT_LIST) {
    if (!u.isInteger(descr.value))
      if (u.isInteger(prevValue))
        descr.value = prevValue
      else
        descr.value = defaultValue
    return descr
  }

  if (descr.value != null &&
      type(descr.values) == "array" &&
      descr.values.len() > 0 &&
      !(descr.value in descr.values))
    descr.value = null

  if (descr.value == null && valueToSet != null && type(descr.values) == "array")
    for (local i = 0; i < descr.values.len(); i++) {
      if (descr.values[i] == valueToSet) {
        descr.value = i
        break
      }
      //select defaultValue if valueToSet dissappear from list
      if (descr.values[i] == defaultValue)
        descr.value = i
    }

  if (descr.value == null)
    if (descr.values)
      descr.value = 0

  return descr
}


function set_useropt_aerobatics_smoke_left_color(value, descr, optionId) {
  let optIndex = u.find_in_array(
    [USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, USEROPT_AEROBATICS_SMOKE_TAIL_COLOR],
    optionId)

  set_option_aerobatics_smoke_color(optIndex, descr.values[value])
}

function set_useropt_measureunits_speed(value, descr, optionId) {
  if (type(descr.values) == "array" && value >= 0 && value < descr.values.len()) {
    local unitType = 0
    if (optionId == USEROPT_MEASUREUNITS_ALT)
      unitType = 1
    else if (optionId == USEROPT_MEASUREUNITS_DIST)
      unitType = 2
    else if (optionId == USEROPT_MEASUREUNITS_CLIMBSPEED)
      unitType = 3
    else if (optionId == USEROPT_MEASUREUNITS_TEMPERATURE)
      unitType = 4
    else if (optionId == USEROPT_MEASUREUNITS_WING_LOADING)
      unitType = 5
    else if (optionId == USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO)
      unitType = 6
    else if (optionId == USEROPT_MEASUREUNITS_RADIAL_SPEED)
      unitType = 7

    set_option_unit_type(unitType, descr.values[value])

    if (isWaitMeasureEvent)
      return true

    isWaitMeasureEvent = true
    handlersManager.doDelayed(function() {
      isWaitMeasureEvent = false
      broadcastEvent("MeasureUnitsChanged")
    })
  }
}

function set_useropt_cd(value, descr, optionId) {
  local optionValue = null
  if (descr.controlType == optionControlType.CHECKBOX) {
    optionValue = value
    set_gui_option(optionId, value)
    setCdOption(optionId, value ? 1 : 0)
  }
  else if (descr.controlType == optionControlType.LIST) {
    if (value in descr.values) {
      optionValue = descr.values[value]
      set_gui_option(optionId, optionValue)
      setCdOption(optionId, optionValue)
    }
    else
      assert(false, $"[ERROR] Value '{value}' is out of range in type {optionId}")
  }
  else
    assert(false, $"[ERROR] No values set for type '{optionId}'")
  if (optionValue != null && descr.onChangeCb)
    descr.onChangeCb(optionId, optionValue, value)
}

let set_useropt_helpers_mode = @(value, descr, optionId) ::g_aircraft_helpers.setOptionValue(optionId, descr.values != null ? getTblValue(value, descr.values, 0) : value)

function set_useropt_instructor_ground_avoidance(value, descr, _optionId) {
  let optionIdx = getTblValue("boolOptionIdx", descr, -1)
  if (optionIdx >= 0 && u.isBool(value))
    set_option_bool(optionIdx, value)
}

function set_useropt_bit_countries_team_a(value, descr, optionId) {
  if (value == 0)
    value = descr.allowedMask
  if (value <= 0)
    return

  set_gui_option(optionId, value)
  ::mission_settings[$"{descr.sideTag}_bitmask"] <- value
  if (descr.onChangeCb)
    descr.onChangeCb(optionId, value, value)
}

function set_useropt_br_min(value, descr, optionId) {
  if (value in descr.values) {
    let optionValue = descr.values[value]
    set_gui_option(optionId, optionValue)
    ::mission_settings[optionId == USEROPT_BR_MIN ? "mrankMin" : "mrankMax"] <- optionValue
  }
}

let def_set_gui_option = @(value, _descr, optionId) set_gui_option(optionId, value)

function set_useropt_mp_team_country_rand(value, descr, _optionId) {
  if (value >= 0 && value < descr.values.len())
    set_gui_option(USEROPT_MP_TEAM, descr.values[value])
}

function set_useropt_bullets0(value, _descr, optionId) {
  set_gui_option(optionId, value)
  let air = getAircraftByName(::aircraft_for_weapons)
  if (air)
    setUnitLastBullets(air, optionId - USEROPT_BULLETS0, value)
  else {
    let groupIndex = optionId - USEROPT_BULLETS0
    logerr($"Options: USEROPT_BULLET{groupIndex}: set: Wrong 'aircraft_for_weapons' type")
    debugTableData(::aircraft_for_weapons)
  }
}

function set_useropt_landing_mode(value, descr, optionId) {
  if (descr.controlType == optionControlType.LIST) {
    if (type(descr.values) != "array")
      return
    if (value < 0 || value >= descr.values.len())
      return

    set_gui_option(optionId, descr.values[value])
  }
  else if (descr.controlType == optionControlType.CHECKBOX) {
    if (u.isBool(value))
      set_gui_option(optionId, value)
  }
}

function set_useropt_damage_indicator_size(value, descr, optionId) {
  if (value >= (descr?.min ?? 0) && value <= (descr?.max ?? 1)
      && (!("step" in descr) || value % descr.step == 0)) {
    ::set_gui_option_in_mode(optionId, value, OPTIONS_MODE_GAMEPLAY)
    broadcastEvent("HudIndicatorChangedSize", { option = optionId })
  }
}

function set_xray_filter_option(value, descr, optionId) {
  def_set_gui_option(value, descr, optionId)
  set_xray_parts_filter(value)
}

let optionsSetMap = {
  [USEROPT_LANGUAGE] = @(value, descr, _optionId) setGameLocalization(descr.values[value], false, true),
  [USEROPT_CUSTOM_LANGUAGE] = @(value, _descr, _optionId) setCustomLocalization(value),
  [USEROPT_VIEWTYPE] = @(value, _descr, _optionId) set_option_view_type(value),
  [USEROPT_SPEECH_TYPE] = function(value, descr, _optionId) {
    let curOption = get_option(USEROPT_SPEECH_TYPE)
    set_option_speech_country_type(descr.values[value])
    checkUnitSpeechLangPackWatch(curOption.value != value && value == SPEECH_COUNTRY_UNIT_VALUE)
  },
  [USEROPT_GUN_TARGET_DISTANCE] = @(value, descr, _optionId) set_option_gun_target_dist(descr.values[value]),
  [USEROPT_BOMB_ACTIVATION_TIME] = function(value, descr, _optionId) {
    let isBombActivationAssault = descr.values[value] == BOMB_ASSAULT_FUSE_TIME_OPT_VALUE
    let bombActivationDelay = isBombActivationAssault ?
      get_bomb_activation_auto_time() : descr.values[value]
    let bombActivationType = isBombActivationAssault ? BOMB_ACT_ASSAULT : BOMB_ACT_TIME
    set_option_bomb_activation_type(bombActivationType)
    set_option_bomb_activation_time(bombActivationDelay)
    saveLocalAccountSettings($"useropt/bomb_activation_time/{descr.diffCode}", bombActivationDelay)
    saveLocalAccountSettings($"useropt/bomb_activation_type/{descr.diffCode}", bombActivationType)
  },
  [USEROPT_BOMB_SERIES] = @(value, descr, _optionId) set_option_bombs_series(descr.values[value]),
  [USEROPT_LOAD_FUEL_AMOUNT] = function(value, descr, optionId) {
    set_gui_option(optionId, descr.values[value])
    if (::aircraft_for_weapons)
      set_unit_option(::aircraft_for_weapons, optionId, descr.values[value])
  },
  [USEROPT_FUEL_AMOUNT_CUSTOM] = function(value, _descr, optionId) {
    set_gui_option(optionId, value)
    if (::aircraft_for_weapons)
      set_unit_option(::aircraft_for_weapons, optionId, value)
  },
  [USEROPT_DEPTHCHARGE_ACTIVATION_TIME] = @(value, descr, _optionId) set_option_depthcharge_activation_time(descr.values[value]),
  [USEROPT_COUNTERMEASURES_PERIODS] = @(value, descr, _optionId) set_option_countermeasures_periods(descr.values[value]),
  [USEROPT_COUNTERMEASURES_SERIES_PERIODS] = @(value, descr, _optionId) set_option_countermeasures_series_periods(descr.values[value]),
  [USEROPT_COUNTERMEASURES_SERIES] = @(value, descr, _optionId) set_option_countermeasures_series(descr.values[value]),
  [USEROPT_USE_PERFECT_RANGEFINDER] = @(value, _descr, _optionId) set_option_use_perfect_rangefinder(value ? 1 : 0),
  [USEROPT_ROCKET_FUSE_DIST] = function(value, descr, optionId) {
    set_option_rocket_fuse_dist(descr.values[value])
    if (::aircraft_for_weapons)
      set_unit_option(::aircraft_for_weapons, optionId, descr.values[value])
  },
  [USEROPT_TORPEDO_DIVE_DEPTH] = function(value, descr, optionId) {
    set_option_torpedo_dive_depth(descr.values[value])
    if (::aircraft_for_weapons)
      set_unit_option(::aircraft_for_weapons, optionId, descr.values[value])
  },
  [USEROPT_AEROBATICS_SMOKE_TYPE] = @(value, descr, _optionId) set_option_aerobatics_smoke_type(descr.values[value]),
  [USEROPT_AEROBATICS_SMOKE_LEFT_COLOR] = set_useropt_aerobatics_smoke_left_color,
  [USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR] = set_useropt_aerobatics_smoke_left_color,
  [USEROPT_AEROBATICS_SMOKE_TAIL_COLOR] = set_useropt_aerobatics_smoke_left_color,
  [USEROPT_INGAME_VIEWTYPE] = @(value, _descr, _optionId) apply_current_view_type(value),
  [USEROPT_INVERTY] = @(value, _descr, _optionId) set_option_invertY(AxisInvertOption.INVERT_Y, value ? 1 : 0),
  [USEROPT_INVERTX] = @(value, _descr, _optionId) set_option_invertX(value ? 1 : 0),
  [USEROPT_GUNNER_INVERTY] = @(value, _descr, _optionId) set_option_invertY(AxisInvertOption.INVERT_GUNNER_Y, value ? 1 : 0),
  [USEROPT_INVERT_THROTTLE] = @(value, _descr, _optionId) set_option_invertY(AxisInvertOption.INVERT_THROTTLE, value),
  [USEROPT_INVERTY_TANK] = @(value, _descr, _optionId) set_option_invertY(AxisInvertOption.INVERT_TANK_Y, value ? 1 : 0),
  [USEROPT_INVERTY_SHIP] = @(value, _descr, _optionId) set_option_invertY(AxisInvertOption.INVERT_SHIP_Y, value ? 1 : 0),
  [USEROPT_INVERTY_HELICOPTER] = @(value, _descr, _optionId) set_option_invertY(AxisInvertOption.INVERT_HELICOPTER_Y, value ? 1 : 0),
  [USEROPT_INVERTY_HELICOPTER_GUNNER] = @(value, _descr, _optionId) set_option_invertY(AxisInvertOption.INVERT_HELICOPTER_GUNNER_Y, value ? 1 : 0),
  [USEROPT_INVERTY_SUBMARINE] = @(value, _descr, _optionId) set_option_invertY(AxisInvertOption.INVERT_SUBMARINE_Y, value ? 1 : 0),
  [USEROPT_INVERTY_SPECTATOR] = @(value, _descr, _optionId) set_option_invertY(AxisInvertOption.INVERT_SPECTATOR_Y, value ? 1 : 0),
  [USEROPT_FORCE_GAIN] = @(value, _descr, _optionId) set_option_gain(value / 50.0),
  [USEROPT_INDICATED_SPEED_TYPE] = @(value, descr, _optionId) set_option_indicatedSpeedType(descr.values[value]),
  [USEROPT_INDICATED_ALTITUDE_TYPE] = @(value, descr, _optionId) set_option_indicatedAltitudeType(descr.values[value]),
  [USEROPT_RADAR_ALTITUDE_ALERT] = @(value, _descr, _optionId) set_option_radarAltitudeAlert(value),
  [USEROPT_AUTO_SHOW_CHAT] = @(value, _descr, _optionId) set_option_auto_show_chat(value ? 1 : 0),
  [USEROPT_CHAT_MESSAGES_FILTER] = @(value, _descr, _optionId) set_option_chat_messages_filter(value),
  [USEROPT_CHAT_FILTER] = function(value, _descr, _optionId) {
    set_option_chat_filter(value ? 1 : 0)
    broadcastEvent("ChatFilterChanged")
  },
  [USEROPT_SHOW_PILOT] = @(value, _descr, _optionId) set_option_showPilot(value ? 1 : 0),
  [USEROPT_GUN_VERTICAL_TARGETING] = @(value, _descr, _optionId) set_option_gunVerticalTargeting(value ? 1 : 0),
  [USEROPT_INVERTCAMERAY] = @(value, _descr, _optionId) set_option_camera_invertY(value ? 1 : 0),
  [USEROPT_ZOOM_FOR_TURRET] = function(value, _descr, _optionId) {
    log($"USEROPT_ZOOM_FOR_TURRET{value}")
    set_option_zoom_turret(value)
  },
  [USEROPT_XCHG_STICKS] = @(value, _descr, _optionId) set_option_xchg_sticks(0, value ? 1 : 0),
  [USEROPT_AUTOSAVE_REPLAYS] = @(value, _descr, _optionId) set_option_autosave_replays(value),
  [USEROPT_XRAY_DEATH] = @(value, _descr, _optionId) set_option_xray_death(value),
  [USEROPT_XRAY_KILL] = @(value, _descr, _optionId) set_option_xray_kill(value),
  [USEROPT_USE_CONTROLLER_LIGHT] = @(value, _descr, _optionId) set_option_controller_light(value),
  [USEROPT_SUBTITLES] = @(value, _descr, _optionId) set_option_subs(value ? 2 : 0),
  [USEROPT_SUBTITLES_RADIO] = @(value, _descr, _optionId) set_option_subs_radio(value ? 2 : 0),
  [USEROPT_PTT] = @(value, _descr, _optionId) set_option_ptt(value ? 1 : 0),
  [USEROPT_VOICE_CHAT] = @(value, _descr, _optionId) set_option_voicechat(value ? 1 : 0),
  [USEROPT_SOUND_ENABLE] = function(value, _descr, _optionId) {
    set_mute_sound(value)
    setSystemConfigOption("sound/fmod_sound_enable", value)
  },
  [USEROPT_CUSTOM_SOUND_MODS] = @(value, _descr, _optionId) setCustomSoundMods(value),
  [USEROPT_SOUND_SPEAKERS_MODE] = @(value, descr, _optionId) setSystemConfigOption("sound/speakerMode", descr.values[value]),
  [USEROPT_VOICE_MESSAGE_VOICE] = @(value, _descr, _optionId) set_option_voice_message_voice(value + 1),//1-based
  [USEROPT_HUD_COLOR] = @(value, _descr, _optionId) set_option_hud_color(value),
  [USEROPT_HUD_INDICATORS] = @(value, _descr, _optionId) set_option_hud_indicators?(value),
  [USEROPT_DELAYED_DOWNLOAD_CONTENT] = function(value, _descr, _optionId) {
    set_option_delayed_download_content(value)
    saveLocalAccountSettings("delayDownloadContent", value)
  },
  [USEROPT_REPLAY_SNAPSHOT_ENABLED] = def_set_gui_option,
  [USEROPT_RECORD_SNAPSHOT_PERIOD] = @(value, descr, optionId) set_gui_option(optionId, descr.values[value]),
  [USEROPT_AI_GUNNER_TIME] = @(value, _descr, _optionId) set_option_ai_gunner_time(value),
  [USEROPT_MEASUREUNITS_SPEED] = set_useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_ALT] = set_useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_DIST] = set_useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_CLIMBSPEED] = set_useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_TEMPERATURE] = set_useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_WING_LOADING] = set_useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO] = set_useropt_measureunits_speed,
  [USEROPT_MEASUREUNITS_RADIAL_SPEED] = set_useropt_measureunits_speed,
  [USEROPT_VIBRATION] = @(value, _descr, _optionId) set_option_vibration(value ? 1 : 0),
  [USEROPT_GRASS_IN_TANK_VISION] = @(value, _descr, _optionId) set_option_grass_in_tank_vision(value ? 1 : 0),
  [USEROPT_GAME_HUD] = @(value, descr, _optionId) set_option_hud(descr.values[value]),
  [USEROPT_CAMERA_SHAKE_MULTIPLIER] = @(value, _descr, _optionId) set_option_multiplier(OPTION_CAMERA_SHAKE, value / 50.0),
  [USEROPT_VR_CAMERA_SHAKE_MULTIPLIER] = @(value, _descr, _optionId) set_option_multiplier(OPTION_VR_CAMERA_SHAKE, value / 50.0),
  [USEROPT_GAMMA] = @(value, _descr, _optionId) set_option_gamma(value / 100.0, true),
  [USEROPT_CONSOLE_GFX_PRESET] = @(value, _descr, _optionId) set_option_console_preset(value),
  [USEROPT_AILERONS_MULTIPLIER] = @(value, _descr, _optionId) set_option_multiplier(OPTION_AILERONS_MULTIPLIER, value / 100.0),
  [USEROPT_ELEVATOR_MULTIPLIER] = @(value, _descr, _optionId) set_option_multiplier(OPTION_ELEVATOR_MULTIPLIER, value / 100.0),
  [USEROPT_RUDDER_MULTIPLIER] = @(value, _descr, _optionId) set_option_multiplier(OPTION_RUDDER_MULTIPLIER, value / 100.0),
  [USEROPT_ZOOM_SENSE] = @(value, _descr, _optionId) set_option_multiplier(OPTION_ZOOM_SENSE, (100.0 - value) / 100.0),
  [USEROPT_MOUSE_SENSE] = @(value, _descr, _optionId) set_option_multiplier(OPTION_MOUSE_SENSE, value / 50.0),
  [USEROPT_JOY_MIN_VIBRATION] = @(value, _descr, _optionId) set_option_multiplier(OPTION_JOY_MIN_VIBRATION, value / 100.0),
  [USEROPT_MOUSE_AIM_SENSE] = @(value, _descr, _optionId) set_option_multiplier(OPTION_MOUSE_AIM_SENSE, value / 50.0),
  [USEROPT_GUNNER_VIEW_SENSE] = @(value, _descr, _optionId) set_option_multiplier(OPTION_GUNNER_VIEW_SENSE, value / 100.0),
  [USEROPT_GUNNER_VIEW_ZOOM_SENS] = @(value, _descr, _optionId) set_option_multiplier(OPTION_GUNNER_VIEW_ZOOM_SENS, value / 100.0),
  [USEROPT_ATGM_AIM_SENS_HELICOPTER] = @(value, _descr, _optionId) set_option_multiplier(OPTION_ATGM_AIM_SENS_HELICOPTER, value / 100.0),
  [USEROPT_ATGM_AIM_ZOOM_SENS_HELICOPTER] = @(value, _descr, _optionId) set_option_multiplier(OPTION_ATGM_AIM_ZOOM_SENS_HELICOPTER, value / 100.0),
  [USEROPT_MOUSE_SMOOTH] = @(value, _descr, _optionId) set_option_mouse_smooth(value ? 1 : 0),
  [USEROPT_VOLUME_MASTER] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_MASTER, value / 100.0, true),
  [USEROPT_VOLUME_MUSIC] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_MUSIC, value / 100.0, true),
  [USEROPT_VOLUME_MENU_MUSIC] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_MENU_MUSIC, value / 100.0, true),
  [USEROPT_VOLUME_SFX] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_SFX, value / 100.0, true),
  [USEROPT_VOLUME_RADIO] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_RADIO, value / 100.0, true),
  [USEROPT_VOLUME_ENGINE] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_ENGINE, value / 100.0, true),
  [USEROPT_VOLUME_MY_ENGINE] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_MY_ENGINE, value / 100.0, true),
  [USEROPT_VOLUME_DIALOGS] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_DIALOGS, value / 100.0, true),
  [USEROPT_VOLUME_GUNS] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_GUNS, value / 100.0, true),
  [USEROPT_VOLUME_VWS] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_VWS, value / 100.0, true),
  [USEROPT_VOLUME_RWR] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_RWR, value / 100.0, true),
  [USEROPT_VOLUME_TINNITUS] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_TINNITUS, value / 100.0, true),
  [USEROPT_HANGAR_SOUND] = @(value, _descr, _optionId) set_option_hangar_sound(value),
  [USEROPT_VOLUME_VOICE_IN] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_VOICE_IN, value / 100.0, true),
  [USEROPT_VOLUME_VOICE_OUT] = @(value, _descr, _optionId) set_sound_volume(SND_TYPE_VOICE_OUT, value / 100.0, true),
  [USEROPT_CONTROLS_PRESET] = function(value, descr, _optionId) {
    if (descr.values[value] != "")
      ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename(descr.values[value]))
  },
  [USEROPT_COUNTRY] = @(value, descr, _optionId) switchProfileCountry(descr.values[value]),
  [USEROPT_PILOT] = @(value, descr, _optionId) set_profile_pilot(descr.values[value]),
  [USEROPT_CROSSHAIR_TYPE] = @(value, descr, _optionId) set_hud_crosshair_type(descr.values[value]),
  [USEROPT_CROSSHAIR_COLOR] = function(value, descr, _optionId) {
    let curVal = descr.values[value]
    set_hud_crosshair_color(curVal)
    let color = color4ToInt(crosshair_colors[curVal].color)
    crosshairColorOpt(color)
  },
  [USEROPT_CROSSHAIR_DEFLECTION] = @(value, _descr, _optionId) set_option_deflection(value),
  [USEROPT_GYRO_SIGHT_DEFLECTION] = @(value, _descr, _optionId) set_gyro_sight_deflection(value),
  [USEROPT_SHOW_INDICATORS] = function(value, _descr, _optionId) {
    if (value)
      ::set_option_indicators_mode(get_option_indicators_mode() | HUD_INDICATORS_SHOW)
    else
      ::set_option_indicators_mode(get_option_indicators_mode() & ~HUD_INDICATORS_SHOW)
  },
  [USEROPT_HUD_SCREENSHOT_LOGO] = @(value, _descr, _optionId) set_option_hud_screenshot_logo(value),
  [USEROPT_HUD_SHOW_FUEL] = @(value, descr, _optionId) set_option_hud_show_fuel(descr.values[value]),
  [USEROPT_HUD_SHOW_AMMO] = @(value, descr, _optionId) set_option_hud_show_ammo(descr.values[value]),
  [USEROPT_HUD_SHOW_TEMPERATURE] = @(value, descr, _optionId) set_option_hud_show_temperature(descr.values[value]),
  [USEROPT_MENU_SCREEN_SAFE_AREA] = function(value, descr, _optionId) {
    if (value >= 0 && value < descr.values.len()) {
      safeAreaMenu.setValue(descr.values[value])
      handlersManager.checkPostLoadCssOnBackToBaseHandler()
    }
  },
  [USEROPT_HUD_SCREEN_SAFE_AREA] = function(value, descr, _optionId) {
    if (value >= 0 && value < descr.values.len()) {
      safeAreaHud.setValue(descr.values[value])
      handlersManager.checkPostLoadCssOnBackToBaseHandler()
    }
  },
  [USEROPT_AUTOPILOT_ON_BOMBVIEW] = @(value, descr, _optionId) set_option_autopilot_on_bombview(descr.values[value]),
  [USEROPT_AUTOREARM_ON_AIRFIELD] = @(value, _descr, _optionId) set_option_autorearm_on_airfield(value),
  [USEROPT_ENABLE_LASER_DESIGNATOR_ON_LAUNCH] = @(value, _descr, _optionId) set_enable_laser_designatior_before_launch(value),
  [USEROPT_AUTO_SEEKER_STABILIZATION] = @(value, _descr, _optionId) set_option_seeker_auto_stabilization(value),
  [USEROPT_ACTIVATE_AIRBORNE_RADAR_ON_SPAWN] = @(value, _descr, _optionId) set_option_activate_airborne_radar_on_spawn(value),
  [USEROPT_USE_RECTANGULAR_RADAR_INDICATOR] = @(value, _descr, _optionId) set_option_use_rectangular_radar_indicator(value),
  [USEROPT_RADAR_TARGET_CYCLING] = @(value, _descr, _optionId) set_option_radar_target_cycling(value),
  [USEROPT_RADAR_AIM_ELEVATION_CONTROL] = @(value, _descr, _optionId) set_option_radar_aim_elevation_control(value),
  [USEROPT_RWR_SENSITIVITY] = @(value, _descr, _optionId) set_option_rwr_sensitivity(value),
  [USEROPT_RADAR_MODE_SELECT] = @(value, _descr, _optionId) set_option_radar_name(value),
  [USEROPT_RADAR_SCAN_PATTERN_SELECT] = @(value, _descr, _optionId) set_option_radar_scan_pattern_name(value),
  [USEROPT_RADAR_SCAN_RANGE_SELECT] = @(value, _descr, _optionId) set_option_radar_range_value(value),
  [USEROPT_USE_RADAR_HUD_IN_COCKPIT] = @(value, _descr, _optionId) set_option_use_radar_hud_in_cockpit(value),
  [USEROPT_USE_TWS_HUD_IN_COCKPIT] = @(value, _descr, _optionId) set_option_use_tws_hud_in_cockpit(value),
  [USEROPT_ACTIVATE_AIRBORNE_ACTIVE_COUNTER_MEASURES_ON_SPAWN] = @(value, _descr, _optionId) set_option_activate_airborne_active_counter_measures_on_spawn(value),
  [USEROPT_SAVE_AI_TARGET_TYPE] = @(value, _descr, _optionId) set_option_ai_target_type(value ? 1 : 0),
  [USEROPT_DEFAULT_AI_TARGET_TYPE] = @(value, _descr, _optionId) set_option_default_ai_target_type(value),
  [USEROPT_ACTIVATE_AIRBORNE_WEAPON_SELECTION_ON_SPAWN] = def_set_gui_option,
  [USEROPT_ACTIVATE_BOMBS_AUTO_RELEASE_ON_SPAWN] = @(value, _descr, _optionId) set_activate_bombs_auto_release_on_spawn(value),
  [USEROPT_AUTOMATIC_EMPTY_CONTAINERS_JETTISON] = def_set_gui_option,
  [USEROPT_SHOW_INDICATORS_TYPE] = function(value, descr, _optionId) {
    local val = get_option_indicators_mode() & ~(HUD_INDICATORS_SELECT | HUD_INDICATORS_CENTER | HUD_INDICATORS_ALL)
    if (descr.values[value] == 0)
      val = val | HUD_INDICATORS_SELECT
    if (descr.values[value] == 1)
      val = val | HUD_INDICATORS_CENTER
    if (descr.values[value] == 2)
      val = val | HUD_INDICATORS_ALL
    set_option_indicators_mode(val)
  },
  [USEROPT_SHOW_INDICATORS_NICK] = function(value, descr, _optionId) {
    local val = get_option_indicators_mode() & ~(HUD_INDICATORS_TEXT_NICK_ALL | HUD_INDICATORS_TEXT_NICK_SQUAD)
    val = val | descr.values[value]
    set_option_indicators_mode(val)
  },
  [USEROPT_SHOW_INDICATORS_TITLE] = function(value, _descr, _optionId) {
    if (value)
      ::set_option_indicators_mode(get_option_indicators_mode() | HUD_INDICATORS_TEXT_TITLE)
    else
      ::set_option_indicators_mode(get_option_indicators_mode() & ~HUD_INDICATORS_TEXT_TITLE)
  },
  [USEROPT_SHOW_INDICATORS_AIRCRAFT] = function(value, _descr, _optionId) {
    if (value)
      ::set_option_indicators_mode(get_option_indicators_mode() | HUD_INDICATORS_TEXT_AIRCRAFT)
    else
      ::set_option_indicators_mode(get_option_indicators_mode() & ~HUD_INDICATORS_TEXT_AIRCRAFT)
  },
  [USEROPT_SHOW_INDICATORS_DIST] = function(value, _descr, _optionId) {
    if (value)
      ::set_option_indicators_mode(get_option_indicators_mode() | HUD_INDICATORS_TEXT_DIST)
    else
      ::set_option_indicators_mode(get_option_indicators_mode() & ~HUD_INDICATORS_TEXT_DIST)
  },
  [USEROPT_SAVE_ZOOM_CAMERA] = @(value, _descr, _optionId) set_option_save_zoom_camera(value),
  [USEROPT_SKIN] = function(value, descr, optionId) {
    if (type(descr.values) == "array") {
      let air = ::aircraft_for_weapons
      if (value >= 0 && value < descr.values.len()) {
        let isAutoSkin = descr.access[value].isAutoSkin
        set_gui_option(optionId, descr.values[value] ?? "")
        setLastSkin(air, isAutoSkin ? null : descr.values[value])
      }
      else
        print($"[ERROR] value '{value}' is out of range")
    }
    else
      print($"[ERROR] No values set for type '{optionId}'")
  },
  [USEROPT_USER_SKIN] = function(value, descr, _optionId) {
    let cdb = get_user_skins_profile_blk()
    if (::cur_aircraft_name) {
      if (cdb?[::cur_aircraft_name] != getTblValue(value, descr.values, "")) {
        cdb[::cur_aircraft_name] = getTblValue(value, descr.values, "")
        saveProfile()
      }
    }
    else {
      log("[ERROR] ::cur_aircraft_name is null")
      debug_dump_stack()
    }
  },
  [USEROPT_FONTS_CSS] = function(value, descr, _optionId) {
    let selFont = getTblValue(value, descr.values)
    if (selFont && ::g_font.setCurrent(selFont))
      handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_SQUAD] = function(value, descr, _optionId) {
    set_hue(TARGET_HUE_SQUAD, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_ALLY] = function(value, descr, _optionId) {
    set_hue(TARGET_HUE_ALLY, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_ENEMY] = function(value, descr, _optionId) {
    set_hue(TARGET_HUE_ENEMY, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_SPECTATOR_ALLY] = function(value, descr, _optionId) {
    set_hue(TARGET_HUE_SPECTATOR_ALLY, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_SPECTATOR_ENEMY] = function(value, descr, _optionId) {
    set_hue(TARGET_HUE_SPECTATOR_ENEMY, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_RELOAD] = function(value, descr, _optionId) {
    set_hue(TARGET_HUE_RELOAD, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_RELOAD_DONE] = function(value, descr, _optionId) {
    set_hue(TARGET_HUE_RELOAD_DONE, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_STROBE_ALLY] = @(value, descr, _optionId) set_strobe_ally(descr.values[value]),
  [USEROPT_STROBE_ENEMY] = @(value, descr, _optionId) set_strobe_enemy(descr.values[value]),
  [USEROPT_AIR_DAMAGE_DISPLAY] = def_set_gui_option,
  [USEROPT_GUNNER_FPS_CAMERA] = def_set_gui_option,
  [USEROPT_HUE_AIRCRAFT_HUD] = function(value, descr, _optionId) {
    let { sat = 1.0, val = 1.0 } = descr.items[value]
    setHsb(TARGET_HUE_AIRCRAFT_HUD, descr.values[value], sat, val)
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_AIRCRAFT_PARAM_HUD] = function(value, descr, _optionId) {
    let { sat = 1.0, val = 1.0 } = descr.items[value]
    setHsb(TARGET_HUE_AIRCRAFT_PARAM_HUD, descr.values[value], sat, val)
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_AIRCRAFT_HUD_ALERT] = function(value, descr, _optionId) {
    let [ v1, v2, v3 ] = descr.values[value]
    setAlertAircraftHues(v1, v2, v3, value)
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_HELICOPTER_CROSSHAIR] = function(value, descr, _optionId) {
    let { sat = 1.0, val = 1.0 } = descr.items[value]
    setHsb(TARGET_HUE_HELICOPTER_CROSSHAIR, descr.values[value], sat, val)
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_HELICOPTER_HUD] = function(value, descr, _optionId) {
    let { sat = 1.0, val = 1.0 } = descr.items[value]
    setHsb(TARGET_HUE_HELICOPTER_HUD, descr.values[value], sat, val)
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_HELICOPTER_PARAM_HUD] = function(value, descr, _optionId) {
    let { sat = 1.0, val = 1.0 } = descr.items[value]
    setHsb(TARGET_HUE_HELICOPTER_PARAM_HUD, descr.values[value], sat, val)
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HORIZONTAL_SPEED] = @(value, _descr, _optionId) set_option_horizontal_speed(value ? 1 : 0),
  [USEROPT_HELICOPTER_HELMET_AIM] = @(value, _descr, _optionId) set_option_use_oculus_to_aim_helicopter(value ? 1 : 0),
  [USEROPT_HELICOPTER_AUTOPILOT_ON_GUNNERVIEW] = @(value, _descr, _optionId) set_option_auto_pilot_on_gunner_view_helicopter(value),
  [USEROPT_HUE_HELICOPTER_HUD_ALERT] = function(value, descr, _optionId) {
    if (hasFeature("reactivGuiForAircraft"))
      setAlertHelicopterHues(descr.values[value][0], descr.values[value][1], descr.values[value][2], value)
    else
      set_hue(TARGET_HUE_HELICOPTER_HUD_ALERT_HIGH, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_HELICOPTER_MFD] = function(value, descr, _optionId) {
    set_hue(TARGET_HUE_HELICOPTER_MFD, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_ARBITER_HUD] = function(value, descr, _optionId) {
    let { sat = 0.0, val = 1.0 } = descr.items[value]
    setHsb(TARGET_HUE_ARBITER_HUD, descr.values[value], sat, val)
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
  },
  [USEROPT_HUE_TANK_THERMOVISION] = function(value, descr, optionId) {
    setHSVOption_ThermovisionColor(descr, descr.values[value])
    handlersManager.checkPostLoadCssOnBackToBaseHandler()
    set_gui_option(optionId, value)
  },
  [USEROPT_ENABLE_CONSOLE_MODE] = @(value, _descr, _optionId) ::switch_show_console_buttons(value),
  //


  [USEROPT_CD_ENGINE] = set_useropt_cd,
  [USEROPT_CD_GUNNERY] = set_useropt_cd,
  [USEROPT_CD_DAMAGE] = set_useropt_cd,
  [USEROPT_CD_STALLS] = set_useropt_cd,
  [USEROPT_CD_REDOUT] = set_useropt_cd,
  [USEROPT_CD_MORTALPILOT] = set_useropt_cd,
  [USEROPT_CD_FLUTTER] = set_useropt_cd,
  [USEROPT_CD_BOMBS] = set_useropt_cd,
  [USEROPT_CD_BOOST] = set_useropt_cd,
  [USEROPT_CD_TPS] = set_useropt_cd,
  [USEROPT_CD_AIM_PRED] = set_useropt_cd,
  [USEROPT_CD_MARKERS] = set_useropt_cd,
  [USEROPT_CD_ARROWS] = set_useropt_cd,
  [USEROPT_CD_AIRCRAFT_MARKERS_MAX_DIST] = set_useropt_cd,
  [USEROPT_CD_INDICATORS] = set_useropt_cd,
  [USEROPT_CD_SPEED_VECTOR] = set_useropt_cd,
  [USEROPT_CD_TANK_DISTANCE] = set_useropt_cd,
  [USEROPT_CD_MAP_AIRCRAFT_MARKERS] = set_useropt_cd,
  [USEROPT_CD_MAP_GROUND_MARKERS] = set_useropt_cd,
  [USEROPT_CD_MARKERS_BLINK] = set_useropt_cd,
  [USEROPT_CD_RADAR] = set_useropt_cd,
  [USEROPT_CD_DAMAGE_IND] = set_useropt_cd,
  [USEROPT_CD_LARGE_AWARD_MESSAGES] = set_useropt_cd,
  [USEROPT_CD_WARNINGS] = set_useropt_cd,
  [USEROPT_CD_AIR_HELPERS] = set_useropt_cd,
  [USEROPT_CD_ALLOW_CONTROL_HELPERS] = set_useropt_cd,
  [USEROPT_CD_FORCE_INSTRUCTOR] = set_useropt_cd,
  [USEROPT_CD_DISTANCE_DETECTION] = set_useropt_cd,
  [USEROPT_CD_COLLECTIVE_DETECTION] = set_useropt_cd,
  [USEROPT_RANK] = set_useropt_cd,
  [USEROPT_REPLAY_LOAD_COCKPIT] = set_useropt_cd,
  [USEROPT_HELPERS_MODE] = set_useropt_helpers_mode,
  [USEROPT_MOUSE_USAGE] = set_useropt_helpers_mode,
  [USEROPT_MOUSE_USAGE_NO_AIM] = set_useropt_helpers_mode,
  [USEROPT_INSTRUCTOR_ENABLED] = set_useropt_helpers_mode,
  [USEROPT_AUTOTRIM] = set_useropt_helpers_mode,
  [USEROPT_INSTRUCTOR_GROUND_AVOIDANCE] = set_useropt_instructor_ground_avoidance,
  [USEROPT_INSTRUCTOR_GEAR_CONTROL] = set_useropt_instructor_ground_avoidance,
  [USEROPT_INSTRUCTOR_FLAPS_CONTROL] = set_useropt_instructor_ground_avoidance,
  [USEROPT_INSTRUCTOR_ENGINE_CONTROL] = set_useropt_instructor_ground_avoidance,
  [USEROPT_INSTRUCTOR_SIMPLE_JOY] = set_useropt_instructor_ground_avoidance,
  [USEROPT_MAP_ZOOM_BY_LEVEL] = set_useropt_instructor_ground_avoidance,
  [USEROPT_SHOW_COMPASS_IN_TANK_HUD] = set_useropt_instructor_ground_avoidance,
  [USEROPT_PITCH_BLOCKER_WHILE_BRACKING] = set_useropt_instructor_ground_avoidance,
  [USEROPT_SAVE_DIR_WHILE_SWITCH_TRIGGER] = set_useropt_instructor_ground_avoidance,
  [USEROPT_HIDE_MOUSE_SPECTATOR] = set_useropt_instructor_ground_avoidance,
  [USEROPT_FIX_GUN_IN_MOUSE_LOOK] = set_useropt_instructor_ground_avoidance,
  [USEROPT_ENABLE_SOUND_SPEED] = set_useropt_instructor_ground_avoidance,
  [USEROPT_VWS_ONLY_IN_COCKPIT] = function(value, descr, _optionId) {
    let optionIdx = getTblValue("boolOptionIdx", descr, -1)
    if (optionIdx >= 0 && u.isBool(value))
      set_option_bool(optionIdx, value)
  },
  [USEROPT_COMMANDER_CAMERA_IN_VIEWS] = @(value, _descr, _optionId) set_commander_camera_in_views(value),
  [USEROPT_TAKEOFF_MODE] = function(value, descr, optionId) {
    if (descr.values.len() > 1 && (value in descr.values))
      set_gui_option(optionId, descr.values[value])
  },
  [USEROPT_MISSION_COUNTRIES_TYPE] = function(value, descr, optionId) {
    if (value in descr.values) {
      set_gui_option(optionId, descr.values[value])
      ::mission_settings.countriesType <- descr.values[value]
    }
  },
  [USEROPT_BIT_COUNTRIES_TEAM_A] = set_useropt_bit_countries_team_a,
  [USEROPT_BIT_COUNTRIES_TEAM_B] = set_useropt_bit_countries_team_a,
  [USEROPT_COUNTRIES_SET] = function(value, descr, optionId) {
    if (value not in descr.values)
      return
    set_gui_option(optionId, value)
    descr?.onChangeCb(optionId, value, value)
  },
  [USEROPT_BIT_UNIT_TYPES] = function(value, descr, optionId) {
    if (value <= 0)
      return

    set_gui_option(optionId, value)
    ::mission_settings.userAllowedUnitTypesMask <- descr.availableUnitTypesMask & value
  },
  [USEROPT_BR_MIN] = set_useropt_br_min,
  [USEROPT_BR_MAX] = set_useropt_br_min,
  [USEROPT_BIT_CHOOSE_UNITS_TYPE] = def_set_gui_option,
  [USEROPT_BIT_CHOOSE_UNITS_RANK] = def_set_gui_option,
  [USEROPT_BIT_CHOOSE_UNITS_OTHER] = def_set_gui_option,
  [USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE] = def_set_gui_option,
  [USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST] = def_set_gui_option,
  [USEROPT_MP_TEAM_COUNTRY_RAND] = set_useropt_mp_team_country_rand,
  [USEROPT_MP_TEAM_COUNTRY] = set_useropt_mp_team_country_rand,
  [USEROPT_SESSION_PASSWORD] = @(value, _descr, _optionId) ::SessionLobby.changePassword(value ? value : ""),
  [USEROPT_BULLETS0] = set_useropt_bullets0,
  [USEROPT_BULLETS1] = set_useropt_bullets0,
  [USEROPT_BULLETS2] = set_useropt_bullets0,
  [USEROPT_BULLETS3] = set_useropt_bullets0,
  [USEROPT_BULLETS4] = set_useropt_bullets0,
  [USEROPT_BULLETS5] = set_useropt_bullets0,
  [USEROPT_HELPERS_MODE_GM] = @(value, descr, _optionId) set_gui_option(USEROPT_HELPERS_MODE, descr.values[value]),
  [USEROPT_LANDING_MODE] = set_useropt_landing_mode,
  [USEROPT_ALLOW_JIP] = set_useropt_landing_mode,
  [USEROPT_QUEUE_JIP] = set_useropt_landing_mode,
  [USEROPT_AUTO_SQUAD] = set_useropt_landing_mode,
  [USEROPT_ORDER_AUTO_ACTIVATE] = set_useropt_landing_mode,
  [USEROPT_FRIENDS_ONLY] = set_useropt_landing_mode,
  [USEROPT_VERSUS_NO_RESPAWN] = set_useropt_landing_mode,
  [USEROPT_OFFLINE_MISSION] = set_useropt_landing_mode,
  [USEROPT_VERSUS_RESPAWN] = set_useropt_landing_mode,
  [USEROPT_MP_TEAM] = set_useropt_landing_mode,
  [USEROPT_DMP_MAP] = set_useropt_landing_mode,
  [USEROPT_DYN_MAP] = set_useropt_landing_mode,
  [USEROPT_DYN_ZONE] = set_useropt_landing_mode,
  [USEROPT_DYN_ALLIES] = set_useropt_landing_mode,
  [USEROPT_DYN_ENEMIES] = set_useropt_landing_mode,
  [USEROPT_DYN_SURROUND] = set_useropt_landing_mode,
  [USEROPT_DYN_FL_ADVANTAGE] = set_useropt_landing_mode,
  [USEROPT_DYN_WINS_TO_COMPLETE] = set_useropt_landing_mode,
  [USEROPT_TIME] = set_useropt_landing_mode,
  [USEROPT_CLIME] = set_useropt_landing_mode,
  [USEROPT_YEAR] = set_useropt_landing_mode,
  [USEROPT_DIFFICULTY] = set_useropt_landing_mode,
  [USEROPT_ALTITUDE] = set_useropt_landing_mode,
  [USEROPT_TIME_LIMIT] = set_useropt_landing_mode,
  [USEROPT_KILL_LIMIT] = set_useropt_landing_mode,
  [USEROPT_TIME_SPAWN] = set_useropt_landing_mode,
  [USEROPT_TICKETS] = set_useropt_landing_mode,
  [USEROPT_LIMITED_FUEL] = set_useropt_landing_mode,
  [USEROPT_LIMITED_AMMO] = set_useropt_landing_mode,
  [USEROPT_FRIENDLY_SKILL] = set_useropt_landing_mode,
  [USEROPT_ENEMY_SKILL] = set_useropt_landing_mode,
  [USEROPT_MODIFICATIONS] = set_useropt_landing_mode,
  [USEROPT_AAA_TYPE] = set_useropt_landing_mode,
  [USEROPT_SITUATION] = set_useropt_landing_mode,
  [USEROPT_SEARCH_DIFFICULTY] = set_useropt_landing_mode,
  [USEROPT_SEARCH_GAMEMODE] = set_useropt_landing_mode,
  [USEROPT_SEARCH_GAMEMODE_CUSTOM] = set_useropt_landing_mode,
  [USEROPT_NUM_PLAYERS] = set_useropt_landing_mode,
  [USEROPT_NUM_FRIENDLIES] = set_useropt_landing_mode,
  [USEROPT_NUM_ENEMIES] = set_useropt_landing_mode,
  [USEROPT_NUM_ATTEMPTS] = set_useropt_landing_mode,
  [USEROPT_OPTIONAL_TAKEOFF] = set_useropt_landing_mode,
  [USEROPT_TIME_BETWEEN_RESPAWNS] = set_useropt_landing_mode,
  [USEROPT_LB_TYPE] = set_useropt_landing_mode,
  [USEROPT_LB_MODE] = set_useropt_landing_mode,
  [USEROPT_IS_BOTS_ALLOWED] = set_useropt_landing_mode,
  [USEROPT_USE_TANK_BOTS] = set_useropt_landing_mode,
  [USEROPT_USE_SHIP_BOTS] = set_useropt_landing_mode,
  [USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS] = set_useropt_landing_mode,
  [USEROPT_DISABLE_AIRFIELDS] = set_useropt_landing_mode,
  [USEROPT_ALLOW_EMPTY_TEAMS] = set_useropt_landing_mode,
  [USEROPT_KEEP_DEAD] = set_useropt_landing_mode,
  [USEROPT_DEDICATED_REPLAY] = set_useropt_landing_mode,
  [USEROPT_AUTOBALANCE] = set_useropt_landing_mode,
  [USEROPT_MAX_PLAYERS] = set_useropt_landing_mode,
  [USEROPT_MIN_PLAYERS] = set_useropt_landing_mode,
  [USEROPT_ROUNDS] = set_useropt_landing_mode,
  [USEROPT_COMPLAINT_CATEGORY] = set_useropt_landing_mode,
  [USEROPT_BAN_PENALTY] = set_useropt_landing_mode,
  [USEROPT_BAN_TIME] = set_useropt_landing_mode,
  [USEROPT_ONLY_FRIENDLIST_CONTACT] = set_useropt_landing_mode,
  [USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL] = set_useropt_landing_mode,
  [USEROPT_RACE_LAPS] = set_useropt_landing_mode,
  [USEROPT_RACE_WINNERS] = set_useropt_landing_mode,
  [USEROPT_RACE_CAN_SHOOT] = set_useropt_landing_mode,
  [USEROPT_USE_KILLSTREAKS] = set_useropt_landing_mode,
  [USEROPT_AUTOMATIC_TRANSMISSION_TANK] = set_useropt_landing_mode,
  [USEROPT_WHEEL_CONTROL_SHIP] = set_useropt_landing_mode,
  [USEROPT_JOYFX] = set_useropt_landing_mode,
  [USEROPT_SEPERATED_ENGINE_CONTROL_SHIP] = set_useropt_landing_mode,
  [USEROPT_BULLET_FALL_INDICATOR_SHIP] = set_useropt_landing_mode,
  [USEROPT_BULLET_FALL_SOUND_SHIP] = set_useropt_landing_mode,
  [USEROPT_SINGLE_SHOT_BY_TURRET] = set_useropt_landing_mode,
  [USEROPT_AUTO_TARGET_CHANGE_SHIP] = set_useropt_landing_mode,
  [USEROPT_REALISTIC_AIMING_SHIP] = set_useropt_landing_mode,
  [USEROPT_TORPEDO_AUTO_SWITCH] = set_useropt_landing_mode,
  [USEROPT_DEFAULT_TORPEDO_FORESTALL_ACTIVE] = set_useropt_landing_mode,
  [USEROPT_REPLAY_ALL_INDICATORS] = set_useropt_landing_mode,
  [USEROPT_CONTENT_ALLOWED_PRESET_ARCADE] = set_useropt_landing_mode,
  [USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC] = set_useropt_landing_mode,
  [USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR] = set_useropt_landing_mode,
  [USEROPT_CONTENT_ALLOWED_PRESET] = set_useropt_landing_mode,
  [USEROPT_GAMEPAD_VIBRATION_ENGINE] = set_useropt_landing_mode,
  [USEROPT_GAMEPAD_ENGINE_DEADZONE] = set_useropt_landing_mode,
  [USEROPT_GAMEPAD_GYRO_TILT_CORRECTION] = set_useropt_landing_mode,
  [USEROPT_FOLLOW_BULLET_CAMERA] = set_useropt_landing_mode,
  [USEROPT_BULLET_FALL_SPOT_SHIP] = set_useropt_landing_mode,
  [USEROPT_AUTO_AIMLOCK_ON_SHOOT] = set_useropt_landing_mode,
  [USEROPT_ALTERNATIVE_TPS_CAMERA] = set_useropt_landing_mode,
  [USEROPT_HOLIDAYS] = set_useropt_landing_mode,
  [USEROPT_HUD_SHOW_TANK_GUNS_AMMO] = function(value, descr, optionId) {
    def_set_gui_option(value, descr, optionId)
    isVisibleTankGunsAmmoIndicator(value)
  },
  [USEROPT_HUD_VISIBLE_ORDERS] = set_useropt_landing_mode,
  [USEROPT_HUD_VISIBLE_REWARDS_MSG] = set_useropt_landing_mode,
  [USEROPT_HUD_VISIBLE_STREAKS] = set_useropt_landing_mode,
  [USEROPT_HUD_VISIBLE_KILLLOG] = set_useropt_landing_mode,
  [USEROPT_HUD_SHOW_NAMES_IN_KILLLOG] = set_useropt_landing_mode,
  [USEROPT_HUD_SHOW_AMMO_TYPE_IN_KILLLOG] = def_set_gui_option,
  [USEROPT_HUD_SHOW_SQUADRON_NAMES_IN_KILLLOG] = def_set_gui_option,
  [USEROPT_HUD_SHOW_DEATH_REASON_IN_SHIP_KILLLOG] = def_set_gui_option,
  [USEROPT_HUD_VISIBLE_CHAT_PLACE] = set_useropt_landing_mode,
  [USEROPT_CAN_QUEUE_TO_NIGHT_BATLLES] = set_useropt_landing_mode,
  [USEROPT_CAN_QUEUE_TO_SMALL_TEAMS_BATTLES] = set_useropt_landing_mode,
  [USEROPT_SHOW_OTHERS_DECALS] = set_useropt_landing_mode,
  [USEROPT_SHOW_ACTION_BAR] = def_set_gui_option,
  [USEROPT_AUTOLOGIN] = @(value, _descr, _optionId) ::set_autologin_enabled(value),
  [USEROPT_DAMAGE_INDICATOR_SIZE] = set_useropt_damage_indicator_size,
  [USEROPT_TACTICAL_MAP_SIZE] = set_useropt_damage_indicator_size,
  [USEROPT_AIR_RADAR_SIZE] = @(value, _descr, optionId) ::set_gui_option_in_mode(optionId, value, OPTIONS_MODE_GAMEPLAY),
  [USEROPT_CLUSTERS] = function(value, descr, optionId) {
    if (value >= 0 && value < descr.values.len())
      ::set_gui_option_in_mode(optionId, descr.values[value], OPTIONS_MODE_MP_DOMINATION)
  },
  [USEROPT_RANDB_CLUSTERS] = function(value, descr, optionId) {
    if (value >= 0 && value <= (1 << descr.values.len()) - 1) {
      let autoIdx = descr.values.findindex(@(v) v == "auto")

      local prevVal = get_option(USEROPT_RANDB_CLUSTERS).value
      local isAutoSelected = false
      local isAutoDeselected = false
      if (autoIdx != null) {
        let prevAutoVal = is_bit_set(prevVal, autoIdx)
        let curAutoVal = is_bit_set(value, autoIdx)
        isAutoSelected = !prevAutoVal && curAutoVal
        isAutoDeselected = prevAutoVal && !curAutoVal
      }

      local clusters = isAutoSelected ? ["auto"]
        : isAutoDeselected ? descr.values.filter(@(_, i) descr.items[i].isVisible && descr.items[i].isDefault)
        : (value == 0) && (autoIdx != null) ? ["auto"]
        : descr.values.filter(@(_, i) !descr.items[i].isAuto && descr.items[i].isVisible && is_bit_set(value, i))

      if (clusters.len() == 0) //all selected clusters may not be visible when unselect Auto cluster
        clusters = descr.values.filter(@(_, i) descr.items[i].isVisible && !descr.items[i].isAuto)

      let newVal = ";".join(clusters)
      ::set_gui_option_in_mode(optionId, newVal, OPTIONS_MODE_MP_DOMINATION)
      broadcastEvent("ClusterChange")
    }
  },
  [USEROPT_PLAY_INACTIVE_WINDOW_SOUND] = def_set_gui_option,
  [USEROPT_INTERNET_RADIO_ACTIVE] = function(value, _descr, _optionId) {
    let internet_radio_options = get_internet_radio_options()
    internet_radio_options["active"] = value
    set_internet_radio_options(internet_radio_options)
  },
  [USEROPT_INTERNET_RADIO_STATION] = function(value, descr, _optionId) {
    let station = descr.values[value]
    if (station != "") {
      let internet_radio_options = get_internet_radio_options()
      internet_radio_options["station"] = station
      set_internet_radio_options(internet_radio_options)
    }
  },
  [USEROPT_COOP_MODE] = function(_value, _descr, _optionId) {
    //dont save this one!
    set_gui_option(USEROPT_COOP_MODE, 0)
  },
  [USEROPT_VOICE_DEVICE_IN] = @(value, descr, _optionId) soundDevice.set_last_voice_device_in(descr.values?[value] ?? ""),
  [USEROPT_SOUND_DEVICE_OUT] = @(value, descr, _optionId) soundDevice.set_last_sound_device_out(descr.values?[value] ?? ""),
  [USEROPT_HEADTRACK_ENABLE] = @(value, _descr, _optionId) ps4_headtrack_set_enable(value),
  [USEROPT_HEADTRACK_SCALE_X] = @(value, _descr, _optionId) ps4_headtrack_set_xscale(value),
  [USEROPT_HEADTRACK_SCALE_Y] = @(value, _descr, _optionId) ps4_headtrack_set_yscale(value),
  [USEROPT_MISSION_NAME_POSTFIX] = function(value, descr, optionId) {
    let currentCampaignMission = getCurrentCampaignMission()
    if (currentCampaignMission != null) {
      let metaInfo = getUrlOrFileMissionMetaInfo(currentCampaignMission)
      let values = ::get_mission_types_from_meta_mission_info(metaInfo)
      if (values.len() > 0) {
        let optValue = descr.values[value]
        if (optValue.len())
          ::mission_settings.postfix = optValue
        else
          ::mission_settings.postfix = values[rnd() % values.len()]
        set_gui_option(optionId, optValue)
      }
    }
  },
  [USEROPT_SHOW_DESTROYED_PARTS] = @(value, _descr, _optionId) set_show_destroyed_parts(value),
  [USEROPT_ACTIVATE_GROUND_RADAR_ON_SPAWN] = @(value, _descr, _optionId) set_activate_ground_radar_on_spawn(value),
  [USEROPT_GROUND_RADAR_TARGET_CYCLING] = @(value, _descr, _optionId) set_option_ground_radar_target_cycling(value),
  [USEROPT_ACTIVATE_GROUND_ACTIVE_COUNTER_MEASURES_ON_SPAWN] = @(value, _descr, _optionId) set_activate_ground_active_counter_measures_on_spawn(value),
  [USEROPT_FPS_CAMERA_PHYSICS] = @(value, _descr, _optionId) set_option_multiplier(OPTION_FPS_CAMERA_PHYS, value / 100.0),
  [USEROPT_FPS_VR_CAMERA_PHYSICS] = @(value, _descr, _optionId) set_option_multiplier(OPTION_FPS_VR_CAMERA_PHYS, value / 100.0),
  [USEROPT_FREE_CAMERA_INERTIA] = @(value, _descr, _optionId) set_option_multiplier(OPTION_FREE_CAMERA_INERTIA, value / 100.0),
  [USEROPT_REPLAY_CAMERA_WIGGLE] = @(value, _descr, _optionId) set_option_multiplier(OPTION_REPLAY_CAMERA_WIGGLE, value / 100.0),
  [USEROPT_TANK_GUNNER_CAMERA_FROM_SIGHT] = @(value, _descr, _optionId) set_option_tank_gunner_camera_from_sight(value),
  [USEROPT_TANK_ALT_CROSSHAIR] = function(value, descr, _optionId) {
    let unit = getPlayerCurUnit()
    let val = descr.values[value]
    if (unit && val != TANK_ALT_CROSSHAIR_ADD_NEW)
      set_option_tank_alt_crosshair(unit.name, val)
  },
  [USEROPT_SHIP_COMBINE_PRI_SEC_TRIGGERS] = function(value, _descr, optionId) {
    set_option_combine_pri_sec_triggers(value)
    set_gui_option(optionId, value)
  },
  [USEROPT_GAMEPAD_CURSOR_CONTROLLER] = @(value, _descr, _optionId) ::g_gamepad_cursor_controls.setValue(value),
  [USEROPT_PS4_CROSSPLAY] = @(value, _descr, _optionId) crossplayModule.setCrossPlayStatus(value),
    //


  [USEROPT_PS4_CROSSNETWORK_CHAT] = @(value, _descr, _optionId) crossplayModule.setCrossNetworkChatStatus(value),
  [USEROPT_DISPLAY_MY_REAL_NICK] = function(value, _descr, optionId) {
    ::set_gui_option_in_mode(optionId, value, OPTIONS_MODE_GAMEPLAY)
    ::update_gamercards()
  },
  [USEROPT_DISPLAY_REAL_NICKS_PARTICIPANTS] = def_set_gui_option,
  [USEROPT_SHOW_SOCIAL_NOTIFICATIONS] = def_set_gui_option,
  [USEROPT_ALLOW_ADDED_TO_CONTACTS] = @(value, _descr, _optionId) setAbilityToBeAddedToContacts(value),
  [USEROPT_ALLOW_SHOW_WISHLIST] = @(value, _descr, _optionId) enableShowWishlistForFriends(value),
  [USEROPT_ALLOW_SHOW_WISHLIST_COMMENTS] = @(value, _descr, _optionId) enableShowWishlistCommentsForFriends(value),
  [USEROPT_ALLOW_ADDED_TO_LEADERBOARDS] = function(value, _descr, _optionId) {
    if (get_allow_to_be_added_to_lb() != value) {
      set_allow_to_be_added_to_lb(value)
      save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
    }
  },
  [USEROPT_QUEUE_EVENT_CUSTOM_MODE] = @(value, descr, _optionId) ::queue_classes.Event.setShouldQueueCustomMode(getTblValue("eventName", descr.context, ""), value),
  [USEROPT_PS4_ONLY_LEADERBOARD] = function(value, _descr, optionId) {
    broadcastEvent("PS4OnlyLeaderboardsValueChanged")
    set_gui_option(optionId, value)
  },
  [USEROPT_HIT_INDICATOR_RADIUS] = def_set_gui_option,
  [USEROPT_HIT_INDICATOR_SIMPLIFIED] = def_set_gui_option,
  [USEROPT_HIT_INDICATOR_ALPHA] = def_set_gui_option,
  [USEROPT_HIT_INDICATOR_SCALE] = def_set_gui_option,
  [USEROPT_HIT_INDICATOR_FADE_TIME] = def_set_gui_option,
  [USEROPT_LWS_IND_TIMEOUT] = def_set_gui_option,
  [USEROPT_LWS_AZIMUTH_IND_TIMEOUT] = def_set_gui_option,
  [USEROPT_LWS_IND_H_TIMEOUT] = def_set_gui_option,
  [USEROPT_LWS_IND_AZIMUTH_H_TIMEOUT] = def_set_gui_option,
  [USEROPT_LWS_IND_RADIUS] = def_set_gui_option,
  [USEROPT_LWS_IND_ALPHA] = def_set_gui_option,
  [USEROPT_LWS_IND_SCALE] = def_set_gui_option,
  [USEROPT_LWS_IND_H_RADIUS] = def_set_gui_option,
  [USEROPT_LWS_IND_H_ALPHA] = def_set_gui_option,
  [USEROPT_LWS_IND_H_SCALE] = def_set_gui_option,
  [USEROPT_FREE_CAMERA_ZOOM_SPEED] = def_set_gui_option,
  [USEROPT_REPLAY_FOV] = def_set_gui_option,
  [USEROPT_HELI_COCKPIT_HUD_DISABLED] = function(value, descr, optionId) {
    def_set_gui_option(value, descr, optionId)
    isHeliPilotHudDisabled(value)
  },
  [USEROPT_XRAY_FILTER_TANK] = set_xray_filter_option,
  [USEROPT_XRAY_FILTER_SHIP] = set_xray_filter_option,
  [USEROPT_TEST_FLIGHT_NAME] = def_set_gui_option,
  [USEROPT_AIR_SPAWN_POINT] = def_set_gui_option,
  [USEROPT_TARGET_RANK] = def_set_gui_option,
}

function set_option(optionId, value, descr = null) {
  if (!descr)
    descr = get_option(optionId)
  if (optionId in optionsSetMap)
    optionsSetMap[optionId](value, descr, optionId)
  else {
    let optionName = userOptionNameByIdx?[optionId] ?? ""
    assert(false, $"[ERROR] Options: Set: Unsupported type {optionId} ({optionName}) - {value}")
    return true
  }
  return true
}

::get_option <- get_option

return {
  set_option
  get_option
  create_option_switchbox
  create_options_container
  create_option_combobox
  crosshair_colors
  image_for_air
  create_option_list
}