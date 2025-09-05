from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadMemberState, memberStatus

let { isInFlight } = require("gameplayBinding")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { format } = require("string")
let systemMsg = require("%scripts/utils/systemMsg.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { getXboxChatEnableStatus } = require("%scripts/chat/chatStates.nut")
let { recentBR, getBRDataByMrankDiff } = require("%scripts/battleRating.nut")
let { getMyStateData } = require("%scripts/user/userUtils.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { registerRespondent } = require("scriptRespondent")
let { addPopup } = require("%scripts/popups/popups.nut")
let { CommunicationState } = require("%scripts/gdk/permissions.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
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
}

let locTags = { [MEMBER_STATUS_LOC_TAG_PREFIX] = "unknown" }
foreach (status, locId in memberStatusLocId)
  locTags[$"{MEMBER_STATUS_LOC_TAG_PREFIX}{status}"] <- locId
systemMsg.registerLocTags(locTags)

function checkAndShowHasOfflinePlayersPopup() {
  if (!g_squad_manager.isSquadLeader())
    return

  let offlineMembers = g_squad_manager.getOfflineMembers()
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
        function() { g_squad_manager.leaveSquad(okFunc) }
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
    [["revoke_invites", function() { g_squad_manager.revokeAllInvites(okFunc) } ],
     ["cancel", cancelFunc]
    ],
    "cancel",
    { cancel_fn = cancelFunc }
  )
}

function checkCrossPlayCondition() {
  let { diffMembers, isLeaderCrossplayOn = true } = g_squad_manager.getDiffCrossPlayConditionMembers()
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

let getSquadMembersFlyoutDataByUnitsGroups = @() g_squad_manager.getMembers().map(
  @(member) { crafts_info = member?.craftsInfoByUnitsGroups })

let canShowMembersBRDiffMsg = @() isProfileReceived.get()
  && !loadLocalAccountSettings("skipped_msg/membersBRDiff", false)

function checkSquadMembersMrankDiff(handler, okFunc) {
  if (!g_squad_manager.isSquadLeader())
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

  loadHandler(gui_handlers.SkipableMsgBox, {
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
  if (!g_squad_manager.isSquadMember() ||
      !g_squad_manager.isMeReady() ||
      (!g_squad_manager.getIsMyCrewsReady() && shouldCheckCrewsReady))
    return func()

  let messageText = (g_squad_manager.getIsMyCrewsReady() && shouldCheckCrewsReady)
    ? loc("msg/switch_off_crews_ready_flag")
    : loc("msg/switch_off_ready_flag")

  let onOkFunc = function() {
    if (g_squad_manager.getIsMyCrewsReady() && shouldCheckCrewsReady)
      g_squad_manager.setCrewsReadyFlag(false)
    else
      g_squad_manager.setReadyFlag(false)

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

function canJoinFlightMsgBox(options = null, okFunc = null, cancelFunc = null) {
  if (!isInMenu.get()) {
    addPopup("", loc("squad/cant_join_in_flight"))
    return false
  }

  if (!g_squad_manager.isInSquad())
    return true

  local msgId = getTblValue("msgId", options, "squad/cant_start_new_flight")
  if (getTblValue("allowWhenAlone", options, true) && !g_squad_manager.isNotAloneOnline())
    return true

  if (!getTblValue("isLeaderCanJoin", options, false) || !g_squad_manager.isSquadLeader()) {
    showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
    return false
  }

  let maxSize = getTblValue("maxSquadSize", options, 0)
  if (maxSize > 0 && g_squad_manager.getOnlineMembersCount() > maxSize) {
    showInfoMsgBox(loc("gamemode/squad_is_too_big",
      {
        squadSize = colorize("userlogColoredText", g_squad_manager.getOnlineMembersCount())
        maxTeamSize = colorize("userlogColoredText", maxSize)
      }))
    return false
  }

  if (g_squad_manager.readyCheck(true)) {
    if (!checkCrossPlayCondition())
      return false

    if (getTblValue("showOfflineSquadMembersPopup", options, false))
      checkAndShowHasOfflinePlayersPopup()
    return true
  }

  if (g_squad_manager.readyCheck(false)) {
    showRevokeNonAcceptInvitesMsgBox(okFunc, cancelFunc)
    return false
  }

  msgId = "squad/not_all_ready"
  showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
  return false
}

function updateMyCountryData(needUpdateSessionLobbyData = true) {
  let memberData = getMyStateData()
  g_squad_manager.updateMyMemberDataAfterActualizeJwt(memberData)

  
  if (needUpdateSessionLobbyData)
    setSessionLobbyCountryData({
      country = memberData.country
      crewAirs = memberData.crewAirs
      selAirs = memberData.selAirs  
      slots = memberData.selSlots
    })
}

function getSquadMembersFlyoutData(teamData, event) {
  let res = {
    canFlyout = true,
    haveRestrictions = false
    members = []
  }

  if (!g_squad_manager.isInSquad() || !teamData)
    return res

  let ediff = events.getEDiffByEvent(event)
  let respawn = events.isEventMultiSlotEnabled(event)
  let shouldUseEac = antiCheat.shouldUseEac(event)
  let squadMembers = g_squad_manager.getMembers()
  foreach (uid, memberData in squadMembers) {
    if (!memberData.online || g_squad_manager.getPlayerStatusInMySquad(uid) == squadMemberState.SQUAD_LEADER)
      continue

    if (memberData.country == "")
      continue

    let mData = {
            uid = memberData.uid
            name = memberData.name
            status = memberStatus.READY
            countries = []
            selAirs = memberData.selAirs
            selSlots = memberData.selSlots
            dislikedMissions = memberData?.dislikedMissions ?? []
            bannedMissions = memberData?.bannedMissions ?? []
            fakeName = memberData?.fakeName ?? false
            queueProfileJwt = memberData?.queueProfileJwt ?? ""
          }

    local haveAvailCountries = false
    local isAnyRequiredAndAvailableFound = false

    let brokenUnits = []
    local haveNotBroken = false
    let needCheckRequired = events.getRequiredCrafts(teamData).len() > 0
    local isValidCountry = true
    let { country } = memberData
    if (isInArray(country, teamData.countries)) {
      local haveAvailable = false
      local haveRequired  = !needCheckRequired

      if (!respawn) {
        let unitName = memberData.selAirs?[country] ?? ""
        if (unitName == "")
          continue

        haveAvailable = events.isUnitAllowedByTeamData(teamData, unitName, ediff)
        let isBroken = isInArray(unitName, memberData.brokenAirs)
        if (isBroken)
          brokenUnits.append(unitName)
        haveNotBroken = haveAvailable && !isBroken
        haveRequired  = haveRequired || events.isAirRequiredAndAllowedByTeamData(teamData, unitName, ediff)
      }
      else {
        if ((memberData.crewAirs?[country] ?? []).len() == 0)
          continue

        foreach (unitName in memberData.crewAirs[country]) {
          haveAvailable = haveAvailable || events.isUnitAllowedByTeamData(teamData, unitName, ediff)
          let isBroken = isInArray(unitName, memberData.brokenAirs)
          if (isBroken)
            brokenUnits.append(unitName)
          haveNotBroken = haveNotBroken || (haveAvailable && !isBroken)
          haveRequired  = haveRequired  || events.isAirRequiredAndAllowedByTeamData(teamData, unitName, ediff)
        }
      }

      haveAvailCountries = haveAvailCountries || haveAvailable
      isAnyRequiredAndAvailableFound = isAnyRequiredAndAvailableFound || (haveAvailable && haveRequired)
      if (haveAvailable && haveNotBroken && haveRequired)
        mData.countries.append(country)
    }
    else {
      isValidCountry = false
    }

    if (shouldUseEac && !(memberData?.isEacInited ?? false))
      mData.status = memberStatus.EAC_NOT_INITED
    else if (!haveAvailCountries)
      mData.status = !isValidCountry ? memberStatus.SELECTED_COUNTRY_NOT_AVAILABLE
      : respawn ? memberStatus.AIRS_NOT_AVAILABLE
      : memberStatus.SELECTED_AIRS_NOT_AVAILABLE
    else if (!isAnyRequiredAndAvailableFound)
      mData.status = memberStatus.NO_REQUIRED_UNITS
    else if (!mData.countries.len())
      mData.status = respawn ? memberStatus.ALL_AVAILABLE_AIRS_BROKEN : memberStatus.SELECTED_AIRS_BROKEN
    else if (brokenUnits.len() && haveNotBroken)
      mData.status = memberStatus.PARTLY_AVAILABLE_AIRS_BROKEN

    res.canFlyout = res.canFlyout && (mData.status == memberStatus.READY || mData.status == memberStatus.PARTLY_AVAILABLE_AIRS_BROKEN)
    res.haveRestrictions = res.haveRestrictions || mData.status == memberStatus.PARTLY_AVAILABLE_AIRS_BROKEN
    res.members.append(mData)
  }

  return res
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
  foreach (_uid, memberData in g_squad_manager.getMembers())
    res.append(getSquadMemberAvailableUnitsCheckingData(memberData, remainUnits, country))

  return res
}

function canJoinByMySquad(operationId = null, controlCountry = "") {
  if (operationId == null)
    operationId = g_squad_manager.getWwOperationId()

  let squadMembers = g_squad_manager.getMembers()
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
  if (!g_squad_manager.isInSquad())
    return true

  let notAvailableMemberNames = []
  foreach (member in g_squad_manager.getMembers())
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
  return handlersManager.loadCustomHandler(gui_handlers.SquadWidgetCustomHandler, { scene = nestObj })
}

registerRespondent("is_in_my_squad", function is_in_my_squad(userId, checkAutosquad = true) {
  return g_squad_manager.isInMySquadById(userId, checkAutosquad)
})

registerRespondent("is_in_squad", function is_in_squad(forChat = false) {
  return g_squad_manager.isInSquad(forChat)
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
  getSquadMembersFlyoutData
  getSquadMemberAvailableUnitsCheckingData
  getSquadMembersAvailableUnitsCheckingData
  initSquadWidgetHandler
}