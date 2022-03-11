local platformModule = require("scripts/clientState/platform.nut")
local extContactsService = require("scripts/contacts/externalContactsService.nut")

local persistent = { isInitedXboxContacts = false }
local pendingXboxContactsToUpdate = {}

::g_script_reloader.registerPersistentData("XboxContactsManagerGlobals", persistent, ["isInitedXboxContacts"])

local updateContactXBoxPresence = function(xboxId, isAllowed)
{
  local contact = ::findContactByXboxId(xboxId)
  if (!contact)
    return

  local forceOffline = !isAllowed
  if (contact.forceOffline == forceOffline && contact.isForceOfflineChecked)
    return

  ::updateContact({
    uid = contact.uid
    forceOffline = forceOffline
    isForceOfflineChecked = true
  })
}

local fetchContactsList = function()
{
  pendingXboxContactsToUpdate.clear()
  //No matter what will be done first,
  //anyway, we will wait all groups data.
  ::xbox_get_people_list_async()
  ::xbox_get_avoid_list_async()
}

local updateContacts = function(needIgnoreInitedFlag = false)
{
  if (!::is_platform_xbox || !::isInMenu())
  {
    if (needIgnoreInitedFlag && persistent.isInitedXboxContacts)
      persistent.isInitedXboxContacts = false
    return
  }

  if (!needIgnoreInitedFlag && persistent.isInitedXboxContacts)
    return

  persistent.isInitedXboxContacts = true
  fetchContactsList()
}

local tryUpdateContacts = function(contactsBlk)
{
  local haveAnyUpdate = false
  foreach (group, usersList in contactsBlk)
    haveAnyUpdate = haveAnyUpdate || usersList.paramCount() > 0

  if (!haveAnyUpdate)
  {
    ::dagor.debug("XBOX CONTACTS: Update: No changes. No need to server call")
    return
  }

  local result = ::request_edit_player_lists(contactsBlk, false)
  if (result)
  {
    foreach(group, playersBlock in contactsBlk)
    {
      foreach (uid, isAdding in playersBlock)
      {
        local contact = ::getContact(uid)
        if (!contact)
          continue

        if (isAdding)
          ::g_contacts.addContact(contact, group)
        else
          ::g_contacts.removeContact(contact, group)
      }
      ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE { groupName = group })
    }
  }
}

local xboxUpdateContactsList = function(usersTable)
{
  //Create or update exist contacts
  local contactsTable = {}
  foreach (uid, playerData in usersTable)
    contactsTable[playerData.id] <- ::updateContact({
      uid = uid
      name = playerData.nick
      xboxId = playerData.id
    })

  local contactsBlk = ::DataBlock()
  contactsBlk[::EPL_FRIENDLIST] <- ::DataBlock()
  contactsBlk[::EPL_BLOCKLIST]  <- ::DataBlock()

  foreach (group, playersArray in pendingXboxContactsToUpdate)
  {
    local existedXBoxContacts = ::get_contacts_array_by_filter_func(group, platformModule.isXBoxPlayerName)
    foreach (xboxPlayerId in playersArray)
    {
      local contact = contactsTable?[xboxPlayerId]
      if (!contact)
        continue

      if (!contact.isInFriendGroup() && group == ::EPL_FRIENDLIST)
      {
        contactsBlk[::EPL_FRIENDLIST][contact.uid] = true
        if (contact.isInBlockGroup())
          contactsBlk[::EPL_BLOCKLIST][contact.uid] = false
      }
      if (!contact.isInBlockGroup() && group == ::EPL_BLOCKLIST)
      {
        contactsBlk[::EPL_BLOCKLIST][contact.uid] = true
        if (contact.isInFriendGroup())
          contactsBlk[::EPL_FRIENDLIST][contact.uid] = false
      }

      //Check both lists, as there can be mistakes
      if (contact.isInFriendGroup() && contact.isInBlockGroup())
      {
        if (group == ::EPL_FRIENDLIST)
          contactsBlk[::EPL_BLOCKLIST][contact.uid] = false
        else
          contactsBlk[::EPL_FRIENDLIST][contact.uid] = false
      }

      //Validate in-game contacts list
      //in case if in xbox contacts list some players
      //are gone. So we need to clear then in game.
      for (local i = existedXBoxContacts.len() - 1; i >= 0; i--)
      {
        if (contact == existedXBoxContacts[i])
        {
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

local proceedXboxPlayersList = function()
{
  if (!(::EPL_FRIENDLIST in pendingXboxContactsToUpdate)
      || !(::EPL_BLOCKLIST in pendingXboxContactsToUpdate))
    return

  local playersList = []
  foreach (group, usersArray in pendingXboxContactsToUpdate)
    playersList.extend(usersArray)

  local knownUsers = {}
  for (local i = playersList.len() - 1; i >= 0; i--)
  {
    local contact = ::findContactByXboxId(playersList[i])
    if (contact)
    {
      knownUsers[contact.uid] <- {
        nick = contact.name
        id = playersList.remove(i)
      }
    }
  }

  extContactsService.requestUnknownXboxIds(
    playersList,
    knownUsers,
    ::Callback(xboxUpdateContactsList, this)
  )
}

local onReceivedXboxListCallback = function(playersList, group)
{
  pendingXboxContactsToUpdate[group] <- playersList
  proceedXboxPlayersList()
}

local xboxOverlayContactClosedCallback = function(playerStatus)
{
  if (playerStatus == XBOX_PERSON_STATUS_CANCELED)
    return

  fetchContactsList()
}

::add_event_listener("SignOut", function(p) {
  pendingXboxContactsToUpdate.clear()
  persistent.isInitedXboxContacts = false
}, this)

::add_event_listener("XboxSystemUIReturn", function(p) {
  if (!::g_login.isLoggedIn())
    return

  updateContacts(true)
}, this)

::add_event_listener("ContactsUpdated", function(p) {
  if (!::is_platform_xbox)
    return

  local xboxContactsToCheck = ::u.filter(::contacts_players, @(contact) contact.needCheckForceOffline())
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
