from "%scripts/dagui_library.nut" import *
from "%scripts/contacts/contactsConsts.nut" import contactEvent, GAME_GROUP_NAME, EPLX_SEARCH, EPLX_PS4_FRIENDS, EPLX_STEAM,
  getMaxContactsByGroup

let { is_gdk } = require("%sqstd/platform.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { request_nick_by_uid_batch } = require("%scripts/matching/requests.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { get_charserver_time_sec } = require("chard")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { isDataBlock } = require("%sqstd/underscore.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { predefinedContactsGroupToWtGroup, steamContactsGroup, recentGroup, blockedMeUids,
  psnApprovedUids, psnBlockedUids, xboxApprovedUids, xboxBlockedUids, contactsGroups,
  contactsByGroups, getContactByName
} = require("%scripts/contacts/contactsListState.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")

let contactsGroupsDefault = [EPLX_SEARCH, EPL_FRIENDLIST, EPL_RECENT_SQUAD, EPL_BLOCKLIST]

local isDisableContactsBroadcastEvents = false

let additionalConsolesContacts = 
  isPlatformSony ? {
      [EPLX_PS4_FRIENDS] = psnApprovedUids,
      [EPL_BLOCKLIST] = psnBlockedUids
    }
  : is_gdk ? {
      [EPL_FRIENDLIST] = xboxApprovedUids,
      [EPL_BLOCKLIST] = xboxBlockedUids
    }
  : {}

function verifyContact(params) {
  let name = params?.playerName
  local newContact = getContact(params?.uid, name, params?.clanTag)
  if (!newContact && name)
    newContact = getContactByName(name)

  return newContact
}

function addContactGroup(group) {
  if (contactsGroups.contains(group))
    return

  contactsGroups.insert(2, group)
  contactsByGroups[group] <- {}
  if (!isDisableContactsBroadcastEvents)
    broadcastEvent(contactEvent.CONTACTS_GROUP_ADDED)
}

function addContact(v_contact, groupName, params = {}) {
  let contact = v_contact || verifyContact(params)
  if (!contact)
    return null

  addContactGroup(groupName) 

  let uid = contact.uid
  if (uid not in contactsByGroups[groupName])
    contactsByGroups[groupName][uid] <- contact

  contact?.updateMuteStatus()
  return contact
}

function updateRecentGroup(recentGroupV) {
  if (recentGroupV == null)
    return
  contactsByGroups[EPL_RECENT_SQUAD] <- {}
  foreach(uid, _ in recentGroupV) {
    addContact(getContact(uid), EPL_RECENT_SQUAD)
  }
  if (!isDisableContactsBroadcastEvents)
    broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, { groupName = EPL_RECENT_SQUAD })
}

recentGroup.subscribe(updateRecentGroup)

function loadRecentGroupOnce() {
  if (recentGroup.get() != null)
    return
  local group = loadLocalAccountSettings($"contacts/{EPL_RECENT_SQUAD}")
  group = isDataBlock(group) ? convertBlk(group) : {}
  recentGroup.set(group)
  if (group.len() == 0)
    return

  let uidsForNickRequest = []
  foreach (uid, _ in group) {
    let contact = getContact(uid)
    if (contact == null)
      uidsForNickRequest.append(uid.tointeger())
  }

  if (uidsForNickRequest.len() == 0)
    return

  request_nick_by_uid_batch(uidsForNickRequest, function(resp) { 
    let nicksByUids = resp?.result
    if (nicksByUids == null)
      return

    foreach (uid, nick in nicksByUids)
      getContact(uid, nick)  

    updateRecentGroup(recentGroup.get())
  })
}

function addRecentContacts(contacts) {
  if (!isLoggedIn.get())
    return

  loadRecentGroupOnce()
  let serverTime = get_charserver_time_sec()
  local uidsToSave = {}
  foreach (contact in contacts) {
    let uid = contact?.userId ?? contact?.uid
    if (uid != null)
      uidsToSave[uid] <- serverTime
  }
  uidsToSave = uidsToSave.__update(recentGroup.get())
  let maxCount = getMaxContactsByGroup(EPL_RECENT_SQUAD)
  if (uidsToSave.len() > maxCount) {
    let resArray = uidsToSave.keys().map(@(v) { uid = v, serverTime = uidsToSave[v] })
    resArray.sort(@(a, b) b.serverTime <=> a.serverTime)
    for (local i = maxCount; i < resArray.len(); i++)
      uidsToSave.$rawdelete(resArray[i].uid)
  }

  saveLocalAccountSettings($"contacts/{EPL_RECENT_SQUAD}", uidsToSave)
  recentGroup.set(uidsToSave)
}

function clear_contacts() {
  contactsGroups.clear()
  foreach (_num, group in contactsGroupsDefault)
    contactsGroups.append(group)
  contactsByGroups.clear()
  foreach (list in contactsGroups)
    contactsByGroups[list] <- {}

  if (!isDisableContactsBroadcastEvents)
    broadcastEvent("ContactsCleared")
}

let buildFullListName = @(name) $"#{GAME_GROUP_NAME}#{name}"

function updateConsolesGroups() {
  foreach (wtGroup, group in additionalConsolesContacts) {
    addContactGroup(wtGroup) 
    foreach (uid, _ in group.get())
      addContact(getContact(uid), wtGroup)
  }
}

function updateSteamContactsGroup(steamContactsGroupV) {
  if (steamContactsGroupV == null)
    return

  addContactGroup(EPLX_STEAM)
  foreach(steamId, contact in steamContactsGroupV)
    contactsByGroups[EPLX_STEAM][steamId] <- contact
  if (!isDisableContactsBroadcastEvents)
    broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, { groupName = EPLX_STEAM })
}

steamContactsGroup.subscribe(updateSteamContactsGroup)

function updateContactsGroups(groups) {
  isDisableContactsBroadcastEvents = true

  clear_contacts()
  updateConsolesGroups()
  foreach (name, wtGroup in predefinedContactsGroupToWtGroup) {
    let contactGroup = buildFullListName(name)
    if (contactGroup not in groups)
      continue

    let list = groups[contactGroup]
    foreach (p in list) {
      let playerUid = (p?.userId ?? p?.uid ?? "").tostring()
      let playerName = p?.nick
      let playerClanTag = p?.clanTag

      let contact = addContact(null, wtGroup, {
        uid = playerUid
        playerName = playerName
        clanTag = playerClanTag
      })

      if (!contact) {
        let errText = playerUid ? "player not found" : "not valid data"
        script_net_assert_once("not found contact for group", $"{errText} /*myUserId = {userIdInt64.get()}*/")
        continue
      }

      contact.setContactServiceGroup(name)
    }
  }

  updateRecentGroup(recentGroup.get())
  updateSteamContactsGroup(steamContactsGroup.get())

  isDisableContactsBroadcastEvents = false
}

if (contactsByGroups.len() == 0)
  clear_contacts()

addListenersWithoutEnv({
  function SignOut(_) {
    recentGroup.set(null)
    blockedMeUids.set({})
    clear_contacts()
  }
  LoginComplete = @(_) loadRecentGroupOnce()
})

return {
  verifyContact
  addContact
  addContactGroup
  updateContactsGroups
  clear_contacts
  addRecentContacts
}