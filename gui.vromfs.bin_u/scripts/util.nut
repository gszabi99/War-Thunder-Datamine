//-file:plus-string
from "%scripts/dagui_natives.nut" import is_myself_chat_moderator, clan_request_sync_profile, get_cyber_cafe_level, is_online_available, update_entitlements, is_tanks_allowed, wp_shop_get_aircraft_xp_rate, direct_launch, chard_request_profile, char_send_blk, get_player_army_for_hud, is_myself_grand_moderator, exit_game, wp_shop_get_aircraft_wp_rate, clan_get_my_clan_id, sync_handler_simulate_request, is_myself_moderator
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { calc_boost_for_cyber_cafe, calc_boost_for_squads_members_from_same_cyber_cafe } = require("%appGlobals/ranks_common_shared.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_current_base_gui_handler } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let DataBlock = require("DataBlock")
let { get_time_msec } = require("dagor.time")
let { floor, fabs } = require("math")
let { rnd } = require("dagor.random")
let { object_to_json_string } = require("json")
//ATTENTION! this file is coupling things to much! Split it!
//shouldDecreaseSize, allowedSizeIncrease = 100
let { is_mplayer_host, is_mplayer_peer, destroy_session } = require("multiplayer")
let penalty = require("penalty")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { boosterEffectType, getActiveBoostersArray } = require("%scripts/items/boosterEffect.nut")
let { getActiveBoostersDescription } = require("%scripts/items/itemVisual.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { havePremium } = require("%scripts/user/premium.nut")
let { get_game_mode, get_game_type } = require("mission")
let { quit_to_debriefing, interrupt_multiplayer } = require("guiMission")
let { stripTags, cutPrefix } = require("%sqstd/string.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { OPTIONS_MODE_GAMEPLAY, OPTIONS_MODE_CAMPAIGN, OPTIONS_MODE_TRAINING,
  OPTIONS_MODE_SINGLE_MISSION, OPTIONS_MODE_DYNAMIC, OPTIONS_MODE_MP_DOMINATION,
  OPTIONS_MODE_MP_SKIRMISH
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { add_msg_box, remove_scene_box, update_msg_boxes, reset_msg_box_check_anim_time, need_new_msg_box_anim
} = require("%sqDagui/framework/msgBox.nut")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")
let { get_warpoints_blk, get_ranks_blk } = require("blkGetters")
let { addBgTaskCb } = require("%scripts/tasker.nut")
let { measureType } = require("%scripts/measureType.nut")

::usageRating_amount <- [0.0003, 0.0005, 0.001, 0.002]
::fakeBullets_prefix <- "fake"

::current_wait_screen <- null

local gui_start_logout_scheduled = false

dagui_propid_add_name_id("tooltipId")

::cssColorsMapDark <- {
  ["commonTextColor"] = "black",
  ["white"] = "black",
  ["activeTextColor"] = "activeTextColorDark",
  ["unlockActiveColor"] = "activeTextColorDark",
  ["highlightedTextColor"] = "activeTextColorDark",
  ["goodTextColor"] = "goodTextColorDark",
  ["badTextColor"] = "badTextColorDark",
  ["userlogColoredText"] = "userlogColoredTextDark",
  ["fadedTextColor"] = "fadedTextColorDark",
  ["warningTextColor"] = "warningTextColorDark",
  ["currencyGoldColor"] = "currencyGoldColorDark",
  ["currencyWpColor"] = "currencyWpColorDark",
  ["currencyRpColor"] = "currencyRpColorDark",
  ["currencyFreeRpColor"] = "currencyFreeRpColorDark",
  ["hotkeyColor"] = "hotkeyColorDark",
  ["axisSymbolColor"] = "axisSymbolColorDark",
}
::cssColorsMapLigth <- {}
foreach (i, v in ::cssColorsMapDark)
    ::cssColorsMapLigth[v] <- i

::global_max_players_versus <- 64
::global_max_players_coop <- 4

::locOrStrip <- function locOrStrip(text) {
  return (text.len() && text.slice(0, 1) != "#") ? stripTags(text) : text
}

::locEnding <- function locEnding(locId, ending, defValue = null) {
  local res = loc(locId + ending, "")
  if (res == "" && ending != "")
    res = loc(locId, defValue)
  return res
}

::getCompoundedText <- function getCompoundedText(firstPart, secondPart, color) {
  return "".concat(firstPart, colorize(color, secondPart))
}

local current_wait_screen_txt = ""
::show_wait_screen <- function show_wait_screen(txt) {
  log("GuiManager: show_wait_screen " + txt)
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


::in_on_lost_psn <- false

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
    ::in_on_lost_psn = true
    add_msg_box("lost_live", loc("yn1/disconnection/psn"), [["ok",
        function() {
          ::in_on_lost_psn = false
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
      rate = "+" + measureType.PERCENT_FLOAT.getMeasureUnitsText((blk?.wpMultiplier ?? 1.0) - 1.0)
      rate = $"{colorize("activeTextColor", rate)}{loc("warpoints/short/colored")}"
    }
    else if (effectType == boosterEffectType.RP) {
      let blk = get_ranks_blk()
      rate = "+" + measureType.PERCENT_FLOAT.getMeasureUnitsText((blk?.xpMultiplier ?? 1.0) - 1.0)
      rate = $"{colorize("activeTextColor", rate)}{loc("currency/researchPoints/sign/colored")}"
    }
    tooltipText.append(loc("mainmenu/activePremium") + loc("ui/colon") + rate)
  }

  local value = ::get_cyber_cafe_bonus_by_effect_type(effectType)
  if (value > 0.0) {
    value = measureType.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(colorize("activeTextColor", value), true)
    tooltipText.append(loc("mainmenu/bonusCyberCafe") + loc("ui/colon") + value)
  }

  value = ::get_squad_bonus_for_same_cyber_cafe(effectType)
  if (value > 0.0) {
    value = measureType.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(colorize("activeTextColor", value), true)
    tooltipText.append(loc("item/FakeBoosterForNetCafeLevel/squad", { num = g_squad_manager.getSameCyberCafeMembersNum() }) + loc("ui/colon") + value)
  }

  let boostersArray = getActiveBoostersArray(effectType)
  let boostersDescription = getActiveBoostersDescription(boostersArray, effectType)
  if (boostersDescription != "")
    tooltipText.append((havePremium.value ? "\n" : "") + boostersDescription)

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

::getAmountAndMaxAmountText <- function getAmountAndMaxAmountText(amount, maxAmount, showMaxAmount = false) {
  local amountText = ""
  if (maxAmount > 1 || showMaxAmount)
    amountText = amount.tostring() + (showMaxAmount && maxAmount > 1 ? "/" + maxAmount : "")
  return amountText;
}

::is_game_mode_with_spendable_weapons <- function is_game_mode_with_spendable_weapons() {
  let mode = get_game_mode()
  return mode == GM_DOMINATION || mode == GM_TOURNAMENT
}

::stringReplace <- function stringReplace(str, replstr, value) {
  local findex = 0;
  local s = str;

  while (true) {
    findex = s.indexof(replstr, findex);
    if (findex != null) {
      s = s.slice(0, findex) + value + s.slice(findex + replstr.len());
      findex += value.len();
    }
    else
      break;
  }
  return s;
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

::get_flush_exp_text <- function get_flush_exp_text(exp_value) {
  if (exp_value == null || exp_value < 0)
    return ""
  let rpPriceText = exp_value.tostring() + loc("currency/researchPoints/sign/colored")
  let coloredPriceText = ::colorTextByValues(rpPriceText, exp_value, 0)
  return format(loc("mainmenu/availableFreeExpForNewResearch"), coloredPriceText)
}

::colorTextByValues <- function colorTextByValues(text, val1, val2, useNeutral = true, useGood = true) {
  local color = ""
  if (val1 >= val2) {
    if (val1 == val2 && useNeutral)
      color = "activeTextColor"
    else if (useGood)
      color = "goodTextColor"
  }
  else
    color = "badTextColor"

  if (color == "")
    return text

  return format("<color=@%s>%s</color>", color, text)
}

::getObjIdByPrefix <- function getObjIdByPrefix(obj, prefix, idProp = "id") {
  if (!obj)
    return null
  let id = obj?[idProp]
  if (!id)
    return null

  return cutPrefix(id, prefix)
}

::array_to_blk <- function array_to_blk(arr, id) {
  let blk = DataBlock()
  if (arr)
    foreach (v in arr)
      blk[id] <- v
  return blk
}

::build_blk_from_container <- function build_blk_from_container(container, arrayKey = "array") {
  let blk = DataBlock()
  let isContainerArray = u.isArray(container)

  local addValue = ::assign_value_to_blk
  if (isContainerArray)
    addValue = ::create_new_pair_key_value_to_blk

  foreach (key, value in container) {
    local newValue = value
    let index = isContainerArray ? arrayKey : key.tostring()
    if (u.isTable(value) || u.isArray(value))
      newValue = ::build_blk_from_container(value, arrayKey)

    addValue(blk, index, newValue)
  }

  return blk
}

::create_new_pair_key_value_to_blk <- function create_new_pair_key_value_to_blk(blk, index, value) {
  /*Known feature - cannot create a pair, if index is used for other type
   i.e. ["string", 1, 2, 3, "string"] in this case will be ("string", "string") result
   on other case [1, 2, 3, "string"] will be (1, 2, 3) result. */

  blk[index] <- value
}

::assign_value_to_blk <- function assign_value_to_blk(blk, index, value) {
  blk[index] = value
}

::buildTableRow <- function buildTableRow(rowName, rowData, even = null, trParams = "", _tablePad = "@tblPad") {
  //tablePad not using, but passed through many calls of this function
  let view = {
    row_id = rowName
    even = even
    trParams = trParams
    cell = []
  }

  foreach (idx, cell in rowData) {
    let haveParams = type(cell) == "table"
    let config = (haveParams ? cell : {}).__merge({
      params = haveParams
      display = (cell?.show ?? true) ? "show" : "hide"
      id = getTblValue("id", cell, "td_" + idx)
      rawParam = getTblValue("rawParam", cell, "")
      needText = getTblValue("needText", cell, true)
      textType = getTblValue("textType", cell, "activeText")
      text = haveParams ? getTblValue("text", cell, "") : cell.tostring()
      textRawParam = getTblValue("textRawParam", cell, "")
      imageType = getTblValue("imageType", cell, "cardImg")
      fontIconType = getTblValue("fontIconType", cell, "fontIcon20")
    })

    view.cell.append(config)
  }

  return handyman.renderCached("%gui/commonParts/tableRow.tpl", view)
}

::buildTableRowNoPad <- function buildTableRowNoPad(rowName, rowData, even = null, trParams = "") {
  return ::buildTableRow(rowName, rowData, even, trParams, "0")
}

function _invoke_multi_array(multiArray, currentArray, currentIndex, invokeCallback) {
  if (currentIndex == multiArray.len()) {
    invokeCallback(currentArray)
    return
  }
  if (type(multiArray[currentIndex]) == "array") {
    foreach (name in multiArray[currentIndex]) {
      currentArray.append(name)
      _invoke_multi_array(multiArray, currentArray, currentIndex + 1, invokeCallback)
      currentArray.pop()
    }
  }
  else {
    currentArray.append(multiArray[currentIndex])
    _invoke_multi_array(multiArray, currentArray, currentIndex + 1, invokeCallback)
    currentArray.pop()
  }
}

::invoke_multi_array <- function invoke_multi_array(multiArray, invokeCallback) {
  _invoke_multi_array(multiArray, [], 0, invokeCallback)
}

::save_to_json <- function save_to_json(obj) {
  assert(isInArray(type(obj), [ "table", "array" ]),
    "Data type not suitable for save_to_json: " + type(obj))

  return object_to_json_string(obj, false)
}

::roman_numerals <- ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                         "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]

::increment_parameter <- function increment_parameter(object, parameter) {
  if (!(parameter in object))
    object[parameter] <- 0;
  object[parameter]++;
}

::get_number_of_units_by_years <- function get_number_of_units_by_years(country, years) {
  let result = {}
  foreach (year in years) {
    result["year" + year] <- 0
    result["beforeyear" + year] <- 0
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
      let parameter = "year" + year;
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

::generatePaginator <- function generatePaginator(nest_obj, handler, cur_page, last_page, my_page = null, show_last_page = false, hasSimpleNavButtons = false) {
  if (!checkObj(nest_obj))
    return

  let guiScene = nest_obj.getScene()
  let paginatorTpl = "%gui/paginator/paginator.tpl"
  local buttonsMid = ""
  let numButtonText = "button { to_page:t='%s'; text:t='%s'; %s on_click:t='goToPage'; underline{}}"
  let numPageText = "activeText{ text:t='%s'; %s}"
  local paginatorObj = nest_obj.findObject("paginator_container")

  if (!checkObj(paginatorObj)) {
    let paginatorMarkUpData = handyman.renderCached(paginatorTpl, { hasSimpleNavButtons = hasSimpleNavButtons })
    paginatorObj = guiScene.createElement(nest_obj, "paginator", handler)
    guiScene.replaceContentFromText(paginatorObj, paginatorMarkUpData, paginatorMarkUpData.len(), handler)
  }

  //if by some mistake cur_page will be a float, - here can be a freeze on mac,
  //because of (cur_page - 1 <= i) can become wrong result
  cur_page = cur_page.tointeger()
  //number of last wisible page
  local lastShowPage = show_last_page ? last_page : min(max(cur_page + 1, 2), last_page)

  let isSinglePage = last_page < 1
  paginatorObj.show(! isSinglePage)
  paginatorObj.enable(! isSinglePage)
  if (isSinglePage)
    return

  if (my_page != null && my_page > lastShowPage && my_page <= last_page)
    lastShowPage = my_page

  for (local i = 0; i <= lastShowPage; i++) {
    if (i == cur_page)
      buttonsMid += format(numPageText, (i + 1).tostring(), (i == my_page ? "mainPlayer:t='yes';" : ""))
    else if ((cur_page - 1 <= i && i <= cur_page + 1)       //around current page
             || (i == my_page)                              //equal my page
             || (i < 3)                                     //always show first 2 entrys
             || (show_last_page && i == lastShowPage))      //show last entry if show_last_page
      buttonsMid += format(numButtonText, i.tostring(), (i + 1).tostring(), (i == my_page ? "mainPlayer:t='yes';" : ""))
    else {
      buttonsMid += format(numPageText, "...", "")
      if (my_page != null && i < my_page && (my_page < cur_page || i > cur_page))
        i = my_page - 1
      else if (i < cur_page)
        i = cur_page - 2
      else if (show_last_page)
        i = lastShowPage - 1
    }
  }

  guiScene.replaceContentFromText(paginatorObj.findObject("paginator_page_holder"), buttonsMid, buttonsMid.len(), handler)
  let nextObj = paginatorObj.findObject("pag_next_page")
  nextObj.show(last_page > cur_page)
  nextObj.to_page = min(last_page, cur_page + 1).tostring()
  let prevObj = paginatorObj.findObject("pag_prew_page")
  prevObj.show(cur_page > 0)
  prevObj.to_page = max(0, cur_page - 1).tostring()
}

::hidePaginator <- function hidePaginator(nestObj) {
  let paginatorObj = nestObj.findObject("paginator_container")
  if (!paginatorObj)
    return
  paginatorObj.show(false)
  paginatorObj.enable(false)
}

::paginator_set_unseen <- function paginator_set_unseen(nestObj, prevUnseen, nextUnseen) {
  let paginatorObj = nestObj.findObject("paginator_container")
  if (!checkObj(paginatorObj))
    return

  let prevObj = paginatorObj.findObject("pag_prew_page_unseen")
  if (prevObj)
    prevObj.setValue(prevUnseen || "")
  let nextObj = paginatorObj.findObject("pag_next_page_unseen")
  if (nextObj)
    nextObj.setValue(nextUnseen || "")
}

::on_have_to_start_chard_op <- function on_have_to_start_chard_op(message) {
//  dlog("GP: on have to start char op message! = " +message)
  log("on_have_to_start_chard_op " + message)

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

::getValueForMode <- function getValueForMode(optionsMode, oType) {
  let mainOptionsMode = getGuiOptionsMode()
  setGuiOptionsMode(optionsMode)
  local value = ::get_option(oType)
  value = value.values[value.value]
  setGuiOptionsMode(mainOptionsMode)
  return value
}

::flushExcessExpToUnit <- function flushExcessExpToUnit(unit) {
  let blk = DataBlock()
  blk.setStr("unit", unit)

  return char_send_blk("cln_move_exp_to_unit", blk)
}

::flushExcessExpToModule <- function flushExcessExpToModule(unit, module) {
  let blk = DataBlock()
  blk.setStr("unit", unit)
  blk.setStr("mod", module)

  return char_send_blk("cln_move_exp_to_module", blk)
}

::quit_and_run_cmd <- function quit_and_run_cmd(cmd) {
  direct_launch(cmd); //FIXME: mac???
  exit_game();
}

::get_bit_value_by_array <- function get_bit_value_by_array(selValues, values) {
  local res = 0
  foreach (i, val in values)
    if (isInArray(val, selValues))
      res = res | (1 << i)
  return res
}

::get_array_by_bit_value <- function get_array_by_bit_value(bitValue, values) {
  let res = []
  foreach (i, val in values)
    if (bitValue & (1 << i))
      res.append(val)
  return res
}

::call_for_handler <- function call_for_handler(handler, func) {
  if (!func)
    return
  if (handler)
    return func.call(handler)
  return func()
}

::is_worldwar_enabled <- function is_worldwar_enabled() {
  return hasFeature("WorldWar")
    && ("g_world_war" in getroottable())
    && (!isPlatformSony || isCrossPlayEnabled())
}

::check_tanks_available <- function check_tanks_available(silent = false) {
  if (is_platform_pc && "is_tanks_allowed" in getroottable() && !is_tanks_allowed()) {
    if (!silent)
      showInfoMsgBox(loc("mainmenu/graphics_card_does_not_support_tank"), "graphics_card_does_not_support_tanks")
    return false
  }
  return true
}

::find_nearest <- function find_nearest(val, arrayOfVal) {
  if (arrayOfVal.len() == 0)
    return -1;

  local bestIdx = 0;
  local bestDist = fabs(arrayOfVal[0] - val);
  for (local i = 1; i < arrayOfVal.len(); i++) {
    let dist = fabs(arrayOfVal[i] - val);
    if (dist < bestDist) {
      bestDist = dist;
      bestIdx = i;
    }
  }

  return bestIdx;
}

local informTexQualityRestrictedDone = false
::informTexQualityRestricted <- function informTexQualityRestricted() {
  if (informTexQualityRestrictedDone)
    return
  let message = loc("msgbox/graphicsOptionValueReduced/lowVideoMemory", {
    name =  colorize("userlogColoredText", loc("options/texQuality"))
    value = colorize("userlogColoredText", loc("options/quality_medium"))
  })
  showInfoMsgBox(message, "sysopt_tex_quality_restricted")
  informTexQualityRestrictedDone = true
}

::is_myself_anyof_moderators <- function is_myself_anyof_moderators() {
  return ::is_myself_moderator() || ::is_myself_grand_moderator() || is_myself_chat_moderator()
}

::unlockCrew <- function unlockCrew(crewId, byGold, cost) {
  let blk = DataBlock()
  blk["crew"] = crewId
  blk["gold"] = byGold
  blk["cost"] = cost?.wp ?? 0
  blk["costGold"] = cost?.gold ?? 0

  return char_send_blk("cln_unlock_crew", blk)
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
      res += "navImgStyle:t='" + style + "'; "
  }
  if (cur > 0)
    res += "navigationImage{ type:t='left' } "
  if (cur < total - 1)
    res += "navigationImage{ type:t='right' } "
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

::getArrayFromInt <- function getArrayFromInt(intNum) {
  let arr = []
  do {
    let div = intNum % 10
    arr.append(div)
    intNum = floor(intNum / 10).tointeger()
  } while (intNum != 0)

  arr.reverse()
  return arr
}

const PASSWORD_SYMBOLS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
::gen_rnd_password <- function gen_rnd_password(charsAmount) {
  local res = ""
  let total = PASSWORD_SYMBOLS.len()
  for (local i = 0; i < charsAmount; i++)
    res += PASSWORD_SYMBOLS[rnd() % total].tochar()
  return res
}

::inherit_table <- function inherit_table(parent_table, child_table) {
  return u.extend(u.copy(parent_table), child_table)
}

::is_mode_with_teams <- function is_mode_with_teams(gt = null) {
  if (gt == null)
    gt = get_game_type()
  return !(gt & (GT_FFA_DEATHMATCH | GT_FFA))
}
::cross_call_api.is_mode_with_teams <- ::is_mode_with_teams


::is_team_friendly <- function is_team_friendly(teamId) {
  return ::is_mode_with_teams() &&
    teamId == get_player_army_for_hud()
}

::get_team_color <- function get_team_color(teamId) {
  return ::is_team_friendly(teamId) ? "hudColorBlue" : "hudColorRed"
}

::get_mplayer_color <- function get_mplayer_color(player) {
  return !player ? "" :
    player.isLocal ? "hudColorHero" :
    player.isInHeroSquad ? "hudColorSquad" :
    ::get_team_color(player.team)
}

::build_mplayer_name <- function build_mplayer_name(player, colored = true, withClanTag = true, withUnit = false, unitNameLoc = "") {
  if (!player)
    return ""

  local unitName = ""
  if (withUnit) {
    if (unitNameLoc == "") {
      let unitId = player.aircraftName
      if (unitId != "")
        unitNameLoc = loc(unitId + "_1")
    }
    if (unitNameLoc != "")
      unitName = loc("ui/parentheses", { text = unitNameLoc })
  }

  let clanTag = withClanTag && !player?.isBot ? player.clanTag : ""
  let name = ::g_contacts.getPlayerFullName(player?.isBot ? player.name : getPlayerName(player.name),
                                              clanTag,
                                              unitName)

  return colored ? colorize(::get_mplayer_color(player), name) : name
}

::is_multiplayer <- @() is_mplayer_host() || is_mplayer_peer()

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