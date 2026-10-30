import "%scripts/g_listener_priority.nut" as g_listener_priority
import "DataBlock" as DataBlock
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/invites/invitesClasses.nut" import findInviteClass
from "%scripts/popups/popups.nut" import MAX_POPUPS_ON_SCREEN, addPopup
from "%scripts/gamercard/gamercardHelpers.nut" import updateGcInvites, doWithAllGamercards
from "%scripts/invites/invitesState.nut" import invitesAmount
from "%scripts/social/crossplay.nut" import crossNetworkChatStatus
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "%sqstd/string.nut" import startsWith
from "chard" import get_charserver_time_sec
from "%scripts/dagui_natives.nut" import get_user_log_blk_body, periodic_task_unregister, get_user_logs_count, periodic_task_register
from "%scripts/dagui_library.nut" import *
from "dagor.workcycle" import deferOnce

let { invitesClasses } = require("%scripts/invites/invitesClasses.nut")

const INVITE_CHAT_LINK_PREFIX = "INV_"
const POPUP_TEXT_COLOR = "@chatInfoColor"

let openInviteWnd = @() loadHandler(get_gui_handler("InvitesWnd"))

function showPopupFriendsInvites(count) {
  addPopup(null, loc("contacts/popup_has_friend_invitations", {count}),
    openInviteWnd, [{ id = "gotoInvites", text = loc("mainmenu/invites"), func = openInviteWnd }])
}

local refreshInvitesTask = -1
let userlogHandlers = {}

let invitesList = persist("invitesList", @() [])

let storedInvites = hardPersistOnUnload("invites.invites", "invitesList", @() invitesList.map(@(i) {
  uid = i.uid, reloadParams = i.reloadParams, receivedTime = i.receivedTime, isSeen = i.isSeen,
  isDelayed = i.isDelayed, isAutoAccepted = i.isAutoAccepted, isRejected = i.isRejected,
  timedShowStamp = i.timedShowStamp, timedExpireStamp = i.timedExpireStamp
}))
deferOnce(@() invitesList.replace(invitesList.map(function(invite) { 
  let params = invite.reloadParams
  foreach (inviteClass in invitesClasses)
    if (inviteClass.getUidByParams(params) == invite.uid) {
      let newInvite = inviteClass(params)
      newInvite.afterScriptsReload(invite)
      return newInvite
    }
  return invite
})))

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

function addSessionRoomInvite(roomId, inviterUid, inviterName, password = null, roomInfo = null) {
  return addInvite(findInviteClass("SessionRoom"),
                   {
                     roomId      = roomId
                     inviterUid  = inviterUid
                     inviterName = inviterName
                     password    = password
                     roomInfo    = roomInfo
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


if (storedInvites != null)
  deferOnce(function() {
    foreach (record in storedInvites) {
      let params = record.reloadParams
      let inviteClass = invitesClasses.findvalue(@(c) c.getUidByParams(params) == record.uid)
      if (inviteClass == null || findInviteByUid(record.uid) != null) 
        continue
      let invite = inviteClass(params)
      invite.afterScriptsReload(record)
      invitesList.append(invite)
    }
    rescheduleInvitesTask()
    updateNewInvitesAmount()
  })

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

function updateCanChatWithPlayerForInvites() {
  foreach (invite in invitesList)
    invite.updateCanChatWithPlayer()
  broadcastEvent("InviteReceived") 
}

crossNetworkChatStatus.subscribe(function(canChat) {
  if (canChat != null)
    updateCanChatWithPlayerForInvites()
})

addListenersWithoutEnv({
  LoginComplete = @(_) fetchNewInvitesFromUserlogs()

  function SignOut(_) {
    invitesList.clear()
    invitesAmount.set(0)
  }

  function ProfileUpdated(_) {
    if (hasFullLoginState.get())
      fetchNewInvitesFromUserlogs()
  }
}, g_listener_priority.DEFAULT_HANDLER)

return freeze({
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
})