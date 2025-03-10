from "%scripts/dagui_natives.nut" import get_user_log_blk_body, periodic_task_unregister, get_user_logs_count, periodic_task_register
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let DataBlock = require("DataBlock")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { startsWith } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { findInviteClass, invitesClasses } = require("%scripts/invites/invitesClasses.nut")
let { MAX_POPUPS_ON_SCREEN, addPopup } = require("%scripts/popups/popups.nut")
let { doWithAllGamercards, updateGcInvites } = require("%scripts/gamercard.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { invitesAmount } = require("%scripts/invites/invitesState.nut")

const INVITE_CHAT_LINK_PREFIX = "INV_"
const POPUP_TEXT_COLOR = "@chatInfoColor"

let openInviteWnd = @() loadHandler(gui_handlers.InvitesWnd)

function showPopupFriendsInvites(count) {
  addPopup(null, loc("contacts/popup_has_friend_invitations", {count}),
    openInviteWnd, [{ id = "gotoInvites", text = loc("mainmenu/invites"), func = openInviteWnd }])
}

let invitesList = persist("invitesList", @() [])

local refreshInvitesTask = -1
let userlogHandlers = {}

let registerInviteUserlogHandler = @(logType, addFn) userlogHandlers[logType] <- addFn

function updateNewInvitesAmount() {
  local amount = 0
  foreach (invite in invitesList)
    if (invite.isNew() && invite.isVisible())
      amount++
  if (amount == invitesAmount.get())
    return

  invitesAmount.set(amount)
  doWithAllGamercards(updateGcInvites)
}

function broadcastInviteReceived(invite) {
  if (!invite.isDelayed && !invite.isAutoAccepted)
    broadcastEvent("InviteReceived", { invite = invite })
}

function broadcastInviteUpdated(invite) {
  if (invite.isVisible())
    broadcastEvent("InviteUpdated", { invite = invite })
}

function findInviteByUid(uid) {
  foreach (invite in invitesList)
    if (invite.uid == uid)
      return invite
  return null
}

function showExpiredInvitePopup() {
  addPopup(null, colorize(POPUP_TEXT_COLOR, loc("multiplayer/invite_is_overtimed")))
}

function showLeaveSessionFirstPopup() {
  addPopup(null, colorize(POPUP_TEXT_COLOR, loc("multiplayer/leave_session_first")))
}

function markAllInvitesSeen() {
  local changed = false
  foreach (invite in invitesList)
    if (invite.markSeen(true))
      changed = true

  if (changed)
    updateNewInvitesAmount()
}

function updateOrCreateInvite(inviteClass, params) {
  let uid = inviteClass.getUidByParams(params)
  local invite = findInviteByUid(uid)
  if (invite) {
    invite.updateParams(params)
    broadcastInviteUpdated(invite)
    return invite
  }

  invite = inviteClass(params)
  if (invite.isValid()) {
    invitesList.append(invite)
    broadcastInviteReceived(invite)
  }
  return invite
}

function removeInvite(invite) {
  foreach (idx, inv in invitesList)
    if (inv == invite) {
      invite.onRemove()
      invitesList.remove(idx)
      updateNewInvitesAmount()
      broadcastEvent("InviteRemoved")
      break
    }
}

function findInviteByChatLink(link) {
  foreach (invite in invitesList)
    if (invite.checkChatLink(link))
      return invite
  return null
}

function removeInviteToSquad(squadId) {
  let uid = findInviteClass("Squad")?.getUidByParams({ squadId = squadId })
  let invite = findInviteByUid(uid)
  if (invite)
    removeInvite(invite)
}

function checkCleanList() {
  local isRemoved = false
  for (local i = invitesList.len() - 1; i >= 0; i--)
    if (invitesList[i].isOutdated()) {
      invitesList.remove(i)
      isRemoved = true
    }
  if (isRemoved)
    broadcastEvent("InviteRemoved")
}

function acceptInviteByLink(link) {
  if (!startsWith(link, INVITE_CHAT_LINK_PREFIX))
    return false

  let invite = findInviteByChatLink(link)
  if (invite && !invite.isOutdated())
    invite.accept()
  else
    showExpiredInvitePopup()
  return true
}

function addInvite(inviteClass, params) {
  if (inviteClass == null) {
    logerr("[Invites] inviteClass is null")
    return null
  }

  checkCleanList()
  updateOrCreateInvite(inviteClass, params)
  updateNewInvitesAmount()
}

function addFriendsInvites(inviters) {
  let inviteClass = findInviteClass("Friend")
  if (inviteClass == null) {
    logerr("[Invites] inviteClass is null")
    return null
  }

  checkCleanList()
  let invitesCount = inviters.len()
  let needShowPopupForEachInvite = invitesCount <= MAX_POPUPS_ON_SCREEN
  foreach(user in inviters) {
    let { nick = "", uid = "" } = user
    if (nick != "" && uid != "")
      updateOrCreateInvite(inviteClass, { inviterName = nick, inviterUid = uid.tostring(),
        needShowPopup = needShowPopupForEachInvite })
  }

  updateNewInvitesAmount()
  if (!needShowPopupForEachInvite)
    showPopupFriendsInvites(invitesCount)
}

function addChatRoomInvite(roomId, inviterName) {
  return addInvite(findInviteClass("ChatRoom"), { roomId = roomId, inviterName = inviterName })
}

function addSessionRoomInvite(roomId, inviterUid, inviterName, password = null) {
  return addInvite(findInviteClass("SessionRoom"),
                   {
                     roomId      = roomId
                     inviterUid  = inviterUid
                     inviterName = inviterName
                     password    = password
                   })
}

function addTournamentBattleInvite(battleId, inviteTime, startTime, endTime) {
  return addInvite(findInviteClass("TournamentBattle"),
                   {
                     battleId = battleId
                     inviteTime = inviteTime
                     startTime = startTime
                     endTime = endTime
                   })
}

function addInviteToSquad(squadId, leaderId) {
  return addInvite(findInviteClass("Squad"), { squadId = squadId, leaderId = leaderId })
}

function timedInvitesUpdate() {
  let now = get_charserver_time_sec()
  checkCleanList()

  foreach (invite in invitesList)
    invite.updateDelayedState(now)

  updateNewInvitesAmount()
}

function rescheduleInvitesTask() {
  if (refreshInvitesTask >= 0) {
    periodic_task_unregister(refreshInvitesTask)
    refreshInvitesTask = -1
  }

  checkCleanList()

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
    triggerDelay = 1  

  let self = callee()
  let cb = function(_dt = 0) {
    timedInvitesUpdate()
    self()
  }
  refreshInvitesTask = periodic_task_register(this, cb, triggerDelay)

  log($"Rescheduled refreshInvitesTask {refreshInvitesTask} with delay {triggerDelay}");
}

function fetchNewInvitesFromUserlogs() {
  local needReshedule = false
  let total = get_user_logs_count()
  for (local i = total - 1; i >= 0; i--) {
    let blk = DataBlock()
    get_user_log_blk_body(i, blk)
    if (userlogHandlers?[blk.type](blk, i) ?? false)
      needReshedule = true
  }

  if (needReshedule)
    rescheduleInvitesTask()
}

function addFriendInvite(name, uid) {
  if (name == "" || uid == "")
    return
  addInvite(findInviteClass("Friend"), { inviterName = name, inviterUid = uid })
}

addListenersWithoutEnv({
  LoginComplete = @(_) fetchNewInvitesFromUserlogs()

  function SignOut(_) {
    invitesList.clear()
    invitesAmount.set(0)
  }

  function ProfileUpdated(_) {
    if (isLoggedIn.get())
      fetchNewInvitesFromUserlogs()
  }

  function ScriptsReloaded(_) {
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
}, g_listener_priority.DEFAULT_HANDLER)

return {
  INVITE_CHAT_LINK_PREFIX
  addFriendInvite
  openInviteWnd
  updateNewInvitesAmount
  getInvitesList = @() invitesList
  registerInviteUserlogHandler
  broadcastInviteReceived
  broadcastInviteUpdated
  findInviteByUid
  showExpiredInvitePopup
  showLeaveSessionFirstPopup
  markAllInvitesSeen
  removeInvite
  removeInviteToSquad
  acceptInviteByLink
  addInvite
  addFriendsInvites
  addChatRoomInvite
  addSessionRoomInvite
  addTournamentBattleInvite
  addInviteToSquad
}