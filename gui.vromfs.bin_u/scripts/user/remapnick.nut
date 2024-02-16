//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { xboxPrefixNameRegexp, psnPrefixNameRegexp, xboxPostfixNameRegexp,
  psnPostfixNameRegexp, steamPostfixNameRegexp, epicPostfixNameRegexp,
  cutPlayerNamePrefix, cutPlayerNamePostfix } = require("%scripts/user/nickTools.nut")
let { isXbox, isSony, isPC } = require("%sqstd/platform.nut")
let { getRealName, getFakeName } = require("%scripts/user/nameMapping.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_DISPLAY_MY_REAL_NICK } = require("%scripts/options/optionsExtNames.nut")
let { userName } = require("%scripts/user/profileStates.nut")

let PC_ICON = "⋆"
let TV_ICON = "⋇"
let PSN_ICON = "⋊"
let NBSP = " " // Non-breaking space character

let function remapNick(name) {
  if (type(name) != "string" || name == "")
    return ""

  let isXboxPrefix = xboxPrefixNameRegexp.match(name)
  let isPsnPrefix = psnPrefixNameRegexp.match(name)
  let isMe = name == userName.value

  if (isXboxPrefix || isPsnPrefix)
    name = cutPlayerNamePrefix(name)

  let isXboxPostfix = xboxPostfixNameRegexp.match(name)
  let isPsnPostfix = psnPostfixNameRegexp.match(name)
  let isSteamPostfix = steamPostfixNameRegexp.match(name)
  let isEpicPostfix = epicPostfixNameRegexp.match(name)

  if (isXboxPostfix || isPsnPostfix || isSteamPostfix || isEpicPostfix)
    name = cutPlayerNamePostfix(name)

  local platformIcon = ""

  if (isXboxPrefix || isXboxPostfix) {
    if (!isXbox)
      platformIcon = TV_ICON
  }
  else if (isPsnPrefix || isPsnPostfix) {
    if (!isSony)
      platformIcon = TV_ICON
    else if (!isMe)
      platformIcon = PSN_ICON
  }
  else if (!isPC)
    platformIcon = PC_ICON

  return NBSP.join([platformIcon, name], true)
}

let function getPlayerName(name) {
  if (name == userName.value || getRealName(name) == userName.value) { //local usage
    if (!::get_gui_option_in_mode(USEROPT_DISPLAY_MY_REAL_NICK, OPTIONS_MODE_GAMEPLAY, true))
      return loc("multiplayer/name")
  }

  return getFakeName(name) ?? remapNick(name)
}

return {
  getPlayerName
}