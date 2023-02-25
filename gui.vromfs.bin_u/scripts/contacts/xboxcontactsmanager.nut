//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let platformModule = require("%scripts/clientState/platform.nut")
let extContactsService = require("%scripts/contacts/externalContactsService.nut")
let { addContact } = require("%scripts/contacts/contactsManager.nut")
let DataBlock = require("DataBlock")

let persistent = { isInitedXboxContacts = false }
let pendingXboxContactsToUpdate = {}

::g_script_reloader.registerPersistentData("XboxContactsManagerGlobals", persistent, ["isInitedXboxContacts"])

let updateContactXBoxPresence = function(xboxId, isAllowed) {
  let contact = ::findContactByXboxId(xboxId)
  if (!contact)
    return

  let forceOffline = !isAllowed
  if (contact.forceOffline == forceOffline && contact.isForceOfflineChecked)
    return

  ::updateContact({
    uid = contact.uid
    forceOffline = forceOffline
    isForceOfflineChecked = true
  })
}

let fetchContactsList = function() {
  pendingXboxContactsToUpdate.clear()
  //No matter what will be done first,
  //anyway, we will wait all groups data.
  ::xbox_get_people_list_async()
  ::xbox_get_avoid_list_async()
}

let updateContacts = function(needIgnoreInitedFlag = false) {
  if (!is_platform_xbox || !::isInMenu()) {
    if (needIgnoreInitedFlag && persistent.isInitedXboxContacts)
      persistent.isInitedXboxContacts = false
    return
  }

  if (!needIgnoreInitedFlag && persistent.isInitedXboxContacts)
    return

  persistent.isInitedXboxContacts = true
  fetchContactsList()
}

let tryUpdateContacts = function(contactsBlk) {
  local haveAnyUpdate = false
  foreach (_group, usersList in contactsBlk)
    haveAnyUpdate = haveAnyUpdate || usersList.paramCount() > 0

  if (!haveAnyUpdate) {
    log("XBOX CONTACTS: Update: No changes. No need to server call")
    return
  }

  let result = ::request_edit_player_lists(contactsBlk, false)
  if (result) {
    foreach (group, playersBlock in contactsBlk) {
      foreach (uid, isAdding in playersBlock) {
        let contact = ::getContact(uid)
        if (!contact)
          continue

        if (isAdding)
          addContact(contact, group)
        else
          ::g_contacts.removeContact(contact, group)
      }
      ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE { groupName = group })
    }
  }
}

let xboxUpdateContactsList = function(usersTable) {
  //Create or update exist contacts
  let contactsTable = {}
  foreach (uid, playerData in usersTable)
    contactsTable[playerData.id] <- ::updateContact({
      uid = uid
      name = playerData.nick
      xboxId = playerData.id
    })

  let contactsBlk = DataBlock()
  contactsBlk[EPL_FRIENDLIST] <- DataBlock()
  contactsBlk[EPL_BLOCKLIST]  <- DataBlock()

  foreach (group, playersArray in pendingXboxContactsToUpdate) {
    let existedXBoxContacts = ::get_contacts_array_by_filter_func(group, platformModule.isXBoxPlayerName)
    foreach (xboxPlayerId in playersArray) {
      let contact = contactsTable?[xboxPlayerId]
      if (!contact)
        continue

      if (!contact.isInFriendGroup() && group == EPL_FRIENDLIST) {
        contactsBlk[EPL_FRIENDLIST][contact.uid] = true
        if (contact.isInBlockGroup())
          contactsBlk[EPL_BLOCKLIST][contact.uid] = false
      }
      if (!contact.isInBlockGroup() && group == EPL_BLOCKLIST) {
        contactsBlk[EPL_BLOCKLIST][contact.uid] = true
        if (contact.isInFriendGroup())
          contactsBlk[EPL_FRIENDLIST][contact.uid] = false
      }

      //Check both lists, as there can be mistakes
      if (contact.isInFriendGroup() && contact.isInBlockGroup()) {
        if (group == EPL_FRIENDLIST)
          contactsBlk[EPL_BLOCKLIST][contact.uid] = false
        else
          contactsBlk[EPL_FRIENDLIST][contact.uid] = false
      }

      //Validate in-game contacts list
      //in case if in xbox contacts list some players
      //are gone. So we need to clear then in game.
      for (local i = existedXBoxContacts.len() - 1; i >= 0; i--) {
        if (contact == existedXBoxContacts[i]) {
          existedXBoxContacts.remove(i)
          break
        }
      }
    }

    foreach (oldContact in existedXBoxContacts)
      contactsBlk[group][oldContact.uid] = false
  }

  tryUpdateContacts(contactsBlk)
  pendingXboxContactsToUpdate.clear()
}

let proceedXboxPlayersList = function() {
  if (!(EPL_FRIENDLIST in pendingXboxContactsToUpdate)
      || !(EPL_BLOCKLIST in pendingXboxContactsToUpdate))
    return

  let playersList = []
  foreach (_group, usersArray in pendingXboxContactsToUpdate)
    playersList.extend(usersArray)

  let knownUsers = {}
  for (local i = playersList.len() - 1; i >= 0; i--) {
    let contact = ::findContactByXboxId(playersList[i])
    if (contact) {
      knownUsers[contact.uid] <- {
        nick = contact.name
        id = playersList.remove(i)
      }
    }
  }

  extContactsService.requestUnknownXboxIds(
    playersList,
    knownUsers,
    Callback(xboxUpdateContactsList, this)
  )
}

let onReceivedXboxListCallback = function(playersList, group) {
  pendingXboxContactsToUpdate[group] <- playersList
  proceedXboxPlayersList()
}

let xboxOverlayContactClosedCallback = function(playerStatus) {
  if (playerStatus == XBOX_PERSON_STATUS_CANCELED)
    return

  fetchContactsList()
}

::add_event_listener("SignOut", function(_p) {
  pendingXboxContactsToUpdate.clear()
  persistent.isInitedXboxContacts = false
}, this)

::add_event_listener("XboxSystemUIReturn", function(_p) {
  if (!::g_login.isLoggedIn())
    return

  updateContacts(true)
}, this)

::add_event_listener("ContactsUpdated", function(_p) {
  if (!is_platform_xbox)
    return

  let xboxContactsToCheck = ::u.filter(::contacts_players, @(contact) contact.needCheckForceOffline())
  xboxContactsToCheck.each(function(contact) {
    if (contact.xboxId != "")
      ::can_view_target_presence(contact.xboxId)
    else
      contact.getXboxId(@() ::can_view_target_presence(contact.xboxId))
  })

  updateContacts()
}, this)

return {
  fetchContactsList = fetchContactsList
  onReceivedXboxListCallback = onReceivedXboxListCallback

  xboxOverlayContactClosedCallback = xboxOverlayContactClosedCallback

  updateContactXBoxPresence = updateContactXBoxPresence
  updateContacts = updateContacts
}
