//-file:plus-string
from "%scripts/dagui_natives.nut" import get_user_log_blk_body, periodic_task_unregister, get_user_logs_count, periodic_task_register
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let DataBlock = require("DataBlock")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { startsWith } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { findInviteClass, invitesClasses } = require("%scripts/invites/invitesClasses.nut")
let { MAX_POPUPS_ON_SCREEN, addPopup } = require("%scripts/popups/popups.nut")

const INVITE_CHAT_LINK_PREFIX = "INV_"

let openInviteWnd = @() loadHandler(gui_handlers.InvitesWnd)

function showPopupFriendsInvites(count) {
  addPopup(null, loc("contacts/popup_has_friend_invitations", {count}),
    openInviteWnd, [{ id = "gotoInvites", text = loc("mainmenu/invites"), func = openInviteWnd }])
}

let invitesList = persist("invitesList", @() [])
let invitesAmount = persist("invitesAmount", @() {val = 0})
let getNewInvitesAmount = @() invitesAmount.val
let setNewInvitesAmount = @(val) invitesAmount.val = val

::g_invites <- {

  popupTextColor = "@chatInfoColor"

  list = invitesList
  newInvitesAmount = 0
  refreshInvitesTask = -1
  userlogHandlers = {}
  getNewInvitesAmount
  setNewInvitesAmount

  function updateOrCreateInvite(inviteClass, params) {
    let uid = inviteClass.getUidByParams(params)
    local invite = this.findInviteByUid(uid)
    if (invite) {
      invite.updateParams(params)
      this.broadcastInviteUpdated(invite)
      return invite
    }

    invite = inviteClass(params)
    if (invite.isValid()) {
      invitesList.append(invite)
      this.broadcastInviteReceived(invite)
    }
    return invite
  }

  function addInvite(inviteClass, params) {
    if (inviteClass == null) {
      logerr("[Invites] inviteClass is null")
      return null
    }

    this.checkCleanList()
    this.updateOrCreateInvite(inviteClass, params)
    this.updateNewInvitesAmount()
  }

  function addFriendsInvites(inviters) {
    let inviteClass = findInviteClass("Friend")
    if (inviteClass == null) {
      logerr("[Invites] inviteClass is null")
      return null
    }

    this.checkCleanList()
    let invitesCount = inviters.len()
    let needShowPopupForEachInvite = invitesCount <= MAX_POPUPS_ON_SCREEN
    foreach(user in inviters) {
      let { nick = "", uid = "" } = user
      if (nick != "" && uid != "")
        this.updateOrCreateInvite(inviteClass, { inviterName = nick, inviterUid = uid.tostring(),
          needShowPopup = needShowPopupForEachInvite })
    }

    this.updateNewInvitesAmount()
    if (!needShowPopupForEachInvite)
      showPopupFriendsInvites(invitesCount)
  }

  function onEventSignOut(_p) {
    invitesList.clear()
    setNewInvitesAmount(0)
  }

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
  return this.addInvite(findInviteClass("ChatRoom"), { roomId = roomId, inviterName = inviterName })
}

::g_invites.addSessionRoomInvite <- function addSessionRoomInvite(roomId, inviterUid, inviterName, password = null) {
  return this.addInvite(findInviteClass("SessionRoom"),
                   {
                     roomId      = roomId
                     inviterUid  = inviterUid
                     inviterName = inviterName
                     password    = password
                   })
}

::g_invites.addTournamentBattleInvite <- function addTournamentBattleInvite(battleId, inviteTime, startTime, endTime) {
  return this.addInvite(findInviteClass("TournamentBattle"),
                   {
                     battleId = battleId
                     inviteTime = inviteTime
                     startTime = startTime
                     endTime = endTime
                   })
}

::g_invites.addInviteToSquad <- function addInviteToSquad(squadId, leaderId) {
  return this.addInvite(findInviteClass("Squad"), { squadId = squadId, leaderId = leaderId })
}

::g_invites.removeInviteToSquad <- function removeInviteToSquad(squadId) {
  let uid = findInviteClass("Squad")?.getUidByParams({ squadId = squadId })
  let invite = this.findInviteByUid(uid)
  if (invite)
    this.remove(invite)
}

::g_invites._lastCleanTime <- -1
::g_invites.checkCleanList <- function checkCleanList() {
  local isRemoved = false
  for (local i = invitesList.len() - 1; i >= 0; i--)
    if (this.list[i].isOutdated()) {
      invitesList.remove(i)
      isRemoved = true
    }
  if (isRemoved)
    broadcastEvent("InviteRemoved")
}

::g_invites.remove <- function remove(invite) {
  foreach (idx, inv in invitesList)
    if (inv == invite) {
      invite.onRemove()
      invitesList.remove(idx)
      this.updateNewInvitesAmount()
      broadcastEvent("InviteRemoved")
      break
    }
}

::g_invites.findInviteByChatLink <- function findInviteByChatLink(link) {
  foreach (invite in invitesList)
    if (invite.checkChatLink(link))
      return invite
  return null
}

::g_invites.findInviteByUid <- function findInviteByUid(uid) {
  foreach (invite in invitesList)
    if (invite.uid == uid)
      return invite
  return null
}

::g_invites.acceptInviteByLink <- function acceptInviteByLink(link) {
  if (!startsWith(link, INVITE_CHAT_LINK_PREFIX))
    return false

  let invite = ::g_invites.findInviteByChatLink(link)
  if (invite && !invite.isOutdated())
    invite.accept()
  else
    this.showExpiredInvitePopup()
  return true
}

::g_invites.showExpiredInvitePopup <- function showExpiredInvitePopup() {
  addPopup(null, colorize(this.popupTextColor, loc("multiplayer/invite_is_overtimed")))
}

::g_invites.showLeaveSessionFirstPopup <- function showLeaveSessionFirstPopup() {
  addPopup(null, colorize(this.popupTextColor, loc("multiplayer/leave_session_first")))
}

::g_invites.markAllSeen <- function markAllSeen() {
  local changed = false
  foreach (invite in invitesList)
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
  if (amount == getNewInvitesAmount())
    return

  setNewInvitesAmount(amount)
  ::do_with_all_gamercards(::update_gc_invites)
}

::g_invites._timedInvitesUpdate <- function _timedInvitesUpdate(_dt = 0) {
  let now = get_charserver_time_sec()
  this.checkCleanList()

  foreach (invite in invitesList)
    invite.updateDelayedState(now)

  this.updateNewInvitesAmount()

  ::g_invites.rescheduleInvitesTask()
}

::g_invites.rescheduleInvitesTask <- function rescheduleInvitesTask() {
  if (this.refreshInvitesTask >= 0) {
    periodic_task_unregister(this.refreshInvitesTask)
    this.refreshInvitesTask = -1
  }

  this.checkCleanList()

  local nextTriggerTimestamp = -1
  foreach (invite in invitesList) {
    let  ts = invite.getNextTriggerTimestamp()
    if (ts < 0)
      continue
    if (nextTriggerTimestamp < 0 || nextTriggerTimestamp > ts)
      nextTriggerTimestamp = ts
  }

  if (nextTriggerTimestamp < 0)
    return

  local triggerDelay = nextTriggerTimestamp - get_charserver_time_sec();
  if (triggerDelay < 1)
    triggerDelay = 1  //  in case we have some timed outs

  this.refreshInvitesTask = periodic_task_register(this,
                                                 this._timedInvitesUpdate,
                                                 triggerDelay)

  log("Rescheduled refreshInvitesTask " + this.refreshInvitesTask + " with delay " + triggerDelay);
}

::g_invites.registerInviteUserlogHandler <- @(logType, addFn)
  ::g_invites.userlogHandlers[logType] <- addFn

::g_invites.fetchNewInvitesFromUserlogs <- function fetchNewInvitesFromUserlogs() {
  local needReshedule = false
  let total = get_user_logs_count()
  for (local i = total - 1; i >= 0; i--) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
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
  invitesList.replace(invitesList.map(function(invite) {
    let params = invite.reloadParams
    foreach (inviteClass in invitesClasses)
      if (inviteClass.getUidByParams(params) == invite.uid) {
        let newInvite = inviteClass(params)
        newInvite.afterScriptsReload(invite)
        return newInvite
      }
    return invite
  }))
}

subscribe_handler(::g_invites, g_listener_priority.DEFAULT_HANDLER)

function addFriendInvite(name, uid) {
  if (name == "" || uid == "")
    return
  ::g_invites.addInvite(findInviteClass("Friend"), { inviterName = name, inviterUid = uid })
}

return {
  INVITE_CHAT_LINK_PREFIX
  addFriendInvite
  openInviteWnd
}