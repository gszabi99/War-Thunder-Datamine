import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "gameplayBinding" import isInFlight
from "string" import format
from "scriptRespondent" import registerRespondent
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import memberStatus

let { getDiffCrossPlayConditionMembers, getIsMyCrewsReady, getMembers, getOfflineMembers, getOnlineMembersCount, getWwOperationId, isInSquad, isMeReady, isMySquadMemberById, isNotAloneOnline, isSquadLeader, isSquadMember, readyCheck } = require("%scripts/squads/squadState.nut")
let { isMemberInMySquadById } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let systemMsg = require("%scripts/utils/systemMsg.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { getXboxChatEnableStatus } = require("%scripts/chat/chatStates.nut")
let { recentBR, getBRDataByMrankDiff } = require("%scripts/battleRating.nut")
let { getMyStateData } = require("%scripts/user/userUtils.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { CommunicationState } = require("%scripts/gdk/permissions.nut")
let { SQUAD_LEAVE_REQUESTED, SQUAD_REVOKE_ALL_INVITES_REQUESTED, SQUAD_SET_READY_REQUESTED, SQUAD_SET_CREWS_READY_REQUESTED, SQUAD_MY_MEMBER_DATA_UPDATE_REQUESTED } = require("%scripts/crossModuleEvents.nut")
let { setSessionLobbyCountryData } = require("%scripts/matchingRooms/sessionLobbyManager.nut")

const MEMBER_STATUS_LOC_TAG_PREFIX = "#msl"

let memberStatusLocId = {
  [memberStatus.READY]                          = "status/squad_ready",
  [memberStatus.AIRS_NOT_AVAILABLE]             = "squadMember/airs_not_available",
  [memberStatus.ALL_AVAILABLE_AIRS_BROKEN]      = "squadMember/all_available_airs_broken",
  [memberStatus.PARTLY_AVAILABLE_AIRS_BROKEN]   = "squadMember/partly_available_airs_broken",
  [memberStatus.SELECTED_AIRS_NOT_AVAILABLE]    = "squadMember/selected_airs_not_available",
  [memberStatus.SELECTED_AIRS_BROKEN]           = "squadMember/selected_airs_broken",
  [memberStatus.NO_REQUIRED_UNITS]              = "squadMember/no_required_units",
  [memberStatus.EAC_NOT_INITED]                 = "squadMember/eac_not_inited",
  [memberStatus.SELECTED_COUNTRY_NOT_AVAILABLE] = "squadMember/selected_country_not_available",
  [memberStatus.NOT_ENOUGH_SUITABLE_UNITS]      = "events/minCraftsToPlay",
}

let locTags = { [MEMBER_STATUS_LOC_TAG_PREFIX] = "unknown" }
foreach (status, locId in memberStatusLocId)
  locTags[$"{MEMBER_STATUS_LOC_TAG_PREFIX}{status}"] <- locId
systemMsg.registerLocTags(locTags)

function checkAndShowHasOfflinePlayersPopup() {
  if (!isSquadLeader())
    return

  let offlineMembers = getOfflineMembers()
  if (offlineMembers.len() == 0)
    return

  let text = loc("ui/colon").concat(loc("squad/has_offline_members"),
    loc("ui/comma").join(offlineMembers
      .map(@(memberData) colorize("warningTextColor", getPlayerName(memberData.name))),
    true))

  addPopup("", text)
}

function showCantJoinSquadMsgBox(id, msg, buttons, defBtn, options) {
  scene_msg_box(id, null, msg, buttons, defBtn, options)
}

function showLeaveSquadMsgBox(msgId, okFunc = null, cancelFunc = null) {
  showCantJoinSquadMsgBox(
    "cant_join",
    loc(msgId),
    [
      [ "leaveSquad",
        function() { broadcastEvent(SQUAD_LEAVE_REQUESTED, { onLeave = okFunc }) }
      ],
      ["cancel", cancelFunc]
    ],
    "cancel",
    { cancel_fn = cancelFunc }
  )
}

function showRevokeNonAcceptInvitesMsgBox(okFunc = null, cancelFunc = null) {
  showCantJoinSquadMsgBox(
    "revoke_non_accept_invitees",
    loc("squad/revoke_non_accept_invites"),
    [["revoke_invites", function() { broadcastEvent(SQUAD_REVOKE_ALL_INVITES_REQUESTED, { onDone = okFunc }) } ],
     ["cancel", cancelFunc]
    ],
    "cancel",
    { cancel_fn = cancelFunc }
  )
}

function checkCrossPlayCondition() {
  let { diffMembers, isLeaderCrossplayOn = true } = getDiffCrossPlayConditionMembers()
  if (!diffMembers.len())
    return true

  let locId = isLeaderCrossplayOn ? "squad/sameCrossPlayConditionAsLeader/enabled" : "squad/otherPlatformsExist"
  let membersNamesArray = diffMembers.map(@(member) colorize("warningTextColor", getPlayerName(member.name)))
  showInfoMsgBox(
    loc(locId,
      { names = ",".join(membersNamesArray, true) }
    ), "members_not_all_crossplay_condition")
  return false
}

let getMemberStatusLocId = @(status) memberStatusLocId?[status] ?? "unknown"
let getMemberStatusLocTag = @(status) $"{MEMBER_STATUS_LOC_TAG_PREFIX}{status in memberStatusLocId ? status : ""}"
let canSquad = @() getXboxChatEnableStatus() == CommunicationState.Allowed

let getSquadMembersFlyoutDataByUnitsGroups = @() getMembers().map(
  @(member) { crafts_info = member?.craftsInfoByUnitsGroups })

let canShowMembersBRDiffMsg = @() isProfileReceived.get()
  && !loadLocalAccountSettings("skipped_msg/membersBRDiff", false)

function checkSquadMembersMrankDiff(handler, okFunc) {
  if (!isSquadLeader())
    return okFunc()

  let brData = getBRDataByMrankDiff()
  if (brData.len() == 0)
    return okFunc()

  if (!canShowMembersBRDiffMsg())
    return okFunc()

  let message = loc("multiplayer/squad/members_br_diff_warning", {
    squadBR = format("%.1f", recentBR.get())
    players = "\n".join(brData.reduce(@(acc, v, k) acc.append(
      "".concat(colorize("userlogColoredText", getPlayerName(k)), loc("ui/colon"), format("%.1f", v))), []))
  })

  loadHandler(get_gui_handler("SkipableMsgBox"), {
    parentHandler = handler
    message = message
    startBtnText = loc("msgbox/btn_yes")
    onStartPressed = okFunc
    skipFunc = function(value) {
      saveLocalAccountSettings("skipped_msg/membersBRDiff", value)
    }
  })
}

function checkSquadUnreadyAndDo(func, cancelFunc = null, shouldCheckCrewsReady = false) {
  if (!isSquadMember() ||
      !isMeReady() ||
      (!getIsMyCrewsReady() && shouldCheckCrewsReady))
    return func()

  let messageText = (getIsMyCrewsReady() && shouldCheckCrewsReady)
    ? loc("msg/switch_off_crews_ready_flag")
    : loc("msg/switch_off_ready_flag")

  let onOkFunc = function() {
    if (getIsMyCrewsReady() && shouldCheckCrewsReady)
      broadcastEvent(SQUAD_SET_CREWS_READY_REQUESTED, { ready = false })
    else
      broadcastEvent(SQUAD_SET_READY_REQUESTED, { ready = false })

    func()
  }
  let onCancelFunc = function() {
    if (cancelFunc)
      cancelFunc()
  }

  scene_msg_box("msg_need_unready", null, messageText,
    [
      ["ok", onOkFunc],
      ["no", onCancelFunc]
    ],
    "ok", { cancel_fn = function() {} })
}

function checkCanChangeGameModeAndDo(func) {
  if (!isSquadMember())
    return func()

  scene_msg_box("msg_cant_replace_leader_gamemode", null, loc("mainmenu/leader_gamemode_notice"),
  [
    ["ok", null]
  ],
  "ok", { cancel_fn = function() {} })
}

function canJoinFlightMsgBox(options = null, okFunc = null, cancelFunc = null) {
  if (!isInMenu.get()) {
    addPopup("", loc("squad/cant_join_in_flight"))
    return false
  }

  if (!isInSquad())
    return true

  local msgId = (options?.msgId ?? "squad/cant_start_new_flight")
  if ((options?.allowWhenAlone ?? true) && !isNotAloneOnline())
    return true

  if (!(options?.isLeaderCanJoin ?? false) || !isSquadLeader()) {
    showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
    return false
  }

  let maxSize = (options?.maxSquadSize ?? 0)
  if (maxSize > 0 && getOnlineMembersCount() > maxSize) {
    showInfoMsgBox(loc("gamemode/squad_is_too_big",
      {
        squadSize = colorize("userlogColoredText", getOnlineMembersCount())
        maxTeamSize = colorize("userlogColoredText", maxSize)
      }))
    return false
  }

  if (readyCheck(true)) {
    if (!checkCrossPlayCondition())
      return false

    if ((options?.showOfflineSquadMembersPopup ?? false))
      checkAndShowHasOfflinePlayersPopup()
    return true
  }

  if (readyCheck(false)) {
    showRevokeNonAcceptInvitesMsgBox(okFunc, cancelFunc)
    return false
  }

  msgId = "squad/not_all_ready"
  showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
  return false
}

function updateMyCountryData(needUpdateSessionLobbyData = true) {
  let memberData = getMyStateData()
  broadcastEvent(SQUAD_MY_MEMBER_DATA_UPDATE_REQUESTED, { memberData })

  
  if (needUpdateSessionLobbyData)
    setSessionLobbyCountryData({
      country = memberData.country
      crewAirs = memberData.crewAirs
      selAirs = memberData.selAirs  
      slots = memberData.selSlots
    })
}

function getSquadMemberAvailableUnitsCheckingData(memberData, remainUnits, country) {
  let memberCantJoinData = {
                               canFlyout = true
                               joinStatus = memberStatus.READY
                               unbrokenAvailableUnits = []
                               memberData = memberData
                             }

  if ((memberData.crewAirs?[country] ?? []).len() == 0) {
    memberCantJoinData.canFlyout = false
    memberCantJoinData.joinStatus = memberStatus.AIRS_NOT_AVAILABLE
    return memberCantJoinData
  }

  let memberAvailableUnits = memberCantJoinData.unbrokenAvailableUnits
  let brokenUnits = []
  foreach (_idx, name in memberData.crewAirs[country])
    if (name in remainUnits)
      if (isInArray(name, memberData.brokenAirs))
        brokenUnits.append(name)
      else
        memberAvailableUnits.append(name)

  if (remainUnits && memberAvailableUnits.len() == 0) {
    memberCantJoinData.canFlyout = false
    memberCantJoinData.joinStatus = brokenUnits.len() ? memberStatus.ALL_AVAILABLE_AIRS_BROKEN
                                                      : memberStatus.AIRS_NOT_AVAILABLE
  }

  return memberCantJoinData
}

function getSquadMembersAvailableUnitsCheckingData(remainUnits, country) {
  let res = []
  foreach (_uid, memberData in getMembers())
    res.append(getSquadMemberAvailableUnitsCheckingData(memberData, remainUnits, country))

  return res
}

function canJoinByMySquad(operationId = null, controlCountry = "") {
  if (operationId == null)
    operationId = getWwOperationId()

  let squadMembers = getMembers()
  foreach (_uid, member in squadMembers) {
    if (!member.online)
      continue

    let memberCountry = member.getWwOperationCountryById(operationId)
    if (!u.isEmpty(memberCountry))
      if (controlCountry == "")
        controlCountry = memberCountry
      else if (controlCountry != memberCountry)
        return false
  }

  return true
}

function isEventAllowedForAllSquadMembers(eventEconomicName, isSilent = false) {
  if (!isInSquad())
    return true

  let notAvailableMemberNames = []
  foreach (member in getMembers())
    if (!member.isEventAllowed(eventEconomicName))
      notAvailableMemberNames.append(member.name)

  let res = !notAvailableMemberNames.len()
  if (res || isSilent)
    return res

  let mText = ", ".join(
    notAvailableMemberNames.map(@(name) colorize("userlogColoredText", getPlayerName(name)))
    true
  )
  let msg = loc("msg/members_no_access_to_mode", {  members = mText  })
  showInfoMsgBox(msg, "members_req_new_content")
  return res
}

function initSquadWidgetHandler(nestObj) {
  if (!hasFeature("Squad") || !hasFeature("SquadWidget") || !checkObj(nestObj))
    return null
  return handlersManager.loadCustomHandler(get_gui_handler("SquadWidgetCustomHandler"), { scene = nestObj })
}

registerRespondent("is_in_my_squad", function is_in_my_squad(userId, checkAutosquad = true) {
  return (isInSquad() && isMySquadMemberById(userId)) ? true
    : checkAutosquad && isMemberInMySquadById(userId)
})

registerRespondent("is_in_squad", function is_in_squad(forChat = false) {
  return isInSquad(forChat)
})

addListenersWithoutEnv({
  CrewsOrderChanged = @(_p) updateMyCountryData(false)
  CountryChanged = @(_) updateMyCountryData()
  function CrewChanged(p) {
    let { isInitSelectedCrews = false } = p
    if (!isInitSelectedCrews)
      updateMyCountryData(!isInFlight())
  }
})

return {
  checkSquadUnreadyAndDo
  isEventAllowedForAllSquadMembers
  canJoinByMySquad
  canJoinFlightMsgBox
  getMemberStatusLocId
  getMemberStatusLocTag
  canSquad
  getSquadMembersFlyoutDataByUnitsGroups
  checkSquadMembersMrankDiff
  updateMyCountryData
  getSquadMemberAvailableUnitsCheckingData
  getSquadMembersAvailableUnitsCheckingData
  initSquadWidgetHandler
  checkCanChangeGameModeAndDo
}