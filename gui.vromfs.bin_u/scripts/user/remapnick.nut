local {
  xboxPrefixNameRegexp,
  psnPrefixNameRegexp,
  xboxPostfixNameRegexp,
  psnPostfixNameRegexp,
  steamPostfixNameRegexp,
  epicPostfixNameRegexp,
  cutPlayerNamePrefix,
  cutPlayerNamePostfix } = require("scripts/user/nickTools.nut")

local {
  isXbox,
  isSony,
  isPC } = require("std/platform.nut")

local PC_ICON = "⋆"
local TV_ICON = "⋇"
local NBSP = " " // Non-breaking space character

return function(name) {
  if (typeof name != "string" || name == "")
    return ""

  local isXboxPrefix = xboxPrefixNameRegexp.match(name)
  local isPsnPrefix = psnPrefixNameRegexp.match(name)

  if (isXboxPrefix || isPsnPrefix)
    name = cutPlayerNamePrefix(name)

  local isXboxPostfix = xboxPostfixNameRegexp.match(name)
  local isPsnPostfix = psnPostfixNameRegexp.match(name)
  local isSteamPostfix = steamPostfixNameRegexp.match(name)
  local isEpicPostfix = epicPostfixNameRegexp.match(name)

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
  }
  else if (!isPC)
    platformIcon = PC_ICON

  return NBSP.join([platformIcon, name], true)
}