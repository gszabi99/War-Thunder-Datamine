local string = require("std/string.nut")

local PC_ICON = ::loc("icon/pc")
local TV_ICON = ::loc("icon/tv")

local STEAM_PLAYER_POSTFIX = "@steam"

local XBOX_ONE_PLAYER_PREFIX = "^"
local XBOX_ONE_PLAYER_POSTFIX = "@live"

local PS4_PLAYER_PREFIX = "*"
local PS4_PLAYER_POSTFIX = "@psn"
local PS4_REGION_NAMES = {
  [::SCE_REGION_SCEE]  = "scee",
  [::SCE_REGION_SCEA]  = "scea",
  [::SCE_REGION_SCEJ]  = "scej"
}

local targetPlatform = ::get_platform()
local isPlatformXboxOne = targetPlatform == "xboxOne"
local isPlatformPS4 = targetPlatform == "ps4"
local isPlatformPC = ["win32", "win64", "macosx", "linux64"].indexof(targetPlatform) != null

local xboxPrefixNameRegexp = ::regexp2($"^['{XBOX_ONE_PLAYER_PREFIX}']")
local xboxPostfixNameRegexp = ::regexp2($".+({XBOX_ONE_PLAYER_POSTFIX})")
local isXBoxPlayerName = @(name) xboxPrefixNameRegexp.match(name) || xboxPostfixNameRegexp.match(name)

local ps4PrefixNameRegexp = ::regexp2($"^['{PS4_PLAYER_PREFIX}']")
local ps4PostfixNameRegexp = ::regexp2($".+({PS4_PLAYER_POSTFIX})")
local isPS4PlayerName = @(name) ps4PrefixNameRegexp.match(name) || ps4PostfixNameRegexp.match(name)

local steamPostfixNameRegexp = ::regexp2($".+({STEAM_PLAYER_POSTFIX})")

local cutPlayerNamePrefix = @(name) string.cutPrefix(name, PS4_PLAYER_PREFIX,
                                    string.cutPrefix(name, XBOX_ONE_PLAYER_PREFIX, name))
local cutPlayerNamePostfix = @(name) string.cutPostfix(name, PS4_PLAYER_POSTFIX,
                                     string.cutPostfix(name, XBOX_ONE_PLAYER_POSTFIX,
                                     string.cutPostfix(name, STEAM_PLAYER_POSTFIX, name)))

local addPlatformIcon = function(name)
{
  local isXboxPrefix = xboxPrefixNameRegexp.match(name)
  local isPs4Prefix = ps4PrefixNameRegexp.match(name)

  if (isXboxPrefix || isPs4Prefix)
    name = cutPlayerNamePrefix(name)

  local isXboxPostfix = xboxPostfixNameRegexp.match(name)
  local isPs4Postfix = ps4PostfixNameRegexp.match(name)
  local isSteamPostfix = steamPostfixNameRegexp.match(name)

  if (isXboxPostfix || isPs4Postfix || isSteamPostfix)
    name = cutPlayerNamePostfix(name)

  local platformIcon = ""

  if (isXboxPrefix || isXboxPostfix)
  {
    if (!isPlatformXboxOne)
      platformIcon = TV_ICON
  }
  else if (isPs4Prefix || isPs4Postfix)
  {
    if (!isPlatformPS4)
      platformIcon = TV_ICON
  }
  else if (!isPlatformPC)
    platformIcon = PC_ICON

  return ::nbsp.join([platformIcon, name], true)
}

local getPlayerName = function(name)
{
  if (name == ::my_user_name)
  {
    local replaceName = ::get_gui_option_in_mode(::USEROPT_REPLACE_MY_NICK_LOCAL, ::OPTIONS_MODE_GAMEPLAY, "")
    if (replaceName != "")
      return replaceName
  }

  return addPlatformIcon(name)
}

local isPlayerFromXboxOne = @(name) isPlatformXboxOne && isXBoxPlayerName(name)
local isPlayerFromPS4 = @(name) isPlatformPS4 && isPS4PlayerName(name)

local isMePS4Player = @() ::g_user_utils.haveTag("ps4")
local isMeXBOXPlayer = @() ::g_user_utils.haveTag("xbone")

local canSpendRealMoney = @() !isPlatformPC || (!::has_entitlement("XBOXAccount") && !::has_entitlement("PSNAccount"))

local isPs4XboxOneInteractionAvailable = function(name)
{
  local isPS4Player = isPS4PlayerName(name)
  local isXBOXPlayer = isXBoxPlayerName(name)
  if (((isMePS4Player() && isXBOXPlayer) || (isMeXBOXPlayer() && isPS4Player)) && !::has_feature("Ps4XboxOneInteraction"))
    return false
  return true
}

local canInteractCrossConsole = function(name) {
  local isPS4Player = isPS4PlayerName(name)
  local isXBOXPlayer = isXBoxPlayerName(name)

  if (!isXBOXPlayer && (isPlatformPC || isPlatformPS4))
    return true

  if ((isPS4Player && isPlatformPS4) || (isXBOXPlayer && isPlatformXboxOne))
    return true

  if (!isPs4XboxOneInteractionAvailable(name))
    return false

  return ::has_feature("XboxCrossConsoleInteraction")
}

return {
  targetPlatform = targetPlatform
  isPlatformXboxOne = isPlatformXboxOne
  isPlatformPS4 = isPlatformPS4
  isPlatformPC = isPlatformPC

  isXBoxPlayerName = isXBoxPlayerName
  isPS4PlayerName = isPS4PlayerName
  getPlayerName = getPlayerName
  cutPlayerNamePrefix = cutPlayerNamePrefix
  cutPlayerNamePostfix = cutPlayerNamePostfix
  isPlayerFromXboxOne = isPlayerFromXboxOne
  isPlayerFromPS4 = isPlayerFromPS4

  isMePS4Player = isMePS4Player
  isMeXBOXPlayer = isMeXBOXPlayer

  canInteractCrossConsole = canInteractCrossConsole
  isPs4XboxOneInteractionAvailable = isPs4XboxOneInteractionAvailable

  canSpendRealMoney = canSpendRealMoney

  ps4RegionName = @() PS4_REGION_NAMES[::ps4_get_region()]
}
