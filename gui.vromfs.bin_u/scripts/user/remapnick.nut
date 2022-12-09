from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let {
  xboxPrefixNameRegexp,
  psnPrefixNameRegexp,
  xboxPostfixNameRegexp,
  psnPostfixNameRegexp,
  steamPostfixNameRegexp,
  epicPostfixNameRegexp,
  cutPlayerNamePrefix,
  cutPlayerNamePostfix } = require("%scripts/user/nickTools.nut")

let {
  isXbox,
  isSony,
  isPC } = require("%sqstd/platform.nut")

let PC_ICON = "⋆"
let TV_ICON = "⋇"
local NBSP = " " // Non-breaking space character

return function(name) {
  if (type(name) != "string" || name == "")
    return ""

  let isXboxPrefix = xboxPrefixNameRegexp.match(name)
  let isPsnPrefix = psnPrefixNameRegexp.match(name)
  let isMe = name == ::my_user_name

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
      platformIcon = "⋊"
  }
  else if (!isPC)
    platformIcon = PC_ICON

  return NBSP.join([platformIcon, name], true)
}