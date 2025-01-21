from "%scripts/dagui_natives.nut" import clan_get_role_rank, ps4_is_ugc_enabled, clan_request_edit_black_list, clan_get_my_clan_type, sync_handler_simulate_signal, clan_action_blk, clan_get_my_role, set_char_cb, clan_request_log, clan_request_accept_membership_request, clan_request_membership_request, clan_request_change_info_blk, clan_get_my_clan_tag, clan_request_my_info, clan_request_disband, clan_get_my_clan_name, clan_request_reject_membership_request, clan_get_clan_log, clan_request_dismiss_member, clan_get_clan_info, char_send_blk, clan_get_membership_requirements, char_send_clan_oneway_blk, clan_get_exp, clan_request_info, clan_get_role_rights, clan_get_requested_clan_id, clan_get_my_clan_id, clan_get_admin_editor_mode
from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clansConsts.nut" import CLAN_SEASON_NUM_IN_YEAR_SHIFT
from "%scripts/contacts/contactsConsts.nut" import contactEvent
from "%scripts/clans/clanState.nut" import is_in_clan

let { g_chat } = require("%scripts/chat/chat.nut")
let { g_clan_type } = require("%scripts/clans/clanType.nut")
let { g_clan_log_type } = require("%scripts/clans/clanLogType.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { round } = require("math")
let { format, split_by_chars } = require("string")
let regexp2 = require("regexp2")
let { get_time_msec, unixtime_to_utc_timetbl } = require("dagor.time")
let time = require("%scripts/time.nut")
let clanRewardsModal = require("%scripts/rewards/clanRewardsModal.nut")
let { isNamePassing, checkName } = require("%scripts/dirtyWordsFilter.nut")
let { convertBlk, copyParamsToTable, eachBlock } = require("%sqstd/datablock.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let lbDataType = require("%scripts/leaderboard/leaderboardDataType.nut")
let { EPLX_CLAN, contactsPlayers, contactsByGroups, addContact, getContactByName,
  clanUserTable } = require("%scripts/contacts/contactsManager.nut")
let { startsWith, slice } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { get_game_settings_blk } = require("blkGetters")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { openClanRequestsWnd } = require("%scripts/clans/clanRequestsModal.nut")
let { openCommentModal } = require("%scripts/wndLib/commentModal.nut")
let { addTask, addBgTaskCb } = require("%scripts/tasker.nut")
let { contactPresence } = require("%scripts/contacts/contactPresence.nut")
let { addPopup, removePopupByHandler } = require("%scripts/popups/popups.nut")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")
let { isPlayerNickInContacts, isPlayerInFriendsGroup } = require("%scripts/contacts/contactsChecks.nut")

const CLAN_ID_NOT_INITED = ""
const CLAN_SEEN_CANDIDATES_SAVE_ID = "seen_clan_candidates"
const MAX_CANDIDATES_NICKNAMES_IN_POPUP = 5
const MY_CLAN_UPDATE_DELAY_MSEC = -60000

::my_clan_info <- null
::last_update_my_clan_time <- MY_CLAN_UPDATE_DELAY_MSEC
local get_my_clan_data_free = true

registerPersistentData("ClansGlobals", getroottable(),
  [
    "my_clan_info"
    "last_update_my_clan_time"
    "get_my_clan_data_free"
  ])

::g_clans <- {
  lastClanId = CLAN_ID_NOT_INITED //only for compare about clan id changed
  seenCandidatesBlk = null
  squadronExp = 0

  function updateClanContacts() {
    contactsByGroups[EPLX_CLAN] <- {}
    if (!is_in_clan())
      return

    foreach (block in (::my_clan_info?.members ?? [])) {
      if (!(block.uid in contactsPlayers))
        ::getContact(block.uid, block.nick)

      let contact = contactsPlayers[block.uid]
      if (!isPlayerInFriendsGroup(block.uid) || contact.unknown)
        contact.presence = ::getMyClanMemberPresence(block.nick)

      if (userIdStr.value != block.uid)
        addContact(contact, EPLX_CLAN)
    }
  }
}

::g_clans.getMyClanType <- function getMyClanType() {
  let code = clan_get_my_clan_type()
  return g_clan_type.getTypeByCode(code)
}

::g_clans.createClan <- function createClan(params, handler) {
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
      ::getContact(uid)?.update({ clanTag = "" })

    broadcastEvent(contactEvent.CONTACTS_UPDATED)
  }
}

/**
 * Edit specified clan.
 * clanId @string - id of clan to edit, -1 if your clan
 * params @DataBlock - result of g_clan->prepareEditRequest function
 */
::g_clans.editClan <- function editClan(clanId, params, handler) {
  let isMyClan = ::my_clan_info != null && clanId == "-1"
  handler.taskId = clan_request_change_info_blk(clanId, params)
  if (handler.taskId < 0)
    return

  set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  if (isMyClan)
    sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp =  function() {
    let owner = getTblValue("owner", handler, null)
    if (clan_get_admin_editor_mode() && "reinitClanWindow" in owner)
      owner.reinitClanWindow()
    else
      ::update_gamercards()
    this.msgBox(
      "clan_edit_sacces",
      loc("clan/edit_clan_success"),
      [["ok", function() { handler.goBack() }]], "ok")
  }
}

::g_clans.upgradeClan <- function upgradeClan(clanId, params, handler) {
  let isMyClan = ::my_clan_info != null && clanId != "-1"
  handler.taskId = clan_action_blk(clanId, "cln_clan_upgrade", params, true)
  if (handler.taskId < 0)
    return

  set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  if (isMyClan)
    sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp =  function() {
    let owner = getTblValue("owner", handler, null)
    if (clan_get_admin_editor_mode() && "reinitClanWindow" in owner)
      owner.reinitClanWindow()
    else
      ::update_gamercards()
    this.msgBox(
      "clan_upgrade_success",
      loc("clan/upgrade_clan_success"),
      [["ok", function() { handler.goBack() }]], "ok")
  }
}

::g_clans.upgradeClanMembers <- function upgradeClanMembers(clanId) {
  let isMyClan = ::my_clan_info != null && clanId != "-1"
  let params = DataBlock()
  let taskId = clan_action_blk(clanId, "cln_clan_members_upgrade", params, true)

  let cb = Callback(
       function() {
        broadcastEvent("ClanMembersUpgraded", { clanId = clanId })
        ::update_gamercards()
        showInfoMsgBox(loc("clan/members_upgrade_success"), "clan_members_upgrade_success")
      },
      this)

  if (addTask(taskId, { showProgressBox = true }, cb) && isMyClan)
    sync_handler_simulate_signal("clan_info_reload")
}

::g_clans.disbandClan <- function disbandClan(clanId, handler) {
  openCommentModal(handler, loc("clan/writeCommentary"), loc("clan/btnDisbandClan"),
                       function(comment) {
                        handler.taskId = clan_request_disband(clanId, comment);

                        if (handler.taskId >= 0) {
                          set_char_cb(handler, this.slotOpCb)
                          handler.showTaskProgressBox()
                          if (this.isMyClan)
                            sync_handler_simulate_signal("clan_info_reload")
                          handler.afterSlotOp = function() {
                              ::requestMyClanData()
                              ::update_gamercards()
                              handler.msgBox("clan_disbanded", loc("clan/clanDisbanded"), [["ok", function() { handler.goBack() } ]], "ok")
                            }
                        }
                      }, true)
}

::g_clans.prepareCreateRequest <- function prepareCreateRequest(clanType, name, tag, slogan, description, announcement, region) {
  let requestData = DataBlock()
  requestData["name"] = name
  requestData["tag"] = tag
  requestData["slogan"] = slogan
  requestData["region"] = region
  requestData["type"] = clanType.getTypeName()

  if (clanType.isDescriptionChangeAllowed())
    requestData["desc"] = description

  if (clanType.isAnnouncementAllowed())
    requestData["announcement"] = announcement

  return requestData
}

::g_clans.getMyClanMembersCount <- function getMyClanMembersCount() {
  return getTblValue("members", ::my_clan_info, []).len()
}

::g_clans.getMyClanMembers <- function getMyClanMembers() {
  return ::my_clan_info?.members ?? []
}

::g_clans.getMyClanCandidates <- function getMyClanCandidates() {
  return getTblValue("candidates", ::my_clan_info, [])
}

::g_clans.prepareEditRequest <- function prepareEditRequest(clanType, name, tag, slogan, description, announcement, region) {
  let requestData = DataBlock()

  requestData["version"] = 2

  if (name != null)
    requestData["name"] = name
  if (tag != null)
    requestData["tag"] = tag
  if (clanType.isDescriptionChangeAllowed() && description != null)
    requestData["desc"] = description
  if (slogan != null)
    requestData["slogan"] = slogan
  if (clanType.isAnnouncementAllowed() && announcement != null)
    requestData["announcement"] = announcement
  if (region != null)
    requestData["region"] = region

  return requestData
}

::g_clans.prepareUpgradeRequest <- function prepareUpgradeRequest(clanType, tag, description, announcement) {
  let requestData = DataBlock()
  requestData["type"] = clanType.getTypeName()
  requestData["tag"] = tag
  requestData["desc"] = clanType.isDescriptionChangeAllowed() ? description : ""
  requestData["announcement"] = clanType.isAnnouncementAllowed() ? announcement : ""
  return requestData
}

/** Returns false if battalion clan type is disabled. */
::g_clans.clanTypesEnabled <- function clanTypesEnabled() {
  return hasFeature("Battalions")
}

/**
 * Return minimum interval between clan region update in menuts.
 * 1 day by default.
 */
::g_clans.getRegionUpdateCooldownTime <- function getRegionUpdateCooldownTime() {
  return getTblValue(
    "clansChangeRegionPeriodSeconds",
    get_game_settings_blk(),
    time.daysToSeconds(1)
  )
}

::g_clans.requestClanLog <- function requestClanLog(clanId, rowsCount, requestMarker, callbackFnSuccess, callbackFnError, handler) {
  let params = DataBlock()
  params._id = clanId.tointeger()
  params.count = rowsCount

  //Allow to display only clan info changes
  if ((clan_get_my_clan_id() != clanId) && !clan_get_admin_editor_mode())
    params.events = "create;info"

  if (requestMarker != null)
    params.last = requestMarker
  let taskId = clan_request_log(clanId, params)
  let successCb = Callback(callbackFnSuccess, handler)
  let errorCb = Callback(callbackFnError, handler)

  addTask(
    taskId,
    null,
    function () {
      let logData = {}
      let logDataBlk = clan_get_clan_log()

      logData.requestMarker <- logDataBlk?.lastMark
      logData.logEntries <- []
      foreach (logEntry in logDataBlk % "log") {
        if (logEntry?.uid != null && logEntry?.nick != null)
          ::getContact(logEntry.uid, logEntry.nick)

        if (logEntry?.uId != null && logEntry?.uN != null)
          ::getContact(logEntry.uId, logEntry.uN)

        let logEntryTable = convertBlk(logEntry)
        let logType = g_clan_log_type.getTypeByName(logEntryTable.ev)

        if ("time" in logEntryTable)
          logEntryTable.time = time.buildDateTimeStr(logEntryTable.time)

        logEntryTable.header <- logType.getLogHeader(logEntryTable)
        if (logType.needDetails(logEntryTable)) {
          let commonFields = logType.getLogDetailsCommonFields()
          let shortCommonDetails = logEntryTable.filter(@(_v, k) commonFields.indexof(k) != null)
          let individualFields = logType.getLogDetailsIndividualFields()
          let shortIndividualDetails = logEntryTable.filter(@(_v, k) individualFields.indexof(k) != null)

          let fullDetails = shortCommonDetails
          foreach (key, value in shortIndividualDetails) {
            let fullKey = $"{logEntryTable.ev}_{key}"
            fullDetails[fullKey] <- value
          }

          logEntryTable.details <- fullDetails
          logEntryTable.details.signText <- logType.getSignText(logEntryTable)
        }

        logData.logEntries.append(logEntryTable)
      }

      successCb(logData)
    },
    errorCb
  )
}

::g_clans.hasRightsToQueueWWar <- function hasRightsToQueueWWar() {
  if (!is_in_clan())
    return false
  if (!hasFeature("WorldWarClansQueue"))
    return false
  let myRights = ::clan_get_role_rights(clan_get_my_role())
  return isInArray("WW_REGISTER", myRights)
}

::g_clans.stripClanTagDecorators <- function stripClanTagDecorators(clanTag) {
  let uftClanTag = utf8(clanTag)
  let length = uftClanTag.charCount()
  return length > 2 ? uftClanTag.slice(1, length - 1) : clanTag
}

::g_clans.checkClanChangedEvent <- function checkClanChangedEvent() {
  if (this.lastClanId == clan_get_my_clan_id())
    return

  let needEvent = this.lastClanId != CLAN_ID_NOT_INITED
  this.lastClanId = clan_get_my_clan_id()
  if (needEvent)
    broadcastEvent("MyClanIdChanged")
}

::g_clans.onEventProfileUpdated <- function onEventProfileUpdated(_p) {
  ::requestMyClanData()
}

::g_clans.onEventScriptsReloaded <- function onEventScriptsReloaded(_p) {
  ::requestMyClanData()
}

::g_clans.onEventSignOut <- function onEventSignOut(_p) {
  this.lastClanId = CLAN_ID_NOT_INITED
  this.seenCandidatesBlk = null
  this.squadronExp = 0
  ::last_update_my_clan_time = MY_CLAN_UPDATE_DELAY_MSEC
}

::g_clans.loadSeenCandidates <- function loadSeenCandidates() {
  let result = DataBlock()
  if (isProfileReceived.get() && this.isHaveRightsToReviewCandidates()) {
    let loaded = loadLocalAccountSettings(CLAN_SEEN_CANDIDATES_SAVE_ID, null)
    if (loaded != null)
      result.setFrom(loaded)
  }
  return result
}

::g_clans.saveCandidates <- function saveCandidates() {
  if (!isProfileReceived.get() || !this.isHaveRightsToReviewCandidates() || !this.seenCandidatesBlk)
    return
  saveLocalAccountSettings(CLAN_SEEN_CANDIDATES_SAVE_ID, this.seenCandidatesBlk)
}

::g_clans.getUnseenCandidatesCount <- function getUnseenCandidatesCount() {
  if (! ::my_clan_info || ! this.getMyClanCandidates().len() ||
    ! this.isHaveRightsToReviewCandidates() || ! this.seenCandidatesBlk)
    return 0

  local count = 0
  let clanCandidates = this.getMyClanCandidates()
  foreach (clanCandidate in clanCandidates) {
    let result = this.seenCandidatesBlk?[clanCandidate.uid]
    if (! result)
      count++
  }
  return count
}

::g_clans.markClanCandidatesAsViewed <- function markClanCandidatesAsViewed() {
  if (! this.isHaveRightsToReviewCandidates())
    return

  local clanInfoChanged = false
  let clanCandidates = this.getMyClanCandidates()
  foreach (clanCandidate in clanCandidates) {
    if (this.seenCandidatesBlk?[clanCandidate.uid] == true)
      continue

    this.seenCandidatesBlk[clanCandidate.uid] = true
    clanInfoChanged = true
  }
  if (clanInfoChanged)
    this.onClanCandidatesChanged()
}

::g_clans.isHaveRightsToReviewCandidates <- function isHaveRightsToReviewCandidates() {
  if (!is_in_clan() || !hasFeature("Clans"))
    return false
  let rights = ::clan_get_role_rights(clan_get_my_role())
  return isInArray("MEMBER_ADDING", rights) || isInArray("MEMBER_REJECT", rights)
}

::g_clans.parseSeenCandidates <- function parseSeenCandidates() {
  if (!hasFeature("Clans"))
    return

  if (!this.seenCandidatesBlk)
    this.seenCandidatesBlk = this.loadSeenCandidates()

  local isChanged = false
  let actualUids = {}
  let newCandidatesNicknames = []
  let clanCandidates = this.getMyClanCandidates()
  foreach (candidate in clanCandidates) {
    actualUids[candidate.uid] <- true
    if (this.seenCandidatesBlk?[candidate.uid] != null)
      continue
    this.seenCandidatesBlk[candidate.uid] <- false
    newCandidatesNicknames.append(getPlayerName(candidate.nick))
    isChanged = true
  }

  for (local i = this.seenCandidatesBlk.paramCount() - 1; i >= 0; i--) {
    let paramName = this.seenCandidatesBlk.getParamName(i)
    if (! (paramName in actualUids)) {
      isChanged = true
      this.seenCandidatesBlk[paramName] = null
    }
  }

  if (! isChanged)
    return

  local extraText = ""
  if (newCandidatesNicknames.len() > MAX_CANDIDATES_NICKNAMES_IN_POPUP) {
    extraText = loc("clan/moreCandidates",
      { count = newCandidatesNicknames.len() - MAX_CANDIDATES_NICKNAMES_IN_POPUP })
    newCandidatesNicknames.resize(MAX_CANDIDATES_NICKNAMES_IN_POPUP)
  }

  if (newCandidatesNicknames.len())
    addPopup(null,
      "".concat(loc("clan/requestReceived"), loc("ui/colon"),
        ", ".join(newCandidatesNicknames, true), $" {extraText}"),
      function() {
        if (this.getMyClanCandidates().len())
          openClanRequestsWnd(this.getMyClanCandidates(), clan_get_my_clan_id(), null)
      },
      null,
      ::g_clans)

  this.onClanCandidatesChanged()
}

::g_clans.onClanCandidatesChanged <- function onClanCandidatesChanged() {
  if (! this.getUnseenCandidatesCount())
    removePopupByHandler(::g_clans)

  this.saveCandidates()
  ::update_clan_alert_icon()
}

::g_clans.getClanPlaceRewardLogData <- function getClanPlaceRewardLogData(clanData, maxCount = -1) {
  return this.getRewardLogData(clanData, "rewardLog", maxCount)
}

::g_clans.getRewardLogData <- function getRewardLogData(clanData, rewardId, maxCount) {
  let list = []
  local count = 0

  foreach (seasonReward in clanData[rewardId]) {
    local params = {
      iconStyle  = seasonReward.iconStyle()
      iconConfig = seasonReward.iconConfig()
      iconParams = seasonReward.iconParams()
      name = seasonReward.name()
      desc = seasonReward.desc()
    }

    params = params.__merge({
      bestRewardsConfig = { seasonName = seasonReward.seasonIdx, title = seasonReward.seasonTitle }
    })
    list.append(params)

    if (maxCount != -1 && ++count == maxCount)
      break
  }
  return list
}

::g_clans.showClanRewardLog <- function showClanRewardLog(clanData) {
  clanRewardsModal.open({
    rewards = this.getClanPlaceRewardLogData(clanData),
    clanId = clanData?.id
  })
}

::g_clans.getClanCreationDateText <- function getClanCreationDateText(clanData) {
  return time.buildDateStr(clanData.cdate)
}

::g_clans.getClanInfoChangeDateText <- function getClanInfoChangeDateText(clanData) {
  return time.buildDateTimeStr(clanData.changedTime, false, false)
}

::g_clans.getClanMembersCountText <- function getClanMembersCountText(clanData) {
  if (clanData.mlimit)
    return format("%d/%d", clanData.members.len(), clanData.mlimit)

  return format("%d", clanData.members.len())
}

::g_clans.haveRankToChangeRoles <- function haveRankToChangeRoles(clanData) {
  if (clanData?.id != clan_get_my_clan_id())
    return false

  let myRank = ::clan_get_role_rank(clan_get_my_role())

  local rolesNumber = 0
  for (local role = 0; role < ECMR_MAX_TOTAL; role++) {
     let rank = clan_get_role_rank(role)
     if (rank != 0 && rank < myRank)
       rolesNumber++
  }

  return (rolesNumber > 1)
}

::g_clans.getMyClanRights <- function getMyClanRights() {
  return ::clan_get_role_rights(::clan_get_admin_editor_mode() ? ECMR_CLANADMIN : clan_get_my_role())
}

::g_clans.getClanMemberRank <- function getClanMemberRank(clanData, name) {
  foreach (member in (clanData?.members ?? []))
    if (member.nick == name)
      return clan_get_role_rank(member.role)

  return 0
}

::g_clans.getLeadersCount <- function getLeadersCount(clanData) {
  local count = 0
  foreach (member in clanData.members) {
    let rights = clan_get_role_rights(member.role)
    if (isInArray("LEADER", rights) ||
        isInArray("DEPUTY", rights))
      count++
  }
  return count
}

::g_clans.dismissMember <- function dismissMember(contact, clanData) {
  let isMyClan = clanData?.id == clan_get_my_clan_id()
  let myClanRights = ::g_clans.getMyClanRights()

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

::g_clans.requestMembership <- function requestMembership(clanId) {
  if (::clan_get_requested_clan_id() == "-1" || clan_get_my_clan_name() == "") {
    this.membershipRequestSend(clanId)
    return
  }

  scene_msg_box("new_request_cancels_old",
                  null,
                  loc("msg/clan/clan_request_cancel_previous",
                    { prevClanName = colorize("hotkeyColor", clan_get_my_clan_name()) }),
                  [
                    ["ok", @() ::g_clans.membershipRequestSend(clanId) ],
                    ["cancel", @() null ]
                  ], "ok", { cancel_fn = @() null })
}

::g_clans.cancelMembership <- function cancelMembership() {
  this.membershipRequestSend("")
}

::g_clans.membershipRequestSend <- function membershipRequestSend(clanId) {
  let taskId = clan_request_membership_request(clanId, "", "", "")
  let onSuccess = function() {
    if (clanId == "") { //Means that membership was canceled
      broadcastEvent("ClanMembershipCanceled")
      return
    }

    addPopup("", loc("clan/requestSent"))
    broadcastEvent("ClanMembershipRequested")
  }
  addTask(taskId, { showProgressBox = true }, onSuccess)
}

::g_clans.approvePlayerRequest <- function approvePlayerRequest(playerUid, clanId) {
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

::g_clans.rejectPlayerRequest <- function rejectPlayerRequest(playerUid, clanId) {
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

::g_clans.blacklistAction <- function blacklistAction(playerUid, actionAdd, clanId) {
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

::g_clans.requestOpenComplainWnd <- function requestOpenComplainWnd(clanId) {
  if (!::tribunal.canComplaint())
    return

  let taskId = clan_request_info(clanId, "", "")
  let onSuccess = function() {
    let clanData = ::get_clan_info_table()
    ::g_clans.openComplainWnd(clanData)
  }

  addTask(taskId, { showProgressBox = true }, onSuccess)
}

::g_clans.openComplainWnd <- function openComplainWnd(clanData) {
  local leader = u.search(clanData.members, @(member) member.role == ECMR_LEADER)
  if (leader == null)
    leader = clanData.members[0]
  ::gui_modal_complain({ name = leader.nick, userId = leader.uid, clanData = clanData })
}

::g_clans.checkSquadronExpChangedEvent <- function checkSquadronExpChangedEvent() {
  let curSquadronExp = clan_get_exp()
  if (this.squadronExp == curSquadronExp)
    return

  this.squadronExp = curSquadronExp
  broadcastEvent("SquadronExpChanged")
}

::ranked_column_prefix <- "dr_era5"  //really used only rank 5, but in lb exist 5

function handleNewMyClanData() {
  ::g_clans.parseSeenCandidates()
  contactsByGroups[EPLX_CLAN] <- {}
  if ("members" not in ::my_clan_info)
    return

  let res = {}
  foreach (_mem, block in ::my_clan_info.members) {
    if (!(block.uid in contactsPlayers))
      ::getContact(block.uid, block.nick)

    let contact = contactsPlayers[block.uid]
    if (!isPlayerInFriendsGroup(block.uid) || contact.unknown)
      contact.presence = ::getMyClanMemberPresence(block.nick)

    if (userIdStr.value != block.uid)
      addContact(contact, EPLX_CLAN)

    res[block.nick] <- ::my_clan_info.tag
  }

  if (res.len() > 0)
    clanUserTable.mutate(@(v) v.__update(res))
}

::requestMyClanData <- function requestMyClanData(forceUpdate = false) {
  let myClanPrevMembersUid = ::g_clans.getMyClanMembers().map(@(m) m.uid)
  if (!get_my_clan_data_free)
    return

  ::g_clans.checkClanChangedEvent()
  ::g_clans.checkSquadronExpChangedEvent()

  let myClanId = clan_get_my_clan_id()
  if (myClanId == "-1") {
    if (::my_clan_info) {
      ::my_clan_info = null
      ::g_clans.parseSeenCandidates()
      clearClanTagForRemovedMembers(myClanPrevMembersUid, [])
      broadcastEvent("ClanInfoUpdate")
      broadcastEvent("ClanChanged") //i.e. dismissed
      ::update_gamercards()
    }
    return
  }

  if (!forceUpdate && getTblValue("id", ::my_clan_info, "-1") == myClanId)
    if (get_time_msec() - ::last_update_my_clan_time < -MY_CLAN_UPDATE_DELAY_MSEC)
      return

  ::last_update_my_clan_time = get_time_msec()
  let taskId = clan_request_my_info()
  get_my_clan_data_free = false
  addBgTaskCb(taskId, function() {
    let wasCreated = !::my_clan_info
    ::my_clan_info = ::get_clan_info_table()

    let myClanCurrMembersUid = ::g_clans.getMyClanMembers().map(@(m) m.uid)
    if (myClanCurrMembersUid.len() < myClanPrevMembersUid.len())
      clearClanTagForRemovedMembers(myClanPrevMembersUid, myClanCurrMembersUid)

    handleNewMyClanData()
    get_my_clan_data_free = true
    broadcastEvent("ClanInfoUpdate")
    ::update_gamercards()
    if (wasCreated)
      broadcastEvent("ClanChanged") //i.e created
  })
}

::is_in_my_clan <- function is_in_my_clan(name = null, uid = null) {
  if (::my_clan_info == null)
    return false
  if ("members" in ::my_clan_info)
    foreach (_i, block in ::my_clan_info.members) {
      if (name)
        if (name == block.nick)
          return true
      if (uid)
        if (uid == block.uid)
          return true
    }
  return false
}

::clan_candidate_list <- [
  { id = "nick", type = lbDataType.NICK }
  { id = "date", type = lbDataType.DATE }
];

let emptyRating = {
  [($"{::ranked_column_prefix}_arc")]   = 0,
  [($"{::ranked_column_prefix}_hist")]  = 0,
  [($"{::ranked_column_prefix}_sim")]   = 0
}

let emptyActivity = {
  cur = 0
  total = 0
}


let clanInfoTemplate = {
  function isRegionChangeAvailable() {
    if (this.regionLastUpdate == 0) // warning disable: -never-declared
      return true

    return this.regionLastUpdate + ::g_clans.getRegionUpdateCooldownTime() <= get_charserver_time_sec() // warning disable: -never-declared
  }

  function getRegionChangeAvailableTime() {
    return this.regionLastUpdate + ::g_clans.getRegionUpdateCooldownTime() // warning disable: -never-declared
  }

  function getClanUpgradeCost() {
    let cost = this.clanType.getNextTypeUpgradeCost()
    local resultingCostGold = cost.gold - this.spentForMemberUpgrades // warning disable: -never-declared
    if (resultingCostGold < 0)
      resultingCostGold = 0
    cost.gold = resultingCostGold
    return cost
  }

  function getAllRegaliaTags() {
    let result = []
    foreach (rewards in ["seasonRewards", "seasonRatingRewards"]) {
      local regalias = getTblValue("regaliaTags", this[rewards], [])
      if (!u.isArray(regalias))
        regalias = [regalias]

      //check for duplicate before add
      //total amount of regalias is less than 10, so this square
      //complexity actually is not a big deal
      foreach (regalia in regalias)
        if (!isInArray(regalia, result))
          result.append(regalia)
    }

    return result
  }

  function memberCount() {
    return this.members.len()
  }

  function getTypeName() {
    return this.clanType.getTypeName()
  }

  function getCreationDateText() {
    return ::g_clans.getClanCreationDateText(this)
  }

  function getInfoChangeDateText() {
    return ::g_clans.getClanInfoChangeDateText(this)
  }

  function getMembersCountText() {
    return ::g_clans.getClanMembersCountText(this)
  }

  function canShowActivity() {
    return hasFeature("ClanActivity")
  }

  function getActivity() {
    return this.astat?.activity ?? 0 // warning disable: -never-declared
  }
}

/**
 * Pass internal clanInfo for debug purposes
 */
::get_clan_info_table <- function get_clan_info_table(clanInfo = null) {
  if (!clanInfo)
    clanInfo = clan_get_clan_info()

  if (!clanInfo?._id)
    return null

  let clan = clone clanInfoTemplate
  clan.id     <- clanInfo._id
  clan.name   <- getTblValue("name",   clanInfo, "")
  clan.tag    <- getTblValue("tag",    clanInfo, "")
  clan.lastPaidTag <- getTblValue("lastPaidTag", clanInfo, "")
  clan.slogan <- getTblValue("slogan", clanInfo, "")
  clan.desc   <- getTblValue("desc",   clanInfo, "")
  clan.region <- getTblValue("region", clanInfo, "")
  clan.announcement <- getTblValue("announcement", clanInfo, "")
  clan.cdate  <- getTblValue("cdate",  clanInfo, 0)
  clan.status <- getTblValue("status", clanInfo, "open")
  clan.mlimit <- getTblValue("mlimit", clanInfo, 0)

  clan.changedByNick <- getTblValue("changed_by_nick", clanInfo, "")
  clan.changedByUid <- getTblValue("changed_by_uid", clanInfo, "")
  clan.changedTime <- getTblValue("changed_time", clanInfo, 0)

  clan.spentForMemberUpgrades <- getTblValue("mspent", clanInfo, 0)
  clan.regionLastUpdate <- getTblValue("region_last_updated", clanInfo, 0)
  clan.clanType   <- g_clan_type.getTypeByName(clanInfo?.type ?? "")
  clan.autoAcceptMembership <- getTblValue("autoaccept",   clanInfo, false)
  clan.membershipRequirements <- DataBlock()
  let membReqs = clan_get_membership_requirements(clanInfo)
  if (membReqs)
    clan.membershipRequirements.setFrom(membReqs);

  clan.astat <- copyParamsToTable(clanInfo?.astat)

  let clanMembersInfo = clanInfo % "members"
  local clanActivityInfo = clanInfo?.activity
  if (!clanActivityInfo)
    clanActivityInfo = DataBlock()

  clan.members <- []

  let member_ratings = getTblValue("member_ratings", clanInfo, {})
  let getTotalActivityPerPeriod = function(expActivity) {
    local res = 0
    eachBlock(expActivity, @(period) res += period.activity)
    return res
  }

  foreach (member in clanMembersInfo) {
    //get common members data
    let memberItem = copyParamsToTable(member)

    //get members ELO
    let ratingTable = getTblValue(memberItem.uid, member_ratings, {})
    foreach (key, value in emptyRating)
      memberItem[key] <- round(getTblValue(key, ratingTable, value))
    memberItem.onlineStatus <- contactPresence.UNKNOWN

    //get members activity
    let memberActivityInfo = clanActivityInfo.getBlockByName(memberItem.uid) || DataBlock()
    foreach (key, value in emptyActivity)
      memberItem[$"{key}Activity"] <- memberActivityInfo.getInt(key, value)
    let history = memberActivityInfo.getBlockByName("history")
    memberItem["activityHistory"] <- u.isDataBlock(history) ? convertBlk(history) : {}
    memberItem["curPeriodActivity"] <- memberActivityInfo?.activity ?? 0
    let expActivity = memberActivityInfo.getBlockByName("expActivity")
    memberItem["expActivity"] <- u.isDataBlock(expActivity) ? convertBlk(expActivity) : {}
    memberItem["totalPeriodActivity"] <- getTotalActivityPerPeriod(expActivity)

    clan.members.append(memberItem)
  }

  let clanCandidatesInfo = clanInfo % "candidates";
  clan.candidates <- []

  foreach (candidate in clanCandidatesInfo) {
    let candidateTemp = {}
    foreach (info, value in candidate)
      candidateTemp[info] <- value
    clan.candidates.append(candidateTemp)
  }

  let clanBlacklist = clanInfo % "blacklist"
  clan.blacklist <- []

  foreach (person in clanBlacklist) {
    let blackTemp = {}
    foreach (info, value in person)
      blackTemp[info] <- value
    clan.blacklist.append(blackTemp)
  }

  let getRewardLog = function(clanInfo_, rewardBlockId, titleClass) {
    if (!(rewardBlockId in clanInfo_))
      return []

    let logObj = []
    eachBlock(clanInfo_[rewardBlockId], function(season, idx) {
      foreach (title in season % "titles")
        logObj.append(titleClass.createFromClanReward(title, idx, season, clan))
    })
    return logObj
  }

  let sortRewardsInlog = @(a, b) b.seasonTime <=> a.seasonTime
  let getBestRewardLog = function() {
    let logObj = []
    foreach (reward in clanInfo % "clanBestRewards")
      logObj.append({ seasonName = reward.seasonName, title = reward.title })
    return logObj
  }

  clan.rewardLog <- getRewardLog(clanInfo, "clanRewardLog", ::ClanSeasonPlaceTitle)
  clan.rewardLog.sort(sortRewardsInlog)
  clan.clanBestRewards <- getBestRewardLog()

  let clanSeasonRewards = clanInfo?.clanSeasonRewards
  clan.seasonRewards <- u.isDataBlock(clanSeasonRewards) ? convertBlk(clanSeasonRewards) : {}
  let clanSeasonRatingRewards = clanInfo?.clanSeasonRatingRewards
  clan.seasonRatingRewards <- u.isDataBlock(clanSeasonRatingRewards)
    ? convertBlk(clanSeasonRatingRewards) : {}

  clan.maxActivityPerPeriod <- clanInfo?.maxActivityPerPeriod ?? 0
  clan.maxClanActivity <- clanInfo?.maxClanActivity ?? 0
  clan.rewardPeriodDays <- clanInfo?.rewardPeriodDays ?? 0
  clan.expRewardEnabled <- clanInfo?.expRewardEnabled ?? false
  clan.historyDepth <- clanInfo?.historyDepth ?? 14
  clan.nextRewardDayId <- clanInfo?.nextRewardDayId

  //dlog("GP: Show clan table");
  //debugTableData(clan);
  return ::getFilteredClanData(clan)
}

function getSeasonName(blk) {
  local name = ""
  if (blk?.type == "worldWar")
    name = loc($"worldwar/season_name/{split_by_chars(blk.titles, "@")?[2] ?? ""}")
  else {
    let year = unixtime_to_utc_timetbl(blk?.seasonStartTimestamp ?? 0).year.tostring()
    let num  = get_roman_numeral(to_integer_safe(blk?.numInYear ?? 0)
      + CLAN_SEASON_NUM_IN_YEAR_SHIFT)
    name = loc("clan/battle_season/name", { year = year, num = num })
  }
  return name
}

class ClanSeasonTitle {
  clanTag = ""
  clanName = ""
  seasonName = ""
  seasonTime = 0
  difficultyName = ""


  constructor (...) {
    assert(false, "Error: attempt to instantiate ClanSeasonTitle intreface class.")
  }

  function getBattleTypeTitle() {
    let difficulty = g_difficulty.getDifficultyByEgdLowercaseName(this.difficultyName)
    return loc(difficulty.abbreviation)
  }

  function getUpdatedClanInfo(unlockBlk) {
    local isMyClan = is_in_clan() && (unlockBlk?.clanId ?? "").tostring() == clan_get_my_clan_id()
    return {
      clanTag  = isMyClan ? clan_get_my_clan_tag()  : unlockBlk?.clanTag
      clanName = isMyClan ? clan_get_my_clan_name() : unlockBlk?.clanName
    }
  }

  function name() {}
  function desc() {}
  function iconStyle() {}
  function iconParams() {}
}


::ClanSeasonPlaceTitle <- class (ClanSeasonTitle) {
  place = ""
  seasonType = ""
  seasonTag = null
  seasonIdx = ""
  seasonTitle = ""

  static function createFromClanReward (titleString, sIdx, season, clanData) {
    let titleParts = split_by_chars(titleString, "@")
    let place = getTblValue(0, titleParts, "")
    let difficultyName = getTblValue(1, titleParts, "")
    let sTag = titleParts?[2]
    return ::ClanSeasonPlaceTitle(
      season?.t,
      season?.type,
      sTag,
      difficultyName,
      place,
      getSeasonName(season),
      clanData.tag,
      clanData.name,
      sIdx,
      titleString
    )
  }


  static function createFromUnlockBlk (unlockBlk) {
    let idParts = split_by_chars(unlockBlk.id, "_")
    let info = ::ClanSeasonPlaceTitle.getUpdatedClanInfo(unlockBlk)
    return ::ClanSeasonPlaceTitle(
      unlockBlk?.t,
      "",
      null,
      unlockBlk?.rewardForDiff,
      idParts[0],
      getSeasonName(unlockBlk),
      info.clanTag,
      info.clanName,
      "",
      ""
    )
  }


  constructor (
    v_seasonTime,
    v_seasonType,
    v_seasonTag,
    v_difficlutyName,
    v_place,
    v_seasonName,
    v_clanTag,
    v_clanName,
    v_seasonIdx,
    v_seasonTitle
  ) {
    this.seasonTime = v_seasonTime
    this.seasonType = v_seasonType
    this.seasonTag = v_seasonTag
    this.difficultyName = v_difficlutyName
    this.place = v_place
    this.seasonName = v_seasonName
    this.clanTag = v_clanTag
    this.clanName = v_clanName
    this.seasonIdx = v_seasonIdx
    this.seasonTitle = v_seasonTitle
  }

  function isWinner() {
    return startsWith(this.place, "place")
  }

  function getPlaceTitle() {
    if (this.isWinner())
      return loc($"clan/season_award/place/{this.place}")
    else
      return loc("clan/season_award/place/top", { top = slice(this.place, 3) })
  }

  function name() {
    let path = this.seasonType == "worldWar" ? "clan/season_award_ww/title" : "clan/season_award/title"
    return loc(
      path,
      {
        achievement = this.getPlaceTitle()
        battleType = this.getBattleTypeTitle()
        season = this.seasonName
      }
    )
  }

  function desc() {
    let placeTitleColored = colorize("activeTextColor", this.getPlaceTitle())
    let params = {
      place = placeTitleColored
      top = placeTitleColored
      squadron = colorize("activeTextColor", nbsp.concat(this.clanTag, this.clanName))
      season = colorize("activeTextColor", this.seasonName)
    }
    let winner = this.isWinner() ? "place" : "top"
    let path = this.seasonType == "worldWar" ? "clan/season_award_ww/desc/" : "clan/season_award/desc/"

    return loc("".concat(path, winner), this.seasonType == "worldWar"
      ? params
      : params.__merge({ battleType = colorize("activeTextColor", this.getBattleTypeTitle()) }))
  }

  function iconStyle() {
    return $"clan_medal_{this.place}_{this.difficultyName}"
  }

  function iconConfig() {
    if (this.seasonType != "worldWar" || !this.seasonTag)
      return null

    let bg_img = "clan_medal_ww_bg"
    let path = this.isWinner() ? this.place : "rating"
    let bin_img = $"clan_medal_ww_{this.seasonTag}_bin_{path}"
    local place_img =$"clan_medal_ww_{this.place}"
    return ";".join([bg_img, bin_img, place_img], true)
  }

  function iconParams() {
    return { season_title = { text = this.seasonName } }
  }
}

// Warning! getFilteredClanData() actualy mutates its parameter and returns it back
::getFilteredClanData <- function getFilteredClanData(clanData, author = "") {
  if ("tag" in clanData)
    clanData.tag = ::checkClanTagForDirtyWords(clanData.tag)

  let textFields = [
    "name"
    "desc"
    "slogan"
    "announcement"
    "region"
  ]

  local isPlayerBlocked = false
  if (isPlatformSony) {
    //Try get author of changes from incomming clanData
    if (author == "") {
      author = clanData?.changedByNick ?? ""
      if (author == "") {
        let uid = clanData?.creator_uid ?? clanData?.changed_by_uid ?? clanData?.changedByUid ?? ""
        if (uid != "")
          author = ::getContact(uid)?.name ?? ""
      }
    }

    isPlayerBlocked = isPlayerNickInContacts(author, EPL_BLOCKLIST)
    if (isPlayerBlocked)
      textFields.append("tag")
  }

  foreach (key in textFields)
    if (key in clanData)
      clanData[key] = ::ps4CheckAndReplaceContentDisabledText(clanData[key], isPlayerBlocked)

  return clanData
}

::checkClanTagForDirtyWords <- function checkClanTagForDirtyWords(clanTag, returnString = true) {
  if (isPlatformSony)
    return returnString ? checkName(clanTag) : isNamePassing(clanTag)
  return returnString ? clanTag : true
}

let ps4ContentDisabledRegExp = regexp2("[^ ]")

::ps4CheckAndReplaceContentDisabledText <- function ps4CheckAndReplaceContentDisabledText(processingString, forceReplace = false) {
  if (!ps4_is_ugc_enabled() || forceReplace)
    processingString = ps4ContentDisabledRegExp.replace("*", processingString)
  return processingString
}

::getMyClanMemberPresence <- function getMyClanMemberPresence(nick) {
  let clanActiveUsers = []

  foreach (roomData in g_chat.rooms)
    if (g_chat.isRoomClan(roomData.id) && roomData.users.len() > 0) {
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

::get_show_in_squadron_statistics <- function get_show_in_squadron_statistics(diff) {
  return ::g_clan_seasons.hasPrizePlacesRewards(diff)
}

::clan_request_set_membership_requirements <- function clan_request_set_membership_requirements(clanIdStr, requirements, autoAccept) {
  let blk = DataBlock()
  blk["membership_req"] <- requirements
  blk["_id"] = clanIdStr
  if (autoAccept)
    blk["autoaccept"] = true
  return char_send_clan_oneway_blk("cln_clan_set_membership_requirements", blk)
}

subscribe_handler(::g_clans, g_listener_priority.DEFAULT_HANDLER)