local platformModule = require("scripts/clientState/platform.nut")
local crossplayModule = require("scripts/social/crossplay.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local xboxChatEnabledCache = null
local function getXboxChatEnableStatus(needOverlayMessage = false) {
  if (!::is_platform_xboxone || !::g_login.isLoggedIn())
    return XBOX_COMMUNICATIONS_ALLOWED

  if (xboxChatEnabledCache == null || (needOverlayMessage && xboxChatEnabledCache == XBOX_COMMUNICATIONS_BLOCKED))
    xboxChatEnabledCache = ::can_use_text_chat_with_target("", needOverlayMessage)//myself, block by parent advisory
  return xboxChatEnabledCache
}

local function isChatEnabled(needOverlayMessage = false) {
  if (!::gchat_is_enabled())
    return false

  if (!::ps4_is_chat_enabled()) {
    if (needOverlayMessage)
      ::ps4_show_chat_restriction()
    return false
  }
  return getXboxChatEnableStatus(needOverlayMessage) != XBOX_COMMUNICATIONS_BLOCKED
}

local function isCrossNetworkMessageAllowed(playerName) {
  if (platformModule.isPlayerFromXboxOne(playerName)
      || platformModule.isPlayerFromPS4(playerName))
    return true

  local crossnetStatus = crossplayModule.getCrossNetworkChatStatus()

  if (crossnetStatus == XBOX_COMMUNICATIONS_ONLY_FRIENDS
    && (::isPlayerNickInContacts(playerName, ::EPL_FRIENDLIST)
      || ::isPlayerNickInContacts(playerName, ::EPLX_PS4_FRIENDS))
  )
    return true

  return crossnetStatus == XBOX_COMMUNICATIONS_ALLOWED
}

local function isChatEnableWithPlayer(playerName) { //when you have contact, you can use direct contact.canInteract
  local contact = ::Contact.getByName(playerName)
  if (contact)
    return contact.canChat()

  if (getXboxChatEnableStatus(false) == XBOX_COMMUNICATIONS_ONLY_FRIENDS)
    return ::isPlayerInFriendsGroup(null, false, playerName)

  if (!isCrossNetworkMessageAllowed(playerName))
    return false

  return isChatEnabled()
}

local function attemptShowOverlayMessage(playerName, needCheckInvite = false) { //tries to display Xbox overlay message
  local contact = ::Contact.getByName(playerName)
  if (contact)
  {
    if (needCheckInvite)
      contact.canInvite(true)
    else
      contact.canChat(true)
  }
  else
    getXboxChatEnableStatus(true)
}

local function invalidateCache() {
  xboxChatEnabledCache = null
}

local function canUseVoice() {
  return ::has_feature("Voice") && ::gchat_is_voice_enabled()
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
})

return {
  getXboxChatEnableStatus = getXboxChatEnableStatus
  isChatEnabled = isChatEnabled
  isChatEnableWithPlayer = isChatEnableWithPlayer
  attemptShowOverlayMessage = attemptShowOverlayMessage
  isCrossNetworkMessageAllowed = isCrossNetworkMessageAllowed
  chatStatesCanUseVoice = canUseVoice
}