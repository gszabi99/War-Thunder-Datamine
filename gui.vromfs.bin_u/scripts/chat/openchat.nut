from "%appGlobals/clientState/platform.nut" import isPlayerFromXboxOne
from "%scripts/chat/chatStates.nut" import hasMenuChat
from "%scripts/gamercard/gamercardHelpers.nut" import getLastGamercardScene
from "%scripts/contacts/contactsActions.nut" import find_contact_by_name_and_do
from "%scripts/chat/chatHandler.nut" import openChatHandlerScene
from "%scripts/chat/chatUtils.nut" import getChatObject
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_natives.nut" import gchat_is_enabled
from "%scripts/dagui_library.nut" import *

let { chatRooms } = require("%scripts/chat/chatStorage.nut")

function openChatScene(ownerHandler = null) {
  if (!gchat_is_enabled() || !hasMenuChat.get()) {
    showInfoMsgBox(loc("msgbox/notAvailbleYet"))
    return false
  }

  let scene = ownerHandler ? ownerHandler.scene : getLastGamercardScene()
  if (!scene?.isValid())
    return false

  let obj = getChatObject(scene)
  openChatHandlerScene(obj.getScene(), obj, true)
  return true
}

function openChatRoom(roomId, ownerHandler = null) {
  if (!openChatScene(ownerHandler))
    return

  broadcastEvent("ChatSwitchCurRoom", { roomId })
}

function openWWOperationChatRoomById(operationId) {
  foreach (room in chatRooms) {
    if (room.type.typeName != "WW_OPERATION")
      continue
    if (room.type.getOperationId(room.id) != operationId)
      continue

    openChatRoom(room.id)
    return
  }
}

function openPrivateRoom(name, ownerHandler) {
  if (openChatScene(ownerHandler))
    broadcastEvent("ChatChangePrivateTo", { user = name })
}

function openChatPrivate(playerName, ownerHandler = null) {
  if (!isPlayerFromXboxOne(playerName))
    return openPrivateRoom(playerName, ownerHandler)

  find_contact_by_name_and_do(playerName, function(contact) {
    if (contact.xboxId == "")
      return contact.updateXboxIdAndDo(@() openPrivateRoom(contact.name, ownerHandler))

    contact.checkCanChat(function(is_enabled) {
      if (is_enabled) {
        openPrivateRoom(contact.name, ownerHandler)
      }
    })
  })
}

return freeze({
  openChatRoom
  openWWOperationChatRoomById
  openChatPrivate
})