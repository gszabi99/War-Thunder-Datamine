from "%scripts/dagui_natives.nut" import gchat_is_enabled
from "%scripts/dagui_library.nut" import *

let { g_chat } = require("%scripts/chat/chat.nut")
let { isPlayerFromXboxOne } = require("%scripts/clientState/platform.nut")
let { hasMenuChat } = require("%scripts/chat/chatStates.nut")
let { getLastGamercardScene } = require("%scripts/gamercard.nut")
let { find_contact_by_name_and_do } = require("%scripts/contacts/contactsActions.nut")
let { menuChatHandler, createMenuChatHandler } = require("%scripts/chat/menuChatHandler.nut")
let { getChatObject } = require("%scripts/chat/chatUtils.nut")

::openChatScene <- function openChatScene(ownerHandler = null) {
  if (!gchat_is_enabled() || !hasMenuChat.value) {
    showInfoMsgBox(loc("msgbox/notAvailbleYet"))
    return false
  }

  let scene = ownerHandler ? ownerHandler.scene : getLastGamercardScene()
  if (!checkObj(scene))
    return false

  let obj = getChatObject(scene)
  if (!menuChatHandler.get()) {
    if (!checkObj(obj))
      return false
    createMenuChatHandler(obj.getScene()).initChat(obj)
  }
  else
    menuChatHandler.get().switchScene(obj, true)
  return true
}

::openChatPrivate <- function openChatPrivate(playerName, ownerHandler = null) {
  if (!isPlayerFromXboxOne(playerName))
    return g_chat.openPrivateRoom(playerName, ownerHandler)

  find_contact_by_name_and_do(playerName, function(contact) {
    if (contact.xboxId == "")
      return contact.updateXboxIdAndDo(@() g_chat.openPrivateRoom(contact.name, ownerHandler))

    contact.checkCanChat(function(is_enabled) {
      if (is_enabled) {
        g_chat.openPrivateRoom(contact.name, ownerHandler)
      }
    })
  })
}
