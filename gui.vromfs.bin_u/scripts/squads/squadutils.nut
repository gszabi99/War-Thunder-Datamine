from "%scripts/dagui_natives.nut" import save_short_token
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import *

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
let { startLogout } = require("%scripts/login/logout.nut")
let { recentBR, getBRDataByMrankDiff } = require("%scripts/battleRating.nut")
let { getMyStateData } = require("%scripts/user/userUtils.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isInMenu, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { registerRespondent } = require("scriptRespondent")
let { addPopup } = require("%scripts/popups/popups.nut")
let { CommunicationState } = require("%scripts/xbox/permissions.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")

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
}

let locTags = { [MEMBER_STATUS_LOC_TAG_PREFIX] = "unknown" }
foreach (status, locId in memberStatusLocId)
  locTags[$"{MEMBER_STATUS_LOC_TAG_PREFIX}{status}"] <- locId
systemMsg.registerLocTags(locTags)

::g_squad_utils <- {
  getMemberStatusLocId = @(status) memberStatusLocId?[status] ?? "unknown"
  getMemberStatusLocTag = @(status) $"{MEMBER_STATUS_LOC_TAG_PREFIX}{status in memberStatusLocId ? status : ""}"

  canSquad = @() getXboxChatEnableStatus() == CommunicationState.Allowed

  getMembersFlyoutDataByUnitsGroups = @() g_squad_manager.getMembers().map(
    @(member) { crafts_info = member?.craftsInfoByUnitsGroups })

  canShowMembersBRDiffMsg = @() isProfileReceived.get()
    && !loadLocalAccountSettings("skipped_msg/membersBRDiff", false)

  checkMembersMrankDiff = function(handler, okFunc) {
    if (!g_squad_manager.isSquadLeader())
      return okFunc()

    let brData = getBRDataByMrankDiff()
    if (brData.len() == 0)
      return okFunc()

    if (!this.canShowMembersBRDiffMsg())
      return okFunc()

    let message = loc("multiplayer/squad/members_br_diff_warning", {
      squadBR = format("%.1f", recentBR.value)
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
}

::g_squad_utils.canJoinFlightMsgBox <- function canJoinFlightMsgBox(options = null,
                                            okFunc = null, cancelFunc = null) {
  if (!isInMenu()) {
    addPopup("", loc("squad/cant_join_in_flight"))
    return false
  }

  if (!g_squad_manager.isInSquad())
    return true

  local msgId = getTblValue("msgId", options, "squad/cant_start_new_flight")
  if (getTblValue("allowWhenAlone", options, true) && !g_squad_manager.isNotAloneOnline())
    return true

  if (!getTblValue("isLeaderCanJoin", options, false) || !g_squad_manager.isSquadLeader()) {
    this.showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
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
    if (!::g_squad_utils.checkCrossPlayCondition())
      return false

    if (getTblValue("showOfflineSquadMembersPopup", options, false))
      this.checkAndShowHasOfflinePlayersPopup()
    return true
  }

  if (g_squad_manager.readyCheck(false)) {
    this.showRevokeNonAcceptInvitesMsgBox(okFunc, cancelFunc)
    return false
  }

  msgId = "squad/not_all_ready"
  this.showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
  return false
}

::g_squad_utils.checkCrossPlayCondition <- function checkCrossPlayCondition() {
  let members = g_squad_manager.getDiffCrossPlayConditionMembers()
  if (!members.len())
    return true

  let locId = $"squad/sameCrossPlayConditionAsLeader/{members[0].crossplay ? "disabled" : "enabled"}"
  let membersNamesArray = members.map(@(member) colorize("warningTextColor", getPlayerName(member.name)))
  showInfoMsgBox(
    loc(locId,
      { names = ",".join(membersNamesArray, true) }
    ), "members_not_all_crossplay_condition")
  return false
}

::g_squad_utils.showRevokeNonAcceptInvitesMsgBox <- function showRevokeNonAcceptInvitesMsgBox(okFunc = null, cancelFunc = null) {
  ::showCantJoinSquadMsgBox(
    "revoke_non_accept_invitees",
    loc("squad/revoke_non_accept_invites"),
    [["revoke_invites", function() { g_squad_manager.revokeAllInvites(okFunc) } ],
     ["cancel", cancelFunc]
    ],
    "cancel",
    { cancel_fn = cancelFunc }
  )
}

::g_squad_utils.showLeaveSquadMsgBox <- function showLeaveSquadMsgBox(msgId, okFunc = null, cancelFunc = null) {
  ::showCantJoinSquadMsgBox(
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

::showCantJoinSquadMsgBox <- function showCantJoinSquadMsgBox(id, msg, buttons, defBtn, options) {
  scene_msg_box(id, null, msg, buttons, defBtn, options)
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

::g_squad_utils.updateMyCountryData <- function updateMyCountryData(needUpdateSessionLobbyData = true) {
  let memberData = getMyStateData()
  g_squad_manager.updateMyMemberDataAfterActualizeJwt(memberData)

  //Update Skirmish Lobby info
  if (needUpdateSessionLobbyData)
    ::SessionLobby.setCountryData({
      country = memberData.country
      crewAirs = memberData.crewAirs
      selAirs = memberData.selAirs  //!!FIX ME need to remove this and use slots in client too.
      slots = memberData.selSlots
    })
}

::g_squad_utils.getMembersFlyoutData <- function getMembersFlyoutData(teamData, event, canChangeMemberCountry = true) {
  let res = {
    canFlyout = true,
    haveRestrictions = false
    members = []
    countriesChanged = 0
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
            isSelfCountry = false
            dislikedMissions = memberData?.dislikedMissions ?? []
            bannedMissions = memberData?.bannedMissions ?? []
            fakeName = memberData?.fakeName ?? false
            queueProfileJwt = memberData?.queueProfileJwt ?? ""
          }

    local haveAvailCountries = false
    local isAnyRequiredAndAvailableFound = false

    let checkOnlyMemberCountry = !canChangeMemberCountry
                                   || isInArray(memberData.country, teamData.countries)
    if (checkOnlyMemberCountry)
      mData.isSelfCountry = true
    else {
      mData.queueProfileJwt = "" //!!! FIX ME: When change member country, leader do not know jwt profile data.
      res.countriesChanged++     // Need either do not change countries or get jwt  for all countries.
    }

    let brokenUnits = []
    local haveNotBroken = false
    let needCheckRequired = events.getRequiredCrafts(teamData).len() > 0
    foreach (country in teamData.countries) {
      if (checkOnlyMemberCountry && country != memberData.country)
        continue

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

    if (shouldUseEac && !(memberData?.isEacInited ?? false))
      mData.status = memberStatus.EAC_NOT_INITED
    else if (!haveAvailCountries)
      mData.status = respawn ? memberStatus.AIRS_NOT_AVAILABLE : memberStatus.SELECTED_AIRS_NOT_AVAILABLE
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

::g_squad_utils.getMembersAvailableUnitsCheckingData <- function getMembersAvailableUnitsCheckingData(remainUnits, country) {
  let res = []
  foreach (_uid, memberData in g_squad_manager.getMembers())
    res.append(this.getMemberAvailableUnitsCheckingData(memberData, remainUnits, country))

  return res
}

::g_squad_utils.getMemberAvailableUnitsCheckingData <- function getMemberAvailableUnitsCheckingData(memberData, remainUnits, country) {
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

::g_squad_utils.checkAndShowHasOfflinePlayersPopup <- function checkAndShowHasOfflinePlayersPopup() {
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

::g_squad_utils.checkSquadsVersion <- function checkSquadsVersion(memberSquadsVersion) {
  if (memberSquadsVersion <= SQUADS_VERSION)
    return

  local message = loc("squad/need_reload")
  scene_msg_box("need_update_squad_version", null, message,
                  [["relogin", function() {
                     save_short_token()
                     startLogout()
                   } ],
                   ["cancel", function() {}]
                  ],
                  "cancel", { cancel_fn = function() {} }
                 )
}

/**
    availableUnitsArrays = [
                             [unitName...]
                           ]

    controlUnits = {
                     unitName = count
                     ...
                   }

    availableUnitsArrayIndex - recursion param
**/
::g_squad_utils.checkAvailableUnits <- function checkAvailableUnits(availableUnitsArrays, controlUnits, availableUnitsArrayIndex = 0) {
  if (availableUnitsArrays.len() >= availableUnitsArrayIndex)
    return true

  let units = availableUnitsArrays[availableUnitsArrayIndex]
  foreach (_idx, name in units) {
    if (controlUnits[name] <= 0)
      continue

    controlUnits[name]--
    if (this.checkAvailableUnits(availableUnitsArrays, controlUnits, availableUnitsArrayIndex++))
      return true

    controlUnits[name]++
  }

  return false
}

::g_squad_utils.canJoinByMySquad <- function canJoinByMySquad(operationId = null, controlCountry = "") {
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

::g_squad_utils.isEventAllowedForAllMembers <- function isEventAllowedForAllMembers(eventEconomicName, isSilent = false) {
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

registerRespondent("is_in_my_squad", function is_in_my_squad(userId, checkAutosquad = true) {
  return g_squad_manager.isInMySquadById(userId, checkAutosquad)
})

registerRespondent("is_in_squad", function is_in_squad(forChat = false) {
  return g_squad_manager.isInSquad(forChat)
})

addListenersWithoutEnv({
  CrewsOrderChanged = @(_p) ::g_squad_utils.updateMyCountryData(false)
})

return {
  checkSquadUnreadyAndDo
}