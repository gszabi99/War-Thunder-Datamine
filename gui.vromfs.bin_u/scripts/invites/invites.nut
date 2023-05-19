//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock = require("DataBlock")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { g_script_reloader, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { startsWith } = require("%sqstd/string.nut")

::g_invites <- {
  [PERSISTENT_DATA_PARAMS] = ["list", "newInvitesAmount"]

  popupTextColor = "@chatInfoColor"

  list = []
  newInvitesAmount = 0
  refreshInvitesTask = -1
  userlogHandlers = {}
}

::g_invites.addInvite <- function addInvite(inviteClass, params) {
  this.checkCleanList()

  let uid = inviteClass.getUidByParams(params)
  local invite = this.findInviteByUid(uid)
  if (invite) {
    invite.updateParams(params)
    this.updateNewInvitesAmount()
    this.broadcastInviteUpdated(invite)
    return invite
  }

  invite = inviteClass(params)
  if (invite.isValid()) {
    this.list.append(invite)
    this.updateNewInvitesAmount()
    this.broadcastInviteReceived(invite)
  }
  return invite
}

::g_invites.broadcastInviteReceived <- function broadcastInviteReceived(invite) {
  if (!invite.isDelayed && !invite.isAutoAccepted)
    broadcastEvent("InviteReceived", { invite = invite })
}

::g_invites.broadcastInviteUpdated <- function broadcastInviteUpdated(invite) {
  if (invite.isVisible())
    broadcastEvent("InviteUpdated", { invite = invite })
}

::g_invites.addChatRoomInvite <- function addChatRoomInvite(roomId, inviterName) {
  return this.addInvite(::g_invites_classes.ChatRoom, { roomId = roomId, inviterName = inviterName })
}

::g_invites.addSessionRoomInvite <- function addSessionRoomInvite(roomId, inviterUid, inviterName, password = null) {
  return this.addInvite(::g_invites_classes.SessionRoom,
                   {
                     roomId      = roomId
                     inviterUid  = inviterUid
                     inviterName = inviterName
                     password    = password
                   })
}

::g_invites.addTournamentBattleInvite <- function addTournamentBattleInvite(battleId, inviteTime, startTime, endTime) {
  return this.addInvite(::g_invites_classes.TournamentBattle,
                   {
                     battleId = battleId
                     inviteTime = inviteTime
                     startTime = startTime
                     endTime = endTime
                   })
}

::g_invites.addInviteToSquad <- function addInviteToSquad(squadId, leaderId) {
  return this.addInvite(::g_invites_classes.Squad, { squadId = squadId, leaderId = leaderId })
}

::g_invites.removeInviteToSquad <- function removeInviteToSquad(squadId) {
  let uid = ::g_invites_classes.Squad.getUidByParams({ squadId = squadId })
  let invite = this.findInviteByUid(uid)
  if (invite)
    this.remove(invite)
}

::g_invites.addFriendInvite <- function addFriendInvite(name, uid) {
  if (u.isEmpty(name) || u.isEmpty(uid))
    return
  return this.addInvite(::g_invites_classes.Friend, { inviterName = name, inviterUid = uid })
}

::g_invites._lastCleanTime <- -1
::g_invites.checkCleanList <- function checkCleanList() {
  local isRemoved = false
  for (local i = this.list.len() - 1; i >= 0; i--)
    if (this.list[i].isOutdated()) {
      this.list.remove(i)
      isRemoved = true
    }
  if (isRemoved)
    broadcastEvent("InviteRemoved")
}

::g_invites.remove <- function remove(invite) {
  foreach (idx, inv in this.list)
    if (inv == invite) {
      invite.onRemove()
      this.list.remove(idx)
      this.updateNewInvitesAmount()
      broadcastEvent("InviteRemoved")
      break
    }
}

::g_invites.findInviteByChatLink <- function findInviteByChatLink(link) {
  foreach (invite in this.list)
    if (invite.checkChatLink(link))
      return invite
  return null
}

::g_invites.findInviteByUid <- function findInviteByUid(uid) {
  foreach (invite in this.list)
    if (invite.uid == uid)
      return invite
  return null
}

::g_invites.acceptInviteByLink <- function acceptInviteByLink(link) {
  if (!startsWith(link, ::BaseInvite.chatLinkPrefix))
    return false

  let invite = ::g_invites.findInviteByChatLink(link)
  if (invite && !invite.isOutdated())
    invite.accept()
  else
    this.showExpiredInvitePopup()
  return true
}

::g_invites.showExpiredInvitePopup <- function showExpiredInvitePopup() {
  ::g_popups.add(null, colorize(this.popupTextColor, loc("multiplayer/invite_is_overtimed")))
}

::g_invites.showLeaveSessionFirstPopup <- function showLeaveSessionFirstPopup() {
  ::g_popups.add(null, colorize(this.popupTextColor, loc("multiplayer/leave_session_first")))
}

::g_invites.markAllSeen <- function markAllSeen() {
  local changed = false
  foreach (invite in this.list)
    if (invite.markSeen(true))
      changed = true

  if (changed)
    this.updateNewInvitesAmount()
}

::g_invites.updateNewInvitesAmount <- function updateNewInvitesAmount() {
  local amount = 0
  foreach (invite in this.list)
    if (invite.isNew() && invite.isVisible())
      amount++
  if (amount == this.newInvitesAmount)
    return

  this.newInvitesAmount = amount
  ::do_with_all_gamercards(::update_gc_invites)
}

::g_invites._timedInvitesUpdate <- function _timedInvitesUpdate(_dt = 0) {
  let now = ::get_charserver_time_sec()
  this.checkCleanList()

  foreach (invite in this.list)
    invite.updateDelayedState(now)

  this.updateNewInvitesAmount()

  ::g_invites.rescheduleInvitesTask()
}

::g_invites.rescheduleInvitesTask <- function rescheduleInvitesTask() {
  if (this.refreshInvitesTask >= 0) {
    ::periodic_task_unregister(this.refreshInvitesTask)
    this.refreshInvitesTask = -1
  }

  this.checkCleanList()

  local nextTriggerTimestamp = -1
  foreach (invite in this.list) {
    let  ts = invite.getNextTriggerTimestamp()
    if (ts < 0)
      continue
    if (nextTriggerTimestamp < 0 || nextTriggerTimestamp > ts)
      nextTriggerTimestamp = ts
  }

  if (nextTriggerTimestamp < 0)
    return

  local triggerDelay = nextTriggerTimestamp - ::get_charserver_time_sec();
  if (triggerDelay < 1)
    triggerDelay = 1  //  in case we have some timed outs

  this.refreshInvitesTask = ::periodic_task_register(this,
                                                 this._timedInvitesUpdate,
                                                 triggerDelay)

  log("Rescheduled refreshInvitesTask " + this.refreshInvitesTask + " with delay " + triggerDelay);
}

::g_invites.registerInviteUserlogHandler <- @(logType, addFn)
  ::g_invites.userlogHandlers[logType] <- addFn

::g_invites.fetchNewInvitesFromUserlogs <- function fetchNewInvitesFromUserlogs() {
  local needReshedule = false
  let total = ::get_user_logs_count()
  for (local i = total - 1; i >= 0; i--) {
    let blk = DataBlock()
    ::get_user_log_blk_body(i, blk)
    if (::g_invites.userlogHandlers?[blk.type](blk, i) ?? false)
      needReshedule = true
  }

  if (needReshedule)
    ::g_invites.rescheduleInvitesTask()
}

::g_invites.onEventProfileUpdated <- function onEventProfileUpdated(_p) {
  if (::g_login.isLoggedIn())
    this.fetchNewInvitesFromUserlogs()
}

::g_invites.onEventLoginComplete <- function onEventLoginComplete(_p) {
  this.fetchNewInvitesFromUserlogs()
}

::g_invites.onEventScriptsReloaded <- function onEventScriptsReloaded(_p) {
  this.list = u.map(this.list, function(invite) {
    let params = invite.reloadParams
    foreach (inviteClass in ::g_invites_classes)
      if (inviteClass.getUidByParams(params) == invite.uid) {
        let newInvite = inviteClass(params)
        newInvite.afterScriptsReload(invite)
        return newInvite
      }
    return invite
  })
}


subscribe_handler(::g_invites, ::g_listener_priority.DEFAULT_HANDLER)
g_script_reloader.registerPersistentDataFromRoot("g_invites")
