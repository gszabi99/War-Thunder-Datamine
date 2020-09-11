local psn = require("sonyLib/webApi.nut")
local { isPlatformSony, isPS4PlayerName } = require("scripts/clientState/platform.nut")
local { requestUnknownPSNIds } = require("scripts/contacts/externalContactsService.nut")

local isContactsUpdated = persist("isContactsUpdated", @() ::Watched(false))

local LIMIT_FOR_ONE_TASK_GET_USERS = 200
local UPDATE_TIMER_LIMIT = 300000
local LAST_UPDATE_FRIENDS = -UPDATE_TIMER_LIMIT

local pendingContactsChanges = {}
local checkGroups = []


//For now it is for PSN only. For all will be later
local updateMuteStatus = function(contact = null) {
  if (!contact)
    return

  local ircName = ::g_string.replace(contact.name, "@", "%40") //!!!Temp hack, *_by_uid will not be working on sony testing build
  ::gchat_voice_mute_peer_by_name(contact.isInBlockGroup(), ircName)
}

local tryUpdateContacts = function(contactsBlk)
{
  local haveAnyUpdate = false
  foreach (group, usersList in contactsBlk)
    haveAnyUpdate = haveAnyUpdate || usersList.paramCount() > 0

  if (!haveAnyUpdate)
  {
    ::dagor.debug("PSN: CONTACTS: Update: No changes. No need to server call")
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

        if (isAdding) {
          if (::g_contacts.isFriendsGroupName(group))
            ::ps4_console_friends[contact.name] <- contact
          ::addContactGroup(group)
          ::contacts[group].append(contact)
        }
        else
          ::g_contacts.removeContact(contact, group)

        updateMuteStatus(contact)
      }
      ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE { groupName = group })
    }
  }
}

local function psnUpdateContactsList(usersTable) {
  //Create or update exist contacts
  local contactsTable = {}
  foreach (uid, playerData in usersTable)
    contactsTable[playerData.id] <- ::updateContact({
      uid = uid
      name = playerData.nick
      psnId = playerData.id
    })

  local contactsBlk = ::DataBlock()
  contactsBlk[::EPLX_PS4_FRIENDS] <- ::DataBlock()
  contactsBlk[::EPL_BLOCKLIST]  <- ::DataBlock()
  contactsBlk[::EPL_FRIENDLIST] <- ::DataBlock()

  foreach (groupName, groupData in pendingContactsChanges)
  {
    local existedPSNContacts = ::get_contacts_array_by_filter_func(groupName, isPS4PlayerName)

    foreach (userInfo in groupData.users) {
      local contact = contactsTable?[userInfo.accountId]
      if (!contact)
        continue

      local friendGroupName = isPS4PlayerName(contact.name)? ::EPLX_PS4_FRIENDS : ::EPL_FRIENDLIST
      if (!contact.isInFriendGroup() && groupName == friendGroupName) {
        contactsBlk[friendGroupName][contact.uid] = true
        if (contact.isInBlockGroup())
          contactsBlk[::EPL_BLOCKLIST][contact.uid] = false
      }

      if (!contact.isInBlockGroup() && groupName == ::EPL_BLOCKLIST) {
        contactsBlk[::EPL_BLOCKLIST][contact.uid] = true
        if (contact.isInFriendGroup())
          contactsBlk[friendGroupName][contact.uid] = false
      }

      //Check both lists, as there can be mistakes
      if (contact.isInFriendGroup() && contact.isInBlockGroup()) {
        if (groupName == ::getFriendGroupName(contact.name))
          contactsBlk[::EPL_BLOCKLIST][contact.uid] = false
        else
          contactsBlk[friendGroupName][contact.uid] = false
      }

      //Check both friend lists, as there can be duplicates
      if (contact.isInGroup(::EPL_FRIENDLIST) && contact.isInGroup(::EPLX_PS4_FRIENDS)) {
        if (friendGroupName == ::EPL_FRIENDLIST)
          contactsBlk[::EPLX_PS4_FRIENDS][contact.uid] = false
        else if (friendGroupName == ::EPLX_PS4_FRIENDS)
          contactsBlk[::EPL_FRIENDLIST][contact.uid] = false
      }

      if (friendGroupName == ::EPLX_PS4_FRIENDS) {
        if (contact.isInGroup(::EPL_FRIENDLIST) && !contact.isInGroup(friendGroupName)) {
          contactsBlk[::EPL_FRIENDLIST][contact.uid] = false
          contactsBlk[friendGroupName][contact.uid] = true
        }
      }

      //Validate in-game contacts list
      //in case if in psn contacts list some players
      //are gone. So we need to clear then in game.
      for (local i = existedPSNContacts.len() - 1; i >= 0; i--)
        if (contact == existedPSNContacts[i]) {
          existedPSNContacts.remove(i)
          break
        }
    }

    foreach (oldContact in existedPSNContacts)
      contactsBlk[groupName][oldContact.uid] = false
  }

  tryUpdateContacts(contactsBlk)
  pendingContactsChanges.clear()
}

local function proceedPlayersList() {
  foreach (groupName in checkGroups)
    if (!(groupName in pendingContactsChanges) || !pendingContactsChanges[groupName].isFinished)
      return

  local playersList = []
  foreach (groupName, data in pendingContactsChanges)
    playersList.extend(data.users)

  local knownUsers = {}
  for (local i = playersList.len() - 1; i >= 0; i--)
  {
    local contact = ::g_contacts.findContactByPSNId(playersList[i].accountId)
    if (contact)
    {
      knownUsers[contact.uid] <- {
        nick = contact.name
        id = playersList.remove(i).accountId
      }
    }
  }

  requestUnknownPSNIds(
    playersList.map(@(u) u.accountId),
    knownUsers,
    ::Callback(psnUpdateContactsList, this)
  )
}

local function onReceviedUsersList(groupName, responseInfoName, response, err) {
  local size = (response?.size || 0) + (response?.start || 0)
  local total = response?.totalResults || size

  if (!(groupName in pendingContactsChanges))
    pendingContactsChanges[groupName] <- {
      isFinished = false
      users = []
    }

  if (!err) {
    foreach (idx, playerData in (response?[responseInfoName] || []))
      pendingContactsChanges[groupName].users.append(playerData.user)
  }
  else {
    ::dagor.debug($"PSN: Contacts: Update {groupName}: received error: {::toString(err)}")
    if (::u.isString(err.code) || err.code < 500 || err.code >= 600)
      ::script_net_assert_once("psn_contacts_error", $"PSN: Contacts: Update {groupName}: received error: {::toString(err)}")
  }

  pendingContactsChanges[groupName].isFinished = err || size >= total
  proceedPlayersList()
}

local function fetchFriendlist() {
  checkGroups.append(::EPLX_PS4_FRIENDS)
  psn.fetch(
    psn.profile.listFriends(),
    @(response, err) onReceviedUsersList(::EPLX_PS4_FRIENDS, "friendList", response, err),
    LIMIT_FOR_ONE_TASK_GET_USERS
  )
}

local function fetchBlocklist() {
  checkGroups.append(::EPL_BLOCKLIST)
  psn.fetch(
    psn.profile.listBlockedUsers(),
    @(response, err) onReceviedUsersList(::EPL_BLOCKLIST, "blockingUsers", response, err),
    LIMIT_FOR_ONE_TASK_GET_USERS
  )
}

local function fetchContactsList() {
  pendingContactsChanges.clear()
  checkGroups.clear()

  fetchFriendlist()
  fetchBlocklist()
}

local function updateContacts(needIgnoreInitedFlag = false) {
  if (!isPlatformSony)
    return

  if (!::isInMenu()) {
    if (needIgnoreInitedFlag && isContactsUpdated.value)
      isContactsUpdated(false)
    return
  }

  if (!needIgnoreInitedFlag && isContactsUpdated.value) {
    if (::dagor.getCurTime() - LAST_UPDATE_FRIENDS > UPDATE_TIMER_LIMIT)
      LAST_UPDATE_FRIENDS = ::dagor.getCurTime()
    else
      return
  }

  isContactsUpdated(true)
  fetchContactsList()
}

::add_event_listener("LoginComplete", function(p) {
  isContactsUpdated(false)
}, this)

::add_event_listener("ContactsUpdated", function(p) {
  updateContacts()
}, this)

// HACK: force-stop push notifications on reload for GFQA. To be removed.
psn.unsubscribe.friendslist()
psn.unsubscribe.blocklist()

return {
  updateContacts = updateContacts
  updateMuteStatus = updateMuteStatus
}
