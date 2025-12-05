from "%scripts/dagui_natives.nut" import sync_handler_simulate_signal, set_char_cb, char_send_blk,
  clan_request_accept_membership_request, clan_request_reject_membership_request, clan_action_blk,
  clan_get_admin_editor_mode, clan_request_change_info_blk, clan_request_disband, clan_get_my_clan_id,
  clan_request_dismiss_member, clan_request_edit_black_list, clan_request_my_info, clan_get_exp,
  clan_request_sync_profile, sync_handler_simulate_request, chard_request_profile
from "%scripts/dagui_library.nut" import *
from "%scripts/contacts/contactsConsts.nut" import EPLX_CLAN
from "%scripts/contacts/contactsConsts.nut" import contactEvent
from "%scripts/clans/clanState.nut" import is_in_clan, MY_CLAN_UPDATE_DELAY_MSEC, lastUpdateMyClanTime, myClanInfo

let u = require("%sqStdLibs/helpers/u.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { eventbus_subscribe } = require("eventbus")
let { addTask, addBgTaskCb } = require("%scripts/tasker.nut")
let { openCommentModal } = require("%scripts/wndLib/commentModal.nut")
let DataBlock  = require("DataBlock")
let { getMyClanRights, getMyClanMembers } = require("%scripts/clans/clanInfo.nut")
let { addContact } = require("%scripts/contacts/contactsManager.nut")
let { contactsPlayers, contactsByGroups, getContactByName, clanUserTable
} = require("%scripts/contacts/contactsListState.nut")
let { contactPresence } = require("%scripts/contacts/contactPresence.nut")
let { isPlayerInFriendsGroup } = require("%scripts/contacts/contactsChecks.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { chatRooms } = require("%scripts/chat/chatStorage.nut")
let { isRoomClan } = require("%scripts/chat/chatRooms.nut")
let { setSeenCandidatesBlk, parseSeenCandidates } = require("%scripts/clans/clanCandidates.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")
let { get_time_msec } = require("dagor.time")
let { get_clan_info_table } = require("%scripts/clans/clanInfoTable.nut")
let penalty = require("penalty")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { defer } = require("dagor.workcycle")

const CLAN_ID_NOT_INITED = ""

let clansPersistent = persist("clansPersistent", @() { isInRequestMyClanData  = false })
local lastClanId = CLAN_ID_NOT_INITED 
local cacheSquadronExp = 0






function editClan(clanId, params, handler) {
  let isMyClan = myClanInfo.get() != null && clanId == "-1"
  handler.taskId = clan_request_change_info_blk(clanId, params)
  if (handler.taskId < 0)
    return

  set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  if (isMyClan)
    sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp =  function() {
    let owner = handler?.owner
    if (clan_get_admin_editor_mode() && "reinitClanWindow" in owner)
      owner.reinitClanWindow()
    else
      updateGamercards()
    handler.msgBox(
      "clan_edit_sacces",
      loc("clan/edit_clan_success"),
      [["ok", function() { handler.goBack() }]], "ok")
  }
}

function upgradeClan(clanId, params, handler) {
  let isMyClan = myClanInfo.get() != null && clanId != "-1"
  handler.taskId = clan_action_blk(clanId, "cln_clan_upgrade", params, true)
  if (handler.taskId < 0)
    return

  set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  if (isMyClan)
    sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp =  function() {
    let owner = handler?.owner
    if (clan_get_admin_editor_mode() && "reinitClanWindow" in owner)
      owner.reinitClanWindow()
    else
      updateGamercards()
    handler.msgBox(
      "clan_upgrade_success",
      loc("clan/upgrade_clan_success"),
      [["ok", function() { handler.goBack() }]], "ok")
  }
}

function upgradeClanMembers(clanId, handler) {
  let isMyClan = myClanInfo.get() != null && clanId != "-1"
  let params = DataBlock()
  let taskId = clan_action_blk(clanId, "cln_clan_members_upgrade", params, true)

  let cb = Callback(
       function() {
        broadcastEvent("ClanMembersUpgraded", { clanId = clanId })
        updateGamercards()
        showInfoMsgBox(loc("clan/members_upgrade_success"), "clan_members_upgrade_success")
      },
      handler)

  if (addTask(taskId, { showProgressBox = true }, cb) && isMyClan)
    sync_handler_simulate_signal("clan_info_reload")
}

function approvePlayerRequest(playerUid, clanId) {
  if (u.isEmpty(playerUid) || u.isEmpty(clanId))
    return

  let onSuccess = function() {
    addPopup("", loc("clan/requestApproved"))
    broadcastEvent("ClanCandidatesListChanged", { userId = playerUid })
  }

  let taskId = clan_request_accept_membership_request(clanId, playerUid, "REGULAR", false)
  sync_handler_simulate_signal("clan_info_reload")
  addTask(taskId, { showProgressBox = true }, onSuccess)
}

function rejectPlayerRequest(playerUid, clanId) {
  if (u.isEmpty(playerUid))
    return

  openCommentModal(
    null,
    loc("clan/writeCommentary"),
    loc("clan/requestReject"),
    function(comment) {
      let onSuccess = function() {
        addPopup("", loc("clan/requestRejected"))
        broadcastEvent("ClanCandidatesListChanged", { userId = playerUid })
      }

      let taskId = clan_request_reject_membership_request(playerUid, comment, clanId)
      sync_handler_simulate_signal("clan_info_reload")
      addTask(taskId, { showProgressBox = true }, onSuccess)
    }
  )
}

function dismissMember(contact, clanData) {
  let isMyClan = clanData?.id == clan_get_my_clan_id()
  let myClanRights = getMyClanRights()

  if ((!isMyClan || !isInArray("MEMBER_DISMISS", myClanRights)) && !clan_get_admin_editor_mode())
    return

  openCommentModal(
    null,
    loc("clan/writeCommentary"),
    loc("clan/btnDismissMember"),
    function(comment) {
      let onSuccess = function() {
        broadcastEvent("ClanMemberDismissed")
        addPopup("", loc("clan/memberDismissed"))
      }

      let taskId = clan_request_dismiss_member(contact.uid, comment)
      addTask(taskId, { showProgressBox = true }, onSuccess)
    }
  )
}

function blacklistAction(playerUid, actionAdd, clanId) {
  openCommentModal(
    null,
    loc("clan/writeCommentary"),
    loc("msgbox/btn_ok"),
    function(comment) {
      let onSuccess = function() {
        let text = actionAdd ? loc("clan/blacklistAddSuccess") : loc("clan/blacklistRemoveSuccess")
        addPopup("", text)
        broadcastEvent("ClanCandidatesListChanged", { userId = playerUid })
      }

      let taskId = clan_request_edit_black_list(playerUid, actionAdd, comment, clanId)
      sync_handler_simulate_signal("clan_info_reload")
      addTask(taskId, { showProgressBox = true }, onSuccess)
    }
  )
}

function getMyClanMemberPresence(nick) {
  let clanActiveUsers = []
  foreach (roomData in chatRooms)
    if (isRoomClan(roomData.id) && roomData.users.len() > 0) {
      foreach (user in roomData.users)
        clanActiveUsers.append(user.name)
      break
    }

  if (isInArray(nick, clanActiveUsers)) {
    let contact = getContactByName(nick)
    if (!(contact?.forceOffline ?? false))
      return contactPresence.ONLINE
  }
  return contactPresence.OFFLINE
}

function updateClanContacts() {
  contactsByGroups[EPLX_CLAN] <- {}
  if (!is_in_clan())
    return

  foreach (block in (myClanInfo.get()?.members ?? [])) {
    if (!(block.uid in contactsPlayers))
      getContact(block.uid, block.nick)

    let contact = contactsPlayers[block.uid]
    if (!isPlayerInFriendsGroup(block.uid) || contact.unknown)
      contact.presence = getMyClanMemberPresence(block.nick)

    if (userIdStr.get() != block.uid)
      addContact(contact, EPLX_CLAN)
  }
}

function handleNewMyClanData() {
  parseSeenCandidates()
  contactsByGroups[EPLX_CLAN] <- {}
  let myClanInfoV = myClanInfo.get()
  if ("members" not in myClanInfoV)
    return

  let res = {}
  foreach (_mem, block in myClanInfoV.members) {
    if (!(block.uid in contactsPlayers))
      getContact(block.uid, block.nick)

    let contact = contactsPlayers[block.uid]
    if (!isPlayerInFriendsGroup(block.uid) || contact.unknown)
      contact.presence = getMyClanMemberPresence(block.nick)

    if (userIdStr.get() != block.uid)
      addContact(contact, EPLX_CLAN)

    res[block.nick] <- myClanInfoV.tag
  }

  if (res.len() > 0)
    clanUserTable.mutate(@(v) v.__update(res))
}

function clearClanTagForRemovedMembers(prevUids, currUids) {
  let uidsToClean = {}
  foreach(prevUid in prevUids)
    uidsToClean[prevUid] <- prevUid

  if (currUids.len())
    foreach(currUid in currUids)
      if (currUid in uidsToClean)
        uidsToClean.rawdelete(currUid)

  if (uidsToClean.len()) {
    foreach(uid in uidsToClean)
      getContact(uid)?.update({ clanTag = "" })

    broadcastEvent(contactEvent.CONTACTS_UPDATED)
  }
}

function checkClanChangedEvent() {
  if (lastClanId == clan_get_my_clan_id())
    return

  let needEvent = lastClanId != CLAN_ID_NOT_INITED
  lastClanId = clan_get_my_clan_id()
  if (needEvent)
    broadcastEvent("MyClanIdChanged")
}

function checkSquadronExpChangedEvent() {
  let curSquadronExp = clan_get_exp()
  if (cacheSquadronExp == curSquadronExp)
    return

  cacheSquadronExp = curSquadronExp
  broadcastEvent("SquadronExpChanged")
}

function requestMyClanData(forceUpdate = false) {
  let myClanPrevMembersUid = getMyClanMembers().map(@(m) m.uid)
  if (clansPersistent.isInRequestMyClanData)
    return

  checkClanChangedEvent()
  checkSquadronExpChangedEvent()

  let myClanId = clan_get_my_clan_id()
  if (myClanId == "-1") {
    if (myClanInfo.get()) {
      myClanInfo.set(null)
      parseSeenCandidates()
      clearClanTagForRemovedMembers(myClanPrevMembersUid, [])
      broadcastEvent("ClanInfoUpdate")
      broadcastEvent("ClanChanged") 
      updateGamercards()
    }
    return
  }

  if (!forceUpdate && (myClanInfo.get()?.id ?? "-1") == myClanId)
    if (get_time_msec() - lastUpdateMyClanTime.get() < -MY_CLAN_UPDATE_DELAY_MSEC)
      return

  lastUpdateMyClanTime.set(get_time_msec())
  let taskId = clan_request_my_info()
  clansPersistent.isInRequestMyClanData = true
  addBgTaskCb(taskId, function() {
    let wasCreated = !myClanInfo.get()
    myClanInfo.set(get_clan_info_table(true)) 

    let myClanCurrMembersUid = getMyClanMembers().map(@(m) m.uid)
    if (myClanCurrMembersUid.len() < myClanPrevMembersUid.len())
      clearClanTagForRemovedMembers(myClanPrevMembersUid, myClanCurrMembersUid)

    handleNewMyClanData()
    clansPersistent.isInRequestMyClanData = false
    broadcastEvent("ClanInfoUpdate")
    updateGamercards()
    if (wasCreated)
      broadcastEvent("ClanChanged") 
  })
}

function createClan(params, handler) {
  handler.taskId = char_send_blk("cln_clan_create", params)
  if (handler.taskId < 0)
    return

  set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp = function() {
    requestMyClanData()
    updateGamercards()
    handler.msgBox(
      "clan_create_sacces",
      loc("clan/create_clan_success"),
      [["ok",  function() { handler.goBack() }]], "ok")
  }
}

function disbandClan(clanId, handler) {
  openCommentModal(
    handler,
    loc("clan/writeCommentary"),
    loc("clan/btnDisbandClan"),
    function(comment) {
      handler.taskId = clan_request_disband(clanId, comment);

      if (handler.taskId >= 0) {
        set_char_cb(handler, handler.slotOpCb)
        handler.showTaskProgressBox()
        if (handler.isMyClan)
          sync_handler_simulate_signal("clan_info_reload")
        handler.afterSlotOp = function() {
            requestMyClanData()
            updateGamercards()
            handler.msgBox("clan_disbanded", loc("clan/clanDisbanded"), [["ok", function() { handler.goBack() } ]], "ok")
          }
      }
    },
    true
  )
}

eventbus_subscribe("on_have_to_start_chard_op", function on_have_to_start_chard_op(data) {
  let { message } = data
  log($"on_have_to_start_chard_op {message}")

  if (message == "sync_clan_vs_profile") {
    let taskId = clan_request_sync_profile()
    addBgTaskCb(taskId, function() {
      requestMyClanData(true)
      updateGamercards()
    })
  }
  else if (message == "clan_info_reload") {
    requestMyClanData(true)
    let myClanId = clan_get_my_clan_id()
    if (myClanId == "-1")
      sync_handler_simulate_request(message)
  }
  else if (message == "profile_reload") {
    let oldPenaltyStatus = penalty.getPenaltyStatus()
    let taskId = chard_request_profile()
    addBgTaskCb(taskId, function() {
      let  newPenaltyStatus = penalty.getPenaltyStatus()
      if (newPenaltyStatus.status != oldPenaltyStatus.status || newPenaltyStatus.duration != oldPenaltyStatus.duration)
        broadcastEvent("PlayerPenaltyStatusChanged", { status = newPenaltyStatus.status })
    })
  }
})

if (isProfileReceived.get() && myClanInfo.get() == null)
  defer(@() requestMyClanData())

addListenersWithoutEnv({
  ProfileUpdated             = @(_) requestMyClanData()

  function SignOut(_) {
    lastClanId = CLAN_ID_NOT_INITED
    setSeenCandidatesBlk(null)
    cacheSquadronExp = 0
    lastUpdateMyClanTime.set(MY_CLAN_UPDATE_DELAY_MSEC)
  }
}, g_listener_priority.DEFAULT_HANDLER)

return {
  createClan
  editClan
  disbandClan
  upgradeClan
  upgradeClanMembers
  approvePlayerRequest
  rejectPlayerRequest
  dismissMember
  blacklistAction
  updateClanContacts
  getMyClanMemberPresence
  handleNewMyClanData
  requestMyClanData
}