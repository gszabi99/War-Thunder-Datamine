local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local { isPlatformSony, isPlatformXboxOne, isPlatformXboxScarlett, isPlatformPS4, isPlatformPS5 } = require("scripts/clientState/platform.nut")

local PS4_CROSSPLAY_OPT_ID = "ps4CrossPlay"
local PS4_CROSSNETWORK_CHAT_OPT_ID = "ps4CrossNetworkChat"

local crossNetworkPlayStatus = persist("crossNetworkPlayStatus", @() Watched(null))
crossNetworkPlayStatus.subscribe(@(v) v == null ? null : ::broadcastEvent("CrossPlayOptionChanged"))

local crossNetworkChatStatus = persist("crossNetworkChatStatus", @() Watched(null))

local resetCrossPlayStatus = @() crossNetworkPlayStatus(null)
local resetCrossNetworkChatStatus = @() crossNetworkChatStatus(null)

local updateCrossNetworkPlayStatus = function(needOverrideValue = false)
{
  if (!needOverrideValue && crossNetworkPlayStatus.value != null)
    return

  if (isPlatformXboxOne)
    crossNetworkPlayStatus(::check_crossnetwork_play_privilege())
  else if (isPlatformSony && ::has_feature("PS4CrossNetwork") && ::g_login.isProfileReceived())
    crossNetworkPlayStatus(::load_local_account_settings(PS4_CROSSPLAY_OPT_ID, true))
  else
    crossNetworkPlayStatus(true)
}

local isCrossNetworkPlayEnabled = function()
{
  updateCrossNetworkPlayStatus()
  return crossNetworkPlayStatus.value
}

local setCrossNetworkPlayStatus = function(val)
{
  if (!isPlatformSony || !::has_feature("PS4CrossNetwork"))
    return

  resetCrossPlayStatus()
  ::save_local_account_settings(PS4_CROSSPLAY_OPT_ID, val)
  updateCrossNetworkPlayStatus()
}

local updateCrossNetworkChatStatus = function(needOverrideValue = false)
{
  if (!needOverrideValue && crossNetworkChatStatus.value != null)
    return

  if (isPlatformXboxOne)
    crossNetworkChatStatus(::check_crossnetwork_communications_permission())
  else if (isPlatformSony && ::has_feature("PS4CrossNetwork") && ::g_login.isProfileReceived())
    crossNetworkChatStatus(::load_local_account_settings(PS4_CROSSNETWORK_CHAT_OPT_ID, XBOX_COMMUNICATIONS_ALLOWED))
  else
    crossNetworkChatStatus(XBOX_COMMUNICATIONS_ALLOWED)
}

local getCrossNetworkChatStatus = function()
{
  updateCrossNetworkChatStatus()
  return crossNetworkChatStatus.value
}

local isCrossNetworkChatEnabled = @() getCrossNetworkChatStatus() == XBOX_COMMUNICATIONS_ALLOWED

local setCrossNetworkChatStatus = function(boolVal)
{
  if (!isPlatformSony || !::has_feature("PS4CrossNetwork"))
    return

  local val = boolVal? XBOX_COMMUNICATIONS_ALLOWED : XBOX_COMMUNICATIONS_BLOCKED
  resetCrossNetworkChatStatus()
  ::save_local_account_settings(PS4_CROSSNETWORK_CHAT_OPT_ID, val)
  updateCrossNetworkChatStatus()
}

local getTextWithCrossplayIcon = @(addIcon, text) (addIcon? (::loc("icon/cross_play") + " " ) : "") + text

local getSeparateLeaderboardPlatformValue = function() {
  if (::has_feature("ConsoleSeparateLeaderboards"))
  {
    if (isPlatformSony)
      return ::get_gui_option_in_mode(::USEROPT_PS4_ONLY_LEADERBOARD, ::OPTIONS_MODE_GAMEPLAY) == true

    if (isPlatformXboxOne)
      return !isCrossNetworkPlayEnabled()
  }

  return false
}

local getSeparateLeaderboardPlatformName = function() {
  // These names are set in config on leaderboard server.
  if (getSeparateLeaderboardPlatformValue())
  {
    if (isPlatformPS4 || isPlatformPS5)
      return "ps4"      // TODO: Change later to 'psn' or 'sony'
    if (isPlatformXboxOne || isPlatformXboxScarlett)
      return "xboxone"  // TODO: Change later to 'xbox' or 'ms'
  }
  return ""
}

local invalidateCache = function()
{
  resetCrossPlayStatus()
  resetCrossNetworkChatStatus()
}

local function reinitCrossNetworkStatus() {
  updateCrossNetworkPlayStatus(true)
  updateCrossNetworkChatStatus(true)
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
  ProfileReceived = @(p) reinitCrossNetworkStatus()
  XboxMultiplayerPrivilegeUpdated = @(p) reinitCrossNetworkStatus()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  isCrossPlayEnabled = isCrossNetworkPlayEnabled
  setCrossPlayStatus = setCrossNetworkPlayStatus
  needShowCrossPlayInfo = @() isPlatformXboxOne

  getCrossNetworkChatStatus = getCrossNetworkChatStatus
  setCrossNetworkChatStatus = setCrossNetworkChatStatus
  isCrossNetworkChatEnabled = isCrossNetworkChatEnabled
  getTextWithCrossplayIcon = getTextWithCrossplayIcon

  getSeparateLeaderboardPlatformName = getSeparateLeaderboardPlatformName
  getSeparateLeaderboardPlatformValue = getSeparateLeaderboardPlatformValue
}