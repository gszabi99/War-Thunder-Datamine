from "%scripts/dagui_natives.nut" import gchat_is_enabled
from "%scripts/dagui_library.nut" import *

let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isPlayerFromXboxOne } = require("%scripts/clientState/platform.nut")
let { hasMenuChat } = require("%scripts/chat/chatStates.nut")
let { getLastGamercardScene } = require("%scripts/gamercard/gamercardHelpers.nut")
let { find_contact_by_name_and_do } = require("%scripts/contacts/contactsActions.nut")
let { openChatHandlerScene } = require("%scripts/chat/chatHandler.nut")
let { getChatObject } = require("%scripts/chat/chatUtils.nut")
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

return {
  openChatRoom
  openWWOperationChatRoomById
  openChatPrivate
}