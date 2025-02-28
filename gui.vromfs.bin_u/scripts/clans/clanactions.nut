from "%scripts/dagui_natives.nut" import sync_handler_simulate_signal, set_char_cb, char_send_blk, clan_request_accept_membership_request, clan_request_reject_membership_request, clan_action_blk, clan_get_admin_editor_mode, clan_request_change_info_blk, clan_request_disband, clan_get_my_clan_id, clan_request_dismiss_member, clan_request_edit_black_list
from "%scripts/dagui_library.nut" import *

let { is_in_clan, myClanInfo } = require("%scripts/clans/clanState.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { addTask } = require("%scripts/tasker.nut")
let { openCommentModal } = require("%scripts/wndLib/commentModal.nut")
let DataBlock  = require("DataBlock")
let { getMyClanRights } = require("%scripts/clans/clanInfo.nut")
let { EPLX_CLAN, contactsPlayers, contactsByGroups, addContact } = require("%scripts/contacts/contactsManager.nut")
let { isPlayerInFriendsGroup } = require("%scripts/contacts/contactsChecks.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")

function createClan(params, handler) {
  handler.taskId = char_send_blk("cln_clan_create", params)
  if (handler.taskId < 0)
    return

  set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp = function() {
    ::requestMyClanData()
    ::update_gamercards()
    handler.msgBox(
      "clan_create_sacces",
      loc("clan/create_clan_success"),
      [["ok",  function() { handler.goBack() }]], "ok")
  }
}

/**
* Edit specified clan.
* clanId @string - id of clan to edit, -1 if your clan
* params @DataBlock - result of g_clan->prepareEditRequest function
*/
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
      ::update_gamercards()
    handler.msgBox(
      "clan_edit_sacces",
      loc("clan/edit_clan_success"),
      [["ok", function() { handler.goBack() }]], "ok")
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
            ::requestMyClanData()
            ::update_gamercards()
            handler.msgBox("clan_disbanded", loc("clan/clanDisbanded"), [["ok", function() { handler.goBack() } ]], "ok")
          }
      }
    },
    true
  )
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
      ::update_gamercards()
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
        ::update_gamercards()
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

function updateClanContacts() {
  contactsByGroups[EPLX_CLAN] <- {}
  if (!is_in_clan())
    return

  foreach (block in (myClanInfo.get()?.members ?? [])) {
    if (!(block.uid in contactsPlayers))
      ::getContact(block.uid, block.nick)

    let contact = contactsPlayers[block.uid]
    if (!isPlayerInFriendsGroup(block.uid) || contact.unknown)
      contact.presence = ::getMyClanMemberPresence(block.nick)

    if (userIdStr.value != block.uid)
      addContact(contact, EPLX_CLAN)
  }
}

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
}