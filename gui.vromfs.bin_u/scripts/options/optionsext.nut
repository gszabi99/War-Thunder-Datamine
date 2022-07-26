from "soundOptions" import *

let { format, split_by_chars } = require("string")
let time = require("%scripts/time.nut")
let colorCorrector = ::require_native("colorCorrector")
let safeAreaMenu = require("%scripts/options/safeAreaMenu.nut")
let safeAreaHud = require("%scripts/options/safeAreaHud.nut")
let globalEnv = require("globalEnv")
let avatars = require("%scripts/user/avatars.nut")
let contentPreset = require("%scripts/customization/contentPreset.nut")
let optionsUtils = require("%scripts/options/optionsUtils.nut")
let optionsMeasureUnits = require("%scripts/options/optionsMeasureUnits.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let soundDevice = require("soundDevice")
let holidays = ::require_native("holidays")
let { getBulletsListHeader } = require("%scripts/weaponry/weaponryDescription.nut")
let { setUnitLastBullets,
        getOptionsBulletsList } = require("%scripts/weaponry/bulletsInfo.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { reloadDargUiScript } = require("reactiveGuiCommand")
let {bombNbr} = require("%scripts/unit/unitStatus.nut")
let { saveProfile } = require("%scripts/clientState/saveProfile.nut")
let { checkUnitSpeechLangPackWatch } = require("%scripts/options/optionsManager.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { aeroSmokesList } = require("%scripts/unlocks/unlockSmoke.nut")
let { has_forced_crosshair } = ::require_native("crosshair")
//


let { getSlotbarOverrideCountriesByMissionName } = require("%scripts/slotbar/slotbarOverride.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getMaxEconomicRank } = require("%scripts/ranks_common_shared.nut")
let { setGuiOptionsMode, getGuiOptionsMode, setCdOption, getCdOption,
  getCdBaseDifficulty } = ::require_native("guiOptions")
let { GUI } = require("%scripts/utils/configs.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let {
 get_option_radar_aim_elevation_control = @() false,
 set_option_radar_aim_elevation_control = @(value) null
} = require("controlsOptions")

global const TANK_ALT_CROSSHAIR_ADD_NEW = -2
global const TANK_CAMO_SCALE_SLIDER_FACTOR = 0.1
::BOMB_ASSAULT_FUSE_TIME_OPT_VALUE <- -1
::SPEECH_COUNTRY_UNIT_VALUE <- 2

const BOMB_ACT_TIME = 0
const BOMB_ACT_ASSAULT = 1

global enum misCountries
{
  ALL
  BY_MISSION
  SYMMETRIC
  CUSTOM
}

setGuiOptionsMode(::OPTIONS_MODE_GAMEPLAY)

::game_mode_maps <- []
::dynamic_layouts <- []
::current_tag <- null
::aircraft_for_weapons <- null
::cur_aircraft_name <- null
::bullets_locId_by_caliber <- []
::modifications_locId_by_caliber <- []
::game_movies_in <- {}
::game_movies_out <- {}
::game_movies_in_ach <- {}
::game_movies_out_ach <- {}
::crosshair_icons <- []
::crosshair_colors <- []
::thermovision_colors <- []
::num_players_for_private <- 0
::PlayersMissionType <- {
  MissionTypeSingle = 0,
  MissionTypeLocal = 1,
  MissionTypeOnline = 2,
};

::KG_TO_TONS <- 0.001

::ttv_video_sizes <- [
  [640,368],
  [720,480],
  [864,480],
  [1280,720],
  [1920,1088],
]

::image_for_air <- function image_for_air(air)
{
  if (typeof(air) == "string")
    air = ::getAircraftByName(air)
  if (!air)
    return ""
  return air.customImage ?? ::get_unit_icon_by_unit(air, air.name)
}

::mission_name_for_takeoff <- ""

::available_mission_types <- ::PlayersMissionType.MissionTypeSingle;

::g_script_reloader.registerPersistentData("OptionsExtGlobals", ::getroottable(),
  [
    "game_mode_maps", "dynamic_layouts",
    "bullets_locId_by_caliber", "modifications_locId_by_caliber",
    "crosshair_icons", "crosshair_colors", "thermovision_colors"
  ])

::check_aircraft_tags <- function(airtags, filtertags)
{
  local isNotFound = false
  for (local j = 0; j < filtertags.len(); j++)
  {
    if (::find_in_array(airtags, filtertags[j]) < 0)
    {
      isNotFound = true
      break
    }
  }
  return !isNotFound
}

local isWaitMeasureEvent = false

::get_game_mode_maps <- function get_game_mode_maps()
{
  if (::game_mode_maps.len())
    return ::game_mode_maps

  for (local modeNo = 0; modeNo < ::GM_COUNT; ++modeNo)
  {
    let mi = ::get_meta_missions_info(modeNo)

    let modeMap = {}
    modeMap.items <- []
    modeMap.values <- []
    modeMap.coop <- []

    for (local i = 0; i < mi.len(); ++i)
    {
      let blkMap = mi[i]
      let chapterName = blkMap.getStr("chapter","")

      let misId = blkMap.getStr("name","")
      modeMap.values.append(misId)
      modeMap.items.append("#missions/" + misId)
      modeMap.coop.append(blkMap.getBool("gt_cooperative", false))

      let videoIn = blkMap.getStr("video_in","")
      if (videoIn.len())
      {
        ::game_movies_in[chapterName+"/"+misId] <- videoIn
        ::dagor.debug("[VIDEO] " + videoIn + " [IN] "+chapterName+"/"+misId);
      }

      let videoOut = blkMap.getStr("video_out","");
      if (videoOut.len())
      {
        ::game_movies_out[chapterName+"/"+misId] <- videoOut
        ::dagor.debug("[VIDEO] " + videoOut + " [OUT] "+chapterName+"/"+misId);
      }

      let videoInAch = blkMap.getStr("achievement_after_video_in","");
      if (videoInAch.len())
      {
        ::game_movies_in_ach[chapterName+"/"+misId] <- videoInAch
        ::dagor.debug("[VIDEO TROPHY] " + videoInAch + " [IN] "+chapterName+"/"+misId);
      }

      let videoOutAch = blkMap.getStr("achievement_after_video_out","");
      if (videoOutAch.len())
      {
        ::game_movies_out_ach[chapterName+"/"+misId] <- videoOutAch
        ::dagor.debug("[VIDEO TROPHY] " + videoOutAch + " [OUT] "+chapterName+"/"+misId);
      }
    }
    ::game_mode_maps.append(modeMap)
  }

  return ::game_mode_maps
}

::get_dynamic_layouts <- function get_dynamic_layouts()
{
  if (::dynamic_layouts.len())
    return ::dynamic_layouts

  let dblk = ::dynamic_get_layouts( )
  for (local i = 0; i < dblk.blockCount(); i++)
  {
    let info = {}
    info.mis_file <- dblk.getBlock(i).getStr("mis_file", "")
    info.name <- dblk.getBlock(i).getStr("name","")
    ::dynamic_layouts.append(info)
  }

  return ::dynamic_layouts
}

::find_in_array <- function find_in_array(arr, val, notFoundValue = -1)
{
  if (typeof arr != "array" && typeof arr != "table")
    return notFoundValue

  foreach (i, v in arr)
    if (v == val)
      return i

  return notFoundValue
}

::get_block_hsv_color <- function get_block_hsv_color(h, s = 1.0, v = 1.0)
{
  if (h > 360)
    h -= 360
  return ::get_color_from_hsv(h, s, v)
}

::create_option_list <- function create_option_list(id, items, value, cb, isFull, spinnerType=null, optionTag = null, params = null)
{
  if (!optionsUtils.checkArgument(id, items, "array"))
    return ""

  if (!optionsUtils.checkArgument(id, value, "integer"))
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

  foreach (idx, item in items)
  {
    let opt = typeof(item) == "string" ? { text = item } : clone item
    opt.selected <- idx == value
    if ("hue" in item)
      opt.hueColor <- ::get_block_hsv_color(item.hue, item?.sat ?? 0.7, item?.val ?? 0.7)
    if ("hues" in item)
      opt.smallHueColor <- item.hues.map(@(hue) { color = ::get_block_hsv_color(hue) })

    if ("rgb" in item)
      opt.hueColor <- item.rgb

    if (typeof(item?.image) == "string") {
      opt.images <- [{ image = item.image }]
      opt.rawdelete("image")
    }

    opt.enabled <- opt?.enabled ?? true
    if (!opt.enabled)
      spinnerType = "ComboBox" //disabled options can be only in dropright or combobox

    view.options.append(opt)
  }

  if (isFull)
  {
    let controlTag = spinnerType || "ComboBox"
    view.controlTag <- controlTag
    if (controlTag == "dropright")
      view.isDropright <- true
    if (controlTag == "ComboBox")
      view.isCombobox <- true
  }

  return ::handyman.renderCached(("%gui/options/spinnerOptions"), view)
}

::create_option_dropright <- function create_option_dropright(id, items, value, cb, isFull)
{
  return create_option_list(id, items, value, cb, isFull, "dropright")
}

::create_option_combobox <- function create_option_combobox(id, items, value, cb, isFull, params = null)
{
  return create_option_list(id, items, value, cb, isFull, "ComboBox", null, params)
}

::create_option_editbox <- ::kwarg(function create_option_editbox(id, value = "", password = false, maxlength = 16, charMask = null) {
  return "EditBox { id:t='{id}'; text:t='{text}'; width:t='0.2@sf'; max-len:t='{len}';{type}{charMask}}".subst({
    id = id,
    text = ::locOrStrip(value.tostring()),
    len = maxlength,
    type = password ? "type:t='password'; password-smb:t='{0}';".subst(::loc("password_mask_char", "*")) : "",
    charMask = charMask? $"char-mask:t='{charMask}';" : ""
  })
})

::create_option_switchbox <- function create_option_switchbox(config)
{
  return ::handyman.renderCached(("%gui/options/optionSwitchbox"), config)
}

::create_option_row_listbox <- function create_option_row_listbox(id, items, value, cb, isFull, listClass="options")
{
  if (!optionsUtils.checkArgument(id, items, "array"))
    return ""
  if (!optionsUtils.checkArgument(id, value, "integer"))
    return ""

  local data = "id:t = '" + id + "'; " + (cb != null ? "on_select:t = '" + cb + "'; " : "")
  data += "on_dbl_click:t = 'onOptionsListboxDblClick'; "
  data += "class:t='" + listClass + "'; "

  let view = { items = [] }
  foreach (idx, item in items)
  {
    let selected = idx == value
    if (::u.isString(item))
      view.items.append({ text = item, selected = selected })
    else
      view.items.append({
        text = ::getTblValue("text", item, "")
        image = ::getTblValue("image", item)
        disabled = ::getTblValue("enabled", item) || false
        selected = selected
        tooltip = ::getTblValue("tooltip", item, "")
      })
  }
  data += ::handyman.renderCached("%gui/commonParts/shopFilter", view)

  if (isFull)
  {
    data = "HorizontalListBox { height:t='ph-6'; pos:t = 'pw-0.5p.p.w-0.5w, 0.5(ph-h)'; position:t = 'absolute'; "
             + data + "}"
  }
  return data
}

::create_option_row_multiselect <- function create_option_row_multiselect(params)
{
  let option = params?.option
  if (!optionsUtils.checkArgument(option?.id, option?.items, "array") ||
    !optionsUtils.checkArgument(option?.id, option?.value, "integer"))
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

  foreach (v in option.items)
  {
    let item = typeof(v) == "string" ? { text = v, image = "" } : v
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

  return ::handyman.renderCached(("%gui/options/optionMultiselect"), view)
}

::create_option_vlistbox <- function create_option_vlistbox(id, items, value, cb, isFull)
{
  if (!optionsUtils.checkArgument(id, items, "array"))
    return ""

  if (!optionsUtils.checkArgument(id, value, "integer"))
    return ""

  local data = ""
  local itemNo = 0
  foreach (item in items)
  {
    data += "option { text:t = '" + item + "'; " + (itemNo == value ? "selected:t = 'yes';" : "") + " }"
    ++itemNo
  }

  data = "id:t = '" + id + "'; " + (cb != null ? "on_select:t = '" + cb + "'; " : "") + data

  if (isFull)
    data = "VericalListBox { " + data + " }"
  return data
}

::create_option_slider <- function create_option_slider(id, value, cb, isFull, sliderType, params = {})
{
  if (!optionsUtils.checkArgument(id, value, "integer"))
    return ""

  let minVal = params?.min ?? 0
  let maxVal = params?.max ?? 100
  let step = params?.step ?? 5
  let clickByPoints = ::abs(maxVal - minVal) == 1 ? "yes" : "no"
  local data = "".concat(
    $"id:t = '{id}'; min:t='{minVal}'; max:t='{maxVal}'; step:t = '{step}'; value:t = '{value}'; ",
    $"clicks-by-points:t='{clickByPoints}'; ",
    cb == null ? "" : $"on_change_value:t = '{cb}'; "
  )
  if (isFull)
    data = "{0} { {1} focus_border{} tdiv{} }".subst(sliderType, data) //tdiv need to focus border not count as slider button

  return data
}

::get_mission_time_text <- function get_mission_time_text(missionTime)
{
  if (::g_string.isStringInteger(missionTime))
    return format("%d:00", missionTime.tointeger())
  if (::g_string.isStringFloat(missionTime))
    missionTime = missionTime.replace(".", ":")
  return ::loc("options/time" + ::g_string.toUpper(missionTime, 1))
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

::get_option <- function get_option(optionId, context = null)
{
  let descr = optionsUtils.createDefaultOption()
  descr.type = optionId
  descr.context = context

  if(::u.isString(optionId))
  {
    descr.controlType = optionControlType.HEADER
    descr.controlName <- ""
    descr.id = "header_" + ::gen_rnd_password(10)
    descr.title = ::loc(descr.type)
    return descr
  }

  if ("onChangeCb" in context)
    descr.onChangeCb = context.onChangeCb

  local defaultValue = 0
  local prevValue = null

  switch (optionId)
  {
    // global settings:
    case ::USEROPT_LANGUAGE:
      let titleCommon = ::loc("profile/language")
      let titleEn = ::loc("profile/language/en")
      descr.title = titleCommon + (titleCommon == titleEn ? "" : ::loc("ui/parentheses/space", { text = titleEn }))
      descr.id = "language"
      descr.items = []
      descr.values = []
      descr.trParams <- "iconType:t='small';"
      let info = ::g_language.getGameLocalizationInfo()
      for (local i = 0; i < info.len(); i++)
      {
        let lang = info[i]
        descr.values.append(lang.id)
        descr.items.append({
          text = lang.title
          image = lang.icon
        })
      }
      descr.value = ::find_in_array(descr.values, ::get_current_language())
      break

    case ::USEROPT_SPEECH_TYPE:
      descr.id = "speech_country_type"
      descr.items = ["#options/speech_country_auto", "#options/speech_country_player", "#options/speech_country_unit"]
      descr.values = [0, 1, 2]
      descr.value = find_in_array(descr.values, ::get_option_speech_country_type())
      break

    case ::USEROPT_MOUSE_USAGE:
    case ::USEROPT_MOUSE_USAGE_NO_AIM:
      let ignoreAim = optionId == ::USEROPT_MOUSE_USAGE_NO_AIM
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

      if (ignoreAim)
      {
        let aimIdx = descr.values.indexof(AIR_MOUSE_USAGE.AIM)
        descr.values.remove(aimIdx)
        descr.items.remove(aimIdx)
      }

      defaultValue = descr.values.indexof(
        ::g_aircraft_helpers.getOptionValue(optionId))
      break;

    case ::USEROPT_INSTRUCTOR_ENABLED:
      descr.id = "instructor_enabled"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = ::g_aircraft_helpers.getOptionValue(optionId)
      break

    case ::USEROPT_AUTOTRIM:
      descr.id = "autotrim"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = ::g_aircraft_helpers.getOptionValue(optionId)
      break

    case ::USEROPT_INSTRUCTOR_GROUND_AVOIDANCE:
      optionsUtils.fillBoolOption(descr, "instructorGroundAvoidance", ::OPTION_INSTRUCTOR_GROUND_AVOIDANCE); break;
    case ::USEROPT_INSTRUCTOR_GEAR_CONTROL:
      optionsUtils.fillBoolOption(descr, "instructorGearControl", ::OPTION_INSTRUCTOR_GEAR_CONTROL); break;
    case ::USEROPT_INSTRUCTOR_FLAPS_CONTROL:
      optionsUtils.fillBoolOption(descr, "instructorFlapsControl", ::OPTION_INSTRUCTOR_FLAPS_CONTROL); break;
    case ::USEROPT_INSTRUCTOR_ENGINE_CONTROL:
      optionsUtils.fillBoolOption(descr, "instructorEngineControl", ::OPTION_INSTRUCTOR_ENGINE_CONTROL); break;
    case ::USEROPT_INSTRUCTOR_SIMPLE_JOY:
      optionsUtils.fillBoolOption(descr, "instructorSimpleJoy", ::OPTION_INSTRUCTOR_SIMPLE_JOY); break;
    case ::USEROPT_MAP_ZOOM_BY_LEVEL:
      optionsUtils.fillBoolOption(descr, "storeMapZoomByLevel", ::OPTION_MAP_ZOOM_BY_LEVEL); break;
    case ::USEROPT_HIDE_MOUSE_SPECTATOR:
      optionsUtils.fillBoolOption(descr, "hideMouseInSpectator", ::OPTION_HIDE_MOUSE_SPECTATOR); break;
    case ::USEROPT_SHOW_COMPASS_IN_TANK_HUD:
      optionsUtils.fillBoolOption(descr, "showCompassInTankHud", ::OPTION_SHOW_COMPASS_IN_TANK_HUD); break;
    case ::USEROPT_FIX_GUN_IN_MOUSE_LOOK:
      optionsUtils.fillBoolOption(descr, "fixGunInMouseLook", ::OPTION_FIX_GUN_IN_MOUSE_LOOK); break;
    case ::USEROPT_ENABLE_SOUND_SPEED:
      optionsUtils.fillBoolOption(descr, "enableSoundSpeed", ::OPTION_ENABLE_SOUND_SPEED); break;
    case ::USEROPT_PITCH_BLOCKER_WHILE_BRACKING:
      optionsUtils.fillBoolOption(descr, "pitchBlockerWhileBraking", ::OPTION_PITCH_BLOCKER_WHILE_BRACKING); break;
    case ::USEROPT_SAVE_DIR_WHILE_SWITCH_TRIGGER:
      optionsUtils.fillBoolOption(descr, "saveDirWhileSwitchTrigger", ::OPTION_SAVE_DIR_WHILE_SWITCH_TRIGGER); break;
    case ::USEROPT_SOUND_RESET_VOLUMES:
      descr.id = "sound_reset_volumes"
      descr.controlType = optionControlType.BUTTON
      descr.funcName <- "resetVolumes"
      descr.delayed <- true
      descr.text <- ::loc("mainmenu/resetVolumes")
      descr.showTitle <- false
      break

    case ::USEROPT_COMMANDER_CAMERA_IN_VIEWS:
      descr.id = "commander_camera_in_views"
      descr.items = [
        "#options/commander_not_in_views",
        "#options/commander_in_gunner_views",
        "#options/commander_in_binocular_views" ]
      descr.values = [0, 1, 2]
      descr.value = ::get_commander_camera_in_views()
      descr.trParams <- "optionWidthInc:t='half';"
      break

    case ::USEROPT_VIEWTYPE:
      descr.id = "viewtype"
      descr.items = ["#options/viewTps", "#options/viewCockpit", "#options/viewVirtual"]
      descr.value = ::get_option_view_type()
      break
    case ::USEROPT_GUN_TARGET_DISTANCE:
      descr.id = "gun_target_dist"
      descr.items = ["#options/no", "50", "100", "150", "200", "250", "300", "400", "500", "600", "700", "800"]
      descr.values = [-1, 50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800]
      descr.value = find_in_array(descr.values, ::get_option_gun_target_dist())
      defaultValue = 300
      break

    case ::USEROPT_BOMB_ACTIVATION_TIME:
      let diffCode = context?.diffCode ?? ::get_difficulty_by_ediff(::get_mission_mode()).diffCode
      let bombActivationType = ::load_local_account_settings($"useropt/bomb_activation_type/{diffCode}",
        ::get_option_bomb_activation_type())
      let isBombActivationAssault = bombActivationType == BOMB_ACT_ASSAULT
      let assaultFuseTime = ::get_bomb_activation_auto_time()
      let bombActivationTime = max(::load_local_account_settings(
        $"useropt/bomb_activation_time/{diffCode}",
          ::get_option_bomb_activation_time()), assaultFuseTime)

      descr.diffCode = diffCode
      descr.id = "bomb_activation_type"
      descr.values = [::BOMB_ASSAULT_FUSE_TIME_OPT_VALUE]
      let activationTimeArray = [0.0, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
      let nearestFuseValue = ::find_nearest(assaultFuseTime, activationTimeArray)
      if (nearestFuseValue >= 0)
        descr.values.extend(activationTimeArray.slice(nearestFuseValue))

      descr.value = ::find_nearest(isBombActivationAssault ? ::BOMB_ASSAULT_FUSE_TIME_OPT_VALUE : bombActivationTime, descr.values)
      descr.items = []
      for (local i = 0; i < descr.values.len(); i++)
      {
        let assaultFuse = descr.values[i] == ::BOMB_ASSAULT_FUSE_TIME_OPT_VALUE
        let text = assaultFuse ? "#options/bomb_activation_type/assault"
          : time.secondsToString(descr.values[i], true, true, 1)
        let tooltipLoc = assaultFuse ? "guiHints/bomb_activation_type/assault" : "guiHints/bomb_activation_type/timer"

        descr.items.append({
          text = text
          tooltip = ::loc(tooltipLoc, { sec = assaultFuse? assaultFuseTime : descr.values[i] })
        })
      }
      let curValue = isBombActivationAssault? assaultFuseTime : descr.values[descr.value]
      if (::get_option_bomb_activation_time() != curValue) {
        ::set_option_bomb_activation_type(isBombActivationAssault ? BOMB_ACT_ASSAULT : BOMB_ACT_TIME)
        ::set_option_bomb_activation_time(curValue)
      }
      break

    case ::USEROPT_BOMB_SERIES:
      descr.id = "bomb_series"
      descr.values = [0]
      descr.items = [ { text = "#options/disabled" } ]
      let unit = ::getAircraftByName(::aircraft_for_weapons)
      let bombSeries = [0, 4, 6, 12, 24, 48]
      let nbrBomb = unit != null ? bombNbr(unit) : bombSeries.top()
      for (local i = 1; i < bombSeries.len(); ++i)
      {
        if (bombSeries[i] >= nbrBomb) // max = -1
          break

        descr.values.append(bombSeries[i])
        let text = descr.values[i].tostring()
        descr.items.append({
          text = text
          tooltip = ::loc("guiHints/bomb_series_num", { num = descr.values[i] })
        })
      }

      descr.values.append(nbrBomb)
      descr.items.append({
        text = ::loc("options/bomb_series_all", { num = nbrBomb })
        tooltip = ::loc("guiHints/bomb_series_all")
      })

      descr.value = find_in_array(descr.values, ::get_option_bombs_series())
      defaultValue = bombSeries[0]
      break

    case ::USEROPT_COUNTERMEASURES_PERIODS:
       descr.id = "countermeasures_periods"
       descr.values = [0.1,0.2,0.5,1.0]
       descr.items = []
       for (local i = 0; i < descr.values.len(); ++i)
       {
         let text = time.secondsToString(descr.values[i], true, true, 2)
         let tooltipLoc = "guiHints/countermeasures_periods/periods"
         descr.items.append({
          text = text
          tooltip = ::loc(tooltipLoc, { sec = descr.values[i] })
          })
       }
       descr.value = find_in_array(descr.values, ::get_option_countermeasures_periods())
       defaultValue = 0.1
       break


    case ::USEROPT_COUNTERMEASURES_SERIES_PERIODS:
       descr.id = "countermeasures_series_periods"
       descr.items = []
       descr.values = [1,2,5,10]
       for (local i = 0; i < descr.values.len(); ++i)
       {
          let text = time.secondsToString(descr.values[i], true, true, 2)
          let tooltipLoc = "guiHints/countermeasures_periods/series_periods"
         descr.items.append({
          text = text
          tooltip = ::loc(tooltipLoc, { sec = descr.values[i] })
          })
       }
       descr.value = find_in_array(descr.values, ::get_option_countermeasures_series_periods())
       defaultValue = 1
       break

    case ::USEROPT_COUNTERMEASURES_SERIES:
       descr.id = "countermeasures_series"
       descr.items = []
       descr.values = [1,2,3,4]
       for (local i = 0; i < descr.values.len(); ++i)
       {
          let text = descr.values[i].tostring()
          let tooltipLoc = "guiHints/countermeasures_periods/series"
         descr.items.append({
          text = text
          tooltip = ::loc(tooltipLoc, { num = descr.values[i] })
          })
       }

       descr.value = find_in_array(descr.values, ::get_option_countermeasures_series())
       defaultValue = 1
       break

    case ::USEROPT_DEPTHCHARGE_ACTIVATION_TIME:
      descr.id = "depthcharge_activation_time"
      descr.items = []
      descr.values = []
      for(local i = 3; i <= 10; i++)
      {
        descr.items.append(time.secondsToString(i, true, true))
        descr.values.append(i)
      }
      descr.value = ::find_in_array(descr.values, ::get_option_depthcharge_activation_time())
      break

    case ::USEROPT_USE_PERFECT_RANGEFINDER:
      descr.id = "use_perfect_rangefinder"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_use_perfect_rangefinder()
      break

    case ::USEROPT_ROCKET_FUSE_DIST:
      descr.id = "rocket_fuse_dist"
      descr.items = ["#options/rocketFuseImpact", "200", "300", "400", "500", "600", "700", "800", "900", "1000"]
      descr.values = [0, 200, 300, 400, 500, 600, 700, 800, 900, 1000]
      if(::aircraft_for_weapons)
        descr.value = ::find_in_array(descr.values, ::get_unit_option(::aircraft_for_weapons, ::USEROPT_ROCKET_FUSE_DIST), null)
      if (!::is_numeric(descr.value))
        descr.value = ::find_in_array(descr.values, ::get_option_rocket_fuse_dist(), null)
      defaultValue = 0
      break

    case ::USEROPT_TORPEDO_DIVE_DEPTH:
      descr.id = "torpedo_dive_depth"
      let items = ::get_options_torpedo_dive_depth()
      descr.items = []
      descr.values = []
      foreach(val in items)
      {
        descr.items.append(val.tostring())
        descr.values.append(val)
      }
      if(::aircraft_for_weapons)
        descr.value = ::find_in_array(descr.values, ::get_unit_option(::aircraft_for_weapons, ::USEROPT_TORPEDO_DIVE_DEPTH), null)
      if (!::is_numeric(descr.value))
        descr.value = ::find_in_array(descr.values, ::get_option_torpedo_dive_depth(), null)
      defaultValue = 0
      break

    case ::USEROPT_AEROBATICS_SMOKE_TYPE:
      descr.id = "aerobatics_smoke_type"
      descr.optionCb = "onTripleAerobaticsSmokeSelected"

      descr.items = []
      descr.values = []
      descr.unlocks <- []

      let localSmokeType = ::get_option_aerobatics_smoke_type()
      foreach(inst in aeroSmokesList.value)
      {
        let { id, unlockId = "", locId = "" } = inst
        if ((id == ::TRICOLOR_INDEX) && !::has_feature("AerobaticTricolorSmoke")) //not triple color
          continue

        if (unlockId != "" && !(::g_unlocks.getUnlockById(unlockId) && ::is_unlocked(-1, unlockId)))
          continue

        descr.items.append(::loc(locId))
        descr.values.append(id)
        descr.unlocks.append(unlockId)
      }

      descr.value = descr.values.findindex(@(v) v == localSmokeType) ?? 1
      break

    case ::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR:
    case ::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR:
    case ::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR:
      {
        let optIndex = find_in_array(
          [::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, ::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, ::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR],
          optionId)

        descr.id = ["aerobatics_smoke_left_color", "aerobatics_smoke_right_color", "aerobatics_smoke_tail_color"][optIndex];

        descr.items = ["#options/aerobaticsSmokeColor1", "#options/aerobaticsSmokeColor2", "#options/aerobaticsSmokeColor3",
                       "#options/aerobaticsSmokeColor4", "#options/aerobaticsSmokeColor5", "#options/aerobaticsSmokeColor6",
                       "#options/aerobaticsSmokeColor7"];

        descr.values = [1, 2, 3, 4, 5, 6, 7];
        descr.value = find_in_array(descr.values, ::get_option_aerobatics_smoke_color(optIndex));
      }
      break;

    case ::USEROPT_INGAME_VIEWTYPE:
      descr.id = "ingame_viewtype"
      descr.items = ["#options/viewTps", "#options/viewCockpit", "#options/viewVirtual"]
      descr.value = ::get_current_view_type()
      break
    case ::USEROPT_GAME_HUD:
      descr.id = "hud"
      descr.items = []
      descr.values = []
      let diffCode = ::get_mission_set_difficulty_int()
      let total = ::g_hud_vis_mode.types.len()
      for(local i = 0; i < total; i++)
      {
        let visType = ::g_hud_vis_mode.types[i]
        if (!visType.isAvailable(diffCode))
          continue
        descr.items.append(visType.getName())
        descr.values.append(visType.hudGm)
      }

      descr.value = ::find_in_array(descr.values, ::get_option_hud())
      break

    case ::USEROPT_FONTS_CSS:
      descr.id = "fonts_type"
      descr.controlName <- "combobox"

      descr.items = []
      descr.values = ::g_font.getAvailableFonts()
      for(local i = 0; i < descr.values.len(); i++)
      {
        let font = descr.values[i]
        descr.items.append({
          text = font.getOptionText()
          fontOverride = font.getFontExample()
        })
      }
      descr.value = ::find_in_array(descr.values, ::g_font.getCurrent(), 0)
      descr.enabled <- descr.values.len() > 1
      break

    case ::USEROPT_ENABLE_CONSOLE_MODE:
      descr.id = "console_mode"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = ::get_is_console_mode_force_enabled()
      break

    case ::USEROPT_GAMEPAD_GYRO_TILT_CORRECTION:
      descr.id = "gamepadGyroTiltCorrection"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_GAMEPAD_ENGINE_DEADZONE:
      descr.id = "gamepadEngDeadZone"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_GAMEPAD_VIBRATION_ENGINE:
      descr.id = "gamepadVibrationForEngine"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false
      break

    case ::USEROPT_JOY_MIN_VIBRATION:
      descr.id = "gamepadMinVibration"
      descr.controlType = optionControlType.SLIDER
      descr.value = (100.0 * ::get_option_multiplier(::OPTION_JOY_MIN_VIBRATION)).tointeger()
      defaultValue = 5
      break

    case ::USEROPT_INVERTY:
      descr.id = "invertY"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_invertY(AxisInvertOption.INVERT_Y) != 0
      break

    case ::USEROPT_INVERTX:
      descr.id = "invertX"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_invertX() == 0 ? 0 : 1
      break

    case ::USEROPT_JOYFX:
      descr.id = "joyFX"
      descr.hint = ::loc("options/joyFX")
      descr.needRestartClient = true
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_INVERT_THROTTLE:
      descr.id = "invertT"
      descr.items = ["#options/no", "#options/yes"]
      descr.value = ::get_option_invertY(AxisInvertOption.INVERT_THROTTLE) == 0 ? 0 : 1
      break

    case ::USEROPT_GUNNER_INVERTY:
      descr.id = "invertY_gunner"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_invertY(AxisInvertOption.INVERT_GUNNER_Y) != 0
      break

    case ::USEROPT_INVERTY_TANK:
      descr.id = "invertY_tank"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_invertY(AxisInvertOption.INVERT_TANK_Y) != 0
      break

    case ::USEROPT_INVERTY_SHIP:
      descr.id = "invertY_ship"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_invertY(AxisInvertOption.INVERT_SHIP_Y) != 0
      break

    case ::USEROPT_INVERTY_HELICOPTER:
      descr.id = "invertY_helicopter"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_invertY(AxisInvertOption.INVERT_HELICOPTER_Y) != 0
      break

    case ::USEROPT_INVERTY_HELICOPTER_GUNNER:
      descr.id = "invertY_helicopter_gunner"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_invertY(AxisInvertOption.INVERT_HELICOPTER_GUNNER_Y) != 0
      break

    //






























    case ::USEROPT_INVERTY_SUBMARINE:
      descr.id = "invertY_submarine"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_invertY(AxisInvertOption.INVERT_SUBMARINE_Y) != 0
      break

    case ::USEROPT_INVERTY_SPECTATOR:
      descr.id = "invertY_spectator"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_invertY(AxisInvertOption.INVERT_SPECTATOR_Y) != 0
      break

    case ::USEROPT_AUTOMATIC_TRANSMISSION_TANK:
      descr.id = "automaticTransmissionTank"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_WHEEL_CONTROL_SHIP:
      descr.id = "selectWheelShipEnable"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false
      break

    case ::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP:
      descr.id = "seperatedEngineControlShip"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false
      break

    case ::USEROPT_BULLET_FALL_INDICATOR_SHIP:
      descr.id = "bulletFallIndicatorShip"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true

      let blk = ::dgs_get_game_params()
      let minCaliber  = blk?.shipsShootingTracking?.minCaliber ?? 0.1
      let minDrawDist = blk?.shipsShootingTracking?.minDrawDist ?? 3500
      descr.hint = ::loc("guiHints/bulletFallIndicatorShip", {
        minCaliber  = ::g_measure_type.MM.getMeasureUnitsText(minCaliber * 1000),
        minDistance = ::g_measure_type.DISTANCE.getMeasureUnitsText(minDrawDist)
      })
      break

    case ::USEROPT_BULLET_FALL_SPOT_SHIP:
      descr.id = "bulletFallSpotShip"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_BULLET_FALL_SOUND_SHIP:
      descr.id = "bulletFallSoundShip"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false

      let blk = ::dgs_get_game_params()
      let minCaliber  = blk?.shipsShootingTracking?.minCaliber ?? 0.1
      let minDrawDist = blk?.shipsShootingTracking?.minDrawDist ?? 3500
      descr.hint = ::loc("guiHints/bulletFallSoundShip", {
        minCaliber  = ::g_measure_type.MM.getMeasureUnitsText(minCaliber * 1000),
        minDistance = ::g_measure_type.DISTANCE.getMeasureUnitsText(minDrawDist)
      })
      break

    case ::USEROPT_SINGLE_SHOT_BY_TURRET:
      descr.id = "singleShotByTurret"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_SHIP_COMBINE_PRI_SEC_TRIGGERS:
      descr.id = "shipCombinePriSecTriggers"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_FOLLOW_BULLET_CAMERA:
      descr.id = "followBulletCamera"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_AUTO_TARGET_CHANGE_SHIP:
      descr.id = "automaticTargetChangeShip"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_REALISTIC_AIMING_SHIP:
      descr.id = "realAimingShip"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false
      break

    case ::USEROPT_DEFAULT_TORPEDO_FORESTALL_ACTIVE:
      descr.id = "default_torpedo_forestall_active"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_ALTERNATIVE_TPS_CAMERA:
      descr.id = "alternative_tps_camera"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false
      break

    ///_INSERT_OPTIONS_HERE_
    //case ::USEROPT_USE_TRACKIR_ZOOM:
    //  descr.id = "useTrackIrZoom"
    //  descr.items = ["#options/no", "#options/yes"]
    //  descr.value = ::get_option_useTrackIrZoom() == 0 ? 0 : 1
    //  break

    case ::USEROPT_INDICATED_SPEED_TYPE:
      descr.id = "indicatedSpeed"
      descr.items = ["#options/speed_tas", "#options/speed_ias", "#options/speed_tas_ias"]
      descr.values = [0, 1, 2]
      descr.value = ::get_option_indicatedSpeedType()
      descr.trParams <- "optionWidthInc:t='half';"
      break

    case ::USEROPT_INVERTCAMERAY:
      descr.id = "invertCameraY"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_camera_invertY() ? 1 : 0
      break

    case ::USEROPT_ZOOM_FOR_TURRET:
      descr.id = "zoomForTurret"
      descr.items = ["#options/no", "#options/yes"]
      descr.value = ::get_option_zoom_turret()
      break

    case ::USEROPT_XCHG_STICKS:
      descr.id = "xchangeSticks"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = !!::get_option_xchg_sticks(0)
      break

    case ::USEROPT_AUTOSAVE_REPLAYS:
      descr.id = "autosave_replays"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_autosave_replays()
      break

    case ::USEROPT_XRAY_DEATH:
      descr.id = "xray_death"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_xray_death()
      break

    case ::USEROPT_XRAY_KILL:
      descr.id = "xray_kill"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_xray_kill()
      break

    case ::USEROPT_USE_CONTROLLER_LIGHT:
      descr.id = "controller_light"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_controller_light()
      break

    case ::USEROPT_SUBTITLES:
      descr.id = "subtitles"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_subs() > 0
      break

    case ::USEROPT_SUBTITLES_RADIO:
      descr.id = "subtitles_radio"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_subs_radio() > 0
      break

    case ::USEROPT_PTT:
      descr.id = "ptt"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_ptt()
      descr.optionCb = "onPTTChange";
      break

    case ::USEROPT_VOICE_CHAT:
      descr.id = "voice_chat"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_voicechat()
      descr.optionCb = "onVoicechatChange";
      break

    case ::USEROPT_VOICE_DEVICE_IN:
      descr.id = "voice_device_in";
      descr.items = [];
      descr.values = [];
      descr.value = 0;
      descr.optionCb = "onInstantOptionApply";
      descr.trParams <- "optionWidthInc:t='double';"
      let lastSoundDevice = soundDevice.get_last_voice_device_in()
      foreach (device in soundDevice.get_record_devices()) {
        descr.items.append(device.name)
        descr.values.append(device.name)
        if (device.name == lastSoundDevice)
          descr.value = descr.values.len() - 1
      }
      break

    case ::USEROPT_SOUND_DEVICE_OUT:
      descr.id = "sound_device_out";
      descr.items = [];
      descr.values = [];
      descr.value = 0;
      descr.optionCb = "onInstantOptionApply";
      descr.trParams <- "optionWidthInc:t='double';"
      let lastSoundDevice = soundDevice.get_last_sound_device_out()
      foreach (device in soundDevice.get_out_devices()) {
        descr.items.append(device.name)
        descr.values.append(device.name)
        if (device.name == lastSoundDevice)
          descr.value = descr.values.len() - 1
      }

      break

    case ::USEROPT_SOUND_ENABLE:
      descr.id = "sound_switch"
      descr.title = ::loc("options/sound")
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.textChecked <- ::loc("options/enabled")
      descr.textUnchecked <- ::loc("#options/disabled")
      descr.hint = ::loc("options/sound")
      if(!is_sound_inited())
        descr.needRestartClient = true
      descr.value = ::getSystemConfigOption("sound/fmod_sound_enable", true)
      break

    case ::USEROPT_SOUND_SPEAKERS_MODE:
      descr.id = "sound_speakers"
      descr.hint = ::loc("options/sound_speakers")
      descr.needRestartClient = true
      descr.items  = ["#controls/AUTO", "#options/sound_speakers/stereo", "5.1", "7.1"]
      descr.values = ["auto", "stereo", "speakers5.1", "speakers7.1"]
      descr.value = ::find_in_array(descr.values, ::getSystemConfigOption("sound/speakerMode", "auto"), 0)
      break

    case ::USEROPT_VOICE_MESSAGE_VOICE:
      descr.id = "voice_message_voice"
      descr.items = ["#options/voice_message_voice1", "#options/voice_message_voice2",
       "#options/voice_message_voice3", "#options/voice_message_voice4"]
      descr.value = ::get_option_voice_message_voice() - 1 //1-based
      break

    case ::USEROPT_MEASUREUNITS_SPEED:
    case ::USEROPT_MEASUREUNITS_ALT:
    case ::USEROPT_MEASUREUNITS_DIST:
    case ::USEROPT_MEASUREUNITS_CLIMBSPEED:
    case ::USEROPT_MEASUREUNITS_TEMPERATURE:
    case ::USEROPT_MEASUREUNITS_WING_LOADING:
    case ::USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO:
      let mesureUnitsOption = optionsMeasureUnits.getOption(optionId)
      descr.id      = mesureUnitsOption.id
      descr.items   = mesureUnitsOption.items
      descr.values  = mesureUnitsOption.values
      descr.value   = mesureUnitsOption.value
      break

    case ::USEROPT_VIBRATION:
      descr.id = "vibration"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_vibration()
      break

    case ::USEROPT_GRASS_IN_TANK_VISION:
      descr.id = "grass_in_tank_vision"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_grass_in_tank_vision()
      break

    case ::USEROPT_AILERONS_MULTIPLIER:
      descr.id = "multiplier_ailerons"
      descr.value = (::get_option_multiplier(::OPTION_AILERONS_MULTIPLIER) * 100).tointeger()
      if (descr.value < 0)
        descr.value = 0
      else if (descr.value > 100)
        descr.value = 100
      break

    case ::USEROPT_ELEVATOR_MULTIPLIER:
      descr.id = "multiplier_elevator"
      descr.value = (::get_option_multiplier(::OPTION_ELEVATOR_MULTIPLIER) * 100).tointeger()
      if (descr.value < 0)
        descr.value = 0
      else if (descr.value > 100)
        descr.value = 100
      break

    case ::USEROPT_RUDDER_MULTIPLIER:
      descr.id = "multiplier_rudder"
      descr.value = (::get_option_multiplier(::OPTION_RUDDER_MULTIPLIER) * 100).tointeger()
      if (descr.value < 0)
        descr.value = 0
      else if (descr.value > 100)
        descr.value = 100
      break

    case ::USEROPT_ZOOM_SENSE:
      descr.id = "multiplier_zoom"
      descr.value = (::get_option_multiplier(::OPTION_ZOOM_SENSE) * 100).tointeger()
      if (descr.value < 0)
        descr.value = 0
      else if (descr.value > 100)
        descr.value = 100
      descr.value = 100 - descr.value
      break

    case ::USEROPT_MOUSE_SENSE:
      descr.id = "multiplier_mouse"
      descr.controlType = optionControlType.SLIDER
      descr.min <- 5
      descr.max <- 100
      descr.value = (::get_option_multiplier(::OPTION_MOUSE_SENSE) * 50.0).tointeger()
      descr.value = clamp(descr.value, descr.min, descr.max)
      break

    case ::USEROPT_MOUSE_AIM_SENSE:
      descr.id = "multiplier_joy_camera_view"
      descr.controlType = optionControlType.SLIDER
      descr.min <- 5
      descr.max <- 100
      descr.value = (::get_option_multiplier(::OPTION_MOUSE_AIM_SENSE) * 50.0).tointeger()
      descr.value = clamp(descr.value, descr.min, descr.max)
      break

    case ::USEROPT_GUNNER_VIEW_SENSE:
      descr.id = "multiplier_gunner_view"
      descr.value = (::get_option_multiplier(::OPTION_GUNNER_VIEW_SENSE) * 100.0).tointeger()
      break

    case ::USEROPT_GUNNER_VIEW_ZOOM_SENS:
      descr.id = "multiplier_gunner_view_zoom"
      descr.value = (::get_option_multiplier(::OPTION_GUNNER_VIEW_ZOOM_SENS) * 100.0).tointeger()
      break

    case ::USEROPT_ATGM_AIM_SENS_HELICOPTER:
      descr.id = "atgm_aim_sens_helicopter"
      descr.value = (::get_option_multiplier(::OPTION_ATGM_AIM_SENS_HELICOPTER) * 100.0).tointeger()
      break

    case ::USEROPT_ATGM_AIM_ZOOM_SENS_HELICOPTER:
      descr.id = "atgm_aim_zoom_sens_helicopter"
      descr.value = (::get_option_multiplier(::OPTION_ATGM_AIM_ZOOM_SENS_HELICOPTER) * 100.0).tointeger()
      break

    case ::USEROPT_MOUSE_SMOOTH:
      descr.id = "mouse_smooth"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_mouse_smooth() != 0
      break

    case ::USEROPT_FORCE_GAIN:
      descr.id = "multiplier_force_gain"
      descr.value = (::get_option_gain() * 50).tointeger()
      break

    case ::USEROPT_CAMERA_SHAKE_MULTIPLIER:
      descr.id = "camera_shake_gain"
      descr.value = (::get_option_multiplier(::OPTION_CAMERA_SHAKE) * 50.0).tointeger()
      descr.controlType = optionControlType.SLIDER
      break

    case ::USEROPT_VR_CAMERA_SHAKE_MULTIPLIER:
      descr.id = "vr_camera_shake_gain"
      descr.value = (::get_option_multiplier(::OPTION_VR_CAMERA_SHAKE) * 50.0).tointeger()
      descr.controlType = optionControlType.SLIDER
      break

    case ::USEROPT_GAMMA:
      descr.id = "video_gamma"
      descr.value = (::get_option_gamma() * 100).tointeger()
      descr.optionCb = "onGammaChange"
      break

    // volume settings:
    case ::USEROPT_VOLUME_MASTER:
      fillSoundDescr(descr, SND_TYPE_MASTER, "volume_master")
      break
    case ::USEROPT_VOLUME_MUSIC:
      fillSoundDescr(descr, SND_TYPE_MUSIC, "volume_music",
        ::loc(::has_feature("Radio") ? "options/volume_music/and_radio" : "options/volume_music"))
      break
    case ::USEROPT_VOLUME_MENU_MUSIC:
      fillSoundDescr(descr, SND_TYPE_MENU_MUSIC, "volume_menu_music")
      break
    case ::USEROPT_VOLUME_SFX:
      fillSoundDescr(descr, SND_TYPE_SFX, "volume_sfx")
      break
    case ::USEROPT_VOLUME_GUNS:
      fillSoundDescr(descr, SND_TYPE_GUNS, "volume_guns")
      break
    case ::USEROPT_VOLUME_TINNITUS:
      fillSoundDescr(descr, SND_TYPE_TINNITUS, "volume_tinnitus")
      break
    case ::USEROPT_HANGAR_SOUND:
      fillSoundDescr(descr, SND_TYPE_TINNITUS, "volume_tinnitus")
      descr.id = "hangar_sound"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = get_option_hangar_sound()
      break
    case ::USEROPT_VOLUME_RADIO:
      fillSoundDescr(descr, SND_TYPE_RADIO, "volume_radio")
      break
    case ::USEROPT_VOLUME_ENGINE:
      fillSoundDescr(descr, SND_TYPE_ENGINE, "volume_engine")
      break
    case ::USEROPT_VOLUME_MY_ENGINE:
      fillSoundDescr(descr, SND_TYPE_MY_ENGINE, "volume_my_engine")
      break
    case ::USEROPT_VOLUME_DIALOGS:
      fillSoundDescr(descr, SND_TYPE_DIALOGS, "volume_dialogs")
      break
    case ::USEROPT_VOLUME_VOICE_IN:
      fillSoundDescr(descr, SND_TYPE_VOICE_IN, "volume_voice_in")
      break
    case ::USEROPT_VOLUME_VOICE_OUT:
      fillSoundDescr(descr, SND_TYPE_VOICE_OUT, "volume_voice_out")
      break

    case ::USEROPT_CONTROLS_PRESET:
      descr.id = "controls_preset"
      descr.items = []
      descr.values = ::g_controls_presets.getControlsPresetsList()
      descr.trParams <- "optionWidthInc:t='double';"

      let p = ::g_controls_manager.getCurPreset().getBasePresetInfo()
        ?? (clone ::g_controls_presets.nullPreset)
      for(local k = 0; k < descr.values.len(); k++)
      {
        let name = descr.values[k]
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
        else if (name == "custom")
        {
          imageName = "preset_custom.png"
          suffix = ""
        }

        descr.items.append({
                            text = "#presets/" + suffix + name
                            image = $"#ui/gameuiskin#{imageName}"
                          })
      }
      descr.optionCb = "onSelectPreset"
      break

    // gui settings:

    case ::USEROPT_ROUNDS:
      descr.id = "rounds"
      descr.items = ["#options/rounds0","#options/rounds1","#options/rounds3","#options/rounds5","#options/rounds7"]
      descr.values = [0, 1, 3, 5, 7]
      defaultValue = 5
      break;

    case ::USEROPT_AAA_TYPE:
      descr.id = "aaa_type"
      descr.items = ["#options/aaaNone", "#options/aaaFriendly", "#options/aaaEnemy", "#options/aaaBoth"]
      descr.values = [0, 1, 2, 3]
      defaultValue = 3
      break

    case ::USEROPT_SITUATION:
      descr.id = "situation"
      descr.items = ["#options/situationCommon", "#options/situationAltAdv", "#options/situationAltDisAdv"]
      descr.values = [0, 1, 2]
      break

    case ::USEROPT_CLIME:
      descr.id = "weather"
      descr.items = ["#options/weatherclear",
                     "#options/weathergood",
                     "#options/weatherhazy",
                     "#options/weatherthinclouds",
                     "#options/weathercloudy",
                     "#options/weatherpoor",
                     "#options/weatherblind",
//                     "#options/weathershower",
                     "#options/weatherrain",
                     "#options/weatherstorm"
                    ]
      descr.values = ["clear", "good", "hazy", "thin_clouds","cloudy","poor","blind",/*"shower"*/"rain","thunder"]
      defaultValue = "cloudy"
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("weather", null)
      break

    case ::USEROPT_TIME:
      descr.id = "time"
      descr.values = ["Dawn", "Morning", "Noon", "Day", "Evening", "Dusk", "Night",
                      "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18"]
      descr.items = ::u.map(descr.values, ::get_mission_time_text)
      defaultValue = "Day"
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("environment", null)
      break

    case ::USEROPT_ALTITUDE:
      descr.id = "altitude"
      descr.items = ["#options/altitude400", "#options/altitude1000", "#options/altitude2000", "#options/altitude3000",
        "#options/altitude5000", "#options/altitude7500", "#options/altitude9000"]
      descr.values = [400.0, 1000.0, 2000.0, 3000.0, 5000.0, 7500.0, 9000.0]
      break

    case ::USEROPT_FRIENDS_ONLY:
      descr.id = "friends_only"
      descr.items = ["#options/no", "#options/yes"]
      descr.values = [0, 1]
      break

    case ::USEROPT_DISABLE_AIRFIELDS:
      descr.id = "disable_airfields"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("disableAirfields", false)
      break

    case ::USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS:
      descr.id = "spawn_ai_tank_on_tank_maps"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("spawnAiTankOnTankMaps", true)
      break

    case ::USEROPT_COOP_MODE:
      descr.id = "coop_mode"
      descr.items = ["#options/create", "#options/private", "#options/single"]
      descr.values = [0, 1, 2]
      defaultValue = 0
      break

    case ::USEROPT_DEDICATED_REPLAY:
      descr.id = "dedicatedReplay"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("dedicatedReplay", false)
      break

    case ::USEROPT_SESSION_PASSWORD:
      descr.id = "session_password"
      descr.controlType = optionControlType.EDITBOX
      descr.controlName <-"editbox"
      descr.value = ::SessionLobby.password
      descr.getValueLocText = function(val)
      {
        if (val == true)
          return ::loc("options/yes")
        return ::loc("options/no")
      }
      break

    case ::USEROPT_TAKEOFF_MODE:
    case ::USEROPT_LANDING_MODE:
      descr.id = (optionId == ::USEROPT_TAKEOFF_MODE) ? "takeoff_mode" : "landing_mode"

      if (optionId == ::USEROPT_TAKEOFF_MODE &&
        (::mission_name_for_takeoff == "dynamic_free_flight01" ||
         ::mission_name_for_takeoff == "dynamic_free_flight02"))
      {
        descr.items = ["#options/takeoffmode/no","#options/takeoffmode/real"]
        descr.values = [0, 2]
        defaultValue = 0
      }
      else
      {
        descr.items = ["#options/takeoffmode/no","#options/takeoffmode/teleport","#options/takeoffmode/real"]
        descr.values = [0, 1, 2]
        defaultValue = 1
      }
      break

    case ::USEROPT_IS_BOTS_ALLOWED:
      descr.id = "isBotsAllowed"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false
      descr.optionCb = "onOptionBotsAllowed"
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("isBotsAllowed", null)
      break

    case ::USEROPT_USE_TANK_BOTS:
      descr.id = "useTankBots"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("useTankBots", null)
      break

    case ::USEROPT_USE_SHIP_BOTS:
      descr.id = "useShipBots"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("useShipBots", null)
      break

    case ::USEROPT_KEEP_DEAD:
      descr.id = "keepDead"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("keepDead", null)
      break

    case ::USEROPT_AUTOBALANCE:
      descr.id = "autoBalance"
      descr.items = ["#options/no", "#options/yes"]
      descr.values = [false, true]
      defaultValue = true
      break

    case ::USEROPT_MAX_PLAYERS:
      descr.id = "maxPlayers"
      descr.items = []
      descr.values = []

      for (local i = 2; i <= ::global_max_players_versus; i+=2)
      {
        descr.items.append("" + i)
        descr.values.append(i)
      }
      defaultValue = ::global_max_players_versus
      break

    case ::USEROPT_MIN_PLAYERS:
      descr.id = "minPlayers"
      descr.items = []
      descr.values = []
      for (local i = 0; i <= ::global_max_players_versus; i+=2)
      {
        descr.items.append("" + i)
        descr.values.append(i)
      }
      break

    case ::USEROPT_COMPLAINT_CATEGORY:
      descr.id = "complaint_category"
      descr.values = ["FOUL", "ABUSE", "TEAMKILL", "BOT", "SPAM", "OTHER"]
      descr.items = []
      for(local i=0; i<descr.values.len(); i++)
        descr.items.append("#charServer/ban/reason/"+descr.values[i])
      break
    case ::USEROPT_BAN_PENALTY:
      descr.id = "ban_penalty"
      descr.values = []
      if (::myself_can_devoice())
      {
        descr.values.append("DEVOICE")
        descr.values.append("SILENT_DEVOICE")
      }
      if (::myself_can_ban())
        descr.values.append("BAN")
      descr.items = []
      for(local i=0; i<descr.values.len(); i++)
        descr.items.append("#charServer/penalty/"+descr.values[i])
      break
    case ::USEROPT_BAN_TIME:
      descr.id = "ban_time"
      descr.values = ::myself_can_ban()? [1, 2, 4, 7, 14] : [1]
      descr.items = []
      let dayVal = time.daysToSeconds(1)
      for(local i=0; i<descr.values.len(); i++)
      {
        descr.items.append(descr.values[i] + ::loc("measureUnits/days"))
        descr.values[i] *= dayVal
      }
      break

    case ::USEROPT_OFFLINE_MISSION:
      descr.id = "OfflineMission"
      descr.items = ["#options/disabled", "#options/enabled"]
      descr.values = [false, true]
      defaultValue = false
      break

    case ::USEROPT_VERSUS_NO_RESPAWN:
      descr.id = "noRespawns"
      descr.items = ["#options/disabled", "#options/enabled"]
      descr.values = [true, false]
      defaultValue = false
      break

    case ::USEROPT_VERSUS_RESPAWN:
      descr.id = "maxRespawns"
      descr.items = ["#options/resp_unlimited", "#options/resp_all", "#options/resp_none"]
      descr.values = [-2, -1,  1]
      for(local i = 2; i <= 3; i++)
      {
        descr.items.append(::loc("options/resp_limited/value", { amount = i }))
        descr.values.append(i)
      }
      defaultValue = -1
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("maxRespawns", null)
      break

    case ::USEROPT_ALLOW_EMPTY_TEAMS:
      descr.id = "allowEmptyTeams"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = false
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("allowEmptyTeams", null)
      break

    case ::USEROPT_ALLOW_JIP:
      descr.id = "allow_jip"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getPublicParam("allowJIP", null)
      break

    case ::USEROPT_QUEUE_JIP:
      descr.id = "queue_jip"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_AUTO_SQUAD:
      descr.id = "auto_squad"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_ORDER_AUTO_ACTIVATE:
      descr.id = "order_auto_activate"
      descr.hint = ::g_orders.autoActivateHint
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_QUEUE_EVENT_CUSTOM_MODE:
      descr.id = "queue_event_custom_mode"
      descr.title = ::loc("events/playersRooms")
      descr.hint = ::loc("events/playersRooms/tooltip")
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.textChecked <- ::loc("options/enabled")
      descr.textUnchecked <- ::loc("#options/disabled")
      descr.value = ::queue_classes.Event.getShouldQueueCustomMode(::getTblValue("eventName", context, ""))
      break

    case ::USEROPT_AUTO_SHOW_CHAT:
      descr.id = "auto_show_chat"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_autoShowChat() != 0
      break

    case ::USEROPT_CHAT_MESSAGES_FILTER:
      descr.id = "chat_messages"
      descr.items = ["#options/chat_messages_all", "#options/chat_messages_team_and_squad", "#options/chat_messages_squad",
        "#options/chat_messages_system", "#options/chat_messages_nothing"]
      descr.values = [0, 1, 2, 3, 4]
      descr.value = ::get_option_chat_messages_filter()
      break

    case ::USEROPT_CHAT_FILTER:
      descr.id = "chat_filter"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_chatFilter() != 0
      break

    case ::USEROPT_DAMAGE_INDICATOR_SIZE:
      descr.id = "damage_indicator_scale"
      descr.controlType = optionControlType.SLIDER
      descr.min <- -2
      descr.max <- 2
      descr.step <- 1
      descr.value = ::get_gui_option_in_mode(optionId, ::OPTIONS_MODE_GAMEPLAY)
      defaultValue = 0
      descr.getValueLocText = @(val) $"{(100 + 33.3 * val / descr.max).tointeger()}%"
      break

    case ::USEROPT_TACTICAL_MAP_SIZE:
      descr.id = "tactical_map_scale"
      descr.controlType = optionControlType.SLIDER
      descr.min <- -2
      descr.max <- 2
      descr.step <- 1
      descr.value = ::get_gui_option_in_mode(optionId, ::OPTIONS_MODE_GAMEPLAY)
      defaultValue = 0
      descr.getValueLocText = @(val) $"{(100 + 33.3 * val / descr.max).tointeger()}%"
      break

    case ::USEROPT_AIR_RADAR_SIZE:
      descr.id = "air_radar_scale"
      descr.controlType = optionControlType.SLIDER
      descr.min <- -2
      descr.max <- 2
      descr.step <- 1
      descr.value = ::get_gui_option_in_mode(optionId, ::OPTIONS_MODE_GAMEPLAY)
      defaultValue = 0
      descr.getValueLocText = @(val) $"{(100 + 33.3 * val / descr.max).tointeger()}%"
      break

    case ::USEROPT_SHOW_PILOT:
      descr.id = "show_pilot"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_showPilot() != 0
      if (::get_dgs_tex_quality() > 0)
        descr.enabled <- false
      break

    case ::USEROPT_GUN_VERTICAL_TARGETING:
      descr.id = "gun_vertical_targeting"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_gunVerticalTargeting() != 0
      break

    case ::USEROPT_AUTOLOGIN:
      descr.id = "auto_login"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::is_autologin_enabled()
      break

    case ::USEROPT_ONLY_FRIENDLIST_CONTACT:
      descr.id = "only_friendlist_contact"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.textChecked <- ::loc("options/enabled")
      descr.textUnchecked <- ::loc("options/disabled")
      defaultValue = false
      break

    case ::USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL:
      descr.id = "mark_direct_messages_as_personal"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.textChecked <- ::loc("options/enabled")
      descr.textUnchecked <- ::loc("options/disabled")
      defaultValue = true
      break

    case ::USEROPT_CROSSHAIR_DEFLECTION:
      descr.id = "crosshair_deflection"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_deflection()
      break
    case ::USEROPT_CROSSHAIR_SPEED:
      descr.id = "crosshair_speed"
      descr.items = ["#options/no", "#options/yes"]
      descr.values = [false, true]
      descr.value = ::get_option_crosshair_speed() ? 1 : 0
      break

    case ::USEROPT_SHOW_INDICATORS:
      descr.id = "show_indicators"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = (::get_option_indicators_mode() & ::HUD_INDICATORS_SHOW) != 0
      break

    case ::USEROPT_REPLAY_ALL_INDICATORS:
      descr.id = "replay_all_indicators"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_REPLAY_LOAD_COCKPIT:
      descr.id = "replay_load_cockpit"
      descr.controlName <- "combobox"
      descr.items = [
        ::loc("options/replay_load_cockpit_no_one")
        ::loc("options/replay_load_cockpit_author")
        ::loc("options/replay_load_cockpit_all")
      ]
      descr.values = [
        ::REPLAY_LOAD_COCKPIT_NO_ONE
        ::REPLAY_LOAD_COCKPIT_AUTHOR
        ::REPLAY_LOAD_COCKPIT_ALL
      ]
      defaultValue = ::REPLAY_LOAD_COCKPIT_AUTHOR
      break

    case ::USEROPT_HUD_SHOW_BONUSES:
      descr.id = "hud_show_bonuses"
      descr.items = ["#options/no", "#options/inarcade", "#options/always"]
      descr.values = [0, 1, 2]
      descr.value = ::get_option_hud_show_bonuses();
      break

    case ::USEROPT_HUD_SCREENSHOT_LOGO:
      descr.id = "hud_screenshot_logo"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_hud_screenshot_logo()
      break

    case ::USEROPT_SAVE_ZOOM_CAMERA:
      descr.id = "save_zoom_camera"
      descr.items = ["#options/zoom/dont_save", "#options/zoom/save_only_tps", "#options/zoom/save"]
      descr.values = [0, 1, 2]
      descr.value = ::get_option_save_zoom_camera() ?? 0
      defaultValue = 0
      break

    case ::USEROPT_HUD_SHOW_FUEL:
      descr.id = "hud_show_fuel"
      descr.items = ["#options/auto", "#options/always"]
      descr.values = [0, 2]

      if (::g_difficulty.SIMULATOR.isAvailable())
      {
        descr.items.insert(1, "#options/inhardcore")
        descr.values.insert(1, 1)
      }

      descr.value = ::find_in_array(descr.values, ::get_option_hud_show_fuel(), 0)
      descr.trParams <- "optionWidthInc:t='half';"
      break

    case ::USEROPT_HUD_SHOW_AMMO:
      descr.id = "hud_show_ammo"
      descr.items = ["#options/auto", "#options/always"]
      descr.values = [0, 2]

      if (::g_difficulty.SIMULATOR.isAvailable())
      {
        descr.items.insert(1, "#options/inhardcore")
        descr.values.insert(1, 1)
      }

      descr.value = ::find_in_array(descr.values, ::get_option_hud_show_ammo(), 0)
      descr.trParams <- "optionWidthInc:t='half';"
      break

    case ::USEROPT_HUD_SHOW_TEMPERATURE:
      descr.id = "hud_show_temperature"
      descr.items = ["#options/auto", "#options/always"]
      descr.values = [0, 2]

      if (::g_difficulty.SIMULATOR.isAvailable())
      {
        descr.items.insert(1, "#options/inhardcore")
        descr.values.insert(1, 1)
      }

      descr.value = ::find_in_array(descr.values, ::get_option_hud_show_temperature(), 0)
      descr.trParams <- "optionWidthInc:t='half';"
      break

    case ::USEROPT_MENU_SCREEN_SAFE_AREA:
      descr.id = "menu_screen_safe_area"
      descr.items  = safeAreaMenu.items
      descr.values = safeAreaMenu.values
      descr.value  = safeAreaMenu.getValueOptionIndex()
      defaultValue = safeAreaMenu.defValue
      break

    case ::USEROPT_HUD_SCREEN_SAFE_AREA:
      descr.id = "hud_screen_safe_area"
      descr.items  = safeAreaHud.items
      descr.values = safeAreaHud.values
      descr.value  = safeAreaHud.getValueOptionIndex()
      defaultValue = safeAreaHud.defValue
      break

    case ::USEROPT_AUTOPILOT_ON_BOMBVIEW:
      descr.id = "autopilot_on_bombview"
      descr.items = ["#options/no", "#options/inmouseaim", "#options/always"]
      descr.values = [0, 1, 2]
      descr.value = ::get_option_autopilot_on_bombview();
      descr.trParams <- "optionWidthInc:t='half';"
      break

    case ::USEROPT_AUTOREARM_ON_AIRFIELD:
      descr.id = "autorearm_on_airfield"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_autorearm_on_airfield()
      break

    case ::USEROPT_ENABLE_LASER_DESIGNATOR_ON_LAUNCH:
      descr.id = "enable_laser_designatior_before_launch"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_enable_laser_designatior_before_launch()
      break;

    case ::USEROPT_AUTO_AIMLOCK_ON_SHOOT:
      descr.id = "auto_aimlock_on_shoot"
      descr.controlType = optionControlType.CHECKBOX;
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_ACTIVATE_AIRBORNE_RADAR_ON_SPAWN:
      descr.id = "activate_airborne_radar_on_spawn"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_activate_airborne_radar_on_spawn()
      break

    case ::USEROPT_USE_RECTANGULAR_RADAR_INDICATOR:
      descr.id = "use_rectangular_radar_indicator"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_use_rectangular_radar_indicator()
      break

    case ::USEROPT_RADAR_TARGET_CYCLING:
      descr.id = "radar_target_cycling"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_radar_target_cycling()
      break

    case ::USEROPT_RADAR_AIM_ELEVATION_CONTROL:
      descr.id = "radar_aim_elevation_control"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = get_option_radar_aim_elevation_control()
      break

    case ::USEROPT_ACTIVATE_AIRBORNE_WEAPON_SELECTION_ON_SPAWN:
      descr.id = "activate_airborne_weapon_selection_on_spawn"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_gui_option(optionId)
      break

    case ::USEROPT_USE_RADAR_HUD_IN_COCKPIT:
      descr.id = "use_radar_hud_in_cockpit"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_use_radar_hud_in_cockpit()
      break

    case ::USEROPT_ACTIVATE_AIRBORNE_ACTIVE_COUNTER_MEASURES_ON_SPAWN:
      descr.id = "activate_airborne_active_counter_measures_on_spawn"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_activate_airborne_active_counter_measures_on_spawn()
      break

    case ::USEROPT_SAVE_AI_TARGET_TYPE:
      descr.id = "save_ai_target_type"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_ai_target_type()
      break

    case ::USEROPT_DEFAULT_AI_TARGET_TYPE:
      descr.id = "default_ai_target_type"
      descr.items = ["#options/ai_gunner_disabled", "#options/ai_gunner_all", "#options/ai_gunner_air", "#options/ai_gunner_ground"]
      descr.values = [0, 1, 2, 3]
      descr.value = ::get_option_default_ai_target_type()
      break

    case ::USEROPT_SHOW_INDICATORS_TYPE:
      descr.id = "show_indicators_type"
      descr.items = ["#options/selected", "#options/centered", "#options/all"]
      descr.values = [0, 1, 2]
      let val = ::get_option_indicators_mode();
      descr.value = (val & ::HUD_INDICATORS_SELECT) ? 0 : ((val & ::HUD_INDICATORS_CENTER) ? 1 : 2);
      break

    case ::USEROPT_SHOW_INDICATORS_NICK:
      descr.id = "show_indicators_nick"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = (::get_option_indicators_mode() & ::HUD_INDICATORS_TEXT_NICK) != 0
      break

    case ::USEROPT_SHOW_INDICATORS_TITLE:
      descr.id = "show_indicators_title"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = (::get_option_indicators_mode() & ::HUD_INDICATORS_TEXT_TITLE) != 0
      break

    case ::USEROPT_SHOW_INDICATORS_AIRCRAFT:
      descr.id = "show_indicators_aircraft"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = (::get_option_indicators_mode() & ::HUD_INDICATORS_TEXT_AIRCRAFT) != 0
      break

    case ::USEROPT_SHOW_INDICATORS_DIST:
      descr.id = "show_indicators_dist"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = (::get_option_indicators_mode() & ::HUD_INDICATORS_TEXT_DIST) != 0
      break

    case ::USEROPT_HELPERS_MODE:
      descr.id = "helpers_mode";
      descr.items = []
      let types = ["mouse_aim", "virtual_instructor", "simplified_controls", "full_real"]
      for(local t=0; t<types.len(); t++)
        descr.items.append({
          text = "#options/" + types[t]
          tooltip = "#options/" + types[t] + "/tooltip"
        })
      descr.values =
      [
        globalEnv.EM_MOUSE_AIM,
        globalEnv.EM_INSTRUCTOR,
        globalEnv.EM_REALISTIC,
        globalEnv.EM_FULL_REAL
      ];
      descr.optionCb = "onHelpersModeChange";
      defaultValue = ::g_aircraft_helpers.getOptionValue(optionId)
      break;

    case ::USEROPT_HELPERS_MODE_GM:
      descr.id = "helpers_mode";
      descr.items = []
      let types = ["mouse_aim", "virtual_instructor", "simplified_controls", "full_real"]
      for(local t=0; t<types.len(); t++)
        descr.items.append({
          text = "#options/" + types[t] + "/tank"
          tooltip = "#options/" + types[t] + "/tank/tooltip"
        })
      descr.values =
      [
        globalEnv.EM_MOUSE_AIM,
        globalEnv.EM_INSTRUCTOR,
        globalEnv.EM_REALISTIC,
        globalEnv.EM_FULL_REAL
      ];
      descr.optionCb = "onHelpersModeChange";
      defaultValue = ::get_option(::USEROPT_HELPERS_MODE).value
      break;

    case ::USEROPT_HUD_COLOR:
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
      descr.value = ::get_option_hud_color()
      break

    case ::USEROPT_HUD_INDICATORS:
      descr.id = "hud_indicators"
      descr.items = [
        "#hud_indicators_presets/preset1",
        "#hud_indicators_presets/preset2",
      ]
      if ("get_option_hud_indicators" in getroottable())
        descr.value = ::get_option_hud_indicators()
      else
        descr.value = 0;
      break

    case ::USEROPT_AI_GUNNER_TIME:
      descr.id = "ai_gunner_time"
      descr.items = ["#options/disabled", "4", "8", "12", "16"]
      descr.value = ::get_option_ai_gunner_time()
      break

    case ::USEROPT_BULLETS0:
    case ::USEROPT_BULLETS1:
    case ::USEROPT_BULLETS2:
    case ::USEROPT_BULLETS3:
    case ::USEROPT_BULLETS4:
    case ::USEROPT_BULLETS5:
      let aircraft = ::aircraft_for_weapons
      let groupIndex = optionId - ::USEROPT_BULLETS0
      descr.id = "bullets" + groupIndex;
      descr.items = []
      descr.values = []
      descr.trParams <- "optionWidthInc:t='double';"
      if (typeof aircraft == "string")
      {
        let air = getAircraftByName(aircraft)
        if (air)
        {
          let bullets = getOptionsBulletsList(air, groupIndex, true)
          descr.title = getBulletsListHeader(air, bullets)

          descr.items = bullets.items
          descr.values = bullets.values
          descr.value = bullets.value
        }
        descr.optionCb = "onMyWeaponOptionUpdate"
      }
      else {
        ::dagor.logerr($"Options: USEROPT_BULLET{groupIndex}: get: Wrong 'aircraft_for_weapons' type")
        ::debugTableData(::aircraft_for_weapons)
        ::callstack()
      }
      break

    case ::USEROPT_MODIFICATIONS:
      let unit = ::getAircraftByName(::aircraft_for_weapons)
      let showFullList = unit?.isBought() || !::isUnitSpecial(unit)
      descr.id = "enable_modifications"
      descr.items = showFullList
        ? ["#options/reference_aircraft", "#options/modified_aircraft"]
        : ["#options/reference_aircraft"]
      descr.values = showFullList
        ? [false, true]
        : [false]
      descr.optionCb = "onUserModificationsUpdate"
      descr.controlType = optionControlType.LIST
      defaultValue = false
      break

    case ::USEROPT_SKIN:
      descr.id = "skin"
      descr.trParams <- "optionWidthInc:t='double';"
      if (typeof ::aircraft_for_weapons == "string")
      {
        let skins = ::g_decorator.getSkinsOption(::aircraft_for_weapons)
        descr.items = skins.items
        descr.values = skins.values
        descr.value = skins.value
      } else
      {
        descr.items = []
        descr.values = []
      }
      break
    case ::USEROPT_USER_SKIN:
      descr.id = "user_skins"
      descr.items = [{
                       text = "#options/disabled"
                       tooltip = "#userSkin/disabled/tooltip"
                    }]
      descr.values = [""]
      defaultValue = ""

      ::dagor.assertf(::cur_aircraft_name!=null, "ERROR: variable cur_aircraft_name is null")

      if (::is_platform_pc && ::has_feature("UserSkins") && ::cur_aircraft_name)
      {
        let userSkins = ::get_user_skins_blk()
        let skinsBlock = userSkins?[::cur_aircraft_name]
        let cdb = ::get_user_skins_profile_blk()
        let setValue = cdb?[::cur_aircraft_name]

        if (skinsBlock)
        {
          for(local i = 0; i < skinsBlock.blockCount(); i++)
          {
            let table = skinsBlock.getBlock(i)
            descr.items.append({
                                text = table.name
                                tooltip = ::loc("userSkin/custom/desc") + " \"" + ::colorize("userlogColoredText", table.name)
                                  + "\"\n" + ::loc("userSkin/custom/note")
                              })

            descr.values.append(table.name)
            if (setValue != null && setValue == table.name)
              descr.value = i + 1
          }
        }
        if (descr.value == null)
        {
          descr.value = 0
          if (setValue)
            cdb[::cur_aircraft_name] = defaultValue
        }
      }
      break

    case ::USEROPT_CONTENT_ALLOWED_PRESET_ARCADE:
    case ::USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC:
    case ::USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR:
    case ::USEROPT_CONTENT_ALLOWED_PRESET:
      let difficulty = contentPreset.getDifficultyByOptionId(optionId)
      defaultValue = difficulty.contentAllowedPresetOptionDefVal
      descr.id = "content_allowed_preset"
      descr.title = ::loc("options/content_allowed_preset")
      if (difficulty != ::g_difficulty.UNKNOWN)
      {
        descr.id += difficulty.diffCode
        descr.title += ::loc("ui/parentheses/space", { text = ::loc(difficulty.locId) })
      }
      descr.hint  = ::loc("guiHints/content_allowed_preset")
      descr.controlType = optionControlType.LIST
      descr.controlName <- "combobox"
      descr.items = []
      descr.values = []
      foreach (value in contentPreset.getContentPresets())
      {
        descr.items.append(::loc("content/tag/" + value))
        descr.values.append(value)
      }
      break


    case ::USEROPT_TANK_SKIN_CONDITION:
      descr.id = "skin_condition"
      descr.controlType = optionControlType.SLIDER
      descr.min <- -100
      descr.max <- 100
      descr.step <- 1
      descr.defVal <- 0
      descr.value = ::hangar_get_tank_skin_condition().tointeger()
      descr.optionCb = "onChangeTankSkinCondition"
      break

    case ::USEROPT_DELAYED_DOWNLOAD_CONTENT:
      descr.id = "delayed_download_content"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_delayed_download_content()
      break

    case ::USEROPT_REPLAY_SNAPSHOT_ENABLED:
      descr.id = "replay_snapshot_enabled"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_gui_option(optionId)
      break

    case ::USEROPT_RECORD_SNAPSHOT_PERIOD:
      descr.id = "record_snapshot_period"
      descr.items = ["120", "60", "30", "10"]
      descr.values = [120, 60, 30, 10]
      descr.value = find_in_array(descr.values, ::get_gui_option(optionId))
      defaultValue = 60
      break

    case ::USEROPT_TANK_CAMO_SCALE:
      descr.id = "camo_scale"
      descr.controlType = optionControlType.SLIDER
      descr.min <- (-100 * TANK_CAMO_SCALE_SLIDER_FACTOR).tointeger()
      descr.max <- (100 * TANK_CAMO_SCALE_SLIDER_FACTOR).tointeger()
      descr.step <- 1
      descr.defVal <- 0
      descr.value = (::hangar_get_tank_camo_scale() * TANK_CAMO_SCALE_SLIDER_FACTOR).tointeger()
      descr.optionCb = "onChangeTankCamoScale"
      break

    case ::USEROPT_TANK_CAMO_ROTATION:
      descr.id = "camo_rotation"
      descr.controlType = optionControlType.SLIDER
      descr.min <- -100
      descr.max <- 100
      descr.step <- 1
      descr.defVal <- 0
      descr.value = ::hangar_get_tank_camo_rotation().tointeger()
      descr.optionCb = "onChangeTankCamoRotation"
      break

    case ::USEROPT_DIFFICULTY:
      descr.id = "difficulty"
      descr.title = ::loc("multiplayer/difficultyShort")
      descr.items = []
      descr.values = []
      descr.diffCode <- []
      descr.optionCb = "onDifficultyChange"

      for(local i = 0; i < ::g_difficulty.types.len(); i++)
      {
        let diff = ::g_difficulty.types[i]
        if (!diff.isAvailable())
          continue

        descr.items.append(diff.getLocName())
        descr.values.append(diff.name)
        descr.diffCode.append(diff.diffCode)
      }

      if (::get_game_mode() != ::GM_TRAINING)
      {
        descr.items.append("#difficulty3")
        descr.values.append("custom")
        descr.diffCode.append(::DIFFICULTY_CUSTOM)
      }

      defaultValue = "arcade";

      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("difficulty", null)
      break

    case ::USEROPT_SEARCH_DIFFICULTY:
      descr.id = "difficulty"
      descr.items = []
      descr.values = []
      descr.idxValues <- []
      descr.optionCb = "onDifficultyChange"

      foreach (idx, diff in ::g_difficulty.types)
        if (diff.isAvailable())
        {
          descr.items.append("#" + diff.locId)
          descr.values.append(diff.name)
          descr.idxValues.append(diff.diffCode)
        }

      if (descr.items.len() > 1)
      {
        descr.items.insert(0, "#options/any")
        descr.values.insert(0, "any")
        descr.idxValues.insert(0, -1)
        defaultValue = "any"
      }

      break

    case ::USEROPT_SEARCH_GAMEMODE:
      descr.id = "mp_mode"
      descr.items = [ "#options/any", "#mainmenu/btnDynamic", "#mainmenu/btnBuilder", "#mainmenu/btnCoop" ]
      descr.values = [ -1, ::GM_DYNAMIC, ::GM_BUILDER, ::GM_SINGLE_MISSION ]
      descr.optionCb = "onGamemodeChange"
      break

    case ::USEROPT_SEARCH_GAMEMODE_CUSTOM:
      descr.id = "mp_mode"
      descr.items = [ "#options/any", "#multiplayer/teamBattleMode", "#multiplayer/dominationMode", "#multiplayer/tournamentMode" ]
      descr.values = [ -1, ::GM_TEAMBATTLE, ::GM_DOMINATION, ::GM_TOURNAMENT ]
      break

    case ::USEROPT_SEARCH_PLAYERMODE:
      descr.id = "mp_mode"
      descr.optionCb = "onPlayerModeChange"
      descr.items = ["#options/any", "#lb/pve", "#lb/pvp"]
      descr.values = [0, 1, 2]
      break

    case ::USEROPT_LB_TYPE:
      descr.id = "lb_type"
      descr.items = ["#lb/timePlayed", "#lb/targetsDestroyed", "#lb/missionsCompleted", "#lb/killRatio", "#lb/flawlessMissions"]
      descr.values = [0, 1, 2, 3, 4]
      break
    case ::USEROPT_LB_MODE:
      descr.id = "lb_mode"
      descr.items = ["#lb/pve", "#lb/pvp"]
      descr.values = [false, true]
      break

    case ::USEROPT_NUM_FRIENDLIES:
      descr.id = "num_friendlies"
      descr.items = []
      descr.values = []
      for (local i = 0; i < 16; i++)
      {
        descr.items.append("" + i)
        descr.values.append(i)
      }
      break

    case ::USEROPT_NUM_ENEMIES:
      descr.id = "num_enemies"
      descr.items = []
      descr.values = []
      for (local i = 0; i <= 16; i++)
      {
        descr.items.append("" + i)
        descr.values.append(i)
      }
      break

    case ::USEROPT_TIME_LIMIT:
      descr.id = "time_limit"
      descr.values = [3, 5, 10, 15, 20, 25, 30, 60, 120, 360]
      descr.items = []
      for(local i = 0; i < descr.values.len(); i++)
        descr.items.append(time.hoursToString(time.secondsToMinutes(descr.values[i]), false))
      defaultValue = 10
      descr.getValueLocText = function(val)
      {
        if (val < 0)
          return ::loc("options/timeLimitAuto")
        if (val > 10000)
          return ::loc("options/timeUnlimited")
        let result = ::getTblValue(values.indexof(val), items)
        if(result != null)
          return result
        return time.hoursToString(time.secondsToMinutes(val), false)
      }
      break

    case ::USEROPT_KILL_LIMIT:
      descr.id = "scoreLimit"
      descr.values = [3, 5, 7, 10, 20]
      descr.items = []
      for (local i = 0; i < descr.values.len(); i++)
        descr.items.append(descr.values[i].tostring());
      defaultValue = descr.values[descr.values.len() / 2];
      break

/*    case ::USEROPT_NUM_PLAYERS:
      descr.id = "numPlayers"
      descr.items = []
      descr.values = []
      local numPlayers = 8
      for (local i = 2; i <= numPlayers; i++)
      {
        descr.items.append("" + i)
        descr.values.append(i)
      }
      descr.optionCb = "onNumPlayers"
      defaultValue = 8
      break

*/
    case ::USEROPT_MISSION_COUNTRIES_TYPE:
      descr.id = "mission_countries_type"
      descr.items = ["#options/countryArcade","#options/countryReal", "#options/countrySymmetric", "#options/countryCustom"]
      descr.values = [misCountries.ALL, misCountries.BY_MISSION, misCountries.SYMMETRIC, misCountries.CUSTOM]
      defaultValue = misCountries.ALL
      descr.optionCb = "onMissionCountriesType"

      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getPublicParam("countriesType", null)
      break

    case ::USEROPT_BIT_COUNTRIES_TEAM_A:
    case ::USEROPT_BIT_COUNTRIES_TEAM_B:
      let team = optionId == ::USEROPT_BIT_COUNTRIES_TEAM_A ? ::g_team.A : ::g_team.B
      descr.id = "countries_team_" + team.id
      descr.sideTag <- team == ::g_team.A ? "country_allies" : "country_axis"
      descr.controlType = optionControlType.BIT_LIST
      descr.controlName <- "multiselect"
      descr.optionCb = "onInstantOptionApply"

      descr.items = []
      descr.values = []
      descr.trParams <- "iconType:t='listbox_country';"
      descr.listClass <- "countries"

      local allowedMask = (1 << shopCountriesList.len()) - 1
      if (::getTblValue("isEventRoom", context, false))
      {
        let allowedList = context?.countries[team.name]
        if (allowedList)
          allowedMask = ::get_bit_value_by_array(allowedList, shopCountriesList)
                        || allowedMask
      }
      else if ("missionName" in context)
      {
        let countries = getSlotbarOverrideCountriesByMissionName(context.missionName)
        if (countries.len())
          allowedMask = ::get_bit_value_by_array(countries, shopCountriesList)
      }
      descr.allowedMask <- allowedMask

      for (local nc = 0; nc < shopCountriesList.len(); nc++)
      {
        let country = shopCountriesList[nc]
        let isEnabled = (allowedMask & (1 << nc)) != 0
        descr.items.append({
          text = "#" + country
          image = ::get_country_icon(country, true)
          enabled = isEnabled
          isVisible = isEnabled
        })
        descr.values.append(country)
      }

      if (::SessionLobby.isInRoom())
      {
        let cList = ::SessionLobby.getPublicParam(descr.sideTag, null)
        if (cList)
          prevValue = ::get_bit_value_by_array(cList, shopCountriesList)
      }
      descr.value = prevValue || ::get_gui_option(optionId)
      if (!descr.value || !::u.isInteger(descr.value))
        descr.value = allowedMask
      else
        descr.value = descr.value & allowedMask

      break

    case ::USEROPT_COUNTRIES_SET:
      descr.id = "countries_set"
      descr.items = []
      descr.values = []
      descr.optionCb = "onInstantOptionApply"
      descr.trParams <- "iconType:t='small'; optionWidthInc:t='double';"

      foreach (idx, countriesSet in (context?.countriesSetList ?? [])) {
        descr.items.append({
          text = ::loc("country/VS")
          images = countriesSet.countries[0].map(@(c) { image = ::get_country_icon(c) })
          imagesAfterText = countriesSet.countries[1].map(@(c) { image = ::get_country_icon(c) })
          textStyle = "margin:t='3@blockInterval, 0';"
        })
        descr.values.append(idx)
      }

      prevValue = ::get_gui_option(optionId)
      defaultValue = 0
      descr.value = (prevValue in descr.values) ? prevValue : defaultValue

      break

    case ::USEROPT_USE_KILLSTREAKS:
      descr.id = "use_killstreaks"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onUseKillStreaks"
      defaultValue = false
      break

    case ::USEROPT_BIT_UNIT_TYPES:
      descr.id = "allowed_unit_types"
      descr.title = ::loc("events/allowed_crafts_no_colon")
      descr.controlType = optionControlType.BIT_LIST
      descr.controlName <- "multiselect"
      descr.showTitle <- true
      descr.optionCb = "onInstantOptionApply"
      descr.items = []
      descr.values = []
      descr.hint = descr.title

      defaultValue = unitTypes.types.reduce(@(res, v) res = res | v.bit, 0)
      prevValue = ::get_gui_option(optionId) ?? defaultValue

      let missionBlk = ::get_mission_meta_info(context?.missionName ?? "")
      let isKillStreaksOptionAvailable = missionBlk && ::is_skirmish_with_killstreaks(missionBlk)
      let useKillStreaks = isKillStreaksOptionAvailable
        && (::get_gui_option(::USEROPT_USE_KILLSTREAKS) ?? false)
      let availableUnitTypesMask = ::get_mission_allowed_unittypes_mask(missionBlk, useKillStreaks)

      descr.availableUnitTypesMask <- availableUnitTypesMask

      foreach (unitType in unitTypes.types)
      {
        if (unitType == unitTypes.INVALID || !unitType.isPresentOnMatching)
          continue
        let isVisible = !!(availableUnitTypesMask & unitType.bit)
        let armyLocName = (unitType == unitTypes.SHIP) ? ::loc("mainmenu/fleet") : unitType.getArmyLocName()
        descr.values.append(unitType.esUnitType)
        descr.items.append({
          id = "bit_" + unitType.tag
          text = unitType.fontIcon + " " + armyLocName
          enabled = isVisible
          isVisible = isVisible
        })
      }

      if (isKillStreaksOptionAvailable)
      {
        let killStreaksOptionLocName = ::loc("options/use_killstreaks")
        descr.textAfter <- ::colorize("fadedTextColor", "+ " + killStreaksOptionLocName)
        descr.hint += "\n" + ::loc("options/advice/disable_option_to_have_more_choices",
          { name = ::colorize("userlogColoredText", killStreaksOptionLocName) })
      }
      break

    case ::USEROPT_BR_MIN:
    case ::USEROPT_BR_MAX:
      let isMin = optionId == ::USEROPT_BR_MIN
      descr.id = isMin ? "battle_rating_min" : "battle_rating_max"
      descr.controlName <- "combobox"
      descr.optionCb = "onInstantOptionApply"
      descr.items = []
      descr.values = []

      let maxEconomicRank = getMaxEconomicRank()
      for (local mrank = 0; mrank <= maxEconomicRank; mrank++)
      {
        let br = ::calc_battle_rating_from_rank(mrank)
        descr.values.append(mrank)
        descr.items.append(format("%.1f", br))
      }

      defaultValue = isMin && descr.items.len() ? 0 : (descr.values.len() - 1)
      break

    case ::USEROPT_RACE_LAPS:
      descr.id = "race_laps"
      descr.values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      defaultValue = 1
      descr.items = []
      for (local i = 0; i < descr.values.len(); i++)
        descr.items.append(descr.values[i].tostring())
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("raceLaps", null)
      break

    case ::USEROPT_RACE_WINNERS:
      descr.id = "race_winners"
      descr.values = [1, 2, 3]
      defaultValue = 1
      descr.items = []
      for (local i = 0; i < descr.values.len(); i++)
        descr.items.append(descr.values[i].tostring())
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("raceWinners", null)
      break

    case ::USEROPT_RACE_CAN_SHOOT:
      descr.id = "race_can_shoot"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      if (::SessionLobby.isInRoom())
      {
        let cannotShoot = ::SessionLobby.getMissionParam("raceForceCannotShoot", null)
        if (cannotShoot != null)
          prevValue = !cannotShoot
      }
      break

    case ::USEROPT_RANK:
      descr.id = "rank"
      descr.title = ::loc("shop/age")
      descr.controlName <- "combobox"
      descr.optionCb = "onInstantOptionApply"

      descr.items = []
      descr.values = []

      if (::getTblValue("isEventRoom", context, false))
      {
        descr.title = ::loc("guiHints/chooseUnitsMMRank")
        let brRanges = ::getTblValue("brRanges", context, [])
        local hasDuplicates = false
        for(local i = 0; i < brRanges.len(); i++)
        {
          let range = brRanges[i]
          let minBR = ::calc_battle_rating_from_rank(::getTblValue(0, range, 0))
          let maxBR = ::calc_battle_rating_from_rank(::getTblValue(1, range, ::max_country_rank))
          let tier = ::events.getTierByMaxBr(maxBR)
          let brText = format("%.1f", minBR)
                       + ((minBR != maxBR) ? " - " + format("%.1f", maxBR) : "")
          let text = brText

          if (descr.values.indexof(tier) != null)
          {
            hasDuplicates = true
            continue
          }
          descr.values.append(tier)
          descr.items.append(text)
        }

        if (::is_dev_version && hasDuplicates)
          ::dagor.assertf(false, "Duplicate BR ranges in matching configs")
      }

      if (!descr.values.len())
        for(local i = 1; i <= ::max_country_rank; i++)
        {
          descr.items.append(::loc("shop/age/num", { num = ::get_roman_numeral(i) }))
          descr.values.append(i)
        }
      break

    case ::USEROPT_BIT_CHOOSE_UNITS_TYPE:
      descr.id = "chooseUnitsType"
      descr.controlType = optionControlType.BIT_LIST
      descr.items = []
      descr.values = []
      for(local i = 0; i < unitTypes.types.len(); i++)
      {
        let unitType = unitTypes.types[i]
        if (!unitType.isAvailable())
          continue
        descr.items.append(unitType.getArmyLocName())
        descr.values.append(unitType.esUnitType)
      }
      break

    case ::USEROPT_BIT_CHOOSE_UNITS_RANK:
      descr.id = "chooseUnitsRank"
      descr.controlType = optionControlType.BIT_LIST
      descr.items = []
      descr.values = []
      for(local i = 1; i <= ::max_country_rank; i++)
      {
        descr.items.append(::get_roman_numeral(i))
        descr.values.append(i)
      }
      break

    case ::USEROPT_BIT_CHOOSE_UNITS_OTHER:
      descr.id = "chooseUnitsOther"
      descr.items = ["#options/chooseUnitsOther/studied", "#options/chooseUnitsOther/unstudied"]
      descr.values = []
      descr.controlType = optionControlType.BIT_LIST
      break

    case ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE:
      descr.id = "chooseUnitsShowUnsupported"
      descr.items = ["#options/chooseUnitsShowUnsupported/show_unsupported",
                     "#options/chooseUnitsShowUnsupported/show_supported"
                    ]
      defaultValue = 3
      descr.singleOption <- true
      descr.hideTitle <- true
      descr.controlType = optionControlType.BIT_LIST
      descr.optionCb = "onSelectedOptionChooseUnsapportedUnit"
      break

    case ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST:
      descr.id = "chooseUnitsNotInCustomList"
      descr.items = ["#options/chooseUnitsNotInCustomList/show_unsupported",
                     "#options/chooseUnitsNotInCustomList/show_supported"
                    ]
      defaultValue = 3
      descr.singleOption <- true
      descr.hideTitle <- true
      descr.controlType = optionControlType.BIT_LIST
      break

    case ::USEROPT_TIME_BETWEEN_RESPAWNS:
      descr.id = "timeBetweenRespawns"
      descr.items = ["30", "40", "50", "60", "120", "180"]
      descr.values = [30, 40, 50, 60, 120, 180]
      break

    case ::USEROPT_YEAR:
      descr.id = "year"
      //filled by onLayoutChange()
      descr.trParams <- "optionWidthInc:t='double';"
      let isKoreanWarDC = ::get_game_mode() == ::GM_DYNAMIC && ::current_campaign?.id == "korea_dynamic"
      let yearsArray = !isKoreanWarDC
        ? [ 1940, 1941, 1942, 1943, 1944, 1945 ]
        : [ 1950, 1951, 1952, 1953 ]
      descr.valuesInt <- yearsArray
      descr.items <- yearsArray.map(@(yyyy) yyyy.tostring())
      descr.values = yearsArray.map(@(yyyy) $"year{yyyy}")
      if (::get_game_mode() == ::GM_DYNAMIC && ::current_campaign)
      {
        let teamOption = ::get_option(::USEROPT_MP_TEAM_COUNTRY)
        let teamIdx = max(teamOption.values[teamOption.value] - 1, 0)
        descr.items = []
        for(local i = 0; i < descr.values.len(); i++)
        {
          local enabled = true
          local tooltip = ""
          let yearId = "country_" + ::current_campaign.countries[teamIdx] + "_" + descr.values[i]
          let blk = ::g_unlocks.getUnlockById(yearId)
          if (blk)
          {
            let config = build_conditions_config(blk)
            ::build_unlock_desc(config)
            enabled = ::is_unlocked_scripted(::UNLOCKABLE_YEAR, yearId)
            tooltip = enabled? "" : config.text
          }
          descr.items.append({
            text = yearsArray[i].tostring()
            enabled = enabled
            tooltip = tooltip
          })
        }
      }
      defaultValue = descr.values[0]
      prevValue = ::get_gui_option(::USEROPT_YEAR)
      descr.value = ::find_in_array(descr.values, prevValue, 0)
      descr.optionCb = "onYearChange"
      break

    case ::USEROPT_TIME_SPAWN:
      descr.id = "spawnTime"
      descr.items = ["5", "10", "15"]
      descr.values = [5.0, 10.0, 15.0]
      break

    case ::USEROPT_MP_TEAM:
      descr.id = "mp_team"
      descr.items = ["#multiplayer/teamA", "#multiplayer/teamB"]
      descr.values = [1, 2]
      descr.optionCb = "onLayoutChange"
      break

    case ::USEROPT_MP_TEAM_COUNTRY_RAND:
    case ::USEROPT_MP_TEAM_COUNTRY:
      descr.id = "mp_team"
      descr.items <- []
      if (optionId == ::USEROPT_MP_TEAM_COUNTRY_RAND)
        descr.values = [0, 1, 2]
      else
        descr.values = [1, 2]

      prevValue = ::get_gui_option(::USEROPT_MP_TEAM)

      local countries = null
      let sessionInfo = ::get_mp_session_info()
      if (sessionInfo)
        countries = ["country_" + sessionInfo.alliesCountry,
                     "country_" + sessionInfo.axisCountry]
      else if (::mission_settings && ::mission_settings.layout)
        countries = ::get_mission_team_countries(::mission_settings.layout)

      if (countries)
      {
        descr.trParams <- "iconType:t='country';"
        descr.trListParams <- "iconType:t='listbox_country';"
        descr.listClass <- "countries"
        local selValue = -1
        for(local i = 0; i < descr.values.len(); i++)
        {
          let c = ::getTblValue(descr.values[i] - 1, countries, "country_0")
          if (!c)
          {
            descr.values.remove(i)
            continue
          }

          local text = "#" + c
          local image = ::get_country_icon(c, true)
          local enabled = false
          local tooltip = ""

          if (::get_game_mode() == ::GM_DYNAMIC && ::current_campaign)
          {
            let countryId = ::current_campaign.id + "_" + ::current_campaign.countries[i]
            let unlock = ::g_unlocks.getUnlockById(countryId)
            if(unlock==null)
              ::dagor.assertf(false, ("Not found unlock " + countryId))
            else
            {
              let blk = build_conditions_config(unlock)
              ::build_unlock_desc(blk)

              text = "#country_" + ::current_campaign.countries[i]
              image = ::get_country_icon("country_" + ::current_campaign.countries[i], true)
              enabled = ::is_unlocked_scripted(::UNLOCKABLE_DYNCAMPAIGN, countryId)
              tooltip = enabled? "" : blk?.text
            }
          }

          descr.items.append({
            text = text
            image = image
            enabled = enabled
            tooltip = tooltip
          })

          if (enabled && (selValue < 0 || prevValue == descr.values[i]))
            selValue = i
        }
        if (selValue >= 0)
          descr.value = selValue
      }

      if (descr.items.len()==0)
      {
        let itemsList = ["#multiplayer/teamRandom", "#multiplayer/teamA", "#multiplayer/teamB"]
        for(local v=0; v< descr.values.len(); v++)
          descr.items.append(itemsList[descr.values[v]])
        descr.value = ::find_in_array(descr.values, prevValue, 0)
      }

      descr.optionCb = "onLayoutChange"
      break

    case ::USEROPT_DMP_MAP:
      descr.id = "dyn_mp_map"
      let modeNo = ::get_game_mode()
      descr.values = []
      descr.items = []
      let gameModeMaps = ::get_game_mode_maps()
      if (modeNo >= 0 && modeNo < gameModeMaps.len())
      {
        for (local i = 0; i < gameModeMaps[modeNo].items.len(); i++)
        {
          if ((modeNo == ::GM_SINGLE_MISSION) || (modeNo == ::GM_EVENT))
            if (!gameModeMaps[modeNo].coop[i])
              continue;

          descr.items.append(gameModeMaps[modeNo].items[i])
          descr.values.append(gameModeMaps[modeNo].values[i])
        }
      }
      descr.optionCb = "onMissionChange"
      break

    case ::USEROPT_DYN_MAP:
      descr.id = "dyn_map"
      descr.values = []
      descr.items = []
      descr.optionCb = "onLayoutChange"
      optionsUtils.fillDynMapOption(descr)
      break

    case ::USEROPT_DYN_ZONE:
      descr.id = "dyn_zone"
      descr.values = []
      descr.items = []
      descr.optionCb = "onSectorChange"
      let dynamic_zones = ::dynamic_get_zones()
      for (local i = 0; i < dynamic_zones.len(); i++)
      {
        descr.items.append(::mission_settings.layoutName+"/"+dynamic_zones[i])
        descr.values.append(dynamic_zones[i])
      }
      break

    case ::USEROPT_DYN_ALLIES:
      descr.id = "dyn_allies"
      descr.items = ["#options/dyncount/few", "#options/dyncount/normal", "#options/dyncount/many"]
      descr.values = [1, 2, 3]
      defaultValue = 2
      break

    case ::USEROPT_DYN_ENEMIES:
      descr.id = "dyn_enemies"
      descr.items = ["#options/dyncount/few", "#options/dyncount/normal", "#options/dyncount/many"]
      descr.values = [1, 2, 3]
      defaultValue = 2
      break

    case ::USEROPT_DYN_FL_ADVANTAGE:
      descr.id = "dyn_fl_advantage"
      descr.items = ["#options/dyn_fl_enemy", "#options/dyn_fl_equal", "#options/dyn_fl_ally"]
      descr.values = [0, 1, 2]
      defaultValue = 1
      break

    case ::USEROPT_DYN_SURROUND:
      descr.id = "dyn_surround"
      descr.items = ["#options/dyncount/front_enemy", "#options/dyncount/front_ally",
                     "#options/dyncount/ally_around_ally", "#options/dyncount/ally_around_enemy",
                     "#options/dyncount/enemy_around_ally", "#options/dyncount/enemy_around_enemy",]
      descr.values = [0, 1, 2, 3, 4, 5]
      descr.optionCb = "onSectorChange"
      break

    case ::USEROPT_DYN_WINS_TO_COMPLETE:
      descr.id = "wins_to_complete"
      descr.items = ["#options/dyncount/capture_all_sectors",
//                     "#options/dyncount/need_3_wins",   //temporary disabled 3 wins for anniversary event
                     "#options/dyncount/need_5_wins",];
      descr.values = [-1, /* 3, */ 5] //temporary disabled 3 wins for anniversary event
      defaultValue = -1
      break;

    case ::USEROPT_OPTIONAL_TAKEOFF:
      descr.id = "optional_takeoff"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("optionalTakeOff", null)
      break

    case ::USEROPT_LOAD_FUEL_AMOUNT:
      {
        descr.id = "fuel_amount"
        descr.items = []
        descr.values = []
        descr.value = null
        defaultValue = -1;
        local maxFuel = 1.0;
        local fuelConsumptionPerHour = 100.0;
        local minutes = [0, 20.0, 30.0, 45.0, 60.0, 1000000.0]
        local isFuelFixed = false
        if(::cur_aircraft_name)
        {
          prevValue = ::get_unit_option(::cur_aircraft_name, ::USEROPT_LOAD_FUEL_AMOUNT)
          maxFuel = ::get_aircraft_max_fuel(::cur_aircraft_name)
          let difOpt = ::get_option(::USEROPT_DIFFICULTY)
          local difficulty = ::SessionLobby.isInRoom() ? ::SessionLobby.getMissionParam("difficulty", difOpt.values[0]) : difOpt.values[difOpt.value]
          if (difficulty == "custom")
            difficulty = ::g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty()).name
          let modOpt = ::get_option(::USEROPT_MODIFICATIONS)
          let useModifications = ::get_game_mode() == ::GM_TEST_FLIGHT || ::get_game_mode() == ::GM_BUILDER ? modOpt.values[modOpt.value] : true
          fuelConsumptionPerHour = ::get_aircraft_fuel_consumption(::cur_aircraft_name, difficulty, useModifications)

          if (fuelConsumptionPerHour > 0 && ::is_in_flight())
          {
            let fixedPercent = ::g_mis_custom_state.getCurMissionRules().getUnitFuelPercent(::cur_aircraft_name)
            if (fixedPercent > 0)
            {
              isFuelFixed = true
              minutes = [fixedPercent * maxFuel / time.minutesToSeconds(fuelConsumptionPerHour)]
              let value = (fixedPercent * 1000000 + 0.5).tointeger()
              if (value != prevValue)
              {
                prevValue = value
                ::set_gui_option(::USEROPT_LOAD_FUEL_AMOUNT, value)
              }
            }
          }
        }

        if (!::is_numeric(prevValue))
        {
          prevValue = ::get_gui_option(::USEROPT_LOAD_FUEL_AMOUNT);
          if (!::is_numeric(prevValue))
            prevValue = -1
        }

        let minFuelPercent = 0.3
        local foundMax = false
        for (local ind = 0; ind < minutes.len(); ind++)
        {
          let m = minutes[ind]
          local timeInHours = time.secondsToMinutes(m)
          let fuelReq = fuelConsumptionPerHour * timeInHours
          local percent = maxFuel > 0.0 ? fuelReq / maxFuel : 0.0
          local text = ""
          if (percent <= minFuelPercent) //minFuel
          {
            if (!isFuelFixed) //we allow to custom rules set fuel below max, but show it as min_tank
            {
              if (descr.values.len() > 0 || m) //only 0 show as minFuelPercent
                continue
              percent = minFuelPercent
              timeInHours = fuelConsumptionPerHour > 0.0 ? maxFuel * percent / fuelConsumptionPerHour : 0.0
            }
            text = ::loc("options/min_tank")
          }
          else if(fuelReq > maxFuel * 0.95) //maxFuel
          {
            if (!isFuelFixed)
            {
              percent = 1.0
              timeInHours = fuelConsumptionPerHour > 0.0 ? maxFuel * percent / fuelConsumptionPerHour : 0.0
            }
            text = ::loc("options/full_tank")
            foundMax = true
          }

          let timeStr = time.hoursToString(timeInHours)
          if (text.len())
            text += ::loc("ui/parentheses/space", { text = timeStr })
          else
            text = timeStr
          descr.items.append(text)
          let value = (percent * 1000000 + 0.5).tointeger()
          descr.values.append(value)
          if(descr.value == null || value <= prevValue)
            descr.value = descr.values.len() - 1

          if (foundMax)
            break
        }
      }
      break

    case ::USEROPT_NUM_ATTEMPTS:
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
      defaultValue = -1
      break

    case ::USEROPT_TICKETS:
      descr.id = "tickets"
      descr.items = ["300", "500", "700", "900", "1200"]
      descr.values = [300, 500, 700, 900, 1200]
      defaultValue = 500
      break

    case ::USEROPT_LIMITED_FUEL:
      descr.id = "limitedFuel"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("isLimitedFuel", false)
      break

    case ::USEROPT_LIMITED_AMMO:
      descr.id = "limitedAmmo"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      if (::SessionLobby.isInRoom())
        prevValue = ::SessionLobby.getMissionParam("isLimitedAmmo", false)
      break

    case ::USEROPT_MISSION_NAME_POSTFIX:
      descr.id = "mission_name_postfix"
      descr.items = []
      descr.values = []
      local index = 0
      if (::current_campaign_mission != null)
      {
        let metaInfo = ::get_mission_meta_info(::current_campaign_mission)
        let values = ::get_mission_types_from_meta_mission_info(metaInfo)
        for (index = 0; index < values.len(); index++)
        {
          descr.items.append("#options/" + values[index])
          descr.values.append(values[index])
        }
      }
      descr.items.append("#options/random")
      descr.values.append("")
      break

    case ::USEROPT_FRIENDLY_SKILL:
    case ::USEROPT_ENEMY_SKILL:
      descr.id = (optionId == ::USEROPT_FRIENDLY_SKILL) ? "friendly_skill" : "enemy_skill"
      descr.items = ["#options/skill0", "#options/skill1", "#options/skill2"]
      descr.values = [0, 1, 2]
      defaultValue = 2
      break

    case ::USEROPT_COUNTRY:
      {
        descr.id = "profileCountry"
        descr.items = []
        descr.values = []
        descr.trParams <- "iconType:t='country';"
        descr.trListParams <- "iconType:t='listbox_country';"
        descr.listClass <- "countries"

        let start = 0; //skip country_0
        let isDominationMode = getGuiOptionsMode() == ::OPTIONS_MODE_MP_DOMINATION
        let dMode = ::game_mode_manager.getCurrentGameMode()
        let event = isDominationMode && dMode && dMode.getEvent()

        for (local nc = start; nc < shopCountriesList.len(); nc++)
        {
          if (::mission_settings.battleMode == BATTLE_TYPES.TANK && nc < 0)
            continue

          let country = (nc < 0) ? "country_0" : shopCountriesList[nc]
          let enabled = (country == "country_0" || ::isCountryAvailable(country))
                          && (!event || ::events.isCountryAvailable(event, country))
          descr.items.append({
            text = "#" + country
            image = ::get_country_icon(country, true, !enabled)
            enabled = enabled
          })
          descr.values.append(country)
        }
        descr.value = 0
        let c = ::get_profile_country_sq()
        for (local nc = 0; nc < descr.values.len(); nc++)
          if (c == descr.values[nc])
          {
            descr.value = nc
          }
        descr.optionCb = "onProfileChange"
      }
      break

    case ::USEROPT_CLUSTER:
    case ::USEROPT_RANDB_CLUSTER:
      descr.id = "cluster"
      descr.items = []
      descr.values = []
      defaultValue = 0

      if (::g_clusters.clusters_info.len() > 0)
      {
        let defaultClusters = split_by_chars(::get_default_network_cluster(), ";")
        let selectedClusters = []
        for(local i = 0; i < ::g_clusters.clusters_info.len(); i++)
        {
          let cluster = ::g_clusters.clusters_info[i]
          let isUnstable = cluster.isUnstable
          descr.items.append({
            text = ::g_clusters.getClusterLocName(cluster.name)
            enable = true
            image = isUnstable ? "#ui/gameuiskin#urgent_warning.svg" : null
            tooltip = isUnstable ? ::loc("multiplayer/cluster_connection_unstable") : null
            isUnstable
          })
          descr.values.append(cluster.name)

          if (::isInArray(cluster.name, defaultClusters))
            selectedClusters.append(descr.values[descr.values.len() - 1])
        }
        defaultValue = selectedClusters.len() > 0 ? ";".join(selectedClusters) : descr.values[0]
      }
      else
      {
        defaultValue = ""
        if (descr.items.len() == 0) //disable_network
        {
          descr.items.append({
            text = "---"
            enable = true
            image = null
            tooltip = null
            isUnstable = false
          })
          descr.values.append(defaultValue)
        }
      }

      prevValue = ::get_gui_option_in_mode(optionId, ::OPTIONS_MODE_MP_DOMINATION)
      if (optionId == ::USEROPT_CLUSTER)
      {
        if (::SessionLobby.isInRoom())
          prevValue = ::SessionLobby.getPublicParam("cluster", null)
      }
      else if (optionId == ::USEROPT_RANDB_CLUSTER)
      {
        descr.controlType = optionControlType.BIT_LIST
        descr.value = 0
        if (::u.isString(prevValue))
          descr.value = ::get_bit_value_by_array(split_by_chars(prevValue, ";"), descr.values)
        if (!descr.value)
          descr.value = ::get_bit_value_by_array(split_by_chars(defaultValue, ";"), descr.values) || 1
      }
      break

    case ::USEROPT_PLAY_INACTIVE_WINDOW_SOUND:
      descr.id = "playInactiveWindowSound"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_gui_option(optionId)
      break

    case ::USEROPT_PILOT:
      descr.id = "profilePilot"
      descr.items = []
      descr.values = []
      descr.trParams <- "iconType:t='pilot';"
      let curPilotImgId = ::get_cur_rank_info().pilotId
      let icons = avatars.getIcons()
      let marketplaceItemdefIds = []
      for (local nc = 0; nc < icons.len(); nc++)
      {
        let unlockId = icons[nc]
        let unlockItem = ::g_unlocks.getUnlockById(unlockId)
        let isShown = ::is_unlocked_scripted(::UNLOCKABLE_PILOT, unlockId) || ::is_unlock_visible(unlockItem)
          || (unlockItem?.hideFeature != null && !::has_feature(unlockItem.hideFeature))
        let marketplaceItemdefId = unlockItem?.marketplaceItemdefId
        if (marketplaceItemdefId != null)
          marketplaceItemdefIds.append(marketplaceItemdefId)
        let item = {
          idx = nc
          unlockId
          image = $"#ui/images/avatars/{unlockId}.png"
          show = isShown
          enabled = ::is_unlocked_scripted(::UNLOCKABLE_PILOT, unlockId)
          tooltipId = ::g_tooltip.getIdUnlock(unlockId, { showProgress = true })
          marketplaceItemdefId
        }
        if (item.show && item.enabled)
        {
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
      break

    case ::USEROPT_CROSSHAIR_TYPE:
      descr.id = "crosshairType"
      descr.items = []
      descr.values = []
      descr.trParams <- "iconType:t='crosshair';"
      let c = ::get_hud_crosshair_type()
      for (local nc = 0; nc < ::crosshair_icons.len(); nc++)
      {
        descr.items.append({
          image = "#ui/gameuiskin#" + ::crosshair_icons[nc]
        })
        descr.values.append(nc)
        if (c == nc)
          descr.value = descr.values.len() - 1
      }
      break

    case ::USEROPT_CROSSHAIR_COLOR:
      descr.id = "crosshairColor"
      descr.items = []
      descr.values = []
      let c = ::get_hud_crosshair_color()
      for (local nc = 0; nc < ::crosshair_colors.len(); nc++)
      {
        descr.values.append(nc)
        let config = crosshair_colors[nc]
        let item = { text = "#crosshairColor/" + config.name }
        if (config.color)
          item.hueColor <- ::g_dagui_utils.color4ToDaguiString(config.color)
        descr.items.append(item)
        if (c == nc)
          descr.value = descr.values.len() - 1
      }
      break

    case ::USEROPT_CD_ENGINE:
      descr.id = "engineControl"
      descr.items = []
      descr.values = []

      foreach (idx, diff in ::g_difficulty.types)
        if (diff.isAvailable())
        {
          descr.items.append("#" + diff.locId)
          descr.values.append(diff.diffCode)
        }

      descr.optionCb = "onCDChange"
      descr.value = getCdOption(::USEROPT_CD_ENGINE)
      break
    case ::USEROPT_CD_GUNNERY:
      descr.id = "realGunnery"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_GUNNERY)
      break
    case ::USEROPT_CD_DAMAGE:
      descr.id = "realDamageModels"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_DAMAGE)
      break
    case ::USEROPT_CD_FLUTTER:
      descr.id = "flutter"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_FLUTTER)
      break
    case ::USEROPT_CD_STALLS:
      descr.id = "stallsAndSpins"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_STALLS)
      break
    case ::USEROPT_CD_REDOUT:
      descr.id = "redOuts"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_REDOUT)
      break
    case ::USEROPT_CD_MORTALPILOT:
      descr.id = "mortalPilots"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_MORTALPILOT)
      break
    case ::USEROPT_CD_BOMBS:
      descr.id = "limitedArmament"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_BOMBS)
      break
    case ::USEROPT_CD_BOOST:
      descr.id = "noArcadeBoost"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_BOOST)
      break
    case ::USEROPT_CD_TPS:
      descr.id = "disableTpsViews"
      descr.items = ["#options/limitViewTps", "#options/limitViewFps", "#options/limitViewCockpit"]
      descr.values = [0, 1, 2]
      descr.optionCb = "onCDChange"
      descr.value = getCdOption(::USEROPT_CD_TPS)
      break
    case ::USEROPT_CD_AIM_PRED:
      descr.id = "hudAimPrediction"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_AIM_PRED)
      break
    case ::USEROPT_CD_MARKERS:
      let teamAirSb = ::loc("options/ally") + ::loc("ui/parentheses/space", { text = ::loc("missions/air_event_simulator") })
      descr.id = "hudMarkers"
      descr.items = ["#options/no", "#options/ally", "#options/all", teamAirSb]
      descr.values = [0, 1, 2, 3]
      descr.optionCb = "onCDChange"
      descr.value = getCdOption(::USEROPT_CD_MARKERS)
      break
    case ::USEROPT_CD_ARROWS:
      descr.id = "hudMarkerArrows"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_ARROWS)
      break
    case ::USEROPT_CD_AIRCRAFT_MARKERS_MAX_DIST:
      descr.id = "hudAircraftMarkersMaxDist"
      descr.items = ["#options/near", "#options/normal", "#options/far", "#options/quality_max"]
      descr.values = [0, 1, 2, 3]
      descr.optionCb = "onCDChange"
      descr.value = getCdOption(::USEROPT_CD_AIRCRAFT_MARKERS_MAX_DIST)
      break
    case ::USEROPT_CD_INDICATORS:
      descr.id = "hudIndicators"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_INDICATORS)
      break
    case ::USEROPT_CD_SPEED_VECTOR:
      descr.id = "hudShowSpeedVector"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_SPEED_VECTOR)
      break
    case ::USEROPT_CD_TANK_DISTANCE:
      descr.id = "hudShowTankDistance"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_TANK_DISTANCE)
      break
    case ::USEROPT_CD_MAP_AIRCRAFT_MARKERS:
      descr.id = "hudMapAircraftMarkers"
      descr.items = ["#options/no", "#options/ally", "#options/all", "#options/player"]
      descr.values = [0, 1, 2, 3]
      descr.optionCb = "onCDChange"
      descr.value = getCdOption(::USEROPT_CD_MAP_AIRCRAFT_MARKERS)
      break
    case ::USEROPT_CD_MAP_GROUND_MARKERS:
      descr.id = "hudMapGroundMarkers"
      descr.items = ["#options/no", "#options/ally", "#options/all"]
      descr.values = [0, 1, 2]
      descr.optionCb = "onCDChange"
      descr.value = getCdOption(::USEROPT_CD_MAP_GROUND_MARKERS)
      break
    case ::USEROPT_CD_MARKERS_BLINK:
      descr.id = "hudMarkersBlink"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_MARKERS_BLINK)
      break
    case ::USEROPT_CD_RADAR:
      descr.id = "hudRadar"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_RADAR)
      break
    case ::USEROPT_CD_DAMAGE_IND:
      descr.id = "hudDamageIndicator"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_DAMAGE_IND)
      break
    case ::USEROPT_CD_LARGE_AWARD_MESSAGES:
      descr.id = "hudLargeAwardMessages"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_LARGE_AWARD_MESSAGES)
      break
    case ::USEROPT_CD_WARNINGS:
      descr.id = "hudWarnings"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange"
      descr.value = !!getCdOption(::USEROPT_CD_WARNINGS)
      break
    case ::USEROPT_CD_AIR_HELPERS:
      descr.id = "aircraftHelpers";
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange";
      descr.value = !!getCdOption(::USEROPT_CD_AIR_HELPERS)
      break;
    case ::USEROPT_CD_COLLECTIVE_DETECTION:
      descr.id = "collectiveDetection";
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange";
      descr.value = !!getCdOption(::USEROPT_CD_COLLECTIVE_DETECTION)
      break;
    case ::USEROPT_CD_DISTANCE_DETECTION:
      descr.id = "distanceDetection";
      descr.items = ["#options/near", "#options/normal", "#options/far"];
      descr.values = [0, 1, 2];
      descr.optionCb = "onCDChange";
      descr.value = getCdOption(::USEROPT_CD_DISTANCE_DETECTION)
      break;
    case ::USEROPT_CD_ALLOW_CONTROL_HELPERS:
      descr.id = "allowControlHelpers";
      descr.items = ["#options/allHelpers", "#options/Instructor", "#options/Realistic", "#options/no"];
      descr.values = [0, 1, 2, 3];
      descr.optionCb = "onCDChange";
      descr.value = getCdOption(::USEROPT_CD_ALLOW_CONTROL_HELPERS)
      break;
    case ::USEROPT_CD_FORCE_INSTRUCTOR:
      descr.id = "forceInstructor";
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onCDChange";
      descr.value = !!getCdOption(::USEROPT_CD_FORCE_INSTRUCTOR)
      break;

    case ::USEROPT_INTERNET_RADIO_ACTIVE:
      descr.id = "internet_radio_active";
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_internet_radio_options()?.active ?? false
      descr.optionCb = "update_internet_radio";
      break;
    case ::USEROPT_INTERNET_RADIO_STATION:
      descr.id = "internet_radio_station";
      descr.items = []
      descr.values = ::get_internet_radio_stations();
      for (local i = 0; i < descr.values.len(); i++)
      {
        let str = "InternetRadio/" + descr.values[i];
        let url_radio = ::get_internet_radio_path(descr.values[i])
        if (::loc(str, "") == "")
          descr.items.append({
            text = descr.values[i],
            tooltip = url_radio
          })
        else
          descr.items.append({
            text = "#" + str,
            tooltip = url_radio
          })
      }
      if (!descr.values.len())
      {
        descr.values.append("")
        descr.items.append("#options/no_internet_radio_stations")
      }
      descr.value = ::find_in_array(descr.values, ::get_internet_radio_options()?.station ?? "", 0)
      descr.optionCb = "update_internet_radio";
      break;

    case ::USEROPT_HEADTRACK_ENABLE:
      descr.id = "headtrack_enable"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::ps4_headtrack_get_enable()
      descr.optionCb = "onHeadtrackEnableChange"
      break

    case ::USEROPT_HEADTRACK_SCALE_X:
      descr.id = "headtrack_scale_x"
      descr.controlType = optionControlType.SLIDER
      descr.value = clamp(::ps4_headtrack_get_xscale(), 5, 200)
      descr.min <- 5
      descr.max <- 200
      break
    case ::USEROPT_HEADTRACK_SCALE_Y:
      descr.id = "headtrack_scale_y"
      descr.controlType = optionControlType.SLIDER
      descr.value = clamp(::ps4_headtrack_get_yscale(), 5, 200)
      descr.min <- 5
      descr.max <- 200
      break

    case ::USEROPT_HUE_ALLY:
      optionsUtils.fillHueOption(descr, "color_picker_hue_ally", 226, ::get_hue(colorCorrector.TARGET_HUE_ALLY))
      break

    case ::USEROPT_HUE_ENEMY:
      optionsUtils.fillHueOption(descr, "color_picker_hue_enemy", 3, ::get_hue(colorCorrector.TARGET_HUE_ENEMY))
      break

    case ::USEROPT_STROBE_ALLY:
      descr.id = "strobe_ally"
      descr.items = ["#options/no", "#options/one_smooth_flash", "#options/two_smooth_flashes", "#options/two_sharp_flashes"]
      descr.values = [0, 1, 2, 3]
      descr.value = ::get_strobe_ally();
      break

    case ::USEROPT_STROBE_ENEMY:
      descr.id = "strobe_enemy"
      descr.items = ["#options/no", "#options/one_smooth_flash", "#options/two_smooth_flashes", "#options/two_sharp_flashes"]
      descr.values = [0, 1, 2, 3]
      descr.value = ::get_strobe_enemy();
      break

    case ::USEROPT_HUE_SQUAD:
      optionsUtils.fillHueOption(descr, "color_picker_hue_squad", 472, ::get_hue(colorCorrector.TARGET_HUE_SQUAD))
      break

    case ::USEROPT_HUE_SPECTATOR_ALLY:
      optionsUtils.fillHueOption(descr, "color_picker_hue_spectator_ally", 112, ::get_hue(colorCorrector.TARGET_HUE_SPECTATOR_ALLY))
      break

    case ::USEROPT_HUE_SPECTATOR_ENEMY:
      optionsUtils.fillHueOption(descr, "color_picker_hue_spectator_enemy", 292, ::get_hue(colorCorrector.TARGET_HUE_SPECTATOR_ENEMY))
      break

    case ::USEROPT_HUE_RELOAD:
      optionsUtils.fillHueOption(descr, "color_picker_hue_reload", 3, ::get_hue(colorCorrector.TARGET_HUE_RELOAD))
      break

    case ::USEROPT_HUE_RELOAD_DONE:
      optionsUtils.fillHueOption(descr, "color_picker_hue_reload_done", 472, ::get_hue(colorCorrector.TARGET_HUE_RELOAD_DONE))
      break

    case ::USEROPT_AIR_DAMAGE_DISPLAY:
      descr.id = "air_damage_display"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_GUNNER_FPS_CAMERA:
      descr.id = "gunner_fps_camera"
      descr.controlType = optionControlType.CHECKBOX;
      descr.controlName <- "switchbox"
      defaultValue = true
      break

    case ::USEROPT_HUE_AIRCRAFT_PARAM_HUD:
      optionsUtils.fillHueSaturationBrightnessOption(descr, "color_picker_hue_aircraft_param_hud",
        10, 0.0, 0.9, ::get_hue(colorCorrector.TARGET_HUE_AIRCRAFT_PARAM_HUD))
      break;

    case ::USEROPT_HUE_AIRCRAFT_HUD_ALERT:
      optionsUtils.fillMultipleHueOption(descr, "color_picker_hue_aircraft_hud_alert", colorCorrector.getAlertAircraftHues())
      break;

    case ::USEROPT_HUE_AIRCRAFT_HUD:
      optionsUtils.fillHueSaturationBrightnessOption(descr, "color_picker_hue_aircraft_hud",
        122, 1.0, 1.0, ::get_hue(colorCorrector.TARGET_HUE_AIRCRAFT_HUD))
      break;

    case ::USEROPT_HUE_HELICOPTER_CROSSHAIR:
      optionsUtils.fillHueSaturationBrightnessOption(descr, "color_picker_hue_helicopter_crosshair",
        122, 0.7, 0.7, ::get_hue(colorCorrector.TARGET_HUE_HELICOPTER_CROSSHAIR))
      break;

    case ::USEROPT_HUE_HELICOPTER_HUD:
      optionsUtils.fillHueSaturationBrightnessOption(descr, "color_picker_hue_helicopter_hud",
        122, 1.0, 1.0, ::get_hue(colorCorrector.TARGET_HUE_HELICOPTER_HUD))
      break;

    case ::USEROPT_HUE_HELICOPTER_PARAM_HUD:
      optionsUtils.fillHueSaturationBrightnessOption(descr, "color_picker_hue_helicopter_param_hud",
        122, 1.0, 1.0, ::get_hue(colorCorrector.TARGET_HUE_HELICOPTER_PARAM_HUD))
      break;

    case ::USEROPT_HUE_HELICOPTER_HUD_ALERT:
      if (::has_feature("reactivGuiForAircraft"))
        optionsUtils.fillMultipleHueOption(descr, "color_picker_hue_helicopter_hud_alert", colorCorrector.getAlertHelicopterHues())
      else
        optionsUtils.fillHueOption(descr, "color_picker_hue_helicopter_hud_alert", 0, ::get_hue(colorCorrector.TARGET_HUE_HELICOPTER_HUD_ALERT_HIGH))
      break;

    case ::USEROPT_HUE_ARBITER_HUD:
      optionsUtils.fillHueSaturationBrightnessOption(descr, "color_picker_hue_arbiter_hud",
        64, 0.0, 1.0, ::get_hue(colorCorrector.TARGET_HUE_ARBITER_HUD)) // white default
      break;

    case ::USEROPT_HUE_HELICOPTER_MFD:
      optionsUtils.fillHueOption(descr, "color_picker_hue_helicopter_mfd", 112, ::get_hue(colorCorrector.TARGET_HUE_HELICOPTER_MFD))
      break;

    case ::USEROPT_HUE_TANK_THERMOVISION:
      optionsUtils.fillHSVOption_ThermovisionColor(descr)
      break;

    case ::USEROPT_HORIZONTAL_SPEED:
      descr.id = "horizontalSpeed"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_horizontal_speed() != 0
      break

    case ::USEROPT_HELICOPTER_HELMET_AIM:
      descr.id = "helicopterHelmetAim"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_use_oculus_to_aim_helicopter() != 0
      break

    case ::USEROPT_HELICOPTER_AUTOPILOT_ON_GUNNERVIEW:
      descr.id = "helicopter_autopilot_on_gunnerview"
      descr.items = ["#options/no", "#options/inmouseaim", "#options/always", "#options/always_damping"]
      descr.values = [0, 1, 2, 3]
      descr.value = ::get_option_auto_pilot_on_gunner_view_helicopter();
      descr.trParams <- "optionWidthInc:t='half';"
      break

    case ::USEROPT_SHOW_DESTROYED_PARTS:
      descr.id = "show_destroyed_parts"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_show_destroyed_parts()
      break

    case ::USEROPT_ACTIVATE_GROUND_RADAR_ON_SPAWN:
      descr.id = "activate_ground_radar_on_spawn"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_activate_ground_radar_on_spawn()
      break

    case ::USEROPT_GROUND_RADAR_TARGET_CYCLING:
      descr.id = "ground_radar_target_cycling"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_ground_radar_target_cycling()
      break

    case ::USEROPT_ACTIVATE_GROUND_ACTIVE_COUNTER_MEASURES_ON_SPAWN:
      descr.id = "activate_ground_active_counter_measures_on_spawn"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_activate_ground_active_counter_measures_on_spawn()
      break

    case ::USEROPT_FPS_CAMERA_PHYSICS:
      descr.id = "fps_camera_physics"
      descr.value = clamp((::get_option_multiplier(::OPTION_FPS_CAMERA_PHYS) * 100.0).tointeger(), 0, 100)
      descr.controlType = optionControlType.SLIDER
      break

    case ::USEROPT_FPS_VR_CAMERA_PHYSICS:
      descr.id = "fps_vr_camera_physics"
      descr.value = clamp((::get_option_multiplier(::OPTION_FPS_VR_CAMERA_PHYS) * 100.0).tointeger(), 0, 100)
      descr.controlType = optionControlType.SLIDER
      break

    case ::USEROPT_FREE_CAMERA_INERTIA:
      descr.id = "free_camera_inertia"
      descr.value = clamp((::get_option_multiplier(::OPTION_FREE_CAMERA_INERTIA) * 100.0).tointeger(), 0, 100)
      break

    case ::USEROPT_REPLAY_CAMERA_WIGGLE:
      descr.id = "replay_camera_wiggle"
      descr.value = clamp((::get_option_multiplier(::OPTION_REPLAY_CAMERA_WIGGLE) * 100.0).tointeger(), 0, 100)
      break

    case ::USEROPT_CLAN_REQUIREMENTS_MIN_AIR_RANK:
    case ::USEROPT_CLAN_REQUIREMENTS_MIN_TANK_RANK:
      if (optionId == ::USEROPT_CLAN_REQUIREMENTS_MIN_AIR_RANK)
      {
        descr.id = "rankReqAircraft"
        descr.title = ::loc("clan/rankReqAircraft")
      }
      else if (optionId == ::USEROPT_CLAN_REQUIREMENTS_MIN_TANK_RANK)
      {
        descr.id = "rankReqTank"
        descr.title = ::loc("clan/rankReqTank")
      }
      descr.optionCb = "onRankReqChange"
      descr.items = []
      descr.values = []
      for(local rank = 0; rank <= ::max_country_rank; ++rank)
      {
        descr.values.append(format("option_%s", rank.tostring()))
        descr.items.append({
          text = (rank == 0 ? ::loc("clan/membRequirementsRankAny") : ::get_roman_numeral(rank))
        })
      }
      descr.value = ::find_in_array(descr.values, "option_0")
      break
    case ::USEROPT_CLAN_REQUIREMENTS_ALL_MIN_RANKS:
      descr.id = "clan_req_all_min_ranks"
      descr.title = ::loc("clan/rankConditionType")
      descr.textUnchecked <- ::loc("clan/minRankCondType_or")
      descr.textChecked <- ::loc("clan/minRankCondType_and")
      break
    case ::USEROPT_CLAN_REQUIREMENTS_MIN_ARCADE_BATTLES:
    case ::USEROPT_CLAN_REQUIREMENTS_MIN_SYM_BATTLES:
    case ::USEROPT_CLAN_REQUIREMENTS_MIN_REAL_BATTLES:
      if (optionId == ::USEROPT_CLAN_REQUIREMENTS_MIN_ARCADE_BATTLES)
      {
        descr.id = "battles_arcade"
        descr.title = ::loc("clan/battlesSelect_arcade")
      }
      else if (optionId == ::USEROPT_CLAN_REQUIREMENTS_MIN_SYM_BATTLES)
      {
        descr.id = "battles_simulation"
        descr.title = ::loc("clan/battlesSelect_simulation")
      }
      else if (optionId == ::USEROPT_CLAN_REQUIREMENTS_MIN_REAL_BATTLES)
      {
        descr.id = "battles_historical"
        descr.title = ::loc("clan/battlesSelect_historical")
      }
      descr.items = []
      descr.values = [0, 1, 3, 5, 8, 10, 20, 30, 40, 50, 75, 100, 200, 300, 400, 500, 750, 1000 ]
      for (local i = 0; i < descr.values.len(); i++)
        descr.items.append(descr.values[i] == 0 ? ::loc("clan/membRequirementsRankAny") : descr.values[i].tostring())
      descr.value = 0
      break
    case ::USEROPT_CLAN_REQUIREMENTS_AUTO_ACCEPT_MEMBERSHIP:
      descr.id = "clan_req_auto_accept_membership"
      descr.title = ::loc("clan/autoAcceptMembershipOn")
      break
    case ::USEROPT_TANK_GUNNER_CAMERA_FROM_SIGHT:
      descr.id = "tank_gunner_camera_from_sight"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_option_tank_gunner_camera_from_sight()
      defaultValue = false
      break
    case ::USEROPT_TANK_ALT_CROSSHAIR:
      descr.id = "tank_alt_crosshair"
      descr.optionCb = "onTankAltCrosshair"

      descr.items = []
      descr.values = []

      if (!has_forced_crosshair())
      {
        descr.items.append(::loc("options/defaultSight"));
        descr.values.append("");
      }

      let presets = ::get_user_alt_crosshairs()
      for (local i = 0; i < presets.len(); i++)
      {
        descr.items.append(presets[i]);
        descr.values.append(presets[i]);
      }

      if (::has_feature("TankAltCrosshair"))
      {
        descr.items.append(::loc("options/addUserSight"))
        descr.values.append(TANK_ALT_CROSSHAIR_ADD_NEW)
      }

      let unit = getPlayerCurUnit()
      descr.value = unit ? ::find_in_array(descr.values, ::get_option_tank_alt_crosshair(unit.name), 0) : 0
      break
    case ::USEROPT_GAMEPAD_CURSOR_CONTROLLER:
      descr.id = "gamepad_cursor_controller"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::g_gamepad_cursor_controls.getValue()
      break
    case ::USEROPT_PS4_CROSSPLAY:
      descr.id = "ps4_crossplay"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.optionCb = "onChangeCrossPlay"
      descr.value = crossplayModule.isCrossPlayEnabled()
      descr.enabled <- !::checkIsInQueue()
      break
    //







    case ::USEROPT_PS4_CROSSNETWORK_CHAT:
      descr.id = "ps4_crossnetwork_chat"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = crossplayModule.isCrossNetworkChatEnabled()
      descr.optionCb = "onChangeCrossNetworkChat"
      break
    case ::USEROPT_DISPLAY_MY_REAL_NICK:
      descr.id = "display_my_real_nick"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_gui_option_in_mode(optionId, ::OPTIONS_MODE_GAMEPLAY, true)
      defaultValue = true
      descr.defVal <- defaultValue
      break

    case ::USEROPT_SHOW_SOCIAL_NOTIFICATIONS:
      descr.id = "show_social_notifications"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      defaultValue = true
      descr.defVal <- defaultValue
      break

    case ::USEROPT_ALLOW_ADDED_TO_CONTACTS:
      descr.id = "allow_added_to_contacts"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_allow_to_be_added_to_contacts()
      defaultValue = true
      descr.defVal <- defaultValue
      break

    case ::USEROPT_ALLOW_ADDED_TO_LEADERBOARDS:
      descr.id = "allow_added_to_leaderboards"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.value = ::get_allow_to_be_added_to_lb()
      defaultValue = true
      descr.defVal <- defaultValue
      break

    case ::USEROPT_PS4_ONLY_LEADERBOARD:
      descr.id = "ps4_only_leaderboards"
      descr.controlType = optionControlType.CHECKBOX
      descr.controlName <- "switchbox"
      descr.enabled <- crossplayModule.isCrossPlayEnabled()
      defaultValue = false
      break

    case ::USEROPT_PRELOADER_SETTINGS:
      descr.id = "preloader_settings"
      descr.controlType = optionControlType.BUTTON
      descr.funcName <- "onPreloaderSettings"
      descr.delayed <- true
      descr.shortcut <- "R3"
      descr.text <- ::loc("preloaderSettings/title")
      descr.title = descr.text
      descr.showTitle <- false
      break

    case ::USEROPT_REVEAL_NOTIFICATIONS:
      descr.id = "reveal_notifications"
      descr.controlType = optionControlType.BUTTON
      descr.funcName <- "onRevealNotifications"
      descr.delayed <- true
      descr.shortcut <- "LB"
      descr.text <- ::loc("mainmenu/btnRevealNotifications")
      descr.title = descr.text
      descr.showTitle <- false
      break

    case ::USEROPT_HDR_SETTINGS:
      descr.id = "hdr_settings"
      descr.controlType = optionControlType.BUTTON
      descr.funcName <- "onHdrSettings"
      descr.delayed <- true
      descr.shortcut <- "RB"
      descr.text <- ::loc("mainmenu/btnHdrSettings")
      descr.title = descr.text
      descr.showTitle <- false
      break

    case ::USEROPT_POSTFX_SETTINGS:
      descr.id = "postfx_setting"
      descr.controlType = optionControlType.BUTTON
      descr.funcName <- "onPostFxSettings"
      descr.delayed <- true
      descr.shortcut <- "X"
      descr.text <- ::loc("mainmenu/btnPostFxSettings")
      descr.title = descr.text
      descr.showTitle <- false
      break

    case ::USEROPT_HOLIDAYS:
      defaultValue = holidays.get_default_culture()
      descr.defVal <- defaultValue
      descr.id = "holidays"
      descr.items = []
      descr.values = []
      let cultures = holidays.list_cultures()
      for (local i = 0; i < cultures.len(); i++)
      {
        descr.values.append(cultures[i])
        descr.items.append(::loc($"options/holidays_{cultures[i]}", cultures[i]))
      }
      break

    default:
      let optionName = ::user_option_name_by_idx?[optionId] ?? ""
      ::dagor.assertf(false, $"[ERROR] Options: Get: Unsupported type {optionId} ({optionName})")
      ::debugTableData(::aircraft_for_weapons)
      ::callstack()
  }

  if (!descr.hint)
    descr.hint = ::loc("guiHints/" + descr.id, "")

  if (descr.needRestartClient)
    descr.hint = "\n".concat(descr.hint, ::colorize("warningTextColor", ::loc("guiHints/restart_required")))

  local valueToSet = defaultValue
  if (prevValue == null)
    prevValue = ::get_gui_option(optionId)
  if (prevValue != null)
    valueToSet = prevValue

  descr.needShowValueText = descr.needShowValueText || descr.controlType == optionControlType.SLIDER
  if (descr.needShowValueText && !descr.optionCb)
    descr.optionCb = "updateOptionValueTextByObj"
  descr.cb <- context?.containerCb ?? descr.optionCb

  if (descr.controlType == optionControlType.SLIDER)
  {
    if (descr.value == null)
      descr.value = clamp(valueToSet || 0, descr?.min ?? 0, descr?.max ?? 1)
    return descr
  }

  if (descr.controlType == optionControlType.CHECKBOX)
  {
    if (descr.value == null)
      descr.value = !!valueToSet
    return descr
  }

  if (descr.controlType == optionControlType.EDITBOX)
  {
    if (!::u.isString(descr.value))
      descr.value = ::u.isString(valueToSet) ? valueToSet : ""
    return descr
  }

  if (!descr.values && descr.items)
  {
    descr.values = []
    for(local i = 0; i < descr.items.len(); i++)
      descr.values.append(i)
  }

  if (descr.controlType == optionControlType.BIT_LIST)
  {
    if (!::u.isInteger(descr.value))
      if (::u.isInteger(prevValue))
        descr.value = prevValue
      else
        descr.value = defaultValue || 0
    return descr
  }

  if (descr.value != null &&
      typeof descr.values == "array" &&
      descr.values.len() > 0 &&
      !(descr.value in descr.values))
    descr.value = null

  if (descr.value == null && valueToSet != null && typeof descr.values == "array")
    for (local i = 0; i < descr.values.len(); i++)
    {
      if (descr.values[i] == valueToSet)
      {
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

::set_option <- function set_option(optionId, value, descr = null)
{
  if (!descr)
    descr = ::get_option(optionId)

  switch (optionId)
  {
    // global settings:
    case ::USEROPT_LANGUAGE:
      ::g_language.setGameLocalization(descr.values[value], false, true)
      break
    case ::USEROPT_VIEWTYPE:
      ::set_option_view_type(value)
      break
    case ::USEROPT_SPEECH_TYPE:
      let curOption = ::get_option(::USEROPT_SPEECH_TYPE)
      ::set_option_speech_country_type(descr.values[value])
      checkUnitSpeechLangPackWatch(curOption.value != value && value == SPEECH_COUNTRY_UNIT_VALUE)
      break
    case ::USEROPT_GUN_TARGET_DISTANCE:
      ::set_option_gun_target_dist(descr.values[value])
      break
    case ::USEROPT_BOMB_ACTIVATION_TIME:
      let isBombActivationAssault = descr.values[value] == ::BOMB_ASSAULT_FUSE_TIME_OPT_VALUE
      let bombActivationDelay = isBombActivationAssault ?
        ::get_bomb_activation_auto_time() : descr.values[value]
      let bombActivationType = isBombActivationAssault ? BOMB_ACT_ASSAULT : BOMB_ACT_TIME
      ::set_option_bomb_activation_type(bombActivationType)
      ::set_option_bomb_activation_time(bombActivationDelay)
      ::save_local_account_settings($"useropt/bomb_activation_time/{descr.diffCode}", bombActivationDelay)
      ::save_local_account_settings($"useropt/bomb_activation_type/{descr.diffCode}", bombActivationType)
      break
    case ::USEROPT_BOMB_SERIES:
      ::set_option_bombs_series(descr.values[value])
      break
    case ::USEROPT_LOAD_FUEL_AMOUNT:
      ::set_gui_option(optionId, descr.values[value])
      if (::aircraft_for_weapons)
       ::set_unit_option(::aircraft_for_weapons, optionId, descr.values[value])
      break
    case ::USEROPT_DEPTHCHARGE_ACTIVATION_TIME:
      ::set_option_depthcharge_activation_time(descr.values[value])
      break
    case ::USEROPT_COUNTERMEASURES_PERIODS:
      ::set_option_countermeasures_periods(descr.values[value])
      break
    case ::USEROPT_COUNTERMEASURES_SERIES_PERIODS:
      ::set_option_countermeasures_series_periods(descr.values[value])
      break
    case ::USEROPT_COUNTERMEASURES_SERIES:
      ::set_option_countermeasures_series(descr.values[value])
      break
    case ::USEROPT_USE_PERFECT_RANGEFINDER:
      ::set_option_use_perfect_rangefinder(value ? 1 : 0)
      break
    case ::USEROPT_ROCKET_FUSE_DIST:
      ::set_option_rocket_fuse_dist(descr.values[value])
      if (::aircraft_for_weapons)
        ::set_unit_option(::aircraft_for_weapons, optionId, descr.values[value])
      break
    case ::USEROPT_TORPEDO_DIVE_DEPTH:
      ::set_option_torpedo_dive_depth(descr.values[value])
      if (::aircraft_for_weapons)
        ::set_unit_option(::aircraft_for_weapons, optionId, descr.values[value])
      break
    case ::USEROPT_AEROBATICS_SMOKE_TYPE:
      ::set_option_aerobatics_smoke_type(descr.values[value])
      break

    case ::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR:
    case ::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR:
    case ::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR:
      {
        let optIndex = find_in_array(
          [::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, ::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, ::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR],
          optionId)

        ::set_option_aerobatics_smoke_color(optIndex, descr.values[value]);
      }
      break;

    case ::USEROPT_INGAME_VIEWTYPE:
      ::apply_current_view_type(value)
      break
    case ::USEROPT_INVERTY:
      ::set_option_invertY(AxisInvertOption.INVERT_Y, value ? 1 : 0)
      break
    case ::USEROPT_INVERTX:
      ::set_option_invertX(value ? 1 : 0)
      break
    case ::USEROPT_GUNNER_INVERTY:
      ::set_option_invertY(AxisInvertOption.INVERT_GUNNER_Y, value ? 1 : 0)
      break
    case ::USEROPT_INVERT_THROTTLE:
      ::set_option_invertY(AxisInvertOption.INVERT_THROTTLE, value)
      break
    case ::USEROPT_INVERTY_TANK:
      ::set_option_invertY(AxisInvertOption.INVERT_TANK_Y, value ? 1 : 0)
      break
    case ::USEROPT_INVERTY_SHIP:
      ::set_option_invertY(AxisInvertOption.INVERT_SHIP_Y, value ? 1 : 0)
      break
    case ::USEROPT_INVERTY_HELICOPTER:
      ::set_option_invertY(AxisInvertOption.INVERT_HELICOPTER_Y, value ? 1 : 0)
      break
    case ::USEROPT_INVERTY_HELICOPTER_GUNNER:
      ::set_option_invertY(AxisInvertOption.INVERT_HELICOPTER_GUNNER_Y, value ? 1 : 0)
      break
    //




    case ::USEROPT_INVERTY_SUBMARINE:
      ::set_option_invertY(AxisInvertOption.INVERT_SUBMARINE_Y, value ? 1 : 0)
      break
    case ::USEROPT_INVERTY_SPECTATOR:
      ::set_option_invertY(AxisInvertOption.INVERT_SPECTATOR_Y, value ? 1 : 0)
      break

    ///_INSERT_OPTIONS_HERE_
    //case ::USEROPT_USE_TRACKIR_ZOOM:
    //  ::set_option_useTrackIrZoom(value)
    //  break

    case ::USEROPT_FORCE_GAIN:
      ::set_option_gain(value/50.0)
      break

    case ::USEROPT_INDICATED_SPEED_TYPE:
      ::set_option_indicatedSpeedType(descr.values[value])
      break

    case ::USEROPT_AUTO_SHOW_CHAT:
      ::set_option_autoShowChat(value ? 1 : 0)
      break

    case ::USEROPT_CHAT_MESSAGES_FILTER:
      ::set_option_chat_messages_filter(value)
      break

    case ::USEROPT_CHAT_FILTER:
      ::set_option_chatFilter(value ? 1 : 0)
      ::broadcastEvent("ChatFilterChanged")
      break

    case ::USEROPT_SHOW_PILOT:
      ::set_option_showPilot(value ? 1 : 0)
      break

    case ::USEROPT_GUN_VERTICAL_TARGETING:
      ::set_option_gunVerticalTargeting(value ? 1 : 0)
      break

    case ::USEROPT_INVERTCAMERAY:
      ::set_option_camera_invertY(value ? 1 : 0)
      break

    case ::USEROPT_ZOOM_FOR_TURRET:
      ::dagor.debug("USEROPT_ZOOM_FOR_TURRET" + value.tostring())
      ::set_option_zoom_turret(value)
      ::apply_joy_preset_xchange(null)
      break

    case ::USEROPT_XCHG_STICKS:
      ::set_option_xchg_sticks(0, value? 1 : 0)
      break

    case ::USEROPT_AUTOSAVE_REPLAYS:
      ::set_option_autosave_replays(value)
      break

    case ::USEROPT_XRAY_DEATH:
      ::set_option_xray_death(value)
      break

    case ::USEROPT_XRAY_KILL:
      ::set_option_xray_kill(value)
      break

    case ::USEROPT_USE_CONTROLLER_LIGHT:
      ::set_option_controller_light(value)
      break

    case ::USEROPT_SUBTITLES:
      ::set_option_subs(value ? 2 : 0)
      break

    case ::USEROPT_SUBTITLES_RADIO:
      ::set_option_subs_radio(value ? 2 : 0)
      break

    case ::USEROPT_PTT:
      ::set_option_ptt(value ? 1 : 0)
      break

    case ::USEROPT_VOICE_CHAT:
      ::set_option_voicechat(value ? 1 : 0)
      break

    case ::USEROPT_SOUND_ENABLE:
      set_mute_sound(value)
      ::setSystemConfigOption("sound/fmod_sound_enable", value)
      break

    case ::USEROPT_SOUND_SPEAKERS_MODE:
      ::setSystemConfigOption("sound/speakerMode", descr.values[value])
      break

    case ::USEROPT_VOICE_MESSAGE_VOICE:
      ::set_option_voice_message_voice(value + 1) //1-based
      break

    case ::USEROPT_HUD_COLOR:
      ::set_option_hud_color(value)
      break

    case ::USEROPT_HUD_INDICATORS:
      if ("set_option_hud_indicators" in getroottable())
        ::set_option_hud_indicators(value)
      break

    case ::USEROPT_DELAYED_DOWNLOAD_CONTENT:
      ::set_option_delayed_download_content(value)
      ::save_local_account_settings("delayDownloadContent", value)
      break

    case ::USEROPT_REPLAY_SNAPSHOT_ENABLED:
      ::set_gui_option(optionId, value)
      break

    case ::USEROPT_RECORD_SNAPSHOT_PERIOD:
      ::set_gui_option(optionId, descr.values[value])
      break

    case ::USEROPT_AI_GUNNER_TIME:
      ::set_option_ai_gunner_time(value)
      break

    case ::USEROPT_MEASUREUNITS_SPEED:
    case ::USEROPT_MEASUREUNITS_ALT:
    case ::USEROPT_MEASUREUNITS_DIST:
    case ::USEROPT_MEASUREUNITS_CLIMBSPEED:
    case ::USEROPT_MEASUREUNITS_TEMPERATURE:
    case ::USEROPT_MEASUREUNITS_WING_LOADING:
    case ::USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO:
      if (typeof descr.values == "array" && value >= 0 && value < descr.values.len())
      {
        local unitType = 0
        if (optionId == ::USEROPT_MEASUREUNITS_ALT)
          unitType = 1
        else if (optionId == ::USEROPT_MEASUREUNITS_DIST)
          unitType = 2
        else if (optionId == ::USEROPT_MEASUREUNITS_CLIMBSPEED)
          unitType = 3
        else if (optionId == ::USEROPT_MEASUREUNITS_TEMPERATURE)
          unitType = 4
        else if (optionId == ::USEROPT_MEASUREUNITS_WING_LOADING)
          unitType = 5
        else if (optionId == ::USEROPT_MEASUREUNITS_POWER_TO_WEIGHT_RATIO)
          unitType = 6

        ::set_option_unit_type(unitType, descr.values[value])

        if (isWaitMeasureEvent)
          break

        isWaitMeasureEvent = true
        ::handlersManager.doDelayed(function() {
          isWaitMeasureEvent = false
          ::broadcastEvent("MeasureUnitsChanged")
        })
      }
      break
    case ::USEROPT_VIBRATION:
      ::set_option_vibration(value ? 1 : 0)
      break

    case ::USEROPT_GRASS_IN_TANK_VISION:
      ::set_option_grass_in_tank_vision(value ? 1 : 0)
      break

    case ::USEROPT_GAME_HUD:
      ::set_option_hud(descr.values[value])
      break

    case ::USEROPT_CAMERA_SHAKE_MULTIPLIER:
      ::set_option_multiplier(::OPTION_CAMERA_SHAKE, value / 50.0)
      break

    case ::USEROPT_VR_CAMERA_SHAKE_MULTIPLIER:
      ::set_option_multiplier(::OPTION_VR_CAMERA_SHAKE, value / 50.0)
      break

    case ::USEROPT_GAMMA:
      ::set_option_gamma(value / 100.0, true)
      break

    // volumes:

    case ::USEROPT_AILERONS_MULTIPLIER:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_AILERONS_MULTIPLIER, val)
      break

    case ::USEROPT_ELEVATOR_MULTIPLIER:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_ELEVATOR_MULTIPLIER, val)
      break

    case ::USEROPT_RUDDER_MULTIPLIER:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_RUDDER_MULTIPLIER, val)
      break

    case ::USEROPT_ZOOM_SENSE:
      let val = (100.0 - value) / 100.0
      ::set_option_multiplier(::OPTION_ZOOM_SENSE, val)
      break

    case ::USEROPT_MOUSE_SENSE:
      let val = value / 50.0
      ::set_option_multiplier(::OPTION_MOUSE_SENSE, val)
      break

    case ::USEROPT_JOY_MIN_VIBRATION:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_JOY_MIN_VIBRATION, val)
      break

    case ::USEROPT_MOUSE_AIM_SENSE:
      let val = value / 50.0
      ::set_option_multiplier(::OPTION_MOUSE_AIM_SENSE, val)
      break

    case ::USEROPT_GUNNER_VIEW_SENSE:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_GUNNER_VIEW_SENSE, val)
      break

    case ::USEROPT_GUNNER_VIEW_ZOOM_SENS:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_GUNNER_VIEW_ZOOM_SENS, val)
      break

    case ::USEROPT_ATGM_AIM_SENS_HELICOPTER:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_ATGM_AIM_SENS_HELICOPTER, val)
      break

    case ::USEROPT_ATGM_AIM_ZOOM_SENS_HELICOPTER:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_ATGM_AIM_ZOOM_SENS_HELICOPTER, val)
      break

    case ::USEROPT_MOUSE_SMOOTH:
      ::set_option_mouse_smooth(value ? 1 : 0)
      break

    case ::USEROPT_VOLUME_MASTER:
      set_sound_volume(SND_TYPE_MASTER, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_MUSIC:
      set_sound_volume(SND_TYPE_MUSIC, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_MENU_MUSIC:
      set_sound_volume(SND_TYPE_MENU_MUSIC, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_SFX:
      set_sound_volume(SND_TYPE_SFX, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_RADIO:
      set_sound_volume(SND_TYPE_RADIO, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_ENGINE:
      set_sound_volume(SND_TYPE_ENGINE, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_MY_ENGINE:
      set_sound_volume(SND_TYPE_MY_ENGINE, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_DIALOGS:
      set_sound_volume(SND_TYPE_DIALOGS, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_GUNS:
      set_sound_volume(SND_TYPE_GUNS, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_TINNITUS:
      set_sound_volume(SND_TYPE_TINNITUS, value / 100.0, true)
      break
    case ::USEROPT_HANGAR_SOUND:
      set_option_hangar_sound(value)
    break
    case ::USEROPT_VOLUME_VOICE_IN:
      set_sound_volume(SND_TYPE_VOICE_IN, value / 100.0, true)
      break
    case ::USEROPT_VOLUME_VOICE_OUT:
      set_sound_volume(SND_TYPE_VOICE_OUT, value / 100.0, true)
      break

    case ::USEROPT_CONTROLS_PRESET:
      if (descr.values[value] != "")
        ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename(descr.values[value]))
      break

    case ::USEROPT_COUNTRY:
      ::switch_profile_country(descr.values[value])
      break
    case ::USEROPT_PILOT:
      ::set_profile_pilot(descr.values[value])
      break

    case ::USEROPT_CROSSHAIR_TYPE:
      ::set_hud_crosshair_type(descr.values[value])
      break

    case ::USEROPT_CROSSHAIR_COLOR:
      ::set_hud_crosshair_color(descr.values[value])
      break

    case ::USEROPT_CROSSHAIR_DEFLECTION:
      ::set_option_deflection(value)
      break
    case ::USEROPT_CROSSHAIR_SPEED:
      ::set_option_crosshair_speed(descr.values[value])
      break

    case ::USEROPT_SHOW_INDICATORS:
      if (value)
        ::set_option_indicators_mode(::get_option_indicators_mode() | ::HUD_INDICATORS_SHOW);
      else
        ::set_option_indicators_mode(::get_option_indicators_mode() & ~::HUD_INDICATORS_SHOW);
      break
    case ::USEROPT_HUD_SHOW_BONUSES:
      ::set_option_hud_show_bonuses(descr.values[value])
      break
    case ::USEROPT_HUD_SCREENSHOT_LOGO:
      ::set_option_hud_screenshot_logo(value)
      break
    case ::USEROPT_HUD_SHOW_FUEL:
      ::set_option_hud_show_fuel(descr.values[value])
      break
    case ::USEROPT_HUD_SHOW_AMMO:
      ::set_option_hud_show_ammo(descr.values[value])
      break
    case ::USEROPT_HUD_SHOW_TEMPERATURE:
      ::set_option_hud_show_temperature(descr.values[value])
      break
    case ::USEROPT_MENU_SCREEN_SAFE_AREA:
      if (value >= 0 && value < descr.values.len())
      {
        safeAreaMenu.setValue(descr.values[value])
        ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      }
      break
    case ::USEROPT_HUD_SCREEN_SAFE_AREA:
      if (value >= 0 && value < descr.values.len())
      {
        safeAreaHud.setValue(descr.values[value])
        ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      }
      break;
    case ::USEROPT_AUTOPILOT_ON_BOMBVIEW:
      ::set_option_autopilot_on_bombview(descr.values[value])
      break;
    case ::USEROPT_AUTOREARM_ON_AIRFIELD:
      ::set_option_autorearm_on_airfield(value)
      break;
    case ::USEROPT_ENABLE_LASER_DESIGNATOR_ON_LAUNCH:
      ::set_enable_laser_designatior_before_launch(value)
      break;
    case ::USEROPT_ACTIVATE_AIRBORNE_RADAR_ON_SPAWN:
      ::set_option_activate_airborne_radar_on_spawn(value)
      break;
    case ::USEROPT_USE_RECTANGULAR_RADAR_INDICATOR:
      ::set_option_use_rectangular_radar_indicator(value)
      break;
    case ::USEROPT_RADAR_TARGET_CYCLING:
      ::set_option_radar_target_cycling(value)
      break;
    case ::USEROPT_RADAR_AIM_ELEVATION_CONTROL:
      set_option_radar_aim_elevation_control(value)
      break;
    case ::USEROPT_USE_RADAR_HUD_IN_COCKPIT:
      ::set_option_use_radar_hud_in_cockpit(value)
      break;
    case ::USEROPT_ACTIVATE_AIRBORNE_ACTIVE_COUNTER_MEASURES_ON_SPAWN:
      ::set_option_activate_airborne_active_counter_measures_on_spawn(value)
      break;
    case ::USEROPT_SAVE_AI_TARGET_TYPE:
      ::set_option_ai_target_type(value ? 1 : 0)
      break;
    case ::USEROPT_DEFAULT_AI_TARGET_TYPE:
      ::set_option_default_ai_target_type(value)
      break;
    case ::USEROPT_ACTIVATE_AIRBORNE_WEAPON_SELECTION_ON_SPAWN:
      ::set_gui_option(optionId, value)
      break;
    case ::USEROPT_SHOW_INDICATORS_TYPE:
      local val = ::get_option_indicators_mode() & ~(::HUD_INDICATORS_SELECT|::HUD_INDICATORS_CENTER|::HUD_INDICATORS_ALL);
      if (descr.values[value] == 0)
        val = val | ::HUD_INDICATORS_SELECT;
      if (descr.values[value] == 1)
        val = val | ::HUD_INDICATORS_CENTER;
      if (descr.values[value] == 2)
        val = val | ::HUD_INDICATORS_ALL;
      ::set_option_indicators_mode(val);
      break
    case ::USEROPT_SHOW_INDICATORS_NICK:
      if (value)
        ::set_option_indicators_mode(::get_option_indicators_mode() | ::HUD_INDICATORS_TEXT_NICK);
      else
        ::set_option_indicators_mode(::get_option_indicators_mode() & ~::HUD_INDICATORS_TEXT_NICK);
      break
    case ::USEROPT_SHOW_INDICATORS_TITLE:
      if (value)
        ::set_option_indicators_mode(::get_option_indicators_mode() | ::HUD_INDICATORS_TEXT_TITLE);
      else
        ::set_option_indicators_mode(::get_option_indicators_mode() & ~::HUD_INDICATORS_TEXT_TITLE);
      break
    case ::USEROPT_SHOW_INDICATORS_AIRCRAFT:
      if (value)
        ::set_option_indicators_mode(::get_option_indicators_mode() | ::HUD_INDICATORS_TEXT_AIRCRAFT);
      else
        ::set_option_indicators_mode(::get_option_indicators_mode() & ~::HUD_INDICATORS_TEXT_AIRCRAFT);
      break
    case ::USEROPT_SHOW_INDICATORS_DIST:
      if (value)
        ::set_option_indicators_mode(::get_option_indicators_mode() | ::HUD_INDICATORS_TEXT_DIST);
      else
        ::set_option_indicators_mode(::get_option_indicators_mode() & ~::HUD_INDICATORS_TEXT_DIST);
      break
    case ::USEROPT_SAVE_ZOOM_CAMERA:
      ::set_option_save_zoom_camera(value)
      break;

    case ::USEROPT_SKIN:
      if (typeof descr.values == "array")
      {
        let air = ::aircraft_for_weapons
        if (value >= 0 && value < descr.values.len())
        {
          ::set_gui_option(optionId, descr.values[value] || ::g_decorator.getAutoSkin(air))
          ::g_decorator.setLastSkin(air, descr.values[value])
        }
        else
          print("[ERROR] value '" + value + "' is out of range")
      }
      else
        print("[ERROR] No values set for type '" + optionId + "'")
      break

    case ::USEROPT_USER_SKIN:
      let cdb = ::get_user_skins_profile_blk()
      if (::cur_aircraft_name)
      {
        if (cdb?[::cur_aircraft_name] != ::getTblValue(value, descr.values, ""))
        {
          cdb[::cur_aircraft_name] = ::getTblValue(value, descr.values, "")
          saveProfile()
        }
      }
      else
      {
        ::dagor.debug("[ERROR] ::cur_aircraft_name is null")
        ::callstack()
      }
      break

    case ::USEROPT_FONTS_CSS:
      let selFont = ::getTblValue(value, descr.values)
      if (selFont && ::g_font.setCurrent(selFont)) {
        ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
        reloadDargUiScript(false)
      }
      break

    case ::USEROPT_HUE_SQUAD:
      ::set_hue(colorCorrector.TARGET_HUE_SQUAD, descr.values[value]);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break

    case ::USEROPT_HUE_ALLY:
      ::set_hue(colorCorrector.TARGET_HUE_ALLY, descr.values[value]);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break

    case ::USEROPT_HUE_ENEMY:
      ::set_hue(colorCorrector.TARGET_HUE_ENEMY, descr.values[value]);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break

    case ::USEROPT_HUE_SPECTATOR_ALLY:
      ::set_hue(colorCorrector.TARGET_HUE_SPECTATOR_ALLY, descr.values[value]);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break

    case ::USEROPT_HUE_SPECTATOR_ENEMY:
      ::set_hue(colorCorrector.TARGET_HUE_SPECTATOR_ENEMY, descr.values[value]);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break

    case ::USEROPT_HUE_RELOAD:
      ::set_hue(colorCorrector.TARGET_HUE_RELOAD, descr.values[value]);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break

    case ::USEROPT_HUE_RELOAD_DONE:
      ::set_hue(colorCorrector.TARGET_HUE_RELOAD_DONE, descr.values[value]);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break

    case ::USEROPT_STROBE_ALLY:
      ::set_strobe_ally(descr.values[value]);
      break

    case ::USEROPT_STROBE_ENEMY:
      ::set_strobe_enemy(descr.values[value]);
      break

    case ::USEROPT_AIR_DAMAGE_DISPLAY:
      ::set_gui_option(optionId, value)
      break

    case ::USEROPT_GUNNER_FPS_CAMERA:
      ::set_gui_option(optionId, value)
      break

    case ::USEROPT_HUE_AIRCRAFT_HUD:
      local { sat = 1.0, val = 1.0 } = descr.items[value]
      colorCorrector.setHsb(colorCorrector.TARGET_HUE_AIRCRAFT_HUD, descr.values[value], sat, val);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break;

    case ::USEROPT_HUE_AIRCRAFT_PARAM_HUD:
      local { sat = 1.0, val = 1.0 } = descr.items[value]
      colorCorrector.setHsb(colorCorrector.TARGET_HUE_AIRCRAFT_PARAM_HUD, descr.values[value], sat, val);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break;

    case ::USEROPT_HUE_AIRCRAFT_HUD_ALERT:
      colorCorrector.setAlertAircraftHues(descr.values[value][0], descr.values[value][1], descr.values[value][2], value);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break;

    case ::USEROPT_HUE_HELICOPTER_CROSSHAIR:
      let { sat = 0.7, val = 0.7 } = descr.items[value]
      colorCorrector.setHsb(colorCorrector.TARGET_HUE_HELICOPTER_CROSSHAIR, descr.values[value], sat, val);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break;

    case ::USEROPT_HUE_HELICOPTER_HUD:
      local { sat = 1.0, val = 1.0 } = descr.items[value]
      colorCorrector.setHsb(colorCorrector.TARGET_HUE_HELICOPTER_HUD, descr.values[value], sat, val);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break;

    case ::USEROPT_HUE_HELICOPTER_PARAM_HUD:
      local { sat = 1.0, val = 1.0 } = descr.items[value]
      colorCorrector.setHsb(colorCorrector.TARGET_HUE_HELICOPTER_PARAM_HUD, descr.values[value], sat, val);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break;

    case ::USEROPT_HORIZONTAL_SPEED:
      ::set_option_horizontal_speed(value ? 1 : 0)
      break

    case ::USEROPT_HELICOPTER_HELMET_AIM:
      ::set_option_use_oculus_to_aim_helicopter(value ? 1 : 0)
      break

    case ::USEROPT_HELICOPTER_AUTOPILOT_ON_GUNNERVIEW:
      ::set_option_auto_pilot_on_gunner_view_helicopter(value)
    break

    case ::USEROPT_HUE_HELICOPTER_HUD_ALERT:
      if (::has_feature("reactivGuiForAircraft"))
        colorCorrector.setAlertHelicopterHues(descr.values[value][0], descr.values[value][1], descr.values[value][2], value);
      else
        ::set_hue(colorCorrector.TARGET_HUE_HELICOPTER_HUD_ALERT_HIGH, descr.values[value]);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break;

    case ::USEROPT_HUE_HELICOPTER_MFD:
      ::set_hue(colorCorrector.TARGET_HUE_HELICOPTER_MFD, descr.values[value]);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break;

    case ::USEROPT_HUE_ARBITER_HUD:
      let { sat = 0.0, val = 1.0 } = descr.items[value]
      colorCorrector.setHsb(colorCorrector.TARGET_HUE_ARBITER_HUD, descr.values[value], sat, val);
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      break;

    case ::USEROPT_HUE_TANK_THERMOVISION:
      optionsUtils.setHSVOption_ThermovisionColor(descr, descr.values[value])
      ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
      ::set_gui_option(optionId, value)
      break;

    case ::USEROPT_ENABLE_CONSOLE_MODE:
      ::switch_show_console_buttons(value)
      break

    case ::USEROPT_CD_ENGINE:
    case ::USEROPT_CD_GUNNERY:
    case ::USEROPT_CD_DAMAGE:
    case ::USEROPT_CD_STALLS:
    case ::USEROPT_CD_REDOUT:
    case ::USEROPT_CD_MORTALPILOT:
    case ::USEROPT_CD_FLUTTER:
    case ::USEROPT_CD_BOMBS:
    case ::USEROPT_CD_BOOST:
    case ::USEROPT_CD_TPS:
    case ::USEROPT_CD_AIM_PRED:
    case ::USEROPT_CD_MARKERS:
    case ::USEROPT_CD_ARROWS:
    case ::USEROPT_CD_AIRCRAFT_MARKERS_MAX_DIST:
    case ::USEROPT_CD_INDICATORS:
    case ::USEROPT_CD_SPEED_VECTOR:
    case ::USEROPT_CD_TANK_DISTANCE:
    case ::USEROPT_CD_MAP_AIRCRAFT_MARKERS:
    case ::USEROPT_CD_MAP_GROUND_MARKERS:
    case ::USEROPT_CD_MARKERS_BLINK:
    case ::USEROPT_CD_RADAR:
    case ::USEROPT_CD_DAMAGE_IND:
    case ::USEROPT_CD_LARGE_AWARD_MESSAGES:
    case ::USEROPT_CD_WARNINGS:
    case ::USEROPT_CD_AIR_HELPERS:
    case ::USEROPT_CD_ALLOW_CONTROL_HELPERS:
    case ::USEROPT_CD_FORCE_INSTRUCTOR:
    case ::USEROPT_CD_DISTANCE_DETECTION:
    case ::USEROPT_CD_COLLECTIVE_DETECTION:
    case ::USEROPT_RANK:
    case ::USEROPT_REPLAY_LOAD_COCKPIT:
      local optionValue = null
      if (descr.controlType == optionControlType.CHECKBOX)
      {
        optionValue = value
        ::set_gui_option(optionId, value)
        setCdOption(optionId, value ? 1 : 0)
      }
      else if (descr.controlType == optionControlType.LIST)
      {
        if (value in descr.values)
        {
          optionValue = descr.values[value]
          ::set_gui_option(optionId, optionValue)
          setCdOption(optionId, optionValue)
        }
        else
          ::dagor.assertf(false, "[ERROR] Value '" + value + "' is out of range in type " + optionId)
      }
      else
        ::dagor.assertf(false, "[ERROR] No values set for type '" + optionId + "'")
      if (optionValue != null && descr.onChangeCb)
        descr.onChangeCb(optionId, optionValue, value)
      break

    case ::USEROPT_HELPERS_MODE:
    case ::USEROPT_MOUSE_USAGE:
    case ::USEROPT_MOUSE_USAGE_NO_AIM:
    case ::USEROPT_INSTRUCTOR_ENABLED:
    case ::USEROPT_AUTOTRIM:
      ::g_aircraft_helpers.setOptionValue(optionId,
          descr.values != null ? ::getTblValue(value, descr.values, 0) : value)
      break

    case ::USEROPT_INSTRUCTOR_GROUND_AVOIDANCE:
    case ::USEROPT_INSTRUCTOR_GEAR_CONTROL:
    case ::USEROPT_INSTRUCTOR_FLAPS_CONTROL:
    case ::USEROPT_INSTRUCTOR_ENGINE_CONTROL:
    case ::USEROPT_INSTRUCTOR_SIMPLE_JOY:
    case ::USEROPT_MAP_ZOOM_BY_LEVEL:
    case ::USEROPT_SHOW_COMPASS_IN_TANK_HUD:
    case ::USEROPT_PITCH_BLOCKER_WHILE_BRACKING:
    case ::USEROPT_SAVE_DIR_WHILE_SWITCH_TRIGGER:
    case ::USEROPT_HIDE_MOUSE_SPECTATOR:
    case ::USEROPT_FIX_GUN_IN_MOUSE_LOOK:
    case ::USEROPT_ENABLE_SOUND_SPEED:
      let optionIdx = ::getTblValue("boolOptionIdx", descr, -1)
      if (optionIdx >= 0 && ::u.isBool(value))
        ::set_option_bool(optionIdx, value)
      break

    case ::USEROPT_COMMANDER_CAMERA_IN_VIEWS:
      ::set_commander_camera_in_views(value)
      break

    case ::USEROPT_TAKEOFF_MODE:
      if (descr.values.len() > 1 && (value in descr.values))
        ::set_gui_option(optionId, descr.values[value])
      break

    case ::USEROPT_MISSION_COUNTRIES_TYPE:
      if (value in descr.values)
      {
        ::set_gui_option(optionId, descr.values[value])
        ::mission_settings.countriesType <- descr.values[value]
      }
      break

    case ::USEROPT_BIT_COUNTRIES_TEAM_A:
    case ::USEROPT_BIT_COUNTRIES_TEAM_B:
      if (value == 0)
        value = descr.allowedMask
      if (value <= 0)
        break

      ::set_gui_option(optionId, value)
      ::mission_settings[descr.sideTag + "_bitmask"] <- value
      if (descr.onChangeCb)
        descr.onChangeCb(optionId, value, value)
      break

    case ::USEROPT_COUNTRIES_SET:
      if (value not in descr.values)
        break
      ::set_gui_option(optionId, value)
      descr?.onChangeCb(optionId, value, value)
      break

    case ::USEROPT_BIT_UNIT_TYPES:
      if (value <= 0)
        break

      ::set_gui_option(optionId, value)
      ::mission_settings.userAllowedUnitTypesMask <- descr.availableUnitTypesMask & value
      break

    case ::USEROPT_BR_MIN:
    case ::USEROPT_BR_MAX:
      if (value in descr.values)
      {
        let optionValue = descr.values[value]
        ::set_gui_option(optionId, optionValue)
        ::mission_settings[optionId == ::USEROPT_BR_MIN ? "mrankMin" : "mrankMax"] <- optionValue
      }
      break

    case ::USEROPT_BIT_CHOOSE_UNITS_TYPE:
    case ::USEROPT_BIT_CHOOSE_UNITS_RANK:
    case ::USEROPT_BIT_CHOOSE_UNITS_OTHER:
    case ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE:
    case ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST:
      ::set_gui_option(optionId, value)
      break

    case ::USEROPT_MP_TEAM_COUNTRY_RAND:
    case ::USEROPT_MP_TEAM_COUNTRY:
      if (value >= 0 && value < descr.values.len())
        ::set_gui_option(::USEROPT_MP_TEAM, descr.values[value])
      break

    case ::USEROPT_SESSION_PASSWORD:
      ::SessionLobby.changePassword(value? value : "")
      break

    case ::USEROPT_BULLETS0:
    case ::USEROPT_BULLETS1:
    case ::USEROPT_BULLETS2:
    case ::USEROPT_BULLETS3:
    case ::USEROPT_BULLETS4:
    case ::USEROPT_BULLETS5:
      ::set_gui_option(optionId, value)
      let air = ::getAircraftByName(::aircraft_for_weapons)
      if (air)
        setUnitLastBullets(air, optionId - ::USEROPT_BULLETS0, value)
      else {
        ::dagor.logerr($"Options: USEROPT_BULLET{groupIndex}: set: Wrong 'aircraft_for_weapons' type")
        ::debugTableData(::aircraft_for_weapons)
      }
      break

    case ::USEROPT_HELPERS_MODE_GM:
     ::set_gui_option(::USEROPT_HELPERS_MODE, descr.values[value])
     break

    case ::USEROPT_LANDING_MODE:
    case ::USEROPT_ALLOW_JIP:
    case ::USEROPT_QUEUE_JIP:
    case ::USEROPT_AUTO_SQUAD:
    case ::USEROPT_ORDER_AUTO_ACTIVATE:
    case ::USEROPT_FRIENDS_ONLY:
    case ::USEROPT_VERSUS_NO_RESPAWN:
    case ::USEROPT_OFFLINE_MISSION:
    case ::USEROPT_VERSUS_RESPAWN:
    case ::USEROPT_MP_TEAM:
    case ::USEROPT_DMP_MAP:
    case ::USEROPT_DYN_MAP:
    case ::USEROPT_DYN_ZONE:
    case ::USEROPT_DYN_ALLIES:
    case ::USEROPT_DYN_ENEMIES:
    case ::USEROPT_DYN_SURROUND:
    case ::USEROPT_DYN_FL_ADVANTAGE:
    case ::USEROPT_DYN_WINS_TO_COMPLETE:
    case ::USEROPT_TIME:
    case ::USEROPT_CLIME:
    case ::USEROPT_YEAR:
    case ::USEROPT_DIFFICULTY:
    case ::USEROPT_ALTITUDE:
    case ::USEROPT_TIME_LIMIT:
    case ::USEROPT_KILL_LIMIT:
    case ::USEROPT_TIME_SPAWN:
    case ::USEROPT_TICKETS:
    case ::USEROPT_LIMITED_FUEL:
    case ::USEROPT_LIMITED_AMMO:
    case ::USEROPT_FRIENDLY_SKILL:
    case ::USEROPT_ENEMY_SKILL:
    case ::USEROPT_MODIFICATIONS:
    case ::USEROPT_AAA_TYPE:
    case ::USEROPT_SITUATION:
    case ::USEROPT_SEARCH_DIFFICULTY:
    case ::USEROPT_SEARCH_GAMEMODE:
    case ::USEROPT_SEARCH_GAMEMODE_CUSTOM:
    case ::USEROPT_NUM_PLAYERS:
    case ::USEROPT_NUM_FRIENDLIES:
    case ::USEROPT_NUM_ENEMIES:
    case ::USEROPT_NUM_ATTEMPTS:
    case ::USEROPT_OPTIONAL_TAKEOFF:
    case ::USEROPT_TIME_BETWEEN_RESPAWNS:
    case ::USEROPT_LB_TYPE:
    case ::USEROPT_LB_MODE:
    case ::USEROPT_IS_BOTS_ALLOWED:
    case ::USEROPT_USE_TANK_BOTS:
    case ::USEROPT_USE_SHIP_BOTS:
    case ::USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS:
    case ::USEROPT_DISABLE_AIRFIELDS:
    case ::USEROPT_ALLOW_EMPTY_TEAMS:
    case ::USEROPT_KEEP_DEAD:
    case ::USEROPT_DEDICATED_REPLAY:
    case ::USEROPT_AUTOBALANCE:
    case ::USEROPT_MAX_PLAYERS:
    case ::USEROPT_MIN_PLAYERS:
    case ::USEROPT_ROUNDS:
    case ::USEROPT_COMPLAINT_CATEGORY:
    case ::USEROPT_BAN_PENALTY:
    case ::USEROPT_BAN_TIME:
    case ::USEROPT_ONLY_FRIENDLIST_CONTACT:
    case ::USEROPT_MARK_DIRECT_MESSAGES_AS_PERSONAL:
    case ::USEROPT_RACE_LAPS:
    case ::USEROPT_RACE_WINNERS:
    case ::USEROPT_RACE_CAN_SHOOT:
    case ::USEROPT_USE_KILLSTREAKS:
    case ::USEROPT_AUTOMATIC_TRANSMISSION_TANK:
    case ::USEROPT_WHEEL_CONTROL_SHIP:
    case ::USEROPT_JOYFX:
    case ::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP:
    case ::USEROPT_BULLET_FALL_INDICATOR_SHIP:
    case ::USEROPT_BULLET_FALL_SOUND_SHIP:
    case ::USEROPT_SINGLE_SHOT_BY_TURRET:
    case ::USEROPT_AUTO_TARGET_CHANGE_SHIP:
    case ::USEROPT_REALISTIC_AIMING_SHIP:
    case ::USEROPT_DEFAULT_TORPEDO_FORESTALL_ACTIVE:
    case ::USEROPT_REPLAY_ALL_INDICATORS:
    case ::USEROPT_CONTENT_ALLOWED_PRESET_ARCADE:
    case ::USEROPT_CONTENT_ALLOWED_PRESET_REALISTIC:
    case ::USEROPT_CONTENT_ALLOWED_PRESET_SIMULATOR:
    case ::USEROPT_CONTENT_ALLOWED_PRESET:
    case ::USEROPT_GAMEPAD_VIBRATION_ENGINE:
    case ::USEROPT_GAMEPAD_ENGINE_DEADZONE:
    case ::USEROPT_GAMEPAD_GYRO_TILT_CORRECTION:
    case ::USEROPT_FOLLOW_BULLET_CAMERA:
    case ::USEROPT_BULLET_FALL_SPOT_SHIP:
    case ::USEROPT_AUTO_AIMLOCK_ON_SHOOT:
    case ::USEROPT_ALTERNATIVE_TPS_CAMERA:
    case ::USEROPT_HOLIDAYS:
    //



      if (descr.controlType == optionControlType.LIST)
      {
        if (typeof descr.values != "array")
          break
        if (value < 0 || value >= descr.values.len())
          break

        ::set_gui_option(optionId, descr.values[value])
      }
      else if (descr.controlType == optionControlType.CHECKBOX)
      {
        if (::u.isBool(value))
          ::set_gui_option(optionId, value)
      }
      break

    //





    case ::USEROPT_AUTOLOGIN:
      ::set_autologin_enabled(value)
      break

    case ::USEROPT_DAMAGE_INDICATOR_SIZE:
    case ::USEROPT_TACTICAL_MAP_SIZE:
      if (value >= (descr?.min ?? 0) && value <= (descr?.max ?? 1)
          && (!("step" in descr) || value % descr.step == 0))
      {
        ::set_gui_option_in_mode(optionId, value, ::OPTIONS_MODE_GAMEPLAY)
        ::broadcastEvent("HudIndicatorChangedSize", { option = optionId })
      }
      break

    case ::USEROPT_AIR_RADAR_SIZE:
      ::set_gui_option_in_mode(optionId, value, ::OPTIONS_MODE_GAMEPLAY)
      break

    case ::USEROPT_CLUSTER:
      if (value >= 0 && value < descr.values.len())
        ::set_gui_option_in_mode(optionId, descr.values[value], ::OPTIONS_MODE_MP_DOMINATION)
      break
    case ::USEROPT_RANDB_CLUSTER:
      if (value >= 0 && value <= (1 << descr.values.len()) - 1)
      {
        local newVal = ""
        for (local i = 0; i < descr.values.len(); i++)
        {
          if (value & 1 << i)
            newVal += (newVal.len() > 0 ? ";" : "") + descr.values[i]
        }
        ::set_gui_option_in_mode(optionId, newVal, ::OPTIONS_MODE_MP_DOMINATION)
        ::broadcastEvent("ClusterChange")
      }
      break

    case ::USEROPT_PLAY_INACTIVE_WINDOW_SOUND:
      ::set_gui_option(optionId, value)
      break;

    case ::USEROPT_INTERNET_RADIO_ACTIVE:
      let internet_radio_options = ::get_internet_radio_options()
      internet_radio_options["active"] = value
      ::set_internet_radio_options(internet_radio_options)
      break
    case ::USEROPT_INTERNET_RADIO_STATION:
      let station = descr.values[value]
      if (station != "")
      {
        let internet_radio_options = ::get_internet_radio_options();
        internet_radio_options["station"] = station
        ::set_internet_radio_options(internet_radio_options);
      }
      break

    case ::USEROPT_COOP_MODE:
      //dont save this one!
      ::set_gui_option(::USEROPT_COOP_MODE, 0)
      break

    case ::USEROPT_VOICE_DEVICE_IN:
      soundDevice.set_last_voice_device_in(descr.values?[value] ?? "")
      break

    case ::USEROPT_SOUND_DEVICE_OUT:
      soundDevice.set_last_sound_device_out(descr.values?[value] ?? "");
      break

    case ::USEROPT_HEADTRACK_ENABLE:
      ::ps4_headtrack_set_enable(value)
      break

    case ::USEROPT_HEADTRACK_SCALE_X:
      ::ps4_headtrack_set_xscale(value)
      break
    case ::USEROPT_HEADTRACK_SCALE_Y:
      ::ps4_headtrack_set_yscale(value)
      break
    case ::USEROPT_MISSION_NAME_POSTFIX:
      if (::current_campaign_mission != null)
      {
        let metaInfo = ::get_mission_meta_info(::current_campaign_mission)
        let values = ::get_mission_types_from_meta_mission_info(metaInfo)
        if (values.len() > 0)
        {
          let optValue = descr.values[value]
          if (optValue.len())
            ::mission_settings.postfix = optValue
          else
            ::mission_settings.postfix = values[::math.rnd() % values.len()]
          ::set_gui_option(optionId, optValue)
        }
      }
      break

    case ::USEROPT_SHOW_DESTROYED_PARTS:
      ::set_show_destroyed_parts(value)
      break

    case ::USEROPT_ACTIVATE_GROUND_RADAR_ON_SPAWN:
      ::set_activate_ground_radar_on_spawn(value)
      break

    case ::USEROPT_GROUND_RADAR_TARGET_CYCLING:
      ::set_option_ground_radar_target_cycling(value)
      break

    case ::USEROPT_ACTIVATE_GROUND_ACTIVE_COUNTER_MEASURES_ON_SPAWN:
      ::set_activate_ground_active_counter_measures_on_spawn(value)
      break

    case ::USEROPT_FPS_CAMERA_PHYSICS:
      ::set_option_multiplier(::OPTION_FPS_CAMERA_PHYS, value / 100.0)
      break

    case ::USEROPT_FPS_VR_CAMERA_PHYSICS:
      ::set_option_multiplier(::OPTION_FPS_VR_CAMERA_PHYS, value / 100.0)
      break

    case ::USEROPT_FREE_CAMERA_INERTIA:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_FREE_CAMERA_INERTIA, val)
      break

    case ::USEROPT_REPLAY_CAMERA_WIGGLE:
      let val = value / 100.0
      ::set_option_multiplier(::OPTION_REPLAY_CAMERA_WIGGLE, val)
      break

    case ::USEROPT_TANK_GUNNER_CAMERA_FROM_SIGHT:
      ::set_option_tank_gunner_camera_from_sight(value)
      break
    case ::USEROPT_TANK_ALT_CROSSHAIR:
      let unit = getPlayerCurUnit()
      let val = descr.values[value]
      if (unit && val != TANK_ALT_CROSSHAIR_ADD_NEW)
        ::set_option_tank_alt_crosshair(unit.name, val)
      break
    case ::USEROPT_SHIP_COMBINE_PRI_SEC_TRIGGERS:
      ::set_option_combine_pri_sec_triggers(value)
      ::set_gui_option(optionId, value)
      break
    case ::USEROPT_GAMEPAD_CURSOR_CONTROLLER:
      ::g_gamepad_cursor_controls.setValue(value)
      break
    case ::USEROPT_PS4_CROSSPLAY:
      crossplayModule.setCrossPlayStatus(value)
      break
    //




    case ::USEROPT_PS4_CROSSNETWORK_CHAT:
      crossplayModule.setCrossNetworkChatStatus(value)
      break
    case ::USEROPT_DISPLAY_MY_REAL_NICK:
      ::set_gui_option_in_mode(optionId, value, ::OPTIONS_MODE_GAMEPLAY)
      ::update_gamercards()
      break
    case ::USEROPT_SHOW_SOCIAL_NOTIFICATIONS:
      ::set_gui_option(optionId, value)
      break

    case ::USEROPT_ALLOW_ADDED_TO_CONTACTS:
      ::set_allow_to_be_added_to_contacts(value)
      ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
      break
    case ::USEROPT_ALLOW_ADDED_TO_LEADERBOARDS:
      ::set_allow_to_be_added_to_lb(value)
      ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
      break

    case ::USEROPT_QUEUE_EVENT_CUSTOM_MODE:
      ::queue_classes.Event.setShouldQueueCustomMode(::getTblValue("eventName", descr.context, ""), value)
      break

    case ::USEROPT_PS4_ONLY_LEADERBOARD:
      ::broadcastEvent("PS4OnlyLeaderboardsValueChanged")
      ::set_gui_option(optionId, value)
      break

    default:
      let optionName = ::user_option_name_by_idx?[optionId] ?? ""
      ::dagor.assertf(false, $"[ERROR] Options: Set: Unsupported type {optionId} ({optionName}) - {value}")
  }
  return true
}

::get_current_wnd_difficulty <- function get_current_wnd_difficulty()
{
  let diffCode = ::loadLocalByAccount("wnd/diffMode", ::get_current_shop_difficulty().diffCode)
  local diff = ::g_difficulty.getDifficultyByDiffCode(diffCode)
  if (!diff.isAvailable())
    diff = ::g_difficulty.ARCADE
  return diff.diffCode
}

::set_current_wnd_difficulty <- function set_current_wnd_difficulty(mode = 0)
{
  ::saveLocalByAccount("wnd/diffMode", mode)
}

::create_options_container <- function create_options_container(name, options, is_centered, columnsRatio = 0.5, absolutePos=true, context = null)
{
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
  for(local i = options.len() - 1; i >= 0; i--)
  {
    let opt = options[i]
    if (!(opt?[2] ?? true))
      continue

    let optionData = get_option(opt[0], context)
    if (optionData == null)
      continue

    let isHeader = optionData.controlType == optionControlType.HEADER
    if(isHeader)
    {
      if(!headerHaveContent)
        continue
      else
        headerHaveContent = false
    } else
      headerHaveContent = true

    if(optionData?.controlName == null)
      optionData.controlName <- opt?[1] ?? "spinner"

    local isVlist = false
    local haveOptText = true
    local elemTxt = ""
    switch (optionData.controlName)
    {
      case "list":
      case "spinner":
        elemTxt = ::create_option_list(optionData.id, optionData.items, optionData.value, optionData.cb, true)
        break

      case "dropright":
        elemTxt = ::create_option_dropright(optionData.id, optionData.items, optionData.value, optionData.cb, true)
        break

      case "combobox":
        elemTxt = ::create_option_combobox(optionData.id, optionData.items, optionData.value, optionData.cb, true)
        break

      case "switchbox":
        elemTxt = ::create_option_switchbox(optionData)
        break

      case "editbox":
        elemTxt = ::create_option_editbox({
          id = optionData.id
          value = optionData?.value ?? ""
          password = optionData?.password ?? false
          maxlength = optionData?.maxlength ?? 16
          charMask = optionData?.charMask
        })
        break

      case "listbox":
        let listClass = ("listClass" in optionData)? optionData.listClass : "options"
        elemTxt = create_option_row_listbox(optionData.id, optionData.items, optionData.value, optionData.cb, true, listClass)
        haveOptText = false
        break

      case "multiselect":
        let listClass = ("listClass" in optionData)? optionData.listClass : "options"
        elemTxt = ::create_option_row_multiselect({ option = optionData, isFull = true, listClass = listClass })
        haveOptText = optionData?.showTitle ?? false
        break

      case "slider":
        elemTxt = create_option_slider(optionData.id, optionData.value, optionData.cb, true, "slider", optionData)
        break

      case "vlist":
        elemTxt = create_option_vlistbox(optionData.id, optionData.items, optionData.value, optionData.cb, true)
        isVlist = true
        break

      case "button":
        elemTxt = ::handyman.renderCached(("%gui/commonParts/button"), optionData)
        haveOptText = optionData?.showTitle ?? false
        break
    }

    let cell = []
    if (elemTxt != null)
    {
      if (isVlist)
        cell.append({ params = {
          width = 0
        }})
      else
      {
        local tdText = ""
        if (haveOptText)
          tdText = ::g_string.stripTags(optionData.getTitle())

        if (optionData.needShowValueText)
          elemTxt += format("optionValueText { id:t='%s'; text:t='%s' }",
            "value_" + optionData.id, optionData.getValueLocText(optionData.value))

        let optionTitleStyle = isHeader ? "optionBlockHeader" : "optiontext"
        cell.append({ params = {
          cellType = "left"
          width = wLeft
          autoScrollText = "yes"
          rawParam = "".concat(optionTitleStyle, " { id:t = 'lbl_", optionData.id,
            "'; text:t ='", tdText, "'; }")
        }})
      }

      cell.append({ params = {
        cellType = "right"
        width = wRight
        rawParam = $"padding-left:t='@optPad'; {elemTxt}"
      }})

      let rowParams = []
      if (isHeader)
        rowParams.append("inactive:t='yes'")
      if ("enabled" in optionData)
        rowParams.append($"enable:t='{optionData.enabled ? "yes" : "no"}';")
      if (!::u.isEmpty(optionData.hint))
        rowParams.append($"tooltip:t='{::g_string.stripTags(optionData.hint)}';")
      if (optionData.controlName == "listbox")
      {
        if ("trListParams" in optionData)
          rowParams.append(optionData.trListParams)
      } else if ("trParams" in optionData)
        rowParams.append(optionData.trParams)

      rowsView.insert(0, {
        row_id = optionData.getTrId()
        trParams = "\n".join(rowParams)
        cell = cell
      })

      if (iRow == 0)
        selectedRow = iRow
      ++iRow
    }

    resDescr.data.insert(0, optionData)
  }

  return {
    tbl = ::handyman.renderCached("%gui/options/optionsContainer", {
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
::get_unit_preset_img <- function get_unit_preset_img(unitName /*or unit group name*/)
{
  if (unitsImgPreset == null) {
    unitsImgPreset = {}
    let guiBlk = GUI.get()
    let blk = guiBlk?.units_presets?[::get_country_flags_preset()]
    if (blk)
      for (local i = 0; i < blk.paramCount(); i++)
        unitsImgPreset[blk.getParamName(i)] <- blk.getParamValue(i)
  }

  return unitsImgPreset?[unitName]
}

::is_tencent_unit_image_reqired <- function is_tencent_unit_image_reqired(unit)
{
  return unit.shopCountry == "country_japan" && unit.unitType == unitTypes.AIRCRAFT
    && ::is_vendor_tencent()
}
