//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
//checked for explicitness
#no-root-fallback
#explicit-this

let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { requestUnknownXboxIds } = require("%scripts/contacts/externalContactsService.nut")
let { xboxApprovedUids, xboxBlockedUids } = require("%scripts/contacts/contactsManager.nut")
let { fetchContacts, updatePresencesByList } = require("%scripts/contacts/contactsState.nut")
let { subscribe_to_presence_update_events, set_presence, DeviceType } = require("%xboxLib/impl/presence.nut")
let { get_title_id } = require("%xboxLib/impl/app.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let logX = log_with_prefix("[XBOX PRESENCE] ")
let { update_presences_for_users } = require("%xboxLib/presence.nut")
let { Permission, check_for_users } = require("%xboxLib/impl/permissions.nut")
let { isEqual } = u

let persistent = { isInitedXboxContacts = false }
let pendingXboxContactsToUpdate = {}

registerPersistentData("XboxContactsManagerGlobals", persistent, ["isInitedXboxContacts"])

let presenceStatuses = {
  ONLINE = "online"
  IN_GAME = "in_game"
}

let console2uid = {}

let uidsListByGroupName = {
  [EPL_FRIENDLIST] = xboxApprovedUids,
  [EPL_BLOCKLIST] = xboxBlockedUids
}

let function updateContactXBoxPresence(xboxId, isAllowed) {
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

let function fetchContactsList() {
  pendingXboxContactsToUpdate.clear()
  //No matter what will be done first,
  //anyway, we will wait all groups data.
  ::xbox_get_people_list_async()
  ::xbox_get_avoid_list_async()
}

let function updateContacts(needIgnoreInitedFlag = false) {
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

let function xboxUpdateContactsList(usersTable) {
  //Create or update exist contacts
  let contactsTable = {}
  foreach (uid, playerData in usersTable) {
    contactsTable[playerData.id] <- ::updateContact({
      uid = uid
      name = playerData.nick
      xboxId = playerData.id
    })
    console2uid[playerData.id] <- uid
  }

  local hasChanged = false
  foreach (groupName, playersArray in pendingXboxContactsToUpdate) {
    let lastUids = uidsListByGroupName[groupName].value
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
      uidsListByGroupName[groupName](curUids)
    hasChanged = hasChanged || hasGroupChanged
    if (groupName == EPL_FRIENDLIST && playersArray.len() > 0)
      update_presences_for_users(playersArray.map(@(v) v.tointeger()))
  }

  pendingXboxContactsToUpdate.clear()
  if (!hasChanged) {
    log("XBOX CONTACTS: Update: No changes. No need to server call")
    return
  }
  fetchContacts()
}

let function proceedXboxPlayersList() {
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

  requestUnknownXboxIds(
    playersList,
    knownUsers,
    Callback(xboxUpdateContactsList, this)
  )
}

let function onReceivedXboxListCallback(playersList, group) {
  pendingXboxContactsToUpdate[group] <- playersList
  proceedXboxPlayersList()
}

let function xboxOverlayContactClosedCallback(playerStatus) {
  if (playerStatus == XBOX_PERSON_STATUS_CANCELED)
    return

  fetchContactsList()
}

let function setXboxPresence(isInBattle) {
  if (!::g_login.isLoggedIn())
    return

  let presence = isInBattle ? presenceStatuses.IN_GAME
    : presenceStatuses.ONLINE
  set_presence(presence, function(success) {
    logX($"Set user presence: {presence}, succeeded: {success}")
  })
}

isInBattleState.subscribe(setXboxPresence)

let function on_presences_update(success, presences) {
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

local request_unknown_ids = function(_unknown_list, _known_list, _current_idx, _callback) {} //fwd decl
request_unknown_ids = function(unknown_list, known_list, current_idx, callback) {
  if (unknown_list.len() == 0) {
    callback(known_list)
    return
  }
  local curContact = unknown_list[current_idx]
  logX($"Requesting xuid for {curContact.uid}")
  curContact.getXboxId(function() {
    known_list.append(curContact)
    let nextIdx = current_idx + 1
    if (nextIdx < unknown_list.len())
      request_unknown_ids(unknown_list, known_list, nextIdx, callback)
    else
      callback(known_list)
  })
}


addListenersWithoutEnv({
  function SignOut(_) {
    pendingXboxContactsToUpdate.clear()
    persistent.isInitedXboxContacts = false
  }

  function XboxSystemUIReturn(_) {
    if (!::g_login.isLoggedIn())
      return

    updateContacts(true)
  }

  function ContactsUpdated(_) {
    if (!is_platform_xbox)
      return

    let xboxContactsToCheck = u.filter(::contacts_players, @(contact) contact.needCheckForceOffline())
    local knownContacts = []
    local unknownContacts = []
    xboxContactsToCheck.each(function(contact) {
      if (contact.xboxId != "")
        knownContacts.append(contact)
      else
        unknownContacts.append(contact)
    })

    request_unknown_ids(unknownContacts, knownContacts, 0, function(result_contacts) {
      local xuidsForRequest = []
      foreach (contact in result_contacts) {
        if (contact.xboxId == "") {
          logX($"{contact.uid} doesn't have valid xuid, skipping it")
          continue
        }
        xuidsForRequest.append(contact.xboxId.tointeger())
      }
      if (xuidsForRequest.len() > 0) {
        check_for_users(Permission.ViewTargetPresence, xuidsForRequest, function(success, results) {
          if (success) {
            foreach (result in results) {
              let xuid = result?.xuid ?? 0
              let allowed = result?.allowed ?? false
              updateContactXBoxPresence(xuid, allowed)
            }
          } else {
            logX("Failed to check target presence for users")
          }
          updateContacts()
        })
      } else {
        logX("No contacts to update, skipping")
      }
    })
  }

  LoginComplete = @(_) setXboxPresence(isInBattleState.value)
})

return {
  fetchContactsList = fetchContactsList
  onReceivedXboxListCallback = onReceivedXboxListCallback

  xboxOverlayContactClosedCallback = xboxOverlayContactClosedCallback

  updateContactXBoxPresence = updateContactXBoxPresence
  updateContacts = updateContacts
}
