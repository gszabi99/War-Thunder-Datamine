from "%scripts/dagui_natives.nut" import ps4_show_chat_restriction, gchat_is_voice_enabled, gchat_is_enabled, ps4_is_chat_enabled
from "%scripts/dagui_library.nut" import *

let platformModule = require("%scripts/clientState/platform.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { hasChat } = require("%scripts/user/matchingFeature.nut")
let { isGuestLogin } = require("%scripts/user/profileStates.nut")
let { check_communications_privilege, check_crossnetwork_communications_permission } = require("%scripts/xbox/permissions.nut")
let { getContactByName } = require("%scripts/contacts/contactsManager.nut")

function getXboxChatEnableStatus() {
  if (!is_platform_xbox || !::g_login.isLoggedIn())
    return XBOX_COMMUNICATIONS_ALLOWED
  return check_crossnetwork_communications_permission()
}

function isChatEnabled(needOverlayMessage = false) {
  if (!gchat_is_enabled())
    return false

  if (!ps4_is_chat_enabled()) {
    if (needOverlayMessage)
      ps4_show_chat_restriction()
    return false
  }
  return getXboxChatEnableStatus() != XBOX_COMMUNICATIONS_BLOCKED
}

function isCrossNetworkMessageAllowed(playerName) {
  if (platformModule.isPlayerFromXboxOne(playerName)
      || platformModule.isPlayerFromPS4(playerName))
    return true

  let crossnetStatus = crossplayModule.getCrossNetworkChatStatus()
  if (crossnetStatus == XBOX_COMMUNICATIONS_ONLY_FRIENDS
    && (::isPlayerInFriendsGroup(null, false, playerName)))
    return true

  return crossnetStatus == XBOX_COMMUNICATIONS_ALLOWED
}

function isChatEnableWithPlayer(playerName) { //when you have contact, you can use direct contact.canInteract
  let contact = getContactByName(playerName)
  if (contact)
    return contact.canChat()

  if (getXboxChatEnableStatus() == XBOX_COMMUNICATIONS_ONLY_FRIENDS)
    return ::isPlayerInFriendsGroup(null, false, playerName)

  if (!isCrossNetworkMessageAllowed(playerName))
    return false

  return isChatEnabled()
}

function attemptShowOverlayMessage() { //tries to display Xbox overlay message
  check_communications_privilege(true, null)
}

function canUseVoice() {
  return hasFeature("Voice") && gchat_is_voice_enabled()
}

let hasMenuChat = Computed(@() hasChat.value && !isGuestLogin.value)

return {
  getXboxChatEnableStatus = getXboxChatEnableStatus
  isChatEnabled = isChatEnabled
  isChatEnableWithPlayer = isChatEnableWithPlayer
  attemptShowOverlayMessage = attemptShowOverlayMessage
  isCrossNetworkMessageAllowed = isCrossNetworkMessageAllowed
  chatStatesCanUseVoice = canUseVoice
  hasMenuChat
}
