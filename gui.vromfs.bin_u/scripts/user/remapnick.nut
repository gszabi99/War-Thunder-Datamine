from "%appGlobals/user/nickTools.nut" import xboxPrefixNameRegexp, psnPrefixNameRegexp,
  xboxPostfixNameRegexp, psnPostfixNameRegexp, steamPostfixNameRegexp, epicPostfixNameRegexp,
  cutPlayerNamePrefix, cutPlayerNamePostfix, PSN_ICON
from "%scripts/user/nameMapping.nut" import getRealName, getFakeName
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_DISPLAY_MY_REAL_NICK
from "%scripts/user/profileStates.nut" import userName
from "%scripts/options/options.nut" import get_gui_option_in_mode
from "%sqstd/platform.nut" import isXbox, isSony, isPC
from "%scripts/dagui_library.nut" import *
from "types" import String

const PC_ICON = "⋆"
const TV_ICON = "⋇"
const NBSP = " " 

function remapNick(name) {
  if (!(name instanceof String) || name == "")
    return ""

  let isXboxPrefix = xboxPrefixNameRegexp.match(name)
  let isPsnPrefix = psnPrefixNameRegexp.match(name)
  let isMe = name == userName.get()

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

function getPlayerName(name) {
  if (name == userName.get() || getRealName(name) == userName.get()) { 
    if (!get_gui_option_in_mode(USEROPT_DISPLAY_MY_REAL_NICK, OPTIONS_MODE_GAMEPLAY, true))
      return loc("multiplayer/name")
  }

  return getFakeName(name) ?? remapNick(name)
}

return freeze({
  getPlayerName
})