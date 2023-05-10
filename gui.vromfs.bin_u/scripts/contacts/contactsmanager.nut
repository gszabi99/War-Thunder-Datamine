//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let mkHardWatched = require("%globalScripts/mkHardWatched.nut")
let { request_nick_by_uid_batch } = require("%scripts/matching/requests.nut")

let contactsWndSizes = Watched(null)

const EPLX_SEARCH = "search"
const EPLX_CLAN = "clan"
const EPLX_PS4_FRIENDS = "ps4_friends"

let contactsGroupsDefault = [EPLX_SEARCH, EPL_FRIENDLIST, EPL_RECENT_SQUAD, EPL_BLOCKLIST]

local isDisableContactsBroadcastEvents = false

let recentGroup = mkHardWatched("recentGroup", null)

let function verifyContact(params) {
  let name = params?.playerName
  local newContact = ::getContact(params?.uid, name, params?.clanTag)
  if (!newContact && name)
    newContact = ::Contact.getByName(name)

  return newContact
}

let function addContactGroup(group) {
  if (::contacts_groups.contains(group))
    return

  ::contacts_groups.insert(2, group)
  ::contacts[group] <- []
  if (!isDisableContactsBroadcastEvents)
    ::broadcastEvent(contactEvent.CONTACTS_GROUP_ADDED)
}

let function addContact(v_contact, groupName, params = {}) {
  let contact = v_contact || verifyContact(params)
  if (!contact)
    return null

  addContactGroup(groupName) //Group can be not exist in list

  let existContactIdx = ::contacts[groupName].findindex(@(c) c.isSameContact(contact.uid))
  if (existContactIdx == null)
    ::contacts[groupName].append(contact)

  contact?.updateMuteStatus()
  return contact
}

let function updateRecentGroup(recentGroupV) {
  if (recentGroupV == null)
    return
  ::contacts[EPL_RECENT_SQUAD] <- []
  foreach(uid, _ in recentGroupV) {
    addContact(::getContact(uid), EPL_RECENT_SQUAD)
  }
  ::broadcastEvent(contactEvent.CONTACTS_GROUP_UPDATE, { groupName = EPL_RECENT_SQUAD })
}

recentGroup.subscribe(updateRecentGroup)

let function loadRecentGroupOnce() {
  if (recentGroup.value != null)
    return
  local group = ::load_local_account_settings($"contacts/{EPL_RECENT_SQUAD}")
  group = group != null ? ::buildTableFromBlk(group) : {}
  recentGroup(group)
  if (group.len() == 0)
    return

  let uidsForNickRequest = []
  foreach (uid, _ in group) {
    let contact = ::getContact(uid)
    if (contact == null)
      uidsForNickRequest.append(uid.tointeger())
  }

  if (uidsForNickRequest.len() == 0)
    return

  request_nick_by_uid_batch(uidsForNickRequest, function(resp) { //TO DO: Need to replace this with a contact request from a contact service
    let nicksByUids = resp?.result
    if (nicksByUids == null)
      return

    foreach (uid, nick in nicksByUids)
      ::getContact(uid, nick)  //create contact

    updateRecentGroup(recentGroup.value)
  })
}

let function addRecentContacts(contacts) {
  if (!::g_login.isLoggedIn())
    return

  loadRecentGroupOnce()
  let serverTime = ::get_charserver_time_sec()
  local uidsToSave = {}
  foreach (contact in contacts) {
    let uid = contact?.userId ?? contact?.uid
    if (uid != null)
      uidsToSave[uid] <- serverTime
  }
  uidsToSave = uidsToSave.__update(recentGroup.value)
  if (uidsToSave.len() > EPL_MAX_PLAYERS_IN_LIST) {
    let resArray = uidsToSave.keys().map(@(v) { uid = v, serverTime = uidsToSave[v] })
    resArray.sort(@(a, b) b.serverTime <=> a.serverTime)
    for (local i = EPL_MAX_PLAYERS_IN_LIST; i < resArray.len(); i++)
      uidsToSave.rawdelete(resArray[i].uid)
  }

  ::save_local_account_settings($"contacts/{EPL_RECENT_SQUAD}", uidsToSave)
  recentGroup(uidsToSave)
}

let function exportRecentSquadContacts(contacts) {
  if (!::g_login.isLoggedIn() || contacts.len() == 0)
    return
  loadRecentGroupOnce()
  if (recentGroup.value.len() != 0)
    return

  foreach(contact in contacts)
    ::getContact(contact?.userId ?? contact?.uid, contact?.nick, contact?.clanTag) //create contact

  addRecentContacts(contacts)
}

let function clear_contacts() {
  ::contacts_groups = []
  foreach (_num, group in contactsGroupsDefault)
    ::contacts_groups.append(group)
  ::contacts = {}
  foreach (list in ::contacts_groups)
    ::contacts[list] <- []

  if (!isDisableContactsBroadcastEvents)
    ::broadcastEvent("ContactsCleared")
}

let function updateContactsGroups(params) {
  isDisableContactsBroadcastEvents = true

  clear_contacts()

  foreach (listName, list in params.groups) {
    if (list == null
        || (
            contactsGroupsDefault.findvalue(@(gr) gr == listName) == null
            && (
                (listName == EPLX_PS4_FRIENDS && !isPlatformSony)
                || list.len() == 0
              )
          )
       )
      continue

    if (listName == EPL_RECENT_SQUAD) { // Need to save contacts on the client before switching to a contact service
      exportRecentSquadContacts(list)
      continue
    }
    foreach (p in list) {
      let playerUid = p?.userId
      let playerName = p?.nick
      let playerClanTag = p?.clanTag

      let player = addContact(null, listName, {
        uid = playerUid
        playerName = playerName
        clanTag = playerClanTag
      })

      if (!player) {
        let myUserId = ::my_user_id_int64 // warning disable: -declared-never-used
        let errText = playerUid ? "player not found" : "not valid data"
        ::script_net_assert_once("not found contact for group", errText)
        continue
      }
    }
  }

  updateRecentGroup(recentGroup.value)

  isDisableContactsBroadcastEvents = false
}

addListenersWithoutEnv({
  function SignOut(_) {
    recentGroup(null)
    clear_contacts()
  }
  LoginComplete = @(_) loadRecentGroupOnce()
})

return {
  contactsWndSizes
  EPLX_SEARCH
  EPLX_CLAN
  EPLX_PS4_FRIENDS
  contactsGroupsDefault

  verifyContact
  addContact
  addContactGroup
  updateContactsGroups
  clear_contacts

  addRecentContacts
}