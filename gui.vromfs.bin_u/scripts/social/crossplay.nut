import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
from "%sqstd/platform.nut" import is_gdk, isSony, isXbox, isXboxScarlett, isPS4, isPS5, isPC
from "%appGlobals/user/nickTools.nut" import isXBoxPlayerName, isPS4PlayerName
from "%scripts/gdk/permissions.nut" import check_crossnetwork_communications_permission, CommunicationState
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_PS4_ONLY_LEADERBOARD
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/options/options.nut" import get_gui_option_in_mode
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "%gdkLib/crossnetwork.nut" import crossnetworkPrivilege
from "%scripts/dagui_library.nut" import *
from "%appGlobals/clientState/platform.nut" import isMeXBOXPlayer, isMePS4Player

let logX = require("%sqstd/log.nut")().with_prefix("[CROSSPLAY] ")
let { broadcastEvent } = subscriptions

const PS4_CROSSPLAY_OPT_ID = "ps4CrossPlay"
const PS4_CROSSNETWORK_CHAT_OPT_ID = "ps4CrossNetworkChat"

let crossNetworkPlayStatus = Watched(null)
crossNetworkPlayStatus.subscribe(function(v) {
  logX($"Status updated -> {v}")
  if (v != null)
    broadcastEvent("CrossPlayOptionChanged")
})

if (is_gdk) {
  logX("Registering for state change update")
  crossnetworkPrivilege.subscribe(function(v) {
    logX($"gdkLib.crossnetworkPrivilege updated -> {v}")
    if (crossNetworkPlayStatus.get() != v)
      crossNetworkPlayStatus.set(v)
    else
      crossNetworkPlayStatus.trigger()
  })
  crossNetworkPlayStatus.set(crossnetworkPrivilege.get())
}

let crossNetworkChatStatus = Watched(null)

let resetCrossPlayStatus = @() crossNetworkPlayStatus.set(null)
let resetCrossNetworkChatStatus = @() crossNetworkChatStatus.set(null)

let updateCrossNetworkPlayStatus = function(needOverrideValue = false) {
  if (is_gdk)
    return

  if (!needOverrideValue && crossNetworkPlayStatus.get() != null)
    return

  if (isSony && hasFeature("PS4CrossNetwork") && isProfileReceived.get())
    crossNetworkPlayStatus.set(loadLocalAccountSettings(PS4_CROSSPLAY_OPT_ID, true))
  else
    crossNetworkPlayStatus.set(true)
}

let isCrossNetworkPlayEnabled = function() {
  if (!is_gdk)
    updateCrossNetworkPlayStatus()
  return crossNetworkPlayStatus.get()
}

let setCrossNetworkPlayStatus = function(val) {
  if (!isSony || !hasFeature("PS4CrossNetwork"))
    return

  resetCrossPlayStatus()
  saveLocalAccountSettings(PS4_CROSSPLAY_OPT_ID, val)
  updateCrossNetworkPlayStatus()
}

let updateCrossNetworkChatStatus = function(needOverrideValue = false) {
  if (!is_gdk && !needOverrideValue && crossNetworkChatStatus.get() != null)
    return

  if (is_gdk)
    crossNetworkChatStatus.set(check_crossnetwork_communications_permission())
  else if (isSony && hasFeature("PS4CrossNetwork") && isProfileReceived.get())
    crossNetworkChatStatus.set(loadLocalAccountSettings(PS4_CROSSNETWORK_CHAT_OPT_ID, CommunicationState.Allowed))
  else
    crossNetworkChatStatus.set(CommunicationState.Allowed)
}

let getCrossNetworkChatStatus = function() {
  updateCrossNetworkChatStatus()
  return crossNetworkChatStatus.get()
}

let isCrossNetworkChatEnabled = @() getCrossNetworkChatStatus() == CommunicationState.Allowed

let setCrossNetworkChatStatus = function(boolVal) {
  if (!isSony || !hasFeature("PS4CrossNetwork"))
    return

  let val = boolVal ? CommunicationState.Allowed : CommunicationState.Blocked
  resetCrossNetworkChatStatus()
  saveLocalAccountSettings(PS4_CROSSNETWORK_CHAT_OPT_ID, val)
  updateCrossNetworkChatStatus()
}

let getTextWithCrossplayIcon = @(addIcon, text) addIcon ? $"{loc("icon/cross_play")} {text}" : text

let getSeparateLeaderboardPlatformValue = function() {
  if (hasFeature("ConsoleSeparateLeaderboards")) {
    if (isSony)
      return get_gui_option_in_mode(USEROPT_PS4_ONLY_LEADERBOARD, OPTIONS_MODE_GAMEPLAY) == true

    if (isXbox)
      return !isCrossNetworkPlayEnabled()
  }

  return false
}

let getSeparateLeaderboardPlatformName = function() {
  
  if (getSeparateLeaderboardPlatformValue()) {
    if (isPS4 || isPS5)
      return "ps4"      
    if (isXbox || isXboxScarlett)
      return "xboxone"  
  }
  return ""
}

function isPs4XboxOneInteractionAvailable(name) {
  let isPS4Player = isPS4PlayerName(name)
  let isXBOXPlayer = isXBoxPlayerName(name)
  if (((isMePS4Player() && isXBOXPlayer) || (isMeXBOXPlayer() && isPS4Player)) && !hasFeature("Ps4XboxOneInteraction"))
    return false
  return true
}

function canInteractCrossConsole(name) {
  let isPS4Player = isPS4PlayerName(name)
  let isXBOXPlayer = isXBoxPlayerName(name)

  if (!isXBOXPlayer && (isPC || isSony))
    return true

  if ((isPS4Player && isSony) || (isXBOXPlayer && is_gdk))
    return true

  if (!isPs4XboxOneInteractionAvailable(name))
    return false

  return hasFeature("XboxCrossConsoleInteraction")
}

let invalidateCache = function() {
  resetCrossPlayStatus()
  resetCrossNetworkChatStatus()
}

function reinitCrossNetworkStatus() {
  updateCrossNetworkPlayStatus(true)
  updateCrossNetworkChatStatus(true)
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
  LoginComplete = @(_p) reinitCrossNetworkStatus()
  XboxMultiplayerPrivilegeUpdated = @(_) reinitCrossNetworkStatus()
}, g_listener_priority.CONFIG_VALIDATION)

return freeze({
  isCrossPlayEnabled = isCrossNetworkPlayEnabled
  setCrossPlayStatus = setCrossNetworkPlayStatus
  crossNetworkPlayStatus
  crossNetworkChatStatus
  needShowCrossPlayInfo = @() is_gdk

  getCrossNetworkChatStatus = getCrossNetworkChatStatus
  setCrossNetworkChatStatus = setCrossNetworkChatStatus
  isCrossNetworkChatEnabled = isCrossNetworkChatEnabled
  getTextWithCrossplayIcon = getTextWithCrossplayIcon

  getSeparateLeaderboardPlatformName = getSeparateLeaderboardPlatformName
  getSeparateLeaderboardPlatformValue = getSeparateLeaderboardPlatformValue

  isPs4XboxOneInteractionAvailable
  canInteractCrossConsole
})
