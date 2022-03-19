local {
  platformId,
  isXboxScarlett,
  isXbox,
  isPS4,
  isPS5,
  isSony,
  isPC,
  is_console,
  consoleRevision } = require("std/platform.nut")

local {
  isXBoxPlayerName,
  isPS4PlayerName,
  cutPlayerNamePrefix, //TODO: Uses in single place,
  cutPlayerNamePostfix //TODO: better to refactor
} = require("scripts/user/nickTools.nut")

local remapNick = require("scripts/user/remapNick.nut")

local PS4_REGION_NAMES = {
  [::SCE_REGION_SCEE]  = "scee",
  [::SCE_REGION_SCEA]  = "scea",
  [::SCE_REGION_SCEJ]  = "scej"
}

local getPlayerName = function(name)
{
  if (name == ::my_user_name)
  {
    local replaceName = ::get_gui_option_in_mode(::USEROPT_REPLACE_MY_NICK_LOCAL, ::OPTIONS_MODE_GAMEPLAY, "")
    if (replaceName != "")
      return replaceName
  }

  return remapNick(name)
}

local isPlayerFromXboxOne = @(name) isXbox && isXBoxPlayerName(name)
local isPlayerFromPS4 = @(name) isSony && isPS4PlayerName(name)

local isMePS4Player = @() ::get_player_tags().indexof("ps4") != null
local isMeXBOXPlayer = @() ::get_player_tags().indexof("xbone") != null

local canSpendRealMoney = @() !isPC || (!::has_entitlement("XBOXAccount") && !::has_entitlement("PSNAccount"))

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

  if (!isXBOXPlayer && (isPC || isSony))
    return true

  if ((isPS4Player && isSony) || (isXBOXPlayer && isXbox))
    return true

  if (!isPs4XboxOneInteractionAvailable(name))
    return false

  return ::has_feature("XboxCrossConsoleInteraction")
}

return {
  targetPlatform = platformId
  consoleRevision
  isPlatformXboxOne = isXbox //TODO: rename isPlatformXboxOne to isXbox, as it is all xboxes
  isPlatformXboxScarlett = isXboxScarlett
  isPlatformPS4 = isPS4
  isPlatformPS5 = isPS5
  isPlatformSony = isSony
  isPlatformPC = isPC
  is_console

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
