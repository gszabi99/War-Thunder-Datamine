local { unixtime_to_utc_timetbl } = ::require_native("dagor.time")
local time = require("scripts/time.nut")
local clanRewardsModal = require("scripts/rewards/clanRewardsModal.nut")
local dirtyWordsFilter = require("scripts/dirtyWords/dirtyWords.nut")
local { getPlayerName, isPlatformSony } = require("scripts/clientState/platform.nut")

const CLAN_ID_NOT_INITED = ""
global const CLAN_SEASON_NUM_IN_YEAR_SHIFT = 1 // Because numInYear is zero-based.
const CLAN_SEEN_CANDIDATES_SAVE_ID = "seen_clan_candidates"
const MAX_CANDIDATES_NICKNAMES_IN_POPUP = 5
const MY_CLAN_UPDATE_DELAY_MSEC = -60000

::my_clan_info <- null
::last_update_my_clan_time <- MY_CLAN_UPDATE_DELAY_MSEC
::get_my_clan_data_free <- true

::g_script_reloader.registerPersistentData("ClansGlobals", ::getroottable(),
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
    ::contacts[::EPLX_CLAN] <- []
    if (!::is_in_clan())
      return

    foreach(block in (::my_clan_info?.members ?? []))
    {
      if(!(block.uid in ::contacts_players))
        ::getContact(block.uid, block.nick)
      ::contacts_players[block.uid].presence = ::getMyClanMemberPresence(block.nick)
      if(::my_user_id_str != block.uid)
        ::contacts[::EPLX_CLAN].append(::contacts_players[block.uid])
    }
  }
}

g_clans.getMyClanType <- function getMyClanType()
{
  local code = ::clan_get_my_clan_type()
  return ::g_clan_type.getTypeByCode(code)
}

g_clans.createClan <- function createClan(params, handler)
{
  handler.taskId = ::char_send_blk("cln_clan_create", params)
  if (handler.taskId < 0)
    return

  ::set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  ::sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp = (@(handler) function() {
    ::requestMyClanData()
    ::update_gamercards()
    handler.msgBox(
      "clan_create_sacces",
      ::loc("clan/create_clan_success"),
      [["ok", (@(handler) function() { handler.goBack() })(handler)]], "ok")
  })(handler)
}

/**
 * Edit specified clan.
 * clanId @string - id of clan to edit, -1 if your clan
 * params @DataBlock - result of g_clan::prepareEditRequest function
 */
g_clans.editClan <- function editClan(clanId, params, handler)
{
  local isMyClan = ::my_clan_info != null && clanId == "-1"
  handler.taskId = ::clan_request_change_info_blk(clanId, params)
  if (handler.taskId < 0)
    return

  ::set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  if (isMyClan)
    ::sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp = (@(handler) function() {
    local owner = ::getTblValue("owner", handler, null)
    if(::clan_get_admin_editor_mode() && "reinitClanWindow" in owner)
      owner.reinitClanWindow()
    else
      ::update_gamercards()
    msgBox(
      "clan_edit_sacces",
      ::loc("clan/edit_clan_success"),
      [["ok", (@(handler) function() { handler.goBack() })(handler)]], "ok")
  })(handler)
}

g_clans.upgradeClan <- function upgradeClan(clanId, params, handler)
{
  local isMyClan = ::my_clan_info != null && clanId != "-1"
  handler.taskId = ::clan_action_blk(clanId, "cln_clan_upgrade", params, true)
  if (handler.taskId < 0)
    return

  ::set_char_cb(handler, handler.slotOpCb)
  handler.showTaskProgressBox()
  if (isMyClan)
    ::sync_handler_simulate_signal("clan_info_reload")
  handler.afterSlotOp = (@(handler) function() {
    local owner = ::getTblValue("owner", handler, null)
    if(::clan_get_admin_editor_mode() && "reinitClanWindow" in owner)
      owner.reinitClanWindow()
    else
      ::update_gamercards()
    msgBox(
      "clan_upgrade_success",
      ::loc("clan/upgrade_clan_success"),
      [["ok", (@(handler) function() { handler.goBack() })(handler)]], "ok")
  })(handler)
}

g_clans.upgradeClanMembers <- function upgradeClanMembers(clanId)
{
  local isMyClan = ::my_clan_info != null && clanId != "-1"
  local params = ::DataBlock()
  local taskId = ::clan_action_blk(clanId, "cln_clan_members_upgrade", params, true)

  local cb = ::Callback(
      (@(clanId) function() {
        ::broadcastEvent("ClanMembersUpgraded", {clanId = clanId})
        ::update_gamercards()
        ::showInfoMsgBox(::loc("clan/members_upgrade_success"), "clan_members_upgrade_success")
      })(clanId),
      this)

  if (::g_tasker.addTask(taskId, {showProgressBox = true}, cb) && isMyClan)
    ::sync_handler_simulate_signal("clan_info_reload")
}

g_clans.disbandClan <- function disbandClan(clanId, handler)
{
  ::gui_modal_comment(handler, ::loc("clan/writeCommentary"), ::loc("clan/btnDisbandClan"),
                      (@(handler, clanId) function(comment) {
                        handler.taskId = ::clan_request_disband(clanId, comment);

                        if (handler.taskId >= 0)
                        {
                          ::set_char_cb(handler, slotOpCb)
                          handler.showTaskProgressBox()
                          if (isMyClan)
                            ::sync_handler_simulate_signal("clan_info_reload")
                          handler.afterSlotOp = (@(handler, isMyClan) function() {
                              ::requestMyClanData()
                              ::update_gamercards()
                              handler.msgBox("clan_disbanded", ::loc("clan/clanDisbanded"), [["ok", (@(handler) function() { handler.goBack() })(handler) ]], "ok")
                            })(handler, isMyClan)
                        }
                      })(handler, clanId), true)
}

g_clans.prepareCreateRequest <- function prepareCreateRequest(clanType, name, tag, slogan, description, announcement, region)
{
  local requestData = ::DataBlock()
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

g_clans.getMyClanMembersCount <- function getMyClanMembersCount()
{
  return ::getTblValue("members", ::my_clan_info, []).len()
}

g_clans.getMyClanMembers <- function getMyClanMembers()
{
  return ::my_clan_info?.members ?? []
}

g_clans.getMyClanCandidates <- function getMyClanCandidates()
{
  return ::getTblValue("candidates", ::my_clan_info, [])
}

g_clans.prepareEditRequest <- function prepareEditRequest(clanType, name, tag, slogan, description, announcement, region)
{
  local requestData = ::DataBlock()

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

g_clans.prepareUpgradeRequest <- function prepareUpgradeRequest(clanType, tag, description, announcement)
{
  local requestData = ::DataBlock()
  requestData["type"] = clanType.getTypeName()
  requestData["tag"] = tag
  requestData["desc"] = clanType.isDescriptionChangeAllowed() ? description : ""
  requestData["announcement"] = clanType.isAnnouncementAllowed() ? announcement : ""
  return requestData
}

/** Returns false if battalion clan type is disabled. */
g_clans.clanTypesEnabled <- function clanTypesEnabled()
{
  return ::has_feature("Battalions")
}

/**
 * Return minimum interval between clan region update in menuts.
 * 1 day by default.
 */
g_clans.getRegionUpdateCooldownTime <- function getRegionUpdateCooldownTime()
{
  return ::getTblValue(
    "clansChangeRegionPeriodSeconds",
    ::get_game_settings_blk(),
    time.daysToSeconds(1)
  )
}

g_clans.requestClanLog <- function requestClanLog(clanId, rowsCount, requestMarker, callbackFnSuccess, callbackFnError, handler)
{
  local params = ::DataBlock()
  params._id = clanId.tointeger()
  params.count = rowsCount

  //Allow to display only clan info changes
  if ((::clan_get_my_clan_id() != clanId) && !::clan_get_admin_editor_mode())
    params.events = "create;info"

  if (requestMarker != null)
    params.last = requestMarker
  local taskId = ::clan_request_log(clanId, params)
  local successCb = ::Callback(callbackFnSuccess, handler)
  local errorCb = ::Callback(callbackFnError, handler)

  ::g_tasker.addTask(
    taskId,
    null,
    (@(successCb) function () {
      local logData = {}
      local logDataBlk = ::clan_get_clan_log()

      logData.requestMarker <- logDataBlk?.lastMark
      logData.logEntries <- []
      foreach (logEntry in logDataBlk % "log")
      {
        if (logEntry?.uid != null && logEntry?.nick != null)
          ::getContact(logEntry.uid, logEntry.nick)

        if (logEntry?.uId != null && logEntry?.uN != null)
          ::getContact(logEntry.uId, logEntry.uN)

        local logEntryTable = ::buildTableFromBlk(logEntry)
        local logType = ::g_clan_log_type.getTypeByName(logEntryTable.ev)

        if ("time" in logEntryTable)
          logEntryTable.time = time.buildDateTimeStr(logEntryTable.time)

        logEntryTable.header <- logType.getLogHeader(logEntryTable)
        if (logType.needDetails(logEntryTable))
        {
          local commonFields = logType.getLogDetailsCommonFields()
          local shortCommonDetails = logEntryTable.filter(@(v,k) commonFields.indexof(k)!=null)
          local individualFields = logType.getLogDetailsIndividualFields()
          local shortIndividualDetails = logEntryTable.filter(@(v,k) individualFields.indexof(k)!=null)

          local fullDetails = shortCommonDetails
          foreach (key, value in shortIndividualDetails)
          {
            local fullKey = logEntryTable.ev + "_" + key
            fullDetails[fullKey] <- value
          }

          logEntryTable.details <- fullDetails
          logEntryTable.details.signText <- logType.getSignText(logEntryTable)
        }

        logData.logEntries.append(logEntryTable)
      }

      successCb(logData)
    })(successCb),
    errorCb
  )
}

g_clans.hasRightsToQueueWWar <- function hasRightsToQueueWWar()
{
  if (!::is_in_clan())
    return false
  if (!::has_feature("WorldWarClansQueue"))
    return false
  local myRights = ::clan_get_role_rights(::clan_get_my_role())
  return ::isInArray("WW_REGISTER", myRights)
}

g_clans.isNonLatinCharsAllowedInClanName <- function isNonLatinCharsAllowedInClanName()
{
  return ::is_vendor_tencent()
}

g_clans.stripClanTagDecorators <- function stripClanTagDecorators(clanTag)
{
  local uftClanTag = ::utf8(clanTag)
  local length = uftClanTag.charCount()
  return length > 2 ? uftClanTag.slice(1, length - 1) : clanTag
}

g_clans.checkClanChangedEvent <- function checkClanChangedEvent()
{
  if (lastClanId == ::clan_get_my_clan_id())
    return

  local needEvent = lastClanId != CLAN_ID_NOT_INITED
  lastClanId = ::clan_get_my_clan_id()
  if (needEvent)
    ::broadcastEvent("MyClanIdChanged")
}

g_clans.onEventProfileUpdated <- function onEventProfileUpdated(p)
{
  ::requestMyClanData()
}

g_clans.onEventScriptsReloaded <- function onEventScriptsReloaded(p)
{
  ::requestMyClanData()
}

g_clans.onEventSignOut <- function onEventSignOut(p)
{
  lastClanId = CLAN_ID_NOT_INITED
  seenCandidatesBlk = null
  squadronExp = 0
  ::last_update_my_clan_time = MY_CLAN_UPDATE_DELAY_MSEC
}

g_clans.loadSeenCandidates <- function loadSeenCandidates()
{
  local result = ::DataBlock()
  if(::g_login.isProfileReceived() && isHaveRightsToReviewCandidates())
  {
    local loaded = ::load_local_account_settings(CLAN_SEEN_CANDIDATES_SAVE_ID, null)
    if(loaded != null)
      result.setFrom(loaded)
  }
  return result
}

g_clans.saveCandidates <- function saveCandidates()
{
  if(!::g_login.isProfileReceived() || !isHaveRightsToReviewCandidates() || !seenCandidatesBlk)
    return
  ::save_local_account_settings(CLAN_SEEN_CANDIDATES_SAVE_ID, seenCandidatesBlk)
}

g_clans.getUnseenCandidatesCount <- function getUnseenCandidatesCount()
{
  if( ! ::my_clan_info || ! getMyClanCandidates().len() ||
    ! isHaveRightsToReviewCandidates() || ! seenCandidatesBlk)
    return 0

  local count = 0
  local clanCandidates = getMyClanCandidates()
  foreach (clanCandidate in clanCandidates)
  {
    local result = seenCandidatesBlk?[clanCandidate.uid]
    if( ! result)
      count++
  }
  return count
}

g_clans.markClanCandidatesAsViewed <- function markClanCandidatesAsViewed()
{
  if( ! isHaveRightsToReviewCandidates())
    return

  local clanInfoChanged = false
  local clanCandidates = getMyClanCandidates()
  foreach (clanCandidate in clanCandidates)
  {
    if (seenCandidatesBlk?[clanCandidate.uid] == true)
      continue

    seenCandidatesBlk[clanCandidate.uid] = true
    clanInfoChanged = true
  }
  if(clanInfoChanged)
    onClanCandidatesChanged()
}

g_clans.isHaveRightsToReviewCandidates <- function isHaveRightsToReviewCandidates()
{
  if (!::is_in_clan() || !::has_feature("Clans"))
    return false
  local rights = ::clan_get_role_rights(::clan_get_my_role())
  return isInArray("MEMBER_ADDING", rights) || isInArray("MEMBER_REJECT", rights)
}

g_clans.parseSeenCandidates <- function parseSeenCandidates()
{
  if (!::has_feature("Clans"))
    return

  if (!seenCandidatesBlk)
    seenCandidatesBlk = loadSeenCandidates()

  local isChanged = false
  local actualUids = {}
  local newCandidatesNicknames = []
  local clanCandidates = getMyClanCandidates()
  foreach(candidate in clanCandidates)
  {
    actualUids[candidate.uid] <- true
    if(seenCandidatesBlk?[candidate.uid] != null)
      continue
    seenCandidatesBlk[candidate.uid] <- false
    newCandidatesNicknames.append(getPlayerName(candidate.nick))
    isChanged = true
  }

  for (local i = seenCandidatesBlk.paramCount()-1; i >= 0; i--)
  {
    local paramName = seenCandidatesBlk.getParamName(i)
    if( ! (paramName in actualUids))
    {
      isChanged = true
      seenCandidatesBlk[paramName] = null
    }
  }

  if( ! isChanged)
    return

  local extraText = ""
  if(newCandidatesNicknames.len() > MAX_CANDIDATES_NICKNAMES_IN_POPUP)
  {
    extraText = ::loc("clan/moreCandidates",
      {count = newCandidatesNicknames.len() - MAX_CANDIDATES_NICKNAMES_IN_POPUP})
    newCandidatesNicknames.resize(MAX_CANDIDATES_NICKNAMES_IN_POPUP)
  }

  if(newCandidatesNicknames.len())
    ::g_popups.add(null,
      ::loc("clan/requestRecieved") +::loc("ui/colon") +::g_string.implode(newCandidatesNicknames, ", ") +
      " " + extraText,
      function()
      {
        if(getMyClanCandidates().len())
          showClanRequests(getMyClanCandidates(), ::clan_get_my_clan_id(), null)
      },
      null,
      ::g_clans)

  onClanCandidatesChanged()
}

g_clans.onClanCandidatesChanged <- function onClanCandidatesChanged()
{
  if( ! getUnseenCandidatesCount())
    ::g_popups.removeByHandler(::g_clans)

  saveCandidates()
  ::update_clan_alert_icon()
}

g_clans.getClanPlaceRewardLogData <- function getClanPlaceRewardLogData(clanData, maxCount = -1)
{
  return getRewardLogData(clanData, "rewardLog", maxCount)
}

g_clans.getRewardLogData <- function getRewardLogData(clanData, rewardId, maxCount)
{
  local list = []
  local count = 0

  foreach (seasonReward in clanData[rewardId])
  {
    local params = {
      iconStyle  = seasonReward.iconStyle()
      iconConfig = seasonReward.iconConfig()
      iconParams = seasonReward.iconParams()
      name = seasonReward.name()
      desc = seasonReward.desc()
    }

    params = params.__merge({
      bestRewardsConfig = {seasonName = seasonReward.seasonIdx, title = seasonReward.seasonTitle}
    })
    list.append(params)

    if (maxCount != -1 && ++count == maxCount)
      break
  }
  return list
}

g_clans.showClanRewardLog <- function showClanRewardLog(clanData)
{
  clanRewardsModal.open({
    rewards = getClanPlaceRewardLogData(clanData),
    clanId = clanData?.id
  })
}

g_clans.getClanCreationDateText <- function getClanCreationDateText(clanData)
{
  return time.buildDateStr(clanData.cdate)
}

g_clans.getClanInfoChangeDateText <- function getClanInfoChangeDateText(clanData)
{
  return time.buildDateTimeStr(clanData.changedTime, false, false)
}

g_clans.getClanMembersCountText <- function getClanMembersCountText(clanData)
{
  if (clanData.mlimit)
    return ::format("%d/%d", clanData.members.len(), clanData.mlimit)

  return ::format("%d", clanData.members.len())
}

g_clans.haveRankToChangeRoles <- function haveRankToChangeRoles(clanData)
{
  if (clanData?.id != ::clan_get_my_clan_id())
    return false

  local myRank = ::clan_get_role_rank(::clan_get_my_role())

  local rolesNumber = 0
  for (local role = 0; role < ::ECMR_MAX_TOTAL; role++)
  {
     local rank = ::clan_get_role_rank(role)
     if (rank != 0 && rank < myRank)
       rolesNumber++
  }

  return (rolesNumber > 1)
}

g_clans.getMyClanRights <- function getMyClanRights()
{
  return ::clan_get_role_rights(::clan_get_admin_editor_mode() ? ::ECMR_CLANADMIN : ::clan_get_my_role())
}

g_clans.getClanMemberRank <- function getClanMemberRank(clanData, name)
{
  foreach(member in (clanData?.members ?? []))
    if (member.nick == name)
      return ::clan_get_role_rank(member.role)

  return 0
}

g_clans.getLeadersCount <- function getLeadersCount(clanData)
{
  local count = 0
  foreach(member in clanData.members)
  {
    local rights = ::clan_get_role_rights(member.role)
    if (::isInArray("LEADER", rights) ||
        ::isInArray("DEPUTY", rights))
      count++
  }
  return count
}

g_clans.dismissMember <- function dismissMember(contact, clanData)
{
  local isMyClan = clanData?.id == ::clan_get_my_clan_id()
  local myClanRights = ::g_clans.getMyClanRights()

  if ((!isMyClan || !::isInArray("MEMBER_DISMISS", myClanRights)) && !::clan_get_admin_editor_mode())
    return

  ::gui_modal_comment(
    null,
    ::loc("clan/writeCommentary"),
    ::loc("clan/btnDismissMember"),
    function(comment) {
      local onSuccess = function() {
        ::broadcastEvent("ClanMemberDismissed")
        ::g_popups.add("", ::loc("clan/memberDismissed"))
      }

      local taskId = ::clan_request_dismiss_member(contact.uid, comment)
      ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess)
    }
  )
}

g_clans.requestMembership <- function requestMembership(clanId)
{
  if (::clan_get_requested_clan_id() == "-1" || ::clan_get_my_clan_name() == "")
  {
    membershipRequestSend(clanId)
    return
  }

  ::scene_msg_box("new_request_cancels_old",
                  null,
                  ::loc("msg/clan/clan_request_cancel_previous",
                    { prevClanName = ::colorize("hotkeyColor", ::clan_get_my_clan_name())}),
                  [
                    ["ok", @() ::g_clans.membershipRequestSend(clanId) ],
                    ["cancel", @() null ]
                  ], "ok", { cancel_fn = @() null })
}

g_clans.cancelMembership <- function cancelMembership()
{
  membershipRequestSend("")
}

g_clans.membershipRequestSend <- function membershipRequestSend(clanId)
{
  local taskId = ::clan_request_membership_request(clanId, "", "", "")
  local onSuccess = function()
  {
    if (clanId == "") //Means that membership was canceled
    {
      ::broadcastEvent("ClanMembershipCanceled")
      return
    }

    ::g_popups.add("", ::loc("clan/requestSent"))
    ::broadcastEvent("ClanMembershipRequested")
  }
  ::g_tasker.addTask(taskId, {showProgressBox = true}, onSuccess)
}

g_clans.approvePlayerRequest <- function approvePlayerRequest(playerUid, clanId)
{
  if (::u.isEmpty(playerUid) || ::u.isEmpty(clanId))
    return

  local onSuccess = function() {
    ::g_popups.add("", ::loc("clan/requestApproved"))
    ::broadcastEvent("ClanCandidatesListChanged", {userId = playerUid})
  }

  local taskId = ::clan_request_accept_membership_request(clanId, playerUid, "REGULAR", false)
  ::sync_handler_simulate_signal("clan_info_reload")
  ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess)
}

g_clans.rejectPlayerRequest <- function rejectPlayerRequest(playerUid, clanId)
{
  if (::u.isEmpty(playerUid))
    return

  ::gui_modal_comment(
    null,
    ::loc("clan/writeCommentary"),
    ::loc("clan/requestReject"),
    function(comment) {
      local onSuccess = function() {
        ::g_popups.add("", ::loc("clan/requestRejected"))
        ::broadcastEvent("ClanCandidatesListChanged", { userId = playerUid })
      }

      local taskId = ::clan_request_reject_membership_request(playerUid, comment, clanId)
      ::sync_handler_simulate_signal("clan_info_reload")
      ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess)
    }
  )
}

g_clans.blacklistAction <- function blacklistAction(playerUid, actionAdd, clanId)
{
  ::gui_modal_comment(
    null,
    ::loc("clan/writeCommentary"),
    ::loc("msgbox/btn_ok"),
    function(comment) {
      local onSuccess = function() {
        local text = actionAdd? ::loc("clan/blacklistAddSuccess") : ::loc("clan/blacklistRemoveSuccess")
        ::g_popups.add("", text)
        ::broadcastEvent("ClanCandidatesListChanged", { userId = playerUid })
      }

      local taskId = ::clan_request_edit_black_list(playerUid, actionAdd, comment, clanId)
      ::sync_handler_simulate_signal("clan_info_reload")
      ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess)
    }
  )
}

g_clans.requestOpenComplainWnd <- function requestOpenComplainWnd(clanId)
{
  if (!::tribunal.canComplaint())
    return

  local taskId = ::clan_request_info(clanId, "", "")
  local onSuccess = function() {
    local clanData = ::get_clan_info_table()
    ::g_clans.openComplainWnd(clanData)
  }

  ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess)
}

g_clans.openComplainWnd <- function openComplainWnd(clanData)
{
  local leader = ::u.search(clanData.members, @(member) member.role == ::ECMR_LEADER)
  if (leader == null)
    leader = clanData.members[0]
  ::gui_modal_complain({name = leader.nick, userId = leader.uid, clanData = clanData})
}

g_clans.checkSquadronExpChangedEvent <- function checkSquadronExpChangedEvent()
{
  local curSquadronExp = ::clan_get_exp()
  if (squadronExp == curSquadronExp)
    return

  squadronExp = curSquadronExp
  ::broadcastEvent("SquadronExpChanged")
}

::ranked_column_prefix <- "dr_era5"  //really used only rank 5, but in lb exist 5

::requestMyClanData <- function requestMyClanData(forceUpdate = false)
{
  if(!::get_my_clan_data_free)
    return

  ::g_clans.checkClanChangedEvent()
  ::g_clans.checkSquadronExpChangedEvent()

  local myClanId = ::clan_get_my_clan_id()
  if(myClanId == "-1")
  {
    if (::my_clan_info)
    {
      ::my_clan_info = null
      ::g_clans.parseSeenCandidates()
      ::broadcastEvent("ClanInfoUpdate")
      ::broadcastEvent("ClanChanged") //i.e. dismissed
      ::update_gamercards()
    }
    return
  }

  if(!forceUpdate && ::getTblValue("id", ::my_clan_info, "-1") == myClanId)
    if(::dagor.getCurTime() - ::last_update_my_clan_time < - MY_CLAN_UPDATE_DELAY_MSEC)
      return

  ::last_update_my_clan_time = ::dagor.getCurTime()
  local taskId = ::clan_request_my_info()
  ::get_my_clan_data_free = false
  ::add_bg_task_cb(taskId, function(){
    local wasCreated = !::my_clan_info
    ::my_clan_info = ::get_clan_info_table()
    ::handle_new_my_clan_data()
    ::get_my_clan_data_free = true
    ::broadcastEvent("ClanInfoUpdate")
    ::update_gamercards()
    if (wasCreated)
      ::broadcastEvent("ClanChanged") //i.e created
  })
}

::is_in_clan <- function is_in_clan()
{
  return ::clan_get_my_clan_id() != "-1"
}

::handle_new_my_clan_data <- function handle_new_my_clan_data()
{
  ::g_clans.parseSeenCandidates()
  ::contacts[::EPLX_CLAN] <- []
  if("members" in ::my_clan_info)
  {
    foreach(mem, block in ::my_clan_info.members)
    {
      if(!(block.uid in ::contacts_players))
        ::getContact(block.uid, block.nick)
      ::contacts_players[block.uid].presence = ::getMyClanMemberPresence(block.nick)
      if(::my_user_id_str != block.uid)
        ::contacts[::EPLX_CLAN].append(::contacts_players[block.uid])
      ::clanUserTable[block.nick] <- ::my_clan_info.tag
    }
  }
}

::is_in_my_clan <- function is_in_my_clan(name = null, uid = null)
{
  if(my_clan_info == null)
    return false
  if("members" in my_clan_info)
    foreach(i, block in my_clan_info.members)
    {
      if(name)
        if(name == block.nick)
          return true
      if(uid)
        if(uid == block.uid)
          return true
    }
  return false
}

::clan_candidate_list <- [
  { id = "nick", type = ::g_lb_data_type.NICK }
  { id = "date", type = ::g_lb_data_type.DATE }
];

::empty_rating <- {
  [(::ranked_column_prefix + "_arc")]   = 0,
  [(::ranked_column_prefix + "_hist")]  = 0,
  [(::ranked_column_prefix + "_sim")]   = 0
}

::empty_activity <- {
  cur = 0
  total = 0
}


::clanInfoTemplate <- {
  function isRegionChangeAvailable()
  {
    if (regionLastUpdate == 0) // warning disable: -never-declared
      return true

    return regionLastUpdate + ::g_clans.getRegionUpdateCooldownTime() <= ::get_charserver_time_sec() // warning disable: -never-declared
  }

  function getRegionChangeAvailableTime()
  {
    return regionLastUpdate + ::g_clans.getRegionUpdateCooldownTime() // warning disable: -never-declared
  }

  function getClanUpgradeCost()
  {
    local cost = type.getNextTypeUpgradeCost()
    local resultingCostGold = cost.gold - spentForMemberUpgrades // warning disable: -never-declared
    if (resultingCostGold < 0)
      resultingCostGold = 0
    cost.gold = resultingCostGold
    return cost
  }

  function getAllRegaliaTags()
  {
    local result = []
    foreach (rewards in ["seasonRewards", "seasonRatingRewards"])
    {
      local regalias = ::getTblValue("regaliaTags", this[rewards], [])
      if (!::u.isArray(regalias))
        regalias = [regalias]

      //check for duplicate before add
      //total amount of regalias is less than 10, so this square
      //complexity actually is not a big deal
      foreach (regalia in regalias)
        if (!::isInArray(regalia, result))
          result.append(regalia)
    }

    return result
  }

  function memberCount()
  {
    return members.len()
  }

  function getTypeName()
  {
    return type.getTypeName()
  }

  function getCreationDateText()
  {
    return ::g_clans.getClanCreationDateText(this)
  }

  function getInfoChangeDateText()
  {
    return ::g_clans.getClanInfoChangeDateText(this)
  }

  function getMembersCountText()
  {
    return ::g_clans.getClanMembersCountText(this)
  }

  function canShowActivity()
  {
    return ::has_feature("ClanActivity")
  }

  function getActivity()
  {
    return astat?.activity ?? 0 // warning disable: -never-declared
  }
}

/**
 * Pass internal clanInfo for debug purposes
 */
::get_clan_info_table <- function get_clan_info_table(clanInfo = null)
{
  if (!clanInfo)
    clanInfo = ::clan_get_clan_info()

  if (!clanInfo?._id)
    return null

  local clan = clone ::clanInfoTemplate
  clan.id     <- clanInfo._id
  clan.name   <- ::getTblValue("name",   clanInfo, "")
  clan.tag    <- ::getTblValue("tag",    clanInfo, "")
  clan.lastPaidTag <- ::getTblValue("lastPaidTag", clanInfo, "")
  clan.slogan <- ::getTblValue("slogan", clanInfo, "")
  clan.desc   <- ::getTblValue("desc",   clanInfo, "")
  clan.region <- ::getTblValue("region", clanInfo, "")
  clan.announcement <- getTblValue("announcement", clanInfo, "")
  clan.cdate  <- ::getTblValue("cdate",  clanInfo, 0)
  clan.status <- ::getTblValue("status", clanInfo, "open")
  clan.mlimit <- ::getTblValue("mlimit", clanInfo, 0)

  clan.changedByNick <- ::getTblValue("changed_by_nick", clanInfo, "")
  clan.changedByUid <- ::getTblValue("changed_by_uid", clanInfo, "")
  clan.changedTime <- ::getTblValue("changed_time", clanInfo, 0)

  clan.spentForMemberUpgrades <- ::getTblValue("mspent", clanInfo, 0)
  clan.regionLastUpdate <- ::getTblValue("region_last_updated", clanInfo, 0)
  clan.type   <- ::g_clan_type.getTypeByName(::getTblValue("type", clanInfo, ""))
  clan.autoAcceptMembership <- ::getTblValue("autoaccept",   clanInfo, false)
  clan.membershipRequirements <- ::DataBlock()
  local membReqs = ::clan_get_membership_requirements( clanInfo )
  if ( membReqs )
    clan.membershipRequirements.setFrom( membReqs );

  clan.astat <- {}

  if (clanInfo?.astat)
    foreach(stat, value in clanInfo.astat)
      clan.astat[stat] <- value

  local clanMembersInfo = clanInfo % "members"
  local clanActivityInfo = clanInfo?.activity
  if (!clanActivityInfo)
    clanActivityInfo = ::DataBlock()

  clan.members <- []

  local member_ratings = ::getTblValue("member_ratings", clanInfo, {})
  local getTotalActivityPerPeriod = function(expActivity)
  {
    if (!expActivity)
      return 0

    local res = 0
    foreach(period in expActivity)
      res += period.activity

    return res
  }
  foreach(member in clanMembersInfo)
  {
    local memberItem = {}

    //get common members data
    foreach(key, value in member)
      memberItem[key] <- value

    //get members ELO
    local ratingTable = ::getTblValue(memberItem.uid, member_ratings, {})
    foreach(key, value in ::empty_rating)
      memberItem[key] <- ::round(::getTblValue(key, ratingTable, value))
    memberItem.onlineStatus <- ::g_contact_presence.UNKNOWN

    //get members activity
    local memberActivityInfo = clanActivityInfo.getBlockByName(memberItem.uid) || ::DataBlock()
    foreach(key, value in ::empty_activity)
      memberItem[key + "Activity"] <- memberActivityInfo.getInt(key, value)
    memberItem["activityHistory"] <-
      ::buildTableFromBlk(memberActivityInfo.getBlockByName("history"))
    memberItem["curPeriodActivity"] <- memberActivityInfo?.activity ?? 0
    memberItem["expActivity"] <-
      ::buildTableFromBlk(memberActivityInfo.getBlockByName("expActivity"))
    memberItem["totalPeriodActivity"] <-
      getTotalActivityPerPeriod(memberActivityInfo.getBlockByName("expActivity"))

    clan.members.append(memberItem)
  }

  local clanCandidatesInfo = clanInfo % "candidates";
  clan.candidates <- []

  foreach(candidate in clanCandidatesInfo)
  {
    local candidateTemp = {}
    foreach(info, value in candidate)
      candidateTemp[info] <- value
    clan.candidates.append(candidateTemp)
  }

  local clanBlacklist = clanInfo % "blacklist"
  clan.blacklist <- []

  foreach(person in clanBlacklist)
  {
    local blackTemp = {}
    foreach(info, value in person)
      blackTemp[info] <- value
    clan.blacklist.append(blackTemp)
  }

  local getRewardLog = (@(clan) function(clanInfo, rewardBlockId, titleClass) {
    if (!(rewardBlockId in clanInfo))
      return []

    local log = []
    foreach (idx, season in clanInfo[rewardBlockId])
    {
      foreach (title in season % "titles")
        log.append(titleClass.createFromClanReward(title, idx, season, clan))
    }
    return log
  })(clan)

  local sortRewardsInlog = @(a, b) b.seasonTime <=> a.seasonTime
  local getBestRewardLog = function() {
    local log = []
    foreach (reward in clanInfo % "clanBestRewards")
      log.append({seasonName = reward.seasonName, title = reward.title})
    return log
  }

  clan.rewardLog <- getRewardLog(clanInfo, "clanRewardLog", ::ClanSeasonPlaceTitle)
  clan.rewardLog.sort(sortRewardsInlog)
  clan.clanBestRewards <- getBestRewardLog()

  clan.seasonRewards <- ::buildTableFromBlk(::getTblValue("clanSeasonRewards", clanInfo))
  clan.seasonRatingRewards <- ::buildTableFromBlk(::getTblValue("clanSeasonRatingRewards", clanInfo))

  clan.maxActivityPerPeriod <- clanInfo?.maxActivityPerPeriod ?? 0
  clan.maxClanActivity <- clanInfo?.maxClanActivity ?? 0
  clan.rewardPeriodDays <- clanInfo?.rewardPeriodDays ?? 0
  clan.expRewardEnabled <- clanInfo?.expRewardEnabled ?? false
  clan.historyDepth <- clanInfo?.historyDepth ?? 14
  clan.nextRewardDayId <- clanInfo?.nextRewardDayId

  //dlog("GP: Show clan table");
  //debugTableData(clan);
  return getFilteredClanData(clan)
}

local function getSeasonName(blk)
{
  local name = ""
  if (blk?.type == "worldWar")
    name = ::loc("worldwar/season_name/" + (::split(blk.titles, "@")?[2] ?? ""))
  else
  {
    local year = unixtime_to_utc_timetbl(blk?.seasonStartTimestamp ?? 0).year.tostring()
    local num  = ::get_roman_numeral(::to_integer_safe(blk?.numInYear ?? 0)
      + CLAN_SEASON_NUM_IN_YEAR_SHIFT)
    name = ::loc("clan/battle_season/name", { year = year, num = num })
  }
  return name
}

class ClanSeasonTitle
{
  clanTag = ""
  clanName = ""
  seasonName = ""
  seasonTime = 0
  difficultyName = ""


  constructor (...)
  {
    ::dagor.assertf(false, "Error: attempt to instantiate ClanSeasonTitle intreface class.")
  }

  function getBattleTypeTitle()
  {
    local difficulty = ::g_difficulty.getDifficultyByEgdLowercaseName(difficultyName)
    return ::loc(difficulty.abbreviation)
  }

  function getUpdatedClanInfo(unlockBlk)
  {
    local isMyClan = ::is_in_clan() && (unlockBlk?.clanId ?? "").tostring() == ::clan_get_my_clan_id()
    return {
      clanTag  = isMyClan ? ::clan_get_my_clan_tag()  : unlockBlk?.clanTag
      clanName = isMyClan ? ::clan_get_my_clan_name() : unlockBlk?.clanName
    }
  }

  function name() {}
  function desc() {}
  function iconStyle() {}
  function iconParams() {}
}


class ClanSeasonPlaceTitle extends ClanSeasonTitle
{
  place = ""
  seasonType = ""
  seasonTag = null
  seasonIdx = ""
  seasonTitle = ""

  static function createFromClanReward (titleString, sIdx, season, clanData)
  {
    local titleParts = ::split(titleString, "@")
    local place = ::getTblValue(0, titleParts, "")
    local difficultyName = ::getTblValue(1, titleParts, "")
    local sTag = titleParts?[2]
    return ClanSeasonPlaceTitle(
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


  static function createFromUnlockBlk (unlockBlk)
  {
    local idParts = ::split(unlockBlk.id, "_")
    local info = ::ClanSeasonPlaceTitle.getUpdatedClanInfo(unlockBlk)
    return ClanSeasonPlaceTitle(
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
    _seasonTime,
    _seasonType,
    _seasonTag,
    _difficlutyName,
    _place,
    _seasonName,
    _clanTag,
    _clanName,
    _seasonIdx,
    _seasonTitle
  )
  {
    seasonTime = _seasonTime
    seasonType = _seasonType
    seasonTag = _seasonTag
    difficultyName = _difficlutyName
    place = _place
    seasonName = _seasonName
    clanTag = _clanTag
    clanName = _clanName
    seasonIdx = _seasonIdx
    seasonTitle = _seasonTitle
  }

  function isWinner()
  {
    return ::g_string.startsWith(place, "place")
  }

  function getPlaceTitle()
  {
    if (isWinner())
      return ::loc("clan/season_award/place/" + place)
    else
      return ::loc("clan/season_award/place/top", { top = ::g_string.slice(place, 3) })
  }

  function name()
  {
    local path = seasonType == "worldWar" ? "clan/season_award_ww/title" : "clan/season_award/title"
    return ::loc(
      path,
      {
        achievement = getPlaceTitle()
        battleType = getBattleTypeTitle()
        season = seasonName
      }
    )
  }

  function desc()
  {
    local placeTitleColored = ::colorize("activeTextColor", getPlaceTitle())
    local params = {
      place = placeTitleColored
      top = placeTitleColored
      squadron = ::colorize("activeTextColor", clanTag + ::nbsp + clanName)
      season = ::colorize("activeTextColor", seasonName)
    }
    local winner = isWinner() ? "place" : "top"
    local path = seasonType == "worldWar" ? "clan/season_award_ww/desc/" : "clan/season_award/desc/"

    return ::loc(path + winner, seasonType == "worldWar"
      ? params
      : params.__merge({battleType = ::colorize("activeTextColor", getBattleTypeTitle())}))
  }

  function iconStyle()
  {
    return "clan_medal_" + place + "_" + difficultyName
  }

  function iconConfig()
  {
    if(seasonType != "worldWar" || !seasonTag)
      return null

    local bg_img = "clan_medal_ww_bg"
    local path = isWinner() ? place : "rating"
    local bin_img = "clan_medal_ww_" + seasonTag + "_bin_" + path
    local place_img = "clan_medal_ww_" + place
    return ::g_string.implode([bg_img, bin_img, place_img], ";")
  }

  function iconParams()
  {
    return { season_title = { text = seasonName } }
  }
}

::getFilteredClanData <- function getFilteredClanData(clanData, author = "")
{
  if ("tag" in clanData)
    clanData.tag = ::checkClanTagForDirtyWords(clanData.tag)

  local textFields = [
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
        local uid = clanData?.creator_uid ?? clanData?.changed_by_uid ?? clanData?.changedByUid ?? ""
        if (uid != "")
          author = ::getContact(uid)?.name ?? ""
      }
    }

    isPlayerBlocked = ::isPlayerNickInContacts(author, ::EPL_BLOCKLIST)
    if (isPlayerBlocked)
      textFields.append("tag")
  }

  foreach (key in textFields)
    if (key in clanData)
      clanData[key] = ::ps4CheckAndReplaceContentDisabledText(clanData[key], isPlayerBlocked)

  return clanData
}

::checkClanTagForDirtyWords <- function checkClanTagForDirtyWords(clanTag, returnString = true)
{
  if (isPlatformSony)
  {
    if (returnString)
      return dirtyWordsFilter.checkPhrase(clanTag)
    else
      return dirtyWordsFilter.isPhrasePassing(clanTag)
  }

  return returnString? clanTag : true
}

::ps4CheckAndReplaceContentDisabledText <- function ps4CheckAndReplaceContentDisabledText(processingString, forceReplace = false)
{
  if (!::ps4_is_ugc_enabled() || forceReplace) {
    local pattern = "[^ ]"
    local replacement = "*"

    processingString = ::regexp2(pattern).replace(replacement, processingString)
  }
  return processingString
}

::getMyClanMemberPresence <- function getMyClanMemberPresence(nick)
{
  local clanActiveUsers = []

  foreach (roomData in ::g_chat.rooms)
    if (::g_chat.isRoomClan(roomData.id) && roomData.users.len() > 0)
    {
      foreach (user in roomData.users)
        clanActiveUsers.append(user.name)
      break
    }

  if (::isInArray(nick, clanActiveUsers))
  {
    local contact = ::Contact.getByName(nick)
    if (!(contact?.forceOffline ?? false))
      return ::g_contact_presence.ONLINE
  }
  return ::g_contact_presence.OFFLINE
}

::get_show_in_squadron_statistics <- function get_show_in_squadron_statistics(modeId)
{
  local gameSettingsBlk = ::get_game_settings_blk()
  if (gameSettingsBlk == null) return true
  local filter = gameSettingsBlk?["squadronStatisticsFilter"]
  return ::getTblValue(modeId, filter, true)
}

::clan_request_set_membership_requirements <- function clan_request_set_membership_requirements(clanIdStr, requirements, autoAccept)
{
  local blk = ::DataBlock()
  blk["membership_req"] <- requirements
  blk["_id"] = clanIdStr
  if (autoAccept)
    blk["autoaccept"] = true
  return ::char_send_clan_oneway_blk("cln_clan_set_membership_requirements", blk)
}

::gui_modal_new_clan <- function gui_modal_new_clan()
{
  gui_start_modal_wnd(::gui_handlers.CreateClanModalHandler)
}

::gui_modal_edit_clan <- function gui_modal_edit_clan(clanData, owner)
{
  gui_start_modal_wnd(::gui_handlers.EditClanModalhandler, {clanData = clanData, owner = owner})
}

::gui_modal_upgrade_clan <- function gui_modal_upgrade_clan(clanData, owner)
{
  gui_start_modal_wnd(::gui_handlers.UpgradeClanModalHandler, {clanData = clanData, owner = owner})
}

::gui_modal_clans <- function gui_modal_clans(startPage = "")
{
  gui_start_modal_wnd(::gui_handlers.ClansModalHandler, {startPage = startPage})
}

::subscribe_handler(::g_clans, ::g_listener_priority.DEFAULT_HANDLER)
