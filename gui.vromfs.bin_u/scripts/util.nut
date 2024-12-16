from "%scripts/dagui_natives.nut" import is_myself_chat_moderator, clan_request_sync_profile, get_cyber_cafe_level, is_online_available, update_entitlements, wp_shop_get_aircraft_xp_rate, direct_launch, chard_request_profile, get_player_army_for_hud, is_myself_grand_moderator, exit_game, wp_shop_get_aircraft_wp_rate, clan_get_my_clan_id, sync_handler_simulate_request, is_myself_moderator
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { calc_boost_for_cyber_cafe, calc_boost_for_squads_members_from_same_cyber_cafe } = require("%appGlobals/ranks_common_shared.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_current_base_gui_handler } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { get_time_msec } = require("dagor.time")
//ATTENTION! this file is coupling things to much! Split it!
//shouldDecreaseSize, allowedSizeIncrease = 100
let { is_mplayer_peer, destroy_session } = require("multiplayer")
let penalty = require("penalty")
let { startLogout } = require("%scripts/login/logout.nut")
let { boosterEffectType, getActiveBoostersArray } = require("%scripts/items/boosterEffect.nut")
let { getActiveBoostersDescription } = require("%scripts/items/itemVisual.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { get_game_mode } = require("mission")
let { quit_to_debriefing, interrupt_multiplayer } = require("guiMission")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { OPTIONS_MODE_GAMEPLAY, OPTIONS_MODE_CAMPAIGN, OPTIONS_MODE_TRAINING,
  OPTIONS_MODE_SINGLE_MISSION, OPTIONS_MODE_DYNAMIC, OPTIONS_MODE_MP_DOMINATION,
  OPTIONS_MODE_MP_SKIRMISH
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { add_msg_box, remove_scene_box, update_msg_boxes, reset_msg_box_check_anim_time, need_new_msg_box_anim
} = require("%sqDagui/framework/msgBox.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { get_warpoints_blk, get_ranks_blk } = require("blkGetters")
let { addBgTaskCb } = require("%scripts/tasker.nut")
let { measureType } = require("%scripts/measureType.nut")
let { is_mode_with_teams, get_mplayer_color } = require("%scripts/utils_sa.nut")

::usageRating_amount <- [0.0003, 0.0005, 0.001, 0.002]

::current_wait_screen <- null

local gui_start_logout_scheduled = false

dagui_propid_add_name_id("tooltipId")

local current_wait_screen_txt = ""
::show_wait_screen <- function show_wait_screen(txt) {
  log($"GuiManager: show_wait_screen {txt}")
  if (checkObj(::current_wait_screen)) {
    if (current_wait_screen_txt == txt)
      return log("already have this screen, just ignore")

    log("wait screen already exist, remove old one.")
    ::current_wait_screen.getScene().destroyElement(::current_wait_screen)
    ::current_wait_screen = null
    reset_msg_box_check_anim_time()
  }

  let guiScene = get_main_gui_scene()
  if (guiScene == null)
    return log("guiScene == null")

  let needAnim = need_new_msg_box_anim()
  ::current_wait_screen = guiScene.loadModal("", "%gui/waitBox.blk", needAnim ? "massTransp" : "div", null)
  if (!checkObj(::current_wait_screen))
    return log("Error: failed to create wait screen")

  let obj = ::current_wait_screen.findObject("wait_screen_msg")
  if (!checkObj(obj))
    return log("Error: failed to find wait_screen_msg")

  obj.setValue(loc(txt))
  current_wait_screen_txt = txt
  broadcastEvent("WaitBoxCreated")
}

::close_wait_screen <- function close_wait_screen() {
  log("close_wait_screen")
  if (!checkObj(::current_wait_screen))
    return

  let guiScene = ::current_wait_screen.getScene()
  guiScene.destroyElement(::current_wait_screen)
  ::current_wait_screen = null
  reset_msg_box_check_anim_time()
  broadcastEvent("ModalWndDestroy")

  guiScene.performDelayed(getroottable(), update_msg_boxes)
}

eventbus_subscribe("on_cannot_create_session", function on_cannot_create_session(...) {
  add_msg_box("cannot_session", loc("NET_CANNOT_CREATE_SESSION"), [["ok", function() {}]], "ok")
})


// left for future ps3/ps4 realisation
function on_lost_psn() {
  log("on_lost_psn")
  let guiScene = get_gui_scene()
  let handler = get_current_base_gui_handler()
  if (handler == null)
    return

  remove_scene_box("connection_failed")

  if (guiScene["list_no_sessions_create"] != null) {
    remove_scene_box("list_no_sessions_create")
  }
  if (guiScene["psn_room_create_error"] != null) {
    remove_scene_box("psn_room_create_error")
  }

  if (!isInMenu()) {
    gui_start_logout_scheduled = true
    ::destroy_session_scripted("on lost psn while not in menu")
    quit_to_debriefing()
    interrupt_multiplayer(true)
  }
  else {
    add_msg_box("lost_live", loc("yn1/disconnection/psn"), [["ok",
        function() {
          ::destroy_session_scripted("after 'on lost psn' message")
          startLogout()
        }
        ]], "ok")
  }
}

eventbus_subscribe("PsnLoginStateChanged", @(p) p?.isSignedIn ? null : on_lost_psn())

::check_logout_scheduled <- function check_logout_scheduled() {
  if (gui_start_logout_scheduled) {
    gui_start_logout_scheduled = false
    on_lost_psn()
  }
}

let optionsModeByGameMode = {
  [GM_CAMPAIGN]          = OPTIONS_MODE_CAMPAIGN,
  [GM_TRAINING]          = OPTIONS_MODE_TRAINING,
  [GM_TEST_FLIGHT]       = OPTIONS_MODE_TRAINING,
  [GM_SINGLE_MISSION]    = OPTIONS_MODE_SINGLE_MISSION,
  [GM_USER_MISSION]      = OPTIONS_MODE_SINGLE_MISSION,
  [GM_DYNAMIC]           = OPTIONS_MODE_DYNAMIC,
  [GM_BUILDER]           = OPTIONS_MODE_DYNAMIC,
  [GM_DOMINATION]        = OPTIONS_MODE_MP_DOMINATION,
  [GM_SKIRMISH]          = OPTIONS_MODE_MP_SKIRMISH,
}

::get_options_mode <- function get_options_mode(game_mode) {
  return optionsModeByGameMode?[game_mode] ?? OPTIONS_MODE_GAMEPLAY
}

::get_squad_bonus_for_same_cyber_cafe <- function get_squad_bonus_for_same_cyber_cafe(effectType, num = -1) {
  if (num < 0)
    num = g_squad_manager.getSameCyberCafeMembersNum()
  let cyberCafeBonusesTable = calc_boost_for_squads_members_from_same_cyber_cafe(num)
  local value = getTblValue(effectType.abbreviation, cyberCafeBonusesTable, 0.0)
  return value
}

::get_cyber_cafe_bonus_by_effect_type <- function get_cyber_cafe_bonus_by_effect_type(effectType, cyberCafeLevel = -1) {
  if (cyberCafeLevel < 0)
    cyberCafeLevel = get_cyber_cafe_level()
  let cyberCafeBonusesTable = calc_boost_for_cyber_cafe(cyberCafeLevel)
  let value = getTblValue(effectType.abbreviation, cyberCafeBonusesTable, 0.0)
  return value
}

::get_current_bonuses_text <- function get_current_bonuses_text(effectType) {
  let tooltipText = []

  if (havePremium.value) {
    local rate = ""
    if (effectType == boosterEffectType.WP) {
      let blk = get_warpoints_blk()
      rate = "".concat("+", measureType.PERCENT_FLOAT.getMeasureUnitsText((blk?.wpMultiplier ?? 1.0) - 1.0))
      rate = $"{colorize("activeTextColor", rate)}{loc("warpoints/short/colored")}"
    }
    else if (effectType == boosterEffectType.RP) {
      let blk = get_ranks_blk()
      rate = "".concat("+", measureType.PERCENT_FLOAT.getMeasureUnitsText((blk?.xpMultiplier ?? 1.0) - 1.0))
      rate = $"{colorize("activeTextColor", rate)}{loc("currency/researchPoints/sign/colored")}"
    }
    tooltipText.append("".concat(loc("mainmenu/activePremium"), loc("ui/colon"), rate))
  }

  local value = ::get_cyber_cafe_bonus_by_effect_type(effectType)
  if (value > 0.0) {
    value = measureType.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(colorize("activeTextColor", value), true)
    tooltipText.append("".concat(loc("mainmenu/bonusCyberCafe"), loc("ui/colon"), value))
  }

  value = ::get_squad_bonus_for_same_cyber_cafe(effectType)
  if (value > 0.0) {
    value = measureType.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(colorize("activeTextColor", value), true)
    tooltipText.append(loc("item/FakeBoosterForNetCafeLevel/squad", { num = loc("ui/colon").concat(g_squad_manager.getSameCyberCafeMembersNum(), value) }))
  }

  let boostersArray = getActiveBoostersArray(effectType)
  let boostersDescription = getActiveBoostersDescription(boostersArray, effectType)
  if (boostersDescription != "")
    tooltipText.append("".concat((havePremium.value ? "\n" : ""), boostersDescription))

  local bonusText = "\n".join(tooltipText, true)
  if (bonusText != "")
    bonusText = $"\n<b>{loc("mainmenu/bonusTitle")}{loc("ui/colon")}</b>\n{bonusText}"

  return bonusText
}

::getCountryByAircraftName <- function getCountryByAircraftName(airName) { //used in code
  let country = ::getShopCountry(airName)
  let cPrefixLen = "country_".len()
  if (country.len() > cPrefixLen)
    return country.slice(cPrefixLen)
  return ""
}

::getShopCountry <- function getShopCountry(airName) {
  let air = getAircraftByName(airName)
  return air?.shopCountry ?? ""
}

::is_game_mode_with_spendable_weapons <- function is_game_mode_with_spendable_weapons() {
  let mode = get_game_mode()
  return mode == GM_DOMINATION || mode == GM_TOURNAMENT
}

local last_update_entitlements_time = get_time_msec()
::get_update_entitlements_timeout_msec <- function get_update_entitlements_timeout_msec() {
  return last_update_entitlements_time - get_time_msec() + 20000
}

::update_entitlements_limited <- function update_entitlements_limited(force = false) {
  if (!is_online_available())
    return -1
  if (force || ::get_update_entitlements_timeout_msec() < 0) {
    last_update_entitlements_time = get_time_msec()
    return update_entitlements()
  }
  return -1
}

::get_number_of_units_by_years <- function get_number_of_units_by_years(country, years) {
  let result = {}
  foreach (year in years) {
    result[$"year{year}"] <- 0
    result[$"beforeyear{year}"] <- 0
  }

  foreach (air in getAllUnits()) {
    if (getEsUnitType(air) != ES_UNIT_TYPE_AIRCRAFT)
      continue
    if (!("tags" in air) || !air.tags)
      continue;
    if (air.shopCountry != country)
      continue;

    local maxYear = 0
    foreach (year in years) {
      let parameter = $"year{year}";
      foreach (tag in air.tags)
        if (tag == parameter) {
          result[parameter]++
          maxYear = max(year, maxYear)
        }
    }
    if (maxYear)
      foreach (year in years)
        if (year > maxYear)
          result[$"beforeyear{year}"]++
  }
  return result;
}

::on_have_to_start_chard_op <- function on_have_to_start_chard_op(message) {
//  dlog($"GP: on have to start char op message! = {message}")
  log($"on_have_to_start_chard_op {message}")

  if (message == "sync_clan_vs_profile") {
    let taskId = clan_request_sync_profile()
    addBgTaskCb(taskId, function() {
      ::requestMyClanData(true)
      ::update_gamercards()
    })
  }
  else if (message == "clan_info_reload") {
    ::requestMyClanData(true)
    let myClanId = clan_get_my_clan_id()
    if (myClanId == "-1")
      sync_handler_simulate_request(message)
  }
  else if (message == "profile_reload") {
    let oldPenaltyStatus = penalty.getPenaltyStatus()
    let taskId = chard_request_profile()
    addBgTaskCb(taskId, function() {
      let  newPenaltyStatus = penalty.getPenaltyStatus()
      if (newPenaltyStatus.status != oldPenaltyStatus.status || newPenaltyStatus.duration != oldPenaltyStatus.duration)
        broadcastEvent("PlayerPenaltyStatusChanged", { status = newPenaltyStatus.status })
    })
  }
}

::quit_and_run_cmd <- function quit_and_run_cmd(cmd) {
  direct_launch(cmd); //FIXME: mac???
  exit_game();
}

::call_for_handler <- function call_for_handler(handler, func) {
  if (!func)
    return
  if (handler)
    return func.call(handler)
  return func()
}

::get_navigation_images_text <- function get_navigation_images_text(cur, total) {
  local res = ""
  if (total > 1) {
    local style = null
    if (cur > 0)
      style = (cur < total - 1) ? "all" : "left"
    else
      style = (cur < total - 1) ? "right" : null
    if (style)
      res = $"navImgStyle:t='{style}'; "
  }
  if (cur > 0)
    res = "".concat(res, "navigationImage{ type:t='left' } ")
  if (cur < total - 1)
    res = "".concat(res, "navigationImage{ type:t='right' } ")
  return res
}

//
// Server message
//

local server_message_text = ""
local server_message_end_time = 0

::show_aas_notify <- function show_aas_notify(text, timeseconds) {
  server_message_text = loc(text)
  server_message_end_time = get_time_msec() + timeseconds * 1000
  broadcastEvent("ServerMessage")
  ::update_gamercards()
}

::server_message_update_scene <- function server_message_update_scene(scene) {
  if (!checkObj(scene))
    return false

  let serverMessageObject = scene.findObject("server_message")
  if (!checkObj(serverMessageObject))
    return false

  local text = ""
  if (get_time_msec() < server_message_end_time)
    text = server_message_text

  serverMessageObject.setValue(text)
  return text != ""
}

::cross_call_api.is_mode_with_teams <- is_mode_with_teams



::build_mplayer_name <- function build_mplayer_name(player, colored = true, withClanTag = true, withUnit = false, unitNameLoc = "") {
  if (!player)
    return ""

  local unitName = ""
  if (withUnit) {
    if (unitNameLoc == "") {
      let unitId = player.aircraftName
      if (unitId != "")
        unitNameLoc = loc($"{unitId}_1")
    }
    if (unitNameLoc != "")
      unitName = loc("ui/parentheses", { text = unitNameLoc })
  }

  let clanTag = withClanTag && !player?.isBot ? player.clanTag : ""
  let name = ::g_contacts.getPlayerFullName(player?.isBot ? player.name : getPlayerName(player.name),
                                              clanTag,
                                              unitName)

  return colored ? colorize(get_mplayer_color(player), name) : name
}

::destroy_session_scripted <- function destroy_session_scripted(sourceInfo) {
  let needEvent = is_mplayer_peer()
  destroy_session(sourceInfo)
  if (needEvent)
    //need delay after destroy session before is_multiplayer become false
    handlersManager.doDelayed(@() broadcastEvent("SessionDestroyed"))
}

::show_not_available_msg_box <- function show_not_available_msg_box() {
  showInfoMsgBox(loc("msgbox/notAvailbleYet"), "not_available", true)
}
