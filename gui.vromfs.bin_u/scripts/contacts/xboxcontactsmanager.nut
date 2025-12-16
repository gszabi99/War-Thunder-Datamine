from "%scripts/dagui_library.nut" import *

let { is_gdk } = require("%sqstd/platform.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { requestUnknownXboxIds } = require("%scripts/contacts/externalContactsService.nut")
let { xboxApprovedUids, xboxBlockedUids, contactsPlayers, findContactByXboxId } = require("%scripts/contacts/contactsListState.nut")
let { fetchContacts, updatePresencesByList } = require("%scripts/contacts/contactsState.nut")
let { subscribe_to_presence_update_events, retrieve_presences_for_users, DeviceType } = require("%gdkLib/impl/presence.nut")
let { get_title_id } = require("%gdkLib/impl/app.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let logX = log_with_prefix("[XBOX PRESENCE] ")
let { update_friends_list, update_avoid_list, retrieve_related_people_list, retrieve_avoid_people_list } = require("%gdkLib/impl/relationships.nut")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { updateContact } = require("%scripts/contacts/contactsActions.nut")

let persistent = { isInitedXboxContacts = false }
let pendingXboxContactsToUpdate = {}

registerPersistentData("XboxContactsManagerGlobals", persistent, ["isInitedXboxContacts"])

let console2uid = {}

let uidsListByGroupName = {
  [EPL_FRIENDLIST] = xboxApprovedUids,
  [EPL_BLOCKLIST] = xboxBlockedUids
}

local processXboxPlayersList = function() {} 


function updateContactPresence(contact, isAllowed) {
  if (!contact)
    return

  let forceOffline = !isAllowed
  if (contact.forceOffline == forceOffline && contact.isForceOfflineChecked)
    return

  updateContact({
    uid = contact.uid
    forceOffline = forceOffline
    isForceOfflineChecked = true
  })
}

function updateContactXBoxPresence(xboxId, isAllowed) {
  let contact = findContactByXboxId(xboxId)
  updateContactPresence(contact, isAllowed)
}

function fetchContactsList() {
  pendingXboxContactsToUpdate.clear()

  update_friends_list(false, function(_) {
    retrieve_related_people_list(function(flist) {
      pendingXboxContactsToUpdate[EPL_FRIENDLIST] <- flist.map(@(v) v.tostring())
      update_avoid_list(false, function(_) {
        retrieve_avoid_people_list(function(alist) {
          pendingXboxContactsToUpdate[EPL_BLOCKLIST] <- alist.map(@(v) v.tostring())
          processXboxPlayersList()
        })
      })
    })
  })
}

function updateContacts(needIgnoreInitedFlag = false) {
  if (!is_gdk || !isInMenu.get()) {
    if (needIgnoreInitedFlag && persistent.isInitedXboxContacts)
      persistent.isInitedXboxContacts = false
    return
  }

  if (!needIgnoreInitedFlag && persistent.isInitedXboxContacts)
    return

  persistent.isInitedXboxContacts = true
  fetchContactsList()
}

function xboxUpdateContactsList(usersTable) {
  
  let contactsTable = {}
  foreach (uid, playerData in usersTable) {
    contactsTable[playerData.id] <- updateContact({
      uid = uid
      name = playerData.nick
      xboxId = playerData.id
    })
    console2uid[playerData.id] <- uid
  }

  local hasChanged = false
  foreach (groupName, playersArray in pendingXboxContactsToUpdate) {
    let lastUids = uidsListByGroupName[groupName].get()
    let curUids = {}
    foreach (xboxPlayerId in playersArray) {
      let contact = contactsTable?[xboxPlayerId]
      if (!contact)
        continue

      let uid = contact.uid
      curUids[uid] <- true
    }
    let hasGroupChanged = !isEqual(curUids, lastUids)
    if (hasGroupChanged)
      uidsListByGroupName[groupName].set(curUids)
    hasChanged = hasChanged || hasGroupChanged
    if (groupName == EPL_FRIENDLIST && playersArray.len() > 0)
      retrieve_presences_for_users(playersArray.map(@(v) v.tointeger()))
  }

  pendingXboxContactsToUpdate.clear()
  if (!hasChanged) {
    log("XBOX CONTACTS: Update: No changes. No need to server call")
    return
  }
  fetchContacts()
}

processXboxPlayersList = function() {
  logX("Processing xbox players lists")

  let playersList = []
  foreach (_group, usersArray in pendingXboxContactsToUpdate)
    playersList.extend(usersArray)

  let knownUsers = {}
  for (local i = playersList.len() - 1; i >= 0; i--) {
    let contact = findContactByXboxId(playersList[i])
    if (contact) {
      knownUsers[contact.uid] <- {
        nick = contact.name
        id = playersList.remove(i)
      }
    }
  }

  requestUnknownXboxIds(
    playersList,
    knownUsers,
    Callback(xboxUpdateContactsList, this)
  )
}

function on_presences_update(success, presences) {
  if (!success) {
    logX("Failed to update presences for users")
    return
  }

  let updPresences = []
  foreach (data in presences) {
    let xuid = data.xuid.tostring()
    if (xuid not in console2uid)
      continue

    let player = {
      userId = console2uid[xuid]
      presences = { online = false }
    }

    if (!data?.activeDevices.len()) {
      updPresences.append(player)
      continue
    }

    foreach (actDev in data.activeDevices) {
      if (actDev.type == DeviceType.XboxOne || actDev.type == DeviceType.Scarlett) {
        if ("activeTitles" not in actDev) {
          player.presences.online = true
          break
        }

        foreach (actTitle in actDev.activeTitles)
          if (actTitle.titleId == get_title_id()) {
            player.presences.online = true
            break
          }
      }
    }
    updPresences.append(player)
  }

  logX("Update presences:", updPresences)
  updatePresencesByList(updPresences)
}

subscribe_to_presence_update_events(on_presences_update)


addListenersWithoutEnv({
  function SignOut(_) {
    pendingXboxContactsToUpdate.clear()
    persistent.isInitedXboxContacts = false
    xboxApprovedUids.set({})
    xboxBlockedUids.set({})
  }

  function XboxSystemUIReturn(_) {
    if (!isLoggedIn.get())
      return

    updateContacts(true)
  }

  function ContactsUpdated(_) {
    if (!is_gdk)
      return

    let xboxContactsToCheck = contactsPlayers.filter(@(contact) contact.needCheckForceOffline())
    xboxContactsToCheck.each(function(contact) {
      updateContactPresence(contact, false)
    })
  }
})

return {
  fetchContactsList = fetchContactsList

  updateContactXBoxPresence = updateContactXBoxPresence
  updateContacts = updateContacts
}
