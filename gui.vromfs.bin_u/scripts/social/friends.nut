//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let editContactsList = require("%scripts/contacts/editContacts.nut")
let { addContactGroup } = require("%scripts/contacts/contactsManager.nut")

::addSocialFriends <- function addSocialFriends(blk, groupName, silent = false) {
  let players = []

  foreach (userId, info in blk) {
    let contact = ::getContact(userId, info.nick)
    if (contact)
      players.append(contact)
  }

  if (players.len()) {
    addContactGroup(groupName)
    editContactsList({ [true] = players }, groupName, !silent)
  }
}
