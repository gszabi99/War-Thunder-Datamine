//checked for plus_string
from "%scripts/dagui_natives.nut" import ps4_show_chat_restriction, gchat_is_voice_enabled, gchat_is_enabled, can_use_text_chat_with_target, ps4_is_chat_enabled
from "%scripts/dagui_library.nut" import *

let platformModule = require("%scripts/clientState/platform.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { hasChat } = require("%scripts/user/matchingFeature.nut")
let { isGuestLogin } = require("%scripts/user/userUtils.nut")

local xboxChatEnabledCache = null
let function getXboxChatEnableStatus(needOverlayMessage = false) {
  if (!is_platform_xbox || !::g_login.isLoggedIn())
    return XBOX_COMMUNICATIONS_ALLOWED

  if (xboxChatEnabledCache == null || (needOverlayMessage && xboxChatEnabledCache == XBOX_COMMUNICATIONS_BLOCKED))
    xboxChatEnabledCache = can_use_text_chat_with_target("", needOverlayMessage) //myself, block by parent advisory
  return xboxChatEnabledCache
}

let function isChatEnabled(needOverlayMessage = false) {
  if (!gchat_is_enabled())
    return false

  if (!ps4_is_chat_enabled()) {
    if (needOverlayMessage)
      ps4_show_chat_restriction()
    return false
  }
  return getXboxChatEnableStatus(needOverlayMessage) != XBOX_COMMUNICATIONS_BLOCKED
}

let function isCrossNetworkMessageAllowed(playerName) {
  if (platformModule.isPlayerFromXboxOne(playerName)
      || platformModule.isPlayerFromPS4(playerName))
    return true

  let crossnetStatus = crossplayModule.getCrossNetworkChatStatus()
  if (crossnetStatus == XBOX_COMMUNICATIONS_ONLY_FRIENDS
    && (::isPlayerInFriendsGroup(null, false, playerName)))
    return true

  return crossnetStatus == XBOX_COMMUNICATIONS_ALLOWED
}

let function isChatEnableWithPlayer(playerName) { //when you have contact, you can use direct contact.canInteract
  let contact = ::Contact.getByName(playerName)
  if (contact)
    return contact.canChat()

  if (getXboxChatEnableStatus(false) == XBOX_COMMUNICATIONS_ONLY_FRIENDS)
    return ::isPlayerInFriendsGroup(null, false, playerName)

  if (!isCrossNetworkMessageAllowed(playerName))
    return false

  return isChatEnabled()
}

let function attemptShowOverlayMessage(playerName, needCheckInvite = false) { //tries to display Xbox overlay message
  let contact = ::Contact.getByName(playerName)
  if (contact) {
    if (needCheckInvite)
      contact.canInvite(true)
    else
      contact.canChat(true)
  }
  else
    getXboxChatEnableStatus(true)
}

let function invalidateCache() {
  xboxChatEnabledCache = null
}

let function canUseVoice() {
  return hasFeature("Voice") && gchat_is_voice_enabled()
}

let hasMenuChat = Computed(@() hasChat.value && !isGuestLogin.value)

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
})

return {
  getXboxChatEnableStatus = getXboxChatEnableStatus
  isChatEnabled = isChatEnabled
  isChatEnableWithPlayer = isChatEnableWithPlayer
  attemptShowOverlayMessage = attemptShowOverlayMessage
  isCrossNetworkMessageAllowed = isCrossNetworkMessageAllowed
  chatStatesCanUseVoice = canUseVoice
  hasMenuChat
}
