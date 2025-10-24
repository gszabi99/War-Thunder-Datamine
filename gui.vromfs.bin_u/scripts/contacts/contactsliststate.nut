from "%scripts/dagui_library.nut" import *
from "%scripts/contacts/contactsConsts.nut" import GAME_GROUP_NAME
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")

let contactsWndSizes = Watched(null)

let steamContactsGroup = mkWatched(persist, "steamContactsGroup", null)
let recentGroup = hardPersistWatched("recentGroup", null)
let blockedMeUids = hardPersistWatched("blockedMeUids", {})
let psnApprovedUids = hardPersistWatched("psnApprovedUids", {})
let psnBlockedUids = hardPersistWatched("psnBlockedUids", {})
let xboxApprovedUids = hardPersistWatched("xboxApprovedUids", {})
let xboxBlockedUids = hardPersistWatched("xboxBlockedUids", {})

let clanUserTable = mkWatched(persist, "clanUserTable", {})
let contactsGroups = persist("contactsGroups", @() [])
let contactsByName = persist("contactsByName", @() {})
let contactsPlayers = persist("contactsPlayers", @() {})







let contactsByGroups = persist("contactsByGroups", @() {})















let predefinedContactsGroupToWtGroup = { 
  approved = EPL_FRIENDLIST
  myRequests = EPL_FRIENDLIST
  myBlacklist = EPL_BLOCKLIST
}

let cacheContactByName = @(contact) contactsByName[contact.name] <- contact
let getContactByName = @(name) contactsByName?[name]

let findContactByPSNId = @(psnId) contactsPlayers.findvalue(@(player) player.psnId == psnId)

function findContactByXboxId(xboxId) {
  foreach (_uid, player in contactsPlayers)
    if (player.xboxId == xboxId)
      return player
  return null
}

blockedMeUids.subscribe(@(_) broadcastEvent("ContactsBlockStatusUpdated"))

function updateContactsListFromContactsServer(res) {
  let blockedMe = res?[GAME_GROUP_NAME].meInBlacklist ?? []
  let newBlockedMeUids = {}
  let uidsChanged = {}
  foreach (contact in blockedMe) {
    if ("uid" not in contact)
      continue

    let uidStr = contact.uid.tostring()
    newBlockedMeUids[uidStr] <- true
    if (uidStr not in blockedMeUids.get())
      uidsChanged[uidStr] <- true
  }
  if (uidsChanged.len() == 0 && newBlockedMeUids.len() == blockedMeUids.get().len()) 
    return

  foreach (uid, _ in blockedMeUids.get())
    if (uid not in newBlockedMeUids)
      uidsChanged[uid] <- false

  blockedMeUids.set(newBlockedMeUids)
  foreach (uid, _ in uidsChanged)
    if (uid in contactsPlayers)
      contactsPlayers[uid].updateMuteStatus()
}

let findContactBySteamId = @(steamId) contactsPlayers.findvalue(@(player) player.steamId == steamId)

function getContactsGroupUidList(groupName) {
  let res = []
  if (!(groupName in contactsByGroups))
    return res
  return contactsByGroups[groupName].keys()
}

return {
  contactsWndSizes
  updateContactsListFromContactsServer
  predefinedContactsGroupToWtGroup
  recentGroup
  blockedMeUids
  psnApprovedUids
  psnBlockedUids
  xboxApprovedUids
  xboxBlockedUids
  contactsGroups
  contactsPlayers
  contactsByGroups
  cacheContactByName
  getContactByName
  findContactBySteamId
  steamContactsGroup
  getContactsGroupUidList
  clanUserTable
  findContactByPSNId
  findContactByXboxId
}