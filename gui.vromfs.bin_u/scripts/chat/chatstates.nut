import "%scripts/social/crossplay.nut" as crossplayModule
from "%appGlobals/clientState/platform.nut" import isPlayerFromXboxOne, isPlayerFromPS4
from "%scripts/user/matchingFeature.nut" import hasChat
from "%scripts/user/profileStates.nut" import isGuestLogin
from "%scripts/gdk/permissions.nut" import check_crossnetwork_communications_permission, CommunicationState
from "%gdkLib/crossnetwork.nut" import communicationsPrivilege
from "%globalScripts/loc_helpers.nut" import locByVendor
from "%scripts/contacts/contactsListState.nut" import getContactByName
from "%scripts/contacts/contactsChecks.nut" import isPlayerInFriendsGroup
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "%sqstd/platform.nut" import is_gdk
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%scripts/dagui_natives.nut" import ps4_show_chat_restriction, gchat_is_voice_enabled, gchat_is_enabled, ps4_is_chat_enabled
from "%scripts/dagui_library.nut" import *

let hasChatCharPermission = Watched(hasFeature("Chat"))

function getXboxChatEnableStatus() {
  if (!is_gdk || !isLoggedIn.get())
    return CommunicationState.Allowed
  return check_crossnetwork_communications_permission()
}

function attemptShowOverlayMessage() {
  if (!communicationsPrivilege.get())
    showInfoMsgBox(locByVendor("xbox/actionNotAvailableLiveCommunications"))
}

function isChatEnabled(needOverlayMessage = false) {
  if (!hasChatCharPermission.get() || !gchat_is_enabled())
    return false

  if (!ps4_is_chat_enabled()) {
    if (needOverlayMessage)
      ps4_show_chat_restriction()
    return false
  }

  if (getXboxChatEnableStatus() == CommunicationState.Blocked) {
    if (needOverlayMessage)
      attemptShowOverlayMessage()
    return false
  }
  return true
}




function is_player_in_friends_group(uid, searchByUid, playerNick) {
  return isPlayerInFriendsGroup(uid, searchByUid, playerNick)
}

function isCrossNetworkMessageAllowed(playerName) {
  if (isPlayerFromXboxOne(playerName)
      || isPlayerFromPS4(playerName))
    return true

  let crossnetStatus = crossplayModule.getCrossNetworkChatStatus()
  if (crossnetStatus == CommunicationState.FriendsOnly
    && (is_player_in_friends_group(null, false, playerName)))
    return true

  return crossnetStatus == CommunicationState.Allowed
}

function checkChatEnableWithPlayer(playerName, callback) { 
  let contact = getContactByName(playerName)
  if (contact) {
    contact.checkCanChat(callback)
    return
  }

  if (getXboxChatEnableStatus() == CommunicationState.FriendsOnly) {
    callback?(is_player_in_friends_group(null, false, playerName))
    return
  }

  if (!isCrossNetworkMessageAllowed(playerName)) {
    callback?(false)
    return
  }

  callback?(isChatEnabled())
}

function isChatEnableWithPlayer(playerName, comms_state) {
  let contact = getContactByName(playerName)
  if (contact) {
    return contact.canChat(comms_state)
  }

  if (getXboxChatEnableStatus() == CommunicationState.FriendsOnly) {
    return is_player_in_friends_group(null, false, playerName)
  }

  if (!isCrossNetworkMessageAllowed(playerName)) {
    return false
  }

  return isChatEnabled()
}

function canUseVoice() {
  return hasFeature("Voice") && gchat_is_voice_enabled()
}

let hasMenuChat = Computed(@() hasChat.get() && hasChatCharPermission.get() && !isGuestLogin.get())

addListenersWithoutEnv({
  ProfileUpdated             = @(_) hasChatCharPermission.set(hasFeature("Chat"))
})

return freeze({
  getXboxChatEnableStatus = getXboxChatEnableStatus
  isChatEnabled = isChatEnabled
  checkChatEnableWithPlayer = checkChatEnableWithPlayer
  isChatEnableWithPlayer = isChatEnableWithPlayer
  attemptShowOverlayMessage = attemptShowOverlayMessage
  isCrossNetworkMessageAllowed = isCrossNetworkMessageAllowed
  chatStatesCanUseVoice = canUseVoice
  hasMenuChat
  hasChatCharPermission
})
