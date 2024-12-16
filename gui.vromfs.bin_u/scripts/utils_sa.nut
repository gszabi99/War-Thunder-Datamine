from "%scripts/dagui_natives.nut" import is_myself_chat_moderator, get_player_army_for_hud, is_myself_grand_moderator, is_myself_moderator
from "%scripts/dagui_library.nut" import *

let { object_to_json_string } = require("json")
let DataBlock = require("DataBlock")
let { format } = require("string")
let { stripTags, cutPrefix } = require("%sqstd/string.nut")
let { rnd } = require("dagor.random")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { is_mplayer_host, is_mplayer_peer } = require("multiplayer")
let { get_game_type } = require("mission")
let u = require("%sqStdLibs/helpers/u.nut")
let { fabs } = require("math")

function getAmountAndMaxAmountText(amount, maxAmount, showMaxAmount = false) {
  let amountText = []
  if (maxAmount > 1 || showMaxAmount) {
    amountText.append(amount)
    if (showMaxAmount && maxAmount > 1)
      amountText.append("/", maxAmount)
  }
  return "".join(amountText)
}


function colorTextByValues(text, val1, val2, useNeutral = true, useGood = true) {
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


function get_flush_exp_text(exp_value) {
  if (exp_value == null || exp_value < 0)
    return ""
  let rpPriceText = "".concat(exp_value, loc("currency/researchPoints/sign/colored"))
  let coloredPriceText = colorTextByValues(rpPriceText, exp_value, 0)
  return format(loc("mainmenu/availableFreeExpForNewResearch"), coloredPriceText)
}

function getObjIdByPrefix(obj, prefix, idProp = "id") {
  if (!obj)
    return null
  let id = obj?[idProp]
  if (!id)
    return null

  return cutPrefix(id, prefix)
}

function array_to_blk(arr, id) {
  let blk = DataBlock()
  if (arr)
    foreach (v in arr)
      blk[id] <- v
  return blk
}

const PASSWORD_SYMBOLS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
function gen_rnd_password(charsAmount) {
  local res = ""
  let total = PASSWORD_SYMBOLS.len()
  for (local i = 0; i < charsAmount; i++)
    res = "".concat(res, PASSWORD_SYMBOLS[rnd() % total].tochar())
  return res
}

function get_bit_value_by_array(selValues, values) {
  local res = 0
  foreach (i, val in values)
    if (isInArray(val, selValues))
      res = res | (1 << i)
  return res
}

function get_array_by_bit_value(bitValue, values) {
  let res = []
  foreach (i, val in values)
    if (bitValue & (1 << i))
      res.append(val)
  return res
}

function save_to_json(obj) {
  assert(isInArray(type(obj), [ "table", "array" ]),
    $"Data type not suitable for save_to_json: {type(obj)}")

  return object_to_json_string(obj, false)
}

let roman_numerals = freeze(["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                         "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"])

let is_multiplayer = @() is_mplayer_host() || is_mplayer_peer()


function is_mode_with_teams(gt = null) {
  if (gt == null)
    gt = get_game_type()
  return !(gt & (GT_FFA_DEATHMATCH | GT_FFA))
}

function is_team_friendly(teamId) {
  return is_mode_with_teams() &&
    teamId == get_player_army_for_hud()
}

function get_team_color(teamId) {
  return is_team_friendly(teamId) ? "hudColorBlue" : "hudColorRed"
}

function get_mplayer_color(player) {
  return !player ? "" :
    player.isLocal ? "hudColorHero" :
    player.isInHeroSquad ? "hudColorSquad" :
    get_team_color(player.team)
}

function locOrStrip(text) {
  return (text.len() && text.slice(0, 1) != "#") ? stripTags(text) : text
}

function buildTableRow(rowName, rowData, even = null, trParams = "", _tablePad = "@tblPad") {
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
      id = getTblValue("id", cell,$"td_{idx}")
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


let buildTableRowNoPad = @(rowName, rowData, even = null, trParams = "") buildTableRow(rowName, rowData, even, trParams, "0")

function findNearest(val, arrayOfVal) {
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

let is_myself_anyof_moderators = @() is_myself_moderator() || is_myself_grand_moderator() || is_myself_chat_moderator()

function get_tomoe_unit_icon(iconName, isForGroup = false) {
  return $"!#ui/unitskin#tomoe_{iconName}{isForGroup ? "_group" : ""}.ddsx"
}

function check_aircraft_tags(airtags, filtertags) {
  local isNotFound = false
  for (local j = 0; j < filtertags.len(); j++) {
    if (u.find_in_array(airtags, filtertags[j]) < 0) {
      isNotFound = true
      break
    }
  }
  return !isNotFound
}

return {
  getAmountAndMaxAmountText
  colorTextByValues
  get_flush_exp_text
  getObjIdByPrefix
  array_to_blk
  get_array_by_bit_value
  get_bit_value_by_array
  roman_numerals
  gen_rnd_password
  save_to_json
  is_myself_anyof_moderators
  buildTableRow
  buildTableRowNoPad
  is_mode_with_teams
  is_multiplayer
  get_team_color
  get_mplayer_color
  locOrStrip
  findNearest
  is_team_friendly
  get_tomoe_unit_icon
  check_aircraft_tags
}