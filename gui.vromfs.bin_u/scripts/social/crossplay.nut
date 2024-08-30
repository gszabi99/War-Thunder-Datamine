//-file:plus-string
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[CROSSPLAY] ")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let { isPlatformSony, isPlatformXboxOne, isPlatformXboxScarlett, isPlatformPS4, isPlatformPS5 } = require("%scripts/clientState/platform.nut")
let { check_crossnetwork_communications_permission, CommunicationState } = require("%scripts/xbox/permissions.nut")
let { crossnetworkPrivilege } = require("%xboxLib/crossnetwork.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_PS4_ONLY_LEADERBOARD
} = require("%scripts/options/optionsExtNames.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")

let PS4_CROSSPLAY_OPT_ID = "ps4CrossPlay"
let PS4_CROSSNETWORK_CHAT_OPT_ID = "ps4CrossNetworkChat"

let crossNetworkPlayStatus = mkWatched(persist, "crossNetworkPlayStatus", null)
crossNetworkPlayStatus.subscribe(function(v) {
  logX($"Status updated -> {crossNetworkPlayStatus.value}")
  if (v) {
    logX("Broadcasting CrossPlayOptionChanged event")
    broadcastEvent("CrossPlayOptionChanged")
  }
})

if (isPlatformXboxOne) {
  logX("Registering for state change update")
  crossnetworkPrivilege.subscribe(function(v) {
    logX($"xboxLib.crossnetworkPrivilege updated -> {v}")
    if (crossNetworkPlayStatus.value != v)
      crossNetworkPlayStatus.update(v)
    else
      crossNetworkPlayStatus.trigger()
  })
  crossNetworkPlayStatus.update(crossnetworkPrivilege.value)
}

let crossNetworkChatStatus = mkWatched(persist, "crossNetworkChatStatus", null)

let resetCrossPlayStatus = @() crossNetworkPlayStatus(null)
let resetCrossNetworkChatStatus = @() crossNetworkChatStatus(null)

let updateCrossNetworkPlayStatus = function(needOverrideValue = false) {
  if (isPlatformXboxOne)
    return

  if (!needOverrideValue && crossNetworkPlayStatus.value != null)
    return

  if (isPlatformSony && hasFeature("PS4CrossNetwork") && ::g_login.isProfileReceived())
    crossNetworkPlayStatus(loadLocalAccountSettings(PS4_CROSSPLAY_OPT_ID, true))
  else
    crossNetworkPlayStatus(true)
}

let isCrossNetworkPlayEnabled = function() {
  if (!isPlatformXboxOne)
    updateCrossNetworkPlayStatus()
  return crossNetworkPlayStatus.value
}

let setCrossNetworkPlayStatus = function(val) {
  if (!isPlatformSony || !hasFeature("PS4CrossNetwork"))
    return

  resetCrossPlayStatus()
  saveLocalAccountSettings(PS4_CROSSPLAY_OPT_ID, val)
  updateCrossNetworkPlayStatus()
}

let updateCrossNetworkChatStatus = function(needOverrideValue = false) {
  if (!needOverrideValue && crossNetworkChatStatus.value != null)
    return

  if (isPlatformXboxOne)
    crossNetworkChatStatus(check_crossnetwork_communications_permission())
  else if (isPlatformSony && hasFeature("PS4CrossNetwork") && ::g_login.isProfileReceived())
    crossNetworkChatStatus(loadLocalAccountSettings(PS4_CROSSNETWORK_CHAT_OPT_ID, CommunicationState.Allowed))
  else
    crossNetworkChatStatus(CommunicationState.Allowed)
}

let getCrossNetworkChatStatus = function() {
  updateCrossNetworkChatStatus()
  return crossNetworkChatStatus.value
}

let isCrossNetworkChatEnabled = @() getCrossNetworkChatStatus() == CommunicationState.Allowed

let setCrossNetworkChatStatus = function(boolVal) {
  if (!isPlatformSony || !hasFeature("PS4CrossNetwork"))
    return

  let val = boolVal ? CommunicationState.Allowed : CommunicationState.Blocked
  resetCrossNetworkChatStatus()
  saveLocalAccountSettings(PS4_CROSSNETWORK_CHAT_OPT_ID, val)
  updateCrossNetworkChatStatus()
}

let getTextWithCrossplayIcon = @(addIcon, text) (addIcon ? (loc("icon/cross_play") + " ") : "") + text

let getSeparateLeaderboardPlatformValue = function() {
  if (hasFeature("ConsoleSeparateLeaderboards")) {
    if (isPlatformSony)
      return ::get_gui_option_in_mode(USEROPT_PS4_ONLY_LEADERBOARD, OPTIONS_MODE_GAMEPLAY) == true

    if (isPlatformXboxOne)
      return !isCrossNetworkPlayEnabled()
  }

  return false
}

let getSeparateLeaderboardPlatformName = function() {
  // These names are set in config on leaderboard server.
  if (getSeparateLeaderboardPlatformValue()) {
    if (isPlatformPS4 || isPlatformPS5)
      return "ps4"      // TODO: Change later to 'psn' or 'sony'
    if (isPlatformXboxOne || isPlatformXboxScarlett)
      return "xboxone"  // TODO: Change later to 'xbox' or 'ms'
  }
  return ""
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

return {
  isCrossPlayEnabled = isCrossNetworkPlayEnabled
  setCrossPlayStatus = setCrossNetworkPlayStatus
  crossNetworkPlayStatus
  needShowCrossPlayInfo = @() isPlatformXboxOne

  getCrossNetworkChatStatus = getCrossNetworkChatStatus
  setCrossNetworkChatStatus = setCrossNetworkChatStatus
  isCrossNetworkChatEnabled = isCrossNetworkChatEnabled
  getTextWithCrossplayIcon = getTextWithCrossplayIcon

  getSeparateLeaderboardPlatformName = getSeparateLeaderboardPlatformName
  getSeparateLeaderboardPlatformValue = getSeparateLeaderboardPlatformValue
}