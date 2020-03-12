local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local PS4_CROSSPLAY_OPT_ID = "ps4CrossPlay"
local PS4_CROSSNETWORK_CHAT_OPT_ID = "ps4CrossNetworkChat"

local persistentData = {
  crossNetworkPlayStatus = null
  crossNetworkChatStatus = null
}

local resetCrossPlayStatus = @() persistentData.crossNetworkPlayStatus = null
local resetCrossNetworkChatStatus = @() persistentData.crossNetworkChatStatus = null

::g_script_reloader.registerPersistentData("crossplay", persistentData,
  ["crossNetworkPlayStatus", "crossNetworkChatStatus"])

local updateCrossNetworkPlayStatus = function()
{
  if (persistentData.crossNetworkPlayStatus != null)
    return

  persistentData.crossNetworkPlayStatus = true
  if (::is_platform_xboxone)
    persistentData.crossNetworkPlayStatus = ::check_crossnetwork_play_privilege()
  else if (::is_platform_ps4 && ::has_feature("PS4CrossNetwork"))
    persistentData.crossNetworkPlayStatus = ::load_local_account_settings(PS4_CROSSPLAY_OPT_ID, true)

  ::broadcastEvent("CrossPlayOptionChanged")
}

local isCrossNetworkPlayEnabled = function()
{
  updateCrossNetworkPlayStatus()
  return persistentData.crossNetworkPlayStatus
}

local setCrossNetworkPlayStatus = function(val)
{
  if (!::is_platform_ps4 || !::has_feature("PS4CrossNetwork"))
    return

  resetCrossPlayStatus()
  ::save_local_account_settings(PS4_CROSSPLAY_OPT_ID, val)
  updateCrossNetworkPlayStatus()
}

local updateCrossNetworkChatStatus = function()
{
  if (persistentData.crossNetworkChatStatus != null)
    return

  persistentData.crossNetworkChatStatus = XBOX_COMMUNICATIONS_ALLOWED
  if (::is_platform_xboxone)
    persistentData.crossNetworkChatStatus = ::check_crossnetwork_communications_permission()
  else if (::is_platform_ps4 && ::has_feature("PS4CrossNetwork"))
    persistentData.crossNetworkChatStatus = ::load_local_account_settings(PS4_CROSSNETWORK_CHAT_OPT_ID, XBOX_COMMUNICATIONS_ALLOWED)
}

local getCrossNetworkChatStatus = function()
{
  updateCrossNetworkChatStatus()
  return persistentData.crossNetworkChatStatus
}

local isCrossNetworkChatEnabled = @() getCrossNetworkChatStatus() == XBOX_COMMUNICATIONS_ALLOWED

local setCrossNetworkChatStatus = function(boolVal)
{
  if (!::is_platform_ps4 || !::has_feature("PS4CrossNetwork"))
    return

  local val = boolVal? XBOX_COMMUNICATIONS_ALLOWED : XBOX_COMMUNICATIONS_BLOCKED
  resetCrossNetworkChatStatus()
  ::save_local_account_settings(PS4_CROSSNETWORK_CHAT_OPT_ID, val)
  updateCrossNetworkChatStatus()
}

local getTextWithCrossplayIcon = @(addIcon, text) (addIcon? (::loc("icon/cross_play") + " " ) : "") + text

local invalidateCache = function()
{
  resetCrossPlayStatus()
  resetCrossNetworkChatStatus()
}

subscriptions.addListenersWithoutEnv({
  XboxSystemUIReturn = function(p) {
    invalidateCache()
    updateCrossNetworkPlayStatus()
    updateCrossNetworkChatStatus()
  }
  SignOut = @(p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  isCrossPlayEnabled = isCrossNetworkPlayEnabled
  setCrossPlayStatus = setCrossNetworkPlayStatus
  needShowCrossPlayInfo = @() ::is_platform_xboxone || (::is_platform_ps4 && ::has_feature("PS4CrossNetwork"))

  getCrossNetworkChatStatus = getCrossNetworkChatStatus
  setCrossNetworkChatStatus = setCrossNetworkChatStatus
  isCrossNetworkChatEnabled = isCrossNetworkChatEnabled
  getTextWithCrossplayIcon = getTextWithCrossplayIcon
}