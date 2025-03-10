from "%scripts/dagui_library.nut" import *

let { get_friends_ids, get_friend_info, steam_is_running, steam_get_app_id } = require("steam")
let { eventbus_subscribe } = require("eventbus")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { requestUnknownSteamIds } = require("%scripts/contacts/externalContactsService.nut")
let { findContactBySteamId, steamContactsGroup } = require("%scripts/contacts/contactsManager.nut")
let { updateContactPresence } = require("%scripts/contacts/contactPresence.nut")
let Contact = require("%scripts/contacts/contact.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { updateContact } = require("%scripts/contacts/contactsActions.nut")

enum STEAM_FRIEND_STATE { 
  OFFLINE
  ONLINE
  BUSY
  AWAY
  SNOOZE
  TO_TRADE 
  TO_PLAY 
}

let onlineStates = {
  [STEAM_FRIEND_STATE.ONLINE] = true,
  [STEAM_FRIEND_STATE.TO_TRADE] = true,
  [STEAM_FRIEND_STATE.TO_PLAY] = true
}

let steamFriendsList = persist("steamFriendsList", @() {})

let steam2uid = {}

let isInWtOnline = @(friend, steamAppId = null) friend.gamePlayed == (steamAppId ?? steam_get_app_id())

function steamUpdateContactsList(usersTable) {
  
  let steamAppId = steam_get_app_id()
  let res = {}
  foreach (uid, playerData in usersTable) {
    let steamId = playerData?.id.tointeger()
    let friend = steamFriendsList?[steamId]
    if (friend == null)
      continue
    res[steamId] <- updateContact({
      uid = uid
      name = playerData.nick
      steamId
      steamName = friend.name
      steamAvatar = friend.icon
      online = isInWtOnline(friend, steamAppId)
      unknown = false
      isSteamOnline = friend.status in onlineStates
    })
    steam2uid[steamId] <- uid
  }

  foreach (steamId, friend in steamFriendsList) {
    if (steamId in steam2uid)
      continue
    let contact = Contact({
      steamId
      steamName = friend.name
      steamAvatar = friend.icon
      online = isInWtOnline(friend, steamAppId)
      unknown = false
      isSteamOnline = friend.status in onlineStates
    })
    updateContactPresence(contact)
    res[steamId] <- contact
  }

  steamContactsGroup.set(res)
}

function proceedPlayersList() {
  let playersList = steamFriendsList.keys()
  let knownUsers = {}
  for (local i = playersList.len() - 1; i >= 0; i--) {
    let contact = findContactBySteamId(playersList[i])
    if (contact) {
      knownUsers[contact.uid] <- {
        nick = contact.name
        id = playersList.remove(i)
      }
    }
  }

  requestUnknownSteamIds(playersList, knownUsers, steamUpdateContactsList)
}

function isChangedFriendsIds(friendsIds) {
  if (friendsIds.len() != steamFriendsList.len())
    return true

  return friendsIds.findindex(@(steamId) steamId not in steamFriendsList) != null
}

function updateSteamFriendsList() {
  if (!steam_is_running() || !hasFeature("SteamFriends"))
    return

  let friendsIds = get_friends_ids()
  if (!isChangedFriendsIds(friendsIds))
    return

  steamFriendsList.clear()
  foreach (steamId in friendsIds)
    steamFriendsList[steamId] <- get_friend_info(steamId)

  proceedPlayersList()
}

function clearContacts() {
  steamContactsGroup.set(null)
  steamFriendsList.clear()
}

if (isLoggedIn.get())
  updateSteamFriendsList()

eventbus_subscribe("steam.friend_state", function(p) {
  let { steamId = null, flags = STEAM_FRIEND_STATE.OFFLINE } = p
  if (steamId not in steamFriendsList)
    return

  let friend = steamFriendsList[steamId]
  friend.status = flags

  let contact = steamContactsGroup.get()?[steamId]
  if (contact == null)
    return
  contact.update({
    online = isInWtOnline(friend)
    unknown = false
    isSteamOnline = friend.status in onlineStates
  })
  updateContactPresence(contact)
})

addListenersWithoutEnv({
  function SteamOverlayStateChanged(p) {
    if (p.active)
      return

    updateSteamFriendsList()
  }

  LoginComplete = @(_) updateSteamFriendsList()
  SignOut = @(_) clearContacts()
})
