from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { requestUnknownXboxIds } = require("%scripts/contacts/externalContactsService.nut")
let { isMultiplayerPrivilegeAvailable,
      checkAndShowMultiplayerPrivilegeWarning } = require("%scripts/user/xboxFeatures.nut")
let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { send_invitation } = require("%scripts/social/xboxSquadManager/impl.nut")


let ignoreSystemInvite = mkWatched(persist, "ignoreSystemInvite", false)
let isSquadStatusCheckedOnce = mkWatched(persist, "isSquadStatusCheckedOnce", false)
let xboxIsGameStartedByInvite = mkWatched(persist, "xboxIsGameStartedByInvite", ::xbox_is_game_started_by_invite())
let lastReceivedUsersCache = mkWatched(persist, "lastReceivedUsersCache", [])
let currentUsersListCache = mkWatched(persist, "currentUsersListCache", [])
let squadExistCheckArray = mkWatched(persist, "squadExistCheckArray", [])
let suspendedData = mkWatched(persist, "suspendedData", null)

local needCheckSquadInvites = false
local needCheckSquadInvitesOnContactsUpdate = false
local notFoundIds = []

let function invalidateCache() {
  lastReceivedUsersCache.update([])
  currentUsersListCache.update([])
  squadExistCheckArray.update([])
  isSquadStatusCheckedOnce.update(false)
  xboxIsGameStartedByInvite.update(false)
  ignoreSystemInvite.update(false)

  needCheckSquadInvites = false
  needCheckSquadInvitesOnContactsUpdate = false
  suspendedData.update(null)
}

let function checkAndDisplayInviteRestiction() {
  if (!ignoreSystemInvite.value)
    return false

  log($"XBOX SQUAD MANAGER: show invite warning restriction, {isMultiplayerPrivilegeAvailable.value}")
  ignoreSystemInvite.update(false)

  if (!isMultiplayerPrivilegeAvailable.value)
    checkAndShowMultiplayerPrivilegeWarning()
  else
    ::g_popups.add(loc("squad/name"), loc("squad/wait_until_battle_end"))

  return true
}

let isMeLeaderByList = @(xboxIdsList) xboxIdsList?[0] == ::get_my_external_id(EPL_XBOXONE)

let function isMeLeader(xboxIdsList)
{
  if (!::g_squad_manager.isInSquad())
    return isMeLeaderByList(xboxIdsList)
  if (::g_squad_manager.isSquadMember())
    return false //!!FIX ME: Better to add squad leave logic here when im real leader.

  if (isMeLeaderByList(xboxIdsList))
    return true

  foreach(member in ::g_squad_manager.getMembers())
  {
    if (member.isMe())
      continue
    let contact = ::getContact(member.uid)
    if (isInArray(contact?.xboxId, xboxIdsList)) //other xbox squad member in my squad already
      return true
  }
  return false
}

let function acceptExistingInvite(playerUid)
{
  let inviteUid = ::g_invites_classes.Squad.getUidByParams({squadId = playerUid})
  let invite = ::g_invites.findInviteByUid(inviteUid)
  if (!invite)
    return false

  invite.checkAutoAcceptXboxInvite()
  return true
}

let function proceedExistedSquadsInfo(params)
{
  if (!::checkMatchingError(params))
    return

  let squads = params?.squads ?? []
  if (!squads.len())
    return

  foreach (squad in squads)
  {
    let membersCount = (squad?.members ?? []).len()
    let maxMembers = squad?.data?.properties?.maxMembers ?? 0
    if (membersCount != 0 && membersCount >= maxMembers)
    {
      ::g_popups.add(null, loc("matching/SQUAD_FULL"))
      return
    }
  }
}

let function checkExistedSquads()
{
  if (::g_squad_manager.isInSquad() || !squadExistCheckArray.value.len())
  {
    squadExistCheckArray.update([])
    return
  }

  let cb = Callback(proceedExistedSquadsInfo, this)
  ::matching_api_func("msquad.get_squads", cb, {players = squadExistCheckArray.value})
}

let function proceedContact(contact, needInviteUser = true)
{
  if (!contact)
    return false

  if (needInviteUser)
  {
    if (::g_squad_manager.canInviteMember(contact.uid) && !::g_squad_manager.isPlayerInvited(contact.uid, contact.name))
      ::g_squad_manager.inviteToSquad(contact.uid, contact.name)
  }
  else if (::g_squad_manager.canDismissMember(contact.uid))
    ::g_squad_manager.dismissFromSquad(contact.uid)
  return true
}

let function validateList(xboxIdsList)
{
  foreach (id in xboxIdsList)
    if (!isInArray(id, lastReceivedUsersCache.value))
      if (!proceedContact(::findContactByXboxId(id), true) && !isInArray(id, notFoundIds))
        notFoundIds.append(id)

  foreach (id in lastReceivedUsersCache.value)
    if (!isInArray(id, xboxIdsList))
      if (!proceedContact(::findContactByXboxId(id), false) && !isInArray(id, notFoundIds))
        notFoundIds.append(id)

  lastReceivedUsersCache.update(clone xboxIdsList)
}

let function checkFoundIds(p)
{
  if (!notFoundIds.len())
    return

  let isLeader = isMeLeader(currentUsersListCache.value)
  foreach(uid, data in p)
  {
    let contact = ::getContact(uid, data.nick)
    if (isLeader && !proceedContact(contact))
      log($"XBOX_SQUAD_MANAGER: Not found xboxId {data.id} after charServer call")

    if (contact)
    {
      contact.update({xboxId = data.id})
      if (needCheckSquadInvitesOnContactsUpdate)
      {
        if (acceptExistingInvite(uid))
          needCheckSquadInvitesOnContactsUpdate = false
        else
          squadExistCheckArray.mutate(@(v) v.append(contact.uidInt64))
      }
    }
  }
  notFoundIds.clear()
  checkExistedSquads()
}

let function requestUnknownIds(idsList)
{
  if (!idsList.len())
    return

  requestUnknownXboxIds(idsList, {}, Callback(checkFoundIds, this))
}

let function checkSquadInvites(xboxIdsList)
{
  let idsArray = []
  squadExistCheckArray.update([])
  foreach (xboxId in xboxIdsList)
  {
    let contact = ::findContactByXboxId(xboxId)
    if (contact)
    {
      if (contact.isMe())
        continue

      if (acceptExistingInvite(contact.uid))
        return

      squadExistCheckArray.mutate(@(v) v.append(contact.uidInt64))
    }
    else
      idsArray.append(xboxId)
  }

  if (!idsArray.len())
  {
    checkExistedSquads()
    return
  }

  notFoundIds = clone idsArray
  needCheckSquadInvitesOnContactsUpdate = true
  requestUnknownIds(notFoundIds)
}

let function updateSquadList(xboxIdsList = [], isScriptCall = false)
{
  if (!isPlatformXboxOne)
    return

  if (!isMultiplayerPrivilegeAvailable.value) {
    ignoreSystemInvite.update(true) //It is called after update
    invalidateCache()

    //updateSquadList was called from script,
    //so no need to wait xbox_on_invite_accepted call
    if (isScriptCall)
      checkAndDisplayInviteRestiction()
    return
  }

  if (!::isInMenu() || !::g_login.isLoggedIn())
  {
    needCheckSquadInvites = true
    log($"XBOX SQUAD MANAGER: set needCheckSquadInvites <{needCheckSquadInvites}>; {toString(xboxIdsList)}")
    suspendedData.update(clone xboxIdsList)
    return
  }

  if (!xboxIdsList || !xboxIdsList.len()) //C++ code return empty array when leader is in battle or offline
  {
    log($"XBOX SQUAD MANAGER: show popup in updateSquadList, needCheckSquadInvites {needCheckSquadInvites}")
    invalidateCache()
    return
  }

  currentUsersListCache.update(clone xboxIdsList)
  if (!isMeLeader(xboxIdsList))
  {
    if (needCheckSquadInvites)
    {
      log("XBOX SQUAD MANAGER: player is not a leader. Requested to check invites on squad update.")
      checkSquadInvites(currentUsersListCache.value)
    }
    else {
      log("XBOX SQUAD MANAGER: player is not a leader. Don't proceed invites.")
      invalidateCache()
    }
    return
  }

  notFoundIds.clear()
  validateList(xboxIdsList)
  log($"XBOX SQUAD MANAGER: notFoundIds {notFoundIds.len()}")

  requestUnknownIds(notFoundIds)
}

let function checkAfterFlight()
{
  if (!isPlatformXboxOne)
    return

  if (isSquadStatusCheckedOnce.value)
    return

  log($"XBOX SQUAD MANAGER: launch checkAfterFlight, suspendedData <{suspendedData.value}>; {::isInMenu()}")
  if (!::isInMenu())
  {
    log("XBOX SQUAD MANAGER: launch checkAfterFlight, terminate process, not in menu.")
    return
  }

  if (suspendedData.value)
  {
    isSquadStatusCheckedOnce.update(true)
    updateSquadList(suspendedData.value, true)
  }

  if (xboxIsGameStartedByInvite.value && !suspendedData.value && !isSquadStatusCheckedOnce.value && !::g_squad_manager.isInSquad())
  {
    log($"XBOX SQUAD MANAGER: show popup in checkAfterFlight, needCheckSquadInvites {needCheckSquadInvites}")
    ::g_popups.add(loc("squad/name"), loc("squad/wait_until_battle_end"))
  }

  suspendedData.update(null)
}

let function isPlayerFromXboxSquadList(userXboxId = "")
{
  checkAfterFlight()

  return isInArray(userXboxId, currentUsersListCache.value)
}

let function sendSystemInvite(uid, name)
{
  //Check, if player not in system lobby already.
  //Because, no need to send system invitation if he is there already.

  let contact = ::getContact(uid, name)
  if (contact.needCheckXboxId())
    contact.getXboxId(Callback(function() {
      if (!isInArray(contact.xboxId, currentUsersListCache.value))
        @() send_invitation(contact.xboxId)
    }, this))
  else if (contact.xboxId != "")
  {
    if (!isInArray(contact.xboxId, currentUsersListCache.value))
      send_invitation(contact.xboxId)
  }
}

let function checkInviteRestrictions()
{
  log("XBOX SQUAD MANAGER: onEventXboxInviteAccepted")

  if (checkAndDisplayInviteRestiction())
    return

  needCheckSquadInvites = true
  if (::is_in_flight())
  {
    log("XBOX SQUAD MANAGER: Event: XboxInviteAccepted: quit mission")
    ::quit_mission()
  }
}

addListenersWithoutEnv({
  XboxInviteAccepted = @(p) checkInviteRestrictions()
  SquadStatusChanged = @(p) ::g_squad_manager.isInSquad() ? null : invalidateCache()
  SignOut = @(p) invalidateCache()
}, ::g_listener_priority.DEFAULT_HANDLER)

::xbox_update_squad <- @(xboxIdsList) updateSquadList.bindenv(this)(xboxIdsList)
::xbox_on_invite_accepted <- @() ::broadcastEvent("XboxInviteAccepted")

return {
  needProceedSquadInvitesAccept = @() needCheckSquadInvites
  isPlayerFromXboxSquadList
  sendSystemInvite
  checkAfterFlight
}