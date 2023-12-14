//checked for plus_string
from "%scripts/dagui_natives.nut" import ps4_get_region, has_entitlement
from "%scripts/dagui_library.nut" import *
let { get_player_tags } = require("auth_wt")
let {
  isXboxScarlett,
  isXbox,
  isPS4,
  isPS5,
  isSony,
  isPC,
  is_console,
  consoleRevision } = require("%sqstd/platform.nut")
let { is_running_on_steam_deck } = require("steam")
let {
  isXBoxPlayerName,
  isPS4PlayerName,
  cutPlayerNamePrefix, //TODO: Uses in single place,
  cutPlayerNamePostfix //TODO: better to refactor
} = require("%scripts/user/nickTools.nut")
let { getFromSettingsBlk } = require("%scripts/clientState/clientStates.nut")

let PS4_REGION_NAMES = {
  [SCE_REGION_SCEE]  = "scee",
  [SCE_REGION_SCEA]  = "scea",
  [SCE_REGION_SCEJ]  = "scej"
}

let isPlayerFromXboxOne = @(name) isXbox && isXBoxPlayerName(name)
let isPlayerFromPS4 = @(name) isSony && isPS4PlayerName(name)

let isMePS4Player = @() get_player_tags().indexof("ps4") != null
let isMeXBOXPlayer = @() get_player_tags().indexof("xbone") != null

let canSpendRealMoney = @() !isPC || (!has_entitlement("XBOXAccount") && !has_entitlement("PSNAccount"))

let isPs4XboxOneInteractionAvailable = function(name) {
  let isPS4Player = isPS4PlayerName(name)
  let isXBOXPlayer = isXBoxPlayerName(name)
  if (((isMePS4Player() && isXBOXPlayer) || (isMeXBOXPlayer() && isPS4Player)) && !hasFeature("Ps4XboxOneInteraction"))
    return false
  return true
}

let canInteractCrossConsole = function(name) {
  let isPS4Player = isPS4PlayerName(name)
  let isXBOXPlayer = isXBoxPlayerName(name)

  if (!isXBOXPlayer && (isPC || isSony))
    return true

  if ((isPS4Player && isSony) || (isXBOXPlayer && isXbox))
    return true

  if (!isPs4XboxOneInteractionAvailable(name))
    return false

  return hasFeature("XboxCrossConsoleInteraction")
}

let function isPlatformShieldTv() {
  return is_platform_android && getFromSettingsBlk("deviceType", "") == "shieldTv"
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
  isPlatformSteamDeck = is_running_on_steam_deck()
  is_console

  isXBoxPlayerName = isXBoxPlayerName
  isPS4PlayerName = isPS4PlayerName
  cutPlayerNamePrefix = cutPlayerNamePrefix
  cutPlayerNamePostfix = cutPlayerNamePostfix
  isPlayerFromXboxOne = isPlayerFromXboxOne
  isPlayerFromPS4 = isPlayerFromPS4

  isMePS4Player = isMePS4Player
  isMeXBOXPlayer = isMeXBOXPlayer

  canInteractCrossConsole = canInteractCrossConsole
  isPs4XboxOneInteractionAvailable = isPs4XboxOneInteractionAvailable

  canSpendRealMoney = canSpendRealMoney

  ps4RegionName = @() PS4_REGION_NAMES[ps4_get_region()]

  isPlatformShieldTv
}
