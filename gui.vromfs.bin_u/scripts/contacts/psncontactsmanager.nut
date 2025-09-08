from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let logS = log_with_prefix("[PSN: Contacts] ")

let { get_time_msec } = require("dagor.time")
let psn = require("%sonyLib/webApi.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { requestUnknownPSNIds } = require("%scripts/contacts/externalContactsService.nut")
let { psnApprovedUids, psnBlockedUids, findContactByPSNId } = require("%scripts/contacts/contactsManager.nut")
let { fetchContacts, updatePresencesByList } = require("%scripts/contacts/contactsState.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isEqual } = u
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { updateContact } = require("%scripts/contacts/contactsActions.nut")

let isContactsUpdated = mkWatched(persist, "isContactsUpdated", false)

let LIMIT_FOR_ONE_TASK_GET_USERS = 200
let UPDATE_TIMER_LIMIT = 10000
local LAST_UPDATE_FRIENDS = -UPDATE_TIMER_LIMIT
let PSN_RESPONSE_FIELDS = { friends = "friends", blocklist = "blocks" }

let convertPsnContact = @(psnEntry) { accountId = psnEntry }

let pendingContactsChanges = {}
let checkGroups = []

let uidsListByGroupName = {
  [EPL_FRIENDLIST] = psnApprovedUids,
  [EPL_BLOCKLIST] = psnBlockedUids
}

let console2uid = {}

function onPresencesReceived(response, _err) {
  let updPresences = []
  foreach (userInfo in (response?.basicPresences ?? [])) {
    let { accountId = null } = userInfo
    if (accountId == null || (accountId not in console2uid))
      continue

    updPresences.append({
      userId = console2uid[accountId]
      presences = { online = userInfo.onlineStatus == "online" }
    })
  }
  updatePresencesByList(updPresences)
}

function gatherPresences(entries) {
  local accounts = entries.map(@(e) e.accountId)
  while (accounts.len() > 0) {
    let chunk = accounts.slice(0, LIMIT_FOR_ONE_TASK_GET_USERS)
    psn.send(psn.profile.getBasicPresences(chunk), onPresencesReceived)
    accounts = accounts.slice(LIMIT_FOR_ONE_TASK_GET_USERS)
  }
}

function psnUpdateContactsList(usersTable) {
  
  let contactsTable = {}
  foreach (uid, playerData in usersTable) {
    contactsTable[playerData.id] <- updateContact({
      uid = uid
      name = playerData.nick
      psnId = playerData.id
    })
    console2uid[playerData.id] <- uid
  }

  local hasChanged = false
  foreach (groupName, groupData in pendingContactsChanges) {
    let lastUids = uidsListByGroupName[groupName].value
    let curUids = {}

    foreach (userInfo in groupData.users) {
      let contact = contactsTable?[userInfo.accountId]
      if (!contact)
        continue

      let uid = contact.uid
      curUids[uid] <- true
    }
    let hasGroupChanged = !isEqual(curUids, lastUids)
    if (hasGroupChanged)
      uidsListByGroupName[groupName](curUids)
    hasChanged = hasChanged || hasGroupChanged
    if (groupName == EPL_FRIENDLIST && hasGroupChanged)
      gatherPresences(groupData.users)
  }

  pendingContactsChanges.clear()
  if (!hasChanged) {
    logS("Update: No changes. No need to server call")
    return
  }
  fetchContacts()
}

function proceedPlayersList() {
  foreach (groupName in checkGroups)
    if (!(groupName in pendingContactsChanges) || !pendingContactsChanges[groupName].isFinished)
      return

  let playersList = []
  foreach (_groupName, data in pendingContactsChanges)
    playersList.extend(data.users)

  let knownUsers = {}
  for (local i = playersList.len() - 1; i >= 0; i--) {
    let contact = findContactByPSNId(playersList[i].accountId)
    if (contact) {
      knownUsers[contact.uid] <- {
        nick = contact.name
        id = playersList.remove(i).accountId
      }
    }
  }

  requestUnknownPSNIds(
    playersList.map(@(player) player.accountId),
    knownUsers,
    psnUpdateContactsList
  )
}

function onReceviedUsersList(groupName, responseInfoName, response, err) {
  let size = (response?.size ?? 0) + (response?.start ?? 0)
  let total = response?.totalResults ?? size

  if (!(groupName in pendingContactsChanges))
    pendingContactsChanges[groupName] <- {
      isFinished = false
      users = []
    }

  if (!err) {
    foreach (_idx, playerData in (response?[responseInfoName] ?? []))
        pendingContactsChanges[groupName].users.append(convertPsnContact(playerData))
  }
  else {
    logS($"Update {groupName}: received error: {toString(err)}")
    if (u.isString(err.code) || err.code < 500 || err.code >= 600)
      logerr($"[PSN: Contacts] Update {groupName}: received error: {toString(err)}")
  }

  pendingContactsChanges[groupName].isFinished = err || size >= total
  proceedPlayersList()
}

function fetchFriendlist() {
  checkGroups.append(EPL_FRIENDLIST)
  psn.fetch(
    psn.profile.listFriends(),
    @(response, err) onReceviedUsersList(EPL_FRIENDLIST, PSN_RESPONSE_FIELDS.friends, response, err),
    LIMIT_FOR_ONE_TASK_GET_USERS
  )
}

function fetchBlocklist() {
  checkGroups.append(EPL_BLOCKLIST)
  psn.fetch(
    psn.profile.listBlockedUsers(),
    @(response, err) onReceviedUsersList(EPL_BLOCKLIST, PSN_RESPONSE_FIELDS.blocklist, response, err),
    LIMIT_FOR_ONE_TASK_GET_USERS
  )
}

function fetchContactsList() {
  pendingContactsChanges.clear()
  checkGroups.clear()

  fetchFriendlist()
  fetchBlocklist()
}

function updateContacts(needIgnoreInitedFlag = false) {
  if (!isPlatformSony)
    return

  if (!isInMenu.get()) {
    if (needIgnoreInitedFlag && isContactsUpdated.get())
      isContactsUpdated.set(false)
    return
  }

  if (!needIgnoreInitedFlag && isContactsUpdated.get()) {
    if (get_time_msec() - LAST_UPDATE_FRIENDS > UPDATE_TIMER_LIMIT)
      LAST_UPDATE_FRIENDS = get_time_msec()
    else
      return
  }

  isContactsUpdated.set(true)
  fetchContactsList()
}

function onPresenceUpdate(data) {
  let accountId = data?.accountId
  if (accountId) {
    let userId = console2uid?[accountId.tostring()]
    let contact = ::getContact(userId)
    if (contact == null)
      return

    updatePresencesByList([{
      userId
      presences = { online = !contact.online }
    }])
  }
}

function onPushNotification(_) {
  updateContacts(true)
}

function initHandlers() {
  updateContacts(true)
  psn.subscribe.friendslist(onPushNotification)
  psn.subscribe.blocklist(onPushNotification)
  psn.subscribeToPresenceUpdates(onPresenceUpdate)
}

function disposeHandlers() {
  pendingContactsChanges.clear()
  isContactsUpdated.set(false)
  psnApprovedUids.set({})
  psnBlockedUids.set({})

  psn.unsubscribe.friendslist(onPushNotification)
  psn.unsubscribe.blocklist(onPushNotification)
  psn.unsubscribeFromPresenceUpdates(onPresenceUpdate)
  psn.abortAllPendingRequests()
}

addListenersWithoutEnv({
  LoginComplete = @(_) initHandlers()
  SignOut = @(_) disposeHandlers()
})

if (isLoggedIn.get())
  initHandlers()

return {
  updateContacts
}
