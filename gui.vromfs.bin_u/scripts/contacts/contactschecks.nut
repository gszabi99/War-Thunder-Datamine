from "%scripts/dagui_library.nut" import *

let { contactsByGroups, EPLX_PS4_FRIENDS } = require("%scripts/contacts/contactsManager.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")

function isPlayerInContacts(uid, groupName) {
  if (!(groupName in contactsByGroups) || isEmpty(uid))
    return false
  return uid in contactsByGroups[groupName]
}

function isPlayerNickInContacts(nick, groupName) {
  if (!(groupName in contactsByGroups))
    return false
  foreach (p in contactsByGroups[groupName])
    if (p.name == nick)
      return true
  return false
}

function isPlayerInFriendsGroup(uid, searchByUid = true, playerNick = "") {
  if (isEmpty(uid))
    searchByUid = false

  local isFriend = false
  if (searchByUid)
    isFriend = isPlayerInContacts(uid, EPL_FRIENDLIST) || isPlayerInContacts(uid, EPLX_PS4_FRIENDS)
  else if (playerNick != "")
    isFriend = isPlayerNickInContacts(playerNick, EPL_FRIENDLIST) || isPlayerNickInContacts(playerNick, EPLX_PS4_FRIENDS)

  return isFriend
}

return {
  isPlayerInContacts
  isPlayerNickInContacts
  isPlayerInFriendsGroup
}