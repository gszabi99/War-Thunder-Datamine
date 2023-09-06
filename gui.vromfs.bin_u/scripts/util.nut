//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { format } = require("string")
let DataBlock = require("DataBlock")
let { get_time_msec } = require("dagor.time")
let { floor, fabs } = require("math")
let { rnd } = require("dagor.random")
let { json_to_string } = require("json")
//ATTENTION! this file is coupling things to much! Split it!
//shouldDecreaseSize, allowedSizeIncrease = 100
let { is_mplayer_host, is_mplayer_peer, destroy_session } = require("multiplayer")
let time = require("%scripts/time.nut")
let penalty = require("penalty")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let stdMath = require("%sqstd/math.nut")
let { isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { set_blk_value_by_path, get_blk_value_by_path, blkOptFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { boosterEffectType, getActiveBoostersArray } = require("%scripts/items/boosterEffect.nut")
let { getActiveBoostersDescription } = require("%scripts/items/itemVisual.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { havePremium } = require("%scripts/user/premium.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { get_game_mode, get_game_type } = require("mission")
let { quit_to_debriefing, interrupt_multiplayer } = require("guiMission")
let { stripTags, cutPrefix, isStringFloat } = require("%sqstd/string.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { OPTIONS_MODE_GAMEPLAY, OPTIONS_MODE_CAMPAIGN, OPTIONS_MODE_TRAINING,
  OPTIONS_MODE_SINGLE_MISSION, OPTIONS_MODE_DYNAMIC, OPTIONS_MODE_MP_DOMINATION,
  OPTIONS_MODE_MP_SKIRMISH
} = require("%scripts/options/optionsExtNames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")

::usageRating_amount <- [0.0003, 0.0005, 0.001, 0.002]
let allowingMultCountry = [1.5, 2, 2.5, 3, 4, 5]
let allowingMultAircraft = [1.3, 1.5, 2, 2.5, 3, 4, 5, 10]
::fakeBullets_prefix <- "fake"
const NOTIFY_EXPIRE_PREMIUM_ACCOUNT = 15
::EATT_UNKNOWN <- -1

::current_campaign_id <- null
::current_campaign_mission <- null
::current_wait_screen <- null

::mp_stat_handler <- null
::statscreen_handler <- null
::tactical_map_handler <- null
::flight_menu_handler <- null
::postfx_settings_handler <- null
::credits_handler <- null

local gui_start_logout_scheduled = false

registerPersistentData("util", getroottable(),
  ["current_campaign_id", "current_campaign_mission"])

::nbsp <- " " // Non-breaking space character

::dagui_propid.add_name_id("tooltipId")

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

let function get_gamepad_specific_localization(locId) {
  if (!showConsoleButtons.value)
    return loc(locId)

  return loc(locId + "/gamepad_specific", locId)
}
::cross_call_api.get_gamepad_specific_localization <- get_gamepad_specific_localization


::locEnding <- function locEnding(locId, ending, defValue = null) {
  local res = loc(locId + ending, "")
  if (res == "" && ending != "")
    res = loc(locId, defValue)
  return res
}

::getCompoundedText <- function getCompoundedText(firstPart, secondPart, color) {
  return "".concat(firstPart, colorize(color, secondPart))
}

::current_wait_screen_txt <- ""
::show_wait_screen <- function show_wait_screen(txt) {
  log("GuiManager: show_wait_screen " + txt)
  if (checkObj(::current_wait_screen)) {
    if (::current_wait_screen_txt == txt)
      return log("already have this screen, just ignore")

    log("wait screen already exist, remove old one.")
    ::current_wait_screen.getScene().destroyElement(::current_wait_screen)
    ::current_wait_screen = null
    ::reset_msg_box_check_anim_time()
  }

  let guiScene = ::get_main_gui_scene()
  if (guiScene == null)
    return log("guiScene == null")

  let needAnim = ::need_new_msg_box_anim()
  ::current_wait_screen = guiScene.loadModal("", "%gui/waitBox.blk", needAnim ? "massTransp" : "div", null)
  if (!checkObj(::current_wait_screen))
    return log("Error: failed to create wait screen")

  let obj = ::current_wait_screen.findObject("wait_screen_msg")
  if (!checkObj(obj))
    return log("Error: failed to find wait_screen_msg")

  obj.setValue(loc(txt))
  ::current_wait_screen_txt = txt
  broadcastEvent("WaitBoxCreated")
}

::close_wait_screen <- function close_wait_screen() {
  log("close_wait_screen")
  if (!checkObj(::current_wait_screen))
    return

  let guiScene = ::current_wait_screen.getScene()
  guiScene.destroyElement(::current_wait_screen)
  ::current_wait_screen = null
  ::reset_msg_box_check_anim_time()
  broadcastEvent("ModalWndDestroy")

  guiScene.performDelayed(getroottable(), ::update_msg_boxes)
}

::on_cannot_create_session <- function on_cannot_create_session() {
  ::add_msg_box("cannot_session", loc("NET_CANNOT_CREATE_SESSION"), [["ok", function() {}]], "ok")
}

::in_on_lost_psn <- false

// left for future ps3/ps4 realisation
let function on_lost_psn() {
  log("on_lost_psn")
  let guiScene = ::get_gui_scene()
  let handler = ::current_base_gui_handler
  if (handler == null)
    return

  ::remove_scene_box("connection_failed")

  if (guiScene["list_no_sessions_create"] != null) {
    ::remove_scene_box("list_no_sessions_create")
  }
  if (guiScene["psn_room_create_error"] != null) {
    ::remove_scene_box("psn_room_create_error")
  }

  if (!::isInMenu()) {
    gui_start_logout_scheduled = true
    ::destroy_session_scripted("on lost psn while not in menu")
    quit_to_debriefing()
    interrupt_multiplayer(true)
  }
  else {
    ::in_on_lost_psn = true
    ::add_msg_box("lost_live", loc("yn1/disconnection/psn"), [["ok",
        function() {
          ::in_on_lost_psn = false
          ::destroy_session_scripted("after 'on lost psn' message")
          startLogout()
        }
        ]], "ok")
  }
}

::check_logout_scheduled <- function check_logout_scheduled() {
  if (gui_start_logout_scheduled) {
    gui_start_logout_scheduled = false
    on_lost_psn()
  }
}

::get_options_mode <- function get_options_mode(game_mode) {
  switch (game_mode) {
    case GM_CAMPAIGN: return OPTIONS_MODE_CAMPAIGN;
    case GM_TRAINING: return OPTIONS_MODE_TRAINING;
    case GM_TEST_FLIGHT: return OPTIONS_MODE_TRAINING;
    case GM_SINGLE_MISSION: return OPTIONS_MODE_SINGLE_MISSION;
    case GM_USER_MISSION: return OPTIONS_MODE_SINGLE_MISSION;
    case GM_DYNAMIC: return OPTIONS_MODE_DYNAMIC;
    case GM_BUILDER: return OPTIONS_MODE_DYNAMIC;
    case GM_DOMINATION: return OPTIONS_MODE_MP_DOMINATION;
    case GM_SKIRMISH: return OPTIONS_MODE_MP_SKIRMISH;
  }
  return OPTIONS_MODE_GAMEPLAY
}

::preload_ingame_scenes <- function preload_ingame_scenes() {
  ::mp_stat_handler = null
  ::tactical_map_handler = null
  ::flight_menu_handler = null
  ::postfx_settings_handler = null

  handlersManager.clearScene()
  handlersManager.loadHandler(gui_handlers.Hud)

  require("%scripts/chat/mpChatModel.nut").init()
}

::get_squad_bonus_for_same_cyber_cafe <- function get_squad_bonus_for_same_cyber_cafe(effectType, num = -1) {
  if (num < 0)
    num = ::g_squad_manager.getSameCyberCafeMembersNum()
  let cyberCafeBonusesTable = ::calc_boost_for_squads_members_from_same_cyber_cafe(num)
  local value = getTblValue(effectType.abbreviation, cyberCafeBonusesTable, 0.0)
  return value
}

::get_cyber_cafe_bonus_by_effect_type <- function get_cyber_cafe_bonus_by_effect_type(effectType, cyberCafeLevel = -1) {
  if (cyberCafeLevel < 0)
    cyberCafeLevel = ::get_cyber_cafe_level()
  let cyberCafeBonusesTable = ::calc_boost_for_cyber_cafe(cyberCafeLevel)
  let value = getTblValue(effectType.abbreviation, cyberCafeBonusesTable, 0.0)
  return value
}

::get_current_bonuses_text <- function get_current_bonuses_text(effectType) {
  let tooltipText = []

  if (havePremium.value) {
    local rate = ""
    if (effectType == boosterEffectType.WP) {
      let blk = ::get_warpoints_blk()
      rate = "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText((blk?.wpMultiplier ?? 1.0) - 1.0)
      rate = ::getWpPriceText(colorize("activeTextColor", rate), true)
    }
    else if (effectType == boosterEffectType.RP) {
      let blk = ::get_ranks_blk()
      rate = "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText((blk?.xpMultiplier ?? 1.0) - 1.0)
      rate = ::getRpPriceText(colorize("activeTextColor", rate), true)
    }
    tooltipText.append(loc("mainmenu/activePremium") + loc("ui/colon") + rate)
  }

  local value = ::get_cyber_cafe_bonus_by_effect_type(effectType)
  if (value > 0.0) {
    value = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(colorize("activeTextColor", value), true)
    tooltipText.append(loc("mainmenu/bonusCyberCafe") + loc("ui/colon") + value)
  }

  value = ::get_squad_bonus_for_same_cyber_cafe(effectType)
  if (value > 0.0) {
    value = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(colorize("activeTextColor", value), true)
    tooltipText.append(loc("item/FakeBoosterForNetCafeLevel/squad", { num = ::g_squad_manager.getSameCyberCafeMembersNum() }) + loc("ui/colon") + value)
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

::add_bg_task_cb <- function add_bg_task_cb(taskId, actionFunc, handler = null) {
  let taskCallback = Callback((@(actionFunc, handler) function(_result = YU2_OK) {
    ::call_for_handler(handler, actionFunc)
  })(actionFunc, handler), handler)
  ::g_tasker.addTask(taskId, null, taskCallback, taskCallback)
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

::enableBtnTable <- function enableBtnTable(obj, table, setInactive = false) {
  if (!checkObj(obj))
    return

  foreach (id, status in table) {
    let idObj = obj.findObject(id)
    if (checkObj(idObj)) {
      if (setInactive)
        idObj.inactiveColor = status ? "no" : "yes"
      else
        idObj.enable(status)
    }
  }
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
  if (!::is_online_available())
    return -1
  if (force || ::get_update_entitlements_timeout_msec() < 0) {
    last_update_entitlements_time = get_time_msec()
    return ::update_entitlements()
  }
  return -1
}

::check_balance_msgBox <- function check_balance_msgBox(cost, afterCheck = null, silent = false) {
  if (cost.isZero())
    return true

  let balance = ::get_gui_balance()
  local text = null
  local isGoldNotEnough = false
  if (cost.wp > 0 && balance.wp < cost.wp)
    text = loc("not_enough_warpoints")
  if (cost.gold > 0 && balance.gold < cost.gold) {
    text = loc("not_enough_gold")
    isGoldNotEnough = true
    ::update_entitlements_limited()
  }

  if (!text)
    return true
  if (silent)
    return false

  let cancelBtnText = ::isInMenu() ? "cancel" : "ok"
  local defButton = cancelBtnText
  let buttons = [[cancelBtnText, (@(afterCheck) function() { if (afterCheck) afterCheck (); })(afterCheck) ]]
  local shopType = ""
  if (isGoldNotEnough && hasFeature("EnableGoldPurchase"))
    shopType = "eagles"
  else if (!isGoldNotEnough && hasFeature("SpendGold"))
    shopType = "warpoints"

  if (::isInMenu() && shopType != "") {
    let purchaseBtn = "#mainmenu/btnBuy"
    defButton = purchaseBtn
    buttons.insert(0, [purchaseBtn, @() ::OnlineShopModel.launchOnlineShop(null, shopType, afterCheck, "buy_gold_msg")])
  }

  ::scene_msg_box("no_money", null, text, buttons, defButton)
  return false
}

//need to remove
let function getPriceText(wp, gold = 0, colored = true, showWp = false, showGold = false) {
  local text = ""
  if (gold != 0 || showGold)
    text += gold + loc(colored ? "gold/short/colored" : "gold/short")
  if (wp != 0 || showWp)
    text += ((text == "") ? "" : ", ") + wp + loc(colored ? "warpoints/short/colored" : "warpoints/short")
  return text
}

::getPriceAccordingToPlayersCurrency <- function getPriceAccordingToPlayersCurrency(wpCurrency, eaglesCurrency, colored = true) {
  let cost = Cost(wpCurrency, eaglesCurrency)
  if (colored)
    return cost.getTextAccordingToBalance()
  return cost.getUncoloredText()
}

::getWpPriceText <- function getWpPriceText(wp, colored = false) {
  return getPriceText(wp, 0, colored, true)
}

//need to remove
::getRpPriceText <- function getRpPriceText(rp, colored = false) {
  if (rp == 0)
    return ""
  return rp.tostring() + loc("currency/researchPoints/sign" + (colored ? "/colored" : ""))
}

::get_crew_sp_text <- function get_crew_sp_text(sp, showEmpty = true) {
  if (!showEmpty && sp == 0)
    return ""
  return decimalFormat(sp) + loc("currency/skillPoints/sign/colored")
}

::get_flush_exp_text <- function get_flush_exp_text(exp_value) {
  if (exp_value == null || exp_value < 0)
    return ""
  let rpPriceText = exp_value.tostring() + loc("currency/researchPoints/sign/colored")
  let coloredPriceText = ::colorTextByValues(rpPriceText, exp_value, 0)
  return format(loc("mainmenu/availableFreeExpForNewResearch"), coloredPriceText)
}

::getCrewSpText <- function getCrewSpText(sp, colored = true) {
  if (sp == 0)
    return ""
  return decimalFormat(sp)
    + loc("currency/skillPoints/sign" + (colored ? "/colored" : ""))
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

::getTooltipObjId <- function getTooltipObjId(obj) {
  return obj?.tooltipId ?? ::getObjIdByPrefix(obj, "tooltip_")
}

::array_to_blk <- function array_to_blk(arr, id) {
  let blk = DataBlock()
  if (arr)
    foreach (v in arr)
      blk[id] <- v
  return blk
}

::buildTableFromBlk <- function buildTableFromBlk(blk) {
  if (!blk)
    return {}
  let res = {}
  for (local i = 0; i < blk.paramCount(); i++)
    ::buildTableFromBlk_AddElement(res, blk.getParamName(i) || "", blk.getParamValue(i))
  for (local i = 0; i < blk.blockCount(); i++) {
    let block = blk.getBlock(i)
    let blockTable = ::buildTableFromBlk(block)
    ::buildTableFromBlk_AddElement(res, block.getBlockName() || "", blockTable)
  }
  return res
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

/**
 * Adds value to table that may already
 * have some value with the same key.
 */
::buildTableFromBlk_AddElement <- function buildTableFromBlk_AddElement(table, elementKey, elementValue) {
  if (!(elementKey in table))
    table[elementKey] <- elementValue
  else if (type(table[elementKey]) == "array")
    table[elementKey].append(elementValue)
  else
    table[elementKey] <- [table[elementKey], elementValue]
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

let function _invoke_multi_array(multiArray, currentArray, currentIndex, invokeCallback) {
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


::showCurBonus <- function showCurBonus(obj, value, tooltipLocName = "", isDiscount = true, fullUpdate = false, tooltip = null) {
  if (!checkObj(obj))
    return

  local text = ""

  if ((isDiscount && value > 0) || (!isDiscount && value != 1)) {
    text = isDiscount ? "-" + value + "%" : "x" + stdMath.roundToDigits(value, 2)
    if (!tooltip && tooltipLocName != "") {
      let prefix = isDiscount ? "discount/" : "bonus/"
      tooltip = format(loc(prefix + tooltipLocName + "/tooltip"), value.tostring())
    }
  }

  if (text != "") {
    obj.setValue(text)
    if (tooltip)
      obj.tooltip = tooltip
  }
  else if (fullUpdate)
      obj.setValue("")
}

::hideBonus <- function hideBonus(obj) {
  if (checkObj(obj))
    obj.setValue("")
}

::showAirExpWpBonus <- function showAirExpWpBonus(obj, airName, showExp = true, showWp = true) {
  if (!obj)
    return

  local exp, wp = 1.0
  if (type(airName) == "string") {
    exp = showExp ? ::wp_shop_get_aircraft_xp_rate(airName) : 1.0
    wp = showWp ? ::wp_shop_get_aircraft_wp_rate(airName) : 1.0
  }
  else
    foreach (a in airName) {
      let aexp = showExp ? ::wp_shop_get_aircraft_xp_rate(a) : 1.0
      if (aexp > exp)
        exp = aexp
      let awp = showWp ? ::wp_shop_get_aircraft_wp_rate(a) : 1.0
      if (awp > wp)
        wp = awp
    }

  local bonusData = ::getBonus(exp, wp, "item", "Aircraft", airName)

  foreach (name, result in bonusData)
    obj[name] = result
}

::getBonus <- function getBonus(exp, wp, imgType, placeType = "", airName = "") {
  local imgColor = ""
  if (exp > 1.0)
    imgColor = (wp > 1.0) ? "wp_exp" : "exp"
  else
    imgColor = (wp > 1.0) ? "wp" : ""

  exp = stdMath.roundToDigits(exp, 2)
  wp = stdMath.roundToDigits(wp, 2)

  let multiplier = exp > wp ?  exp : wp
  let image = ::getBonusImage(imgType, multiplier, airName == "" ? "country" : "air")

  local tooltipText = ""
  let locEnd = (type(airName) == "string") ? "/tooltip" : "/group/tooltip"
  if (imgColor != "") {
    tooltipText += exp <= 1.0 ? "" : format(loc("bonus/" + (imgColor == "wp_exp" ? "exp" : imgColor) + imgType + placeType + "Mul" + locEnd), "x" + exp)
    if (wp > 1)
      tooltipText += ((tooltipText == "") ? "" : "\n") + format(loc("bonus/" + (imgColor == "wp_exp" ? "wp" : imgColor) + imgType + placeType + "Mul" + locEnd), "x" + wp)
  }

  local data = {
                 bonusType = imgColor
                 tooltip = tooltipText
               }
  data["background-image"] <- image

  return data
}

let function find_max_lower_value(val, list) {
  local res = null
  local found = false
  foreach (v in list) {
    if (v == val)
      return v

    if (v < val) {
      if (!found || v > res)
        res = v
      found = true
      continue
    }
    //v > val
    if (!found && (res == null || v < res))
      res = v
  }
  return res
}

::getBonusImage <- function getBonusImage(bType, multiplier, useBy) {
  if ((bType != "item" && bType != "country") || multiplier == 1.0)
    return ""

  let allowingMult = useBy == "country" ? allowingMultCountry : allowingMultAircraft

  multiplier = find_max_lower_value(multiplier, allowingMult)
  if (multiplier == null)
    return ""

  multiplier = ::stringReplace(multiplier.tostring(), ".", "_")
  return $"#ui/gameuiskin#{bType}_bonus_mult_{multiplier}"
}

::save_to_json <- function save_to_json(obj) {
  assert(isInArray(type(obj), [ "table", "array" ]),
    "Data type not suitable for save_to_json: " + type(obj))

  return json_to_string(obj, false)
}

::roman_numerals <- ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                         "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]

let get_roman_numeral_lookup = [
  "", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX",
  "", "X", "XX", "XXX", "XL", "L", "LX", "LXX", "LXXX", "XC",
  "", "C", "CC", "CCC", "CD", "D", "DC", "DCC", "DCCC", "CM",
]
const MAX_ROMAN_DIGIT = 3

//Function from http://blog.stevenlevithan.com/archives/javascript-roman-numeral-converter
::get_roman_numeral <- function get_roman_numeral(num) {
  if (!::is_numeric(num) || num < 0) {
    script_net_assert_once("get_roman_numeral", "get_roman_numeral(" + num + ")")
    return ""
  }

  num = num.tointeger()
  if (num >= 4000)
    return num.tostring()

  local thousands = ""
  for (local n = 0; n < num / 1000; n++)
    thousands += "M"

  local roman = ""
  local i = -1
  while (num > 0 && i++ < MAX_ROMAN_DIGIT) {
    let digit = num % 10
    num = num / 10
    roman = getTblValue(digit + (i * 10), get_roman_numeral_lookup, "") + roman
  }
  return thousands + roman
}


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
    if (::get_es_unit_type(air) != ES_UNIT_TYPE_AIRCRAFT)
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

::isProductionCircuit <- function isProductionCircuit() {
  return ::get_cur_circuit_name().indexof("production") != null
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
    let taskId = ::clan_request_sync_profile()
    ::add_bg_task_cb(taskId, function() {
      ::requestMyClanData(true)
      ::update_gamercards()
    })
  }
  else if (message == "clan_info_reload") {
    ::requestMyClanData(true)
    let myClanId = ::clan_get_my_clan_id()
    if (myClanId == "-1")
      ::sync_handler_simulate_request(message)
  }
  else if (message == "profile_reload") {
    let oldPenaltyStatus = penalty.getPenaltyStatus()
    let taskId = ::chard_request_profile()
    ::add_bg_task_cb(taskId, function() {
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

let function startCreateWndByGamemode(_handler, _obj) {
  let gm = ::match_search_gm
  if (gm == GM_EVENT)
    ::gui_start_briefing()
  else if (gm == GM_DYNAMIC)
    ::gui_start_dynamic_layouts()
  else if (gm == GM_BUILDER) {
    ::mission_settings.coop = true
    ::gui_start_builder()
  }
  else if (gm == GM_SINGLE_MISSION)
    ::gui_start_singleMissions()
  else if (gm == GM_USER_MISSION)
    ::gui_start_userMissions()
  else if (gm == GM_SKIRMISH)
    ::gui_create_skirmish()
  else if (gm == GM_DOMINATION || gm == GM_TOURNAMENT)
    ::gui_start_mislist()
  else //any coop - create dyncampaign
    ::gui_start_dynamic_layouts()
  //may be not actual with current hndler managment system
  //handler.guiScene.initCursor("%gui/cursor.blk", "normal")
  ::update_gamercards()
}

::checkAndCreateGamemodeWnd <- function checkAndCreateGamemodeWnd(handler, gm) {
  if (!::check_gamemode_pkg(gm))
    return

  handler.checkedNewFlight((@(handler, gm) function() {
    let tbl = ::build_check_table(null, gm)
    tbl.silent <- false
    if (::checkAllowed.bindenv(handler)(tbl)) {
      ::match_search_gm = gm
      startCreateWndByGamemode(handler, null)
    }
  })(handler, gm))
}

::flushExcessExpToUnit <- function flushExcessExpToUnit(unit) {
  let blk = DataBlock()
  blk.setStr("unit", unit)

  return ::char_send_blk("cln_move_exp_to_unit", blk)
}

::flushExcessExpToModule <- function flushExcessExpToModule(unit, module) {
  let blk = DataBlock()
  blk.setStr("unit", unit)
  blk.setStr("mod", module)

  return ::char_send_blk("cln_move_exp_to_module", blk)
}

::get_config_blk_paths <- function get_config_blk_paths() {
  // On PS4 path is "/app0/config.blk", but it is read-only.
  return {
    read  = (is_platform_pc) ? ::get_config_name() : null
    write = (is_platform_pc) ? ::get_config_name() : null
  }
}

::getSystemConfigOption <- function getSystemConfigOption(path, defVal = null) {
  let filename = ::get_config_blk_paths().read
  if (!filename)
    return defVal
  let blk = blkOptFromPath(filename)
  let val = get_blk_value_by_path(blk, path)
  return (val != null) ? val : defVal
}

::setSystemConfigOption <- function setSystemConfigOption(path, val) {
  let filename = ::get_config_blk_paths().write
  if (!filename)
    return
  let blk = blkOptFromPath(filename)
  if (set_blk_value_by_path(blk, path, val))
    blk.saveToTextFile(filename)
}

::quit_and_run_cmd <- function quit_and_run_cmd(cmd) {
  ::direct_launch(cmd); //FIXME: mac???
  ::exit_game();
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

::is_chinese_harmonized <- function is_chinese_harmonized() {
  return ::get_current_language() == "HChinese" //we need to check language too early when get_language from profile not work
}

::is_vietnamese_version <- function is_vietnamese_version() {
  return ::get_current_language() == "Vietnamese" //we need to check language too early when get_language from profile not work
}

::is_chinese_version <- function is_chinese_version() {
  let language = ::get_current_language()
  return language == "Chinese"
    || language == "TChinese"
    || language == "Korean"
}

::is_worldwar_enabled <- function is_worldwar_enabled() {
  return hasFeature("WorldWar")
    && ("g_world_war" in getroottable())
    && (!isPlatformSony || isCrossPlayEnabled())
}

::check_tanks_available <- function check_tanks_available(silent = false) {
  if (is_platform_pc && "is_tanks_allowed" in getroottable() && !::is_tanks_allowed()) {
    if (!silent)
      ::showInfoMsgBox(loc("mainmenu/graphics_card_does_not_support_tank"), "graphics_card_does_not_support_tanks")
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

::checkRemnantPremiumAccount <- function checkRemnantPremiumAccount() {
  if (!::g_login.isProfileReceived() || !hasFeature("EnablePremiumPurchase")
      || !hasFeature("SpendGold"))
    return

  let currDays = time.getUtcDays()
  let premAccName = ::shop_get_premium_account_ent_name()
  let expire = ::entitlement_expires_in(premAccName)
  if (expire > 0)
    ::saveLocalByAccount("premium/lastDayHavePremium", currDays)
  if (expire >= NOTIFY_EXPIRE_PREMIUM_ACCOUNT)
    return

  let lastDaysReminder = ::loadLocalByAccount("premium/lastDayBuyPremiumReminder", 0)
  if (lastDaysReminder == currDays)
    return

  let lastDaysHavePremium = ::loadLocalByAccount("premium/lastDayHavePremium", 0)
  local msgText = ""
  if (expire > 0)
    msgText = loc("msgbox/ending_premium_account")
  else if (lastDaysHavePremium != 0) {
    let deltaDaysReminder = currDays - lastDaysReminder
    let deltaDaysHavePremium = currDays - lastDaysHavePremium
    let gmBlk = ::get_game_settings_blk()
    let daysCounter = gmBlk?.reminderBuyPremiumDays ?? 7
    if (2 * deltaDaysReminder >= deltaDaysHavePremium || deltaDaysReminder >= daysCounter)
      msgText = loc("msgbox/ended_premium_account")
  }

  if (msgText != "") {
    ::saveLocalByAccount("premium/lastDayBuyPremiumReminder", currDays)
    ::scene_msg_box("no_premium", null,  msgText,
          [
            ["ok", @() ::OnlineShopModel.launchOnlineShop(null, "premium")],
            ["cancel", @() null ]
          ], "ok",
          { saved = true })
  }
}

local informTexQualityRestrictedDone = false
::informTexQualityRestricted <- function informTexQualityRestricted() {
  if (informTexQualityRestrictedDone)
    return
  let message = loc("msgbox/graphicsOptionValueReduced/lowVideoMemory", {
    name =  colorize("userlogColoredText", loc("options/texQuality"))
    value = colorize("userlogColoredText", loc("options/quality_medium"))
  })
  ::showInfoMsgBox(message, "sysopt_tex_quality_restricted")
  informTexQualityRestrictedDone = true
}

::is_myself_anyof_moderators <- function is_myself_anyof_moderators() {
  return ::is_myself_moderator() || ::is_myself_grand_moderator() || ::is_myself_chat_moderator()
}

::unlockCrew <- function unlockCrew(crewId, byGold, cost) {
  let blk = DataBlock()
  blk["crew"] = crewId
  blk["gold"] = byGold
  blk["cost"] = cost?.wp ?? 0
  blk["costGold"] = cost?.gold ?? 0

  return ::char_send_blk("cln_unlock_crew", blk)
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

::is_numeric <- function is_numeric(value) {
  local t = type(value)
  return t == "integer" || t == "float" || t == "int64"
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

::to_integer_safe <- function to_integer_safe(value, defValue = 0, needAssert = true) {
  if (!::is_numeric(value) && (!u.isString(value) || !isStringFloat(value))) {
    if (needAssert)
      script_net_assert_once("to_int_safe", $"can't convert '{value}' to integer")
    return defValue
  }
  return value.tointeger()
}

::to_float_safe <- function to_float_safe(value, defValue = 0, needAssert = true) {
  if (!::is_numeric(value)
    && (!u.isString(value) || !isStringFloat(value))) {
    if (needAssert)
      script_net_assert_once("to_float_safe", "can't convert '" + value + "' to float")
    return defValue
  }
  return value.tofloat()
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
    teamId == ::get_player_army_for_hud()
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
  ::showInfoMsgBox(loc("msgbox/notAvailbleYet"), "not_available", true)
}

::is_hangar_blur_available <- function is_hangar_blur_available() {
  return ("enable_dof" in getroottable())
}

::hangar_blur <- function hangar_blur(enable, params = null) {
  if (!::is_hangar_blur_available())
    return
  if (enable) {
    ::enable_dof(getTblValue("nearFrom",   params, 0), // meters
                 getTblValue("nearTo",     params, 0), // meters
                 getTblValue("nearEffect", params, 0), // 0..1
                 getTblValue("farFrom",    params, 0), // meters
                 getTblValue("farTo",      params, 0.1), // meters
                 getTblValue("farEffect",  params, 1)) // 0..1
  }
  else
    ::disable_dof()
}

::warningIfGold <- function warningIfGold(text, cost) {
  if ((cost?.gold ?? 0) > 0)
    text = colorize("@red", loc("shop/needMoneyQuestion_warning")) + "\n" + text
  return text
}
