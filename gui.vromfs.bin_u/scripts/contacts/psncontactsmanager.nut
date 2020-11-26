local stdLog = require("std/log.nut")()
local log = stdLog.with_prefix("[PSN: Contacts] ")
local logerr = stdLog.logerr

local psn = require("sonyLib/webApi.nut")
local { isPlatformSony, isPS4PlayerName } = require("scripts/clientState/platform.nut")
local { requestUnknownPSNIds } = require("scripts/contacts/externalContactsService.nut")

local isContactsUpdated = persist("isContactsUpdated", @() ::Watched(false))

local LIMIT_FOR_ONE_TASK_GET_USERS = 200
local UPDATE_TIMER_LIMIT = 10000
local LAST_UPDATE_FRIENDS = -UPDATE_TIMER_LIMIT
local PSN_RESPONSE_FIELDS = psn.getPreferredVersion() == 2
  ? { friends = "friends", blocklist = "blocks" }
  : { friends = "friendList", blocklist = "blockingUsers" }

local convertPsnContact = (psn.getPreferredVersion() == 2)
  ? @(psnEntry) { accountId = psnEntry }
  : @(psnEntry) { accountId = psnEntry.user.accountId }

local pendingContactsChanges = {}
local checkGroups = []


local tryUpdateContacts = function(contactsBlk)
{
  local haveAnyUpdate = false
  foreach (group, usersList in contactsBlk)
    haveAnyUpdate = haveAnyUpdate || usersList.paramCount() > 0

  if (!haveAnyUpdate)
  {
    log("Update: No changes. No need to server call")
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

        contact.updateMuteStatus()
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

      if (!contact.isInPSNFriends() && groupName == ::EPLX_PS4_FRIENDS) {
        contactsBlk[::EPLX_PS4_FRIENDS][contact.uid] = true
        if (contact.isInBlockGroup())
          contactsBlk[::EPL_BLOCKLIST][contact.uid] = false
      }

      if (!contact.isInBlockGroup() && groupName == ::EPL_BLOCKLIST) {
        contactsBlk[::EPL_BLOCKLIST][contact.uid] = true
        if (contact.isInPSNFriends())
          contactsBlk[::EPLX_PS4_FRIENDS][contact.uid] = false

        if (contact.isInFriendGroup())
          contactsBlk[::EPL_FRIENDLIST][contact.uid] = false
      }

      //Check both lists, as there can be mistakes
      if (contact.isInPSNFriends() && contact.isInBlockGroup()) {
        if (groupName == ::EPLX_PS4_FRIENDS)
          contactsBlk[::EPL_BLOCKLIST][contact.uid] = false
        else
          contactsBlk[::EPLX_PS4_FRIENDS][contact.uid] = false
      }

      //Validate in-game contacts list
      //in case if in psn contacts list some players
      //are gone. So we need to clear then in game.
      //But, if player was added to blocklist on PC, left it there.
      for (local i = existedPSNContacts.len() - 1; i >= 0; i--)
      {
        if (contact.isSameContact(existedPSNContacts[i].uid)
          || (groupName == ::EPL_BLOCKLIST
              && existedPSNContacts[i].isInBlockGroup()
              && !existedPSNContacts[i].isInPSNFriends())
          ) {
            existedPSNContacts.remove(i)
            break
          }
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
        pendingContactsChanges[groupName].users.append(convertPsnContact(playerData))
  }
  else {
    log($"Update {groupName}: received error: {::toString(err)}")
    if (::u.isString(err.code) || err.code < 500 || err.code >= 600)
      logerr($"[PSN: Contacts] Update {groupName}: received error: {::toString(err)}")
  }

  pendingContactsChanges[groupName].isFinished = err || size >= total
  proceedPlayersList()
}

local function fetchFriendlist() {
  checkGroups.append(::EPLX_PS4_FRIENDS)
  ::addContactGroup(::EPLX_PS4_FRIENDS)
  psn.fetch(
    psn.profile.listFriends(),
    @(response, err) onReceviedUsersList(::EPLX_PS4_FRIENDS, PSN_RESPONSE_FIELDS.friends, response, err),
    LIMIT_FOR_ONE_TASK_GET_USERS
  )
}

local function fetchBlocklist() {
  checkGroups.append(::EPL_BLOCKLIST)
  psn.fetch(
    psn.profile.listBlockedUsers(),
    @(response, err) onReceviedUsersList(::EPL_BLOCKLIST, PSN_RESPONSE_FIELDS.blocklist, response, err),
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
  updateContacts(true)

  psn.subscribe.friendslist(function() {
    updateContacts(true)
  })

  psn.subscribe.blocklist(function() {
    updateContacts(true)
  })
}, this)

::add_event_listener("SignOut", function(p) {
  pendingContactsChanges.clear()
  isContactsUpdated(false)

  psn.unsubscribe.friendslist()
  psn.unsubscribe.blocklist()
  psn.abortAllPendingRequests()
})

return {
  updateContacts
}
