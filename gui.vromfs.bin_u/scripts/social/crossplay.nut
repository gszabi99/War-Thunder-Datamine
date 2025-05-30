from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[CROSSPLAY] ")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let { isPlatformSony, isPlatformXbox, isPlatformXboxScarlett, isPlatformPS4, isPlatformPS5 } = require("%scripts/clientState/platform.nut")
let { check_crossnetwork_communications_permission, CommunicationState } = require("%scripts/gdk/permissions.nut")
let { crossnetworkPrivilege } = require("%gdkLib/crossnetwork.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_PS4_ONLY_LEADERBOARD
} = require("%scripts/options/optionsExtNames.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")

let PS4_CROSSPLAY_OPT_ID = "ps4CrossPlay"
let PS4_CROSSNETWORK_CHAT_OPT_ID = "ps4CrossNetworkChat"

let crossNetworkPlayStatus = mkWatched(persist, "crossNetworkPlayStatus", null)
crossNetworkPlayStatus.subscribe(function(v) {
  logX($"Status updated -> {v}")
  if (v != null)
    broadcastEvent("CrossPlayOptionChanged")
})

if (is_gdk) {
  logX("Registering for state change update")
  crossnetworkPrivilege.subscribe(function(v) {
    logX($"gdkLib.crossnetworkPrivilege updated -> {v}")
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
  if (is_gdk)
    return

  if (!needOverrideValue && crossNetworkPlayStatus.value != null)
    return

  if (isPlatformSony && hasFeature("PS4CrossNetwork") && isProfileReceived.get())
    crossNetworkPlayStatus(loadLocalAccountSettings(PS4_CROSSPLAY_OPT_ID, true))
  else
    crossNetworkPlayStatus(true)
}

let isCrossNetworkPlayEnabled = function() {
  if (!is_gdk)
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
  if (!is_gdk && !needOverrideValue && crossNetworkChatStatus.value != null)
    return

  if (is_gdk)
    crossNetworkChatStatus(check_crossnetwork_communications_permission())
  else if (isPlatformSony && hasFeature("PS4CrossNetwork") && isProfileReceived.get())
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

let getTextWithCrossplayIcon = @(addIcon, text) addIcon ? $"{loc("icon/cross_play")} {text}" : text

let getSeparateLeaderboardPlatformValue = function() {
  if (hasFeature("ConsoleSeparateLeaderboards")) {
    if (isPlatformSony)
      return get_gui_option_in_mode(USEROPT_PS4_ONLY_LEADERBOARD, OPTIONS_MODE_GAMEPLAY) == true

    if (isPlatformXbox)
      return !isCrossNetworkPlayEnabled()
  }

  return false
}

let getSeparateLeaderboardPlatformName = function() {
  
  if (getSeparateLeaderboardPlatformValue()) {
    if (isPlatformPS4 || isPlatformPS5)
      return "ps4"      
    if (isPlatformXbox || isPlatformXboxScarlett)
      return "xboxone"  
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
  crossNetworkChatStatus
  needShowCrossPlayInfo = @() is_gdk

  getCrossNetworkChatStatus = getCrossNetworkChatStatus
  setCrossNetworkChatStatus = setCrossNetworkChatStatus
  isCrossNetworkChatEnabled = isCrossNetworkChatEnabled
  getTextWithCrossplayIcon = getTextWithCrossplayIcon

  getSeparateLeaderboardPlatformName = getSeparateLeaderboardPlatformName
  getSeparateLeaderboardPlatformValue = getSeparateLeaderboardPlatformValue
}