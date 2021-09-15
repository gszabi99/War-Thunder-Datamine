local systemMsg = require("scripts/utils/systemMsg.nut")
local playerContextMenu = require("scripts/user/playerContextMenu.nut")
local platformModule = require("scripts/clientState/platform.nut")
local antiCheat = require("scripts/penitentiary/antiCheat.nut")
local { getXboxChatEnableStatus } = require("scripts/chat/chatStates.nut")
local { startLogout } = require("scripts/login/logout.nut")
local { recentBR, getBRDataByMrankDiff } = require("scripts/battleRating.nut")

const MEMBER_STATUS_LOC_TAG_PREFIX = "#msl"

global enum memberStatus {
  READY
  SELECTED_AIRS_BROKEN
  NO_REQUIRED_UNITS
  SELECTED_AIRS_NOT_AVAILABLE
  ALL_AVAILABLE_AIRS_BROKEN
  PARTLY_AVAILABLE_AIRS_BROKEN
  AIRS_NOT_AVAILABLE
  EAC_NOT_INITED
}

local memberStatusLocId = {
  [memberStatus.READY]                          = "status/squad_ready",
  [memberStatus.AIRS_NOT_AVAILABLE]             = "squadMember/airs_not_available",
  [memberStatus.ALL_AVAILABLE_AIRS_BROKEN]      = "squadMember/all_available_airs_broken",
  [memberStatus.PARTLY_AVAILABLE_AIRS_BROKEN]   = "squadMember/partly_available_airs_broken",
  [memberStatus.SELECTED_AIRS_NOT_AVAILABLE]    = "squadMember/selected_airs_not_available",
  [memberStatus.SELECTED_AIRS_BROKEN]           = "squadMember/selected_airs_broken",
  [memberStatus.NO_REQUIRED_UNITS]              = "squadMember/no_required_units",
  [memberStatus.EAC_NOT_INITED]                 = "squadMember/eac_not_inited",
}

local locTags = { [MEMBER_STATUS_LOC_TAG_PREFIX] = "unknown" }
foreach(status, locId in memberStatusLocId)
  locTags[MEMBER_STATUS_LOC_TAG_PREFIX + status] <- locId
systemMsg.registerLocTags(locTags)

::g_squad_utils <- {
  getMemberStatusLocId = @(status) memberStatusLocId?[status] ?? "unknown"
  getMemberStatusLocTag = @(status) MEMBER_STATUS_LOC_TAG_PREFIX + (status in memberStatusLocId ? status : "")

  canSquad = @() getXboxChatEnableStatus() == XBOX_COMMUNICATIONS_ALLOWED

  getMembersFlyoutDataByUnitsGroups = @() ::g_squad_manager.getMembers().map(
    @(member) { crafts_info = member?.craftsInfoByUnitsGroups })

  canShowMembersBRDiffMsg = @() ::g_login.isProfileReceived()
    && !::load_local_account_settings("skipped_msg/membersBRDiff", false)

  checkMembersMrankDiff = function(handler, okFunc) {
    if (!::g_squad_manager.isSquadLeader())
      return okFunc()

    local brData = getBRDataByMrankDiff()
    if (brData.len() == 0)
      return okFunc()

    if (!canShowMembersBRDiffMsg())
      return okFunc()

    local message = ::loc("multiplayer/squad/members_br_diff_warning", {
      squadBR = format("%.1f", recentBR.value)
      players = "\n".join(brData.reduce(@(acc, v, k) acc.append(
        "".concat(::colorize("userlogColoredText", k), ::loc("ui/colon"), format("%.1f", v))), []))
    })

    ::gui_start_modal_wnd(::gui_handlers.SkipableMsgBox, {
      parentHandler = handler
      message = message
      ableToStartAndSkip = true
      startBtnText = ::loc("msgbox/btn_yes")
      onStartPressed = okFunc
      skipFunc = function(value) {
        ::save_local_account_settings("skipped_msg/membersBRDiff", value)
      }
    })
  }
}

g_squad_utils.canJoinFlightMsgBox <- function canJoinFlightMsgBox(options = null,
                                            okFunc = null, cancelFunc = null)
{
  if (!::isInMenu())
  {
    ::g_popups.add("", ::loc("squad/cant_join_in_flight"))
    return false
  }

  if (!::g_squad_manager.isInSquad())
    return true

  local msgId = ::getTblValue("msgId", options, "squad/cant_start_new_flight")
  if (::getTblValue("allowWhenAlone", options, true) && !::g_squad_manager.isNotAloneOnline())
    return true

  if (!::getTblValue("isLeaderCanJoin", options, false) || !::g_squad_manager.isSquadLeader())
  {
    showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
    return false
  }

  local maxSize = ::getTblValue("maxSquadSize", options, 0)
  if (maxSize > 0 && ::g_squad_manager.getOnlineMembersCount() > maxSize)
  {
    ::showInfoMsgBox(::loc("gamemode/squad_is_too_big",
      {
        squadSize = ::colorize("userlogColoredText", ::g_squad_manager.getOnlineMembersCount())
        maxTeamSize = ::colorize("userlogColoredText", maxSize)
      }))
    return false
  }

  if (::g_squad_manager.readyCheck(true))
  {
    if (!::g_squad_utils.checkCrossPlayCondition())
      return false

    if (::getTblValue("showOfflineSquadMembersPopup", options, false))
      checkAndShowHasOfflinePlayersPopup()
    return true
  }

  if (::g_squad_manager.readyCheck(false))
  {
    showRevokeNonAcceptInvitesMsgBox(okFunc, cancelFunc)
    return false
  }

  msgId = "squad/not_all_ready"
  showLeaveSquadMsgBox(msgId, okFunc, cancelFunc)
  return false
}

g_squad_utils.checkCrossPlayCondition <- function checkCrossPlayCondition()
{
  local members = ::g_squad_manager.getDiffCrossPlayConditionMembers()
  if (!members.len())
    return true

  local locId = "squad/sameCrossPlayConditionAsLeader/" + (members[0].crossplay? "disabled" : "enabled")
  local membersNamesArray = members.map(@(member) ::colorize("warningTextColor", platformModule.getPlayerName(member.name)))
  ::showInfoMsgBox(
    ::loc(locId,
      { names = ::g_string.implode(membersNamesArray, ",")}
    ), "members_not_all_crossplay_condition")
  return false
}

g_squad_utils.showRevokeNonAcceptInvitesMsgBox <- function showRevokeNonAcceptInvitesMsgBox(okFunc = null, cancelFunc = null)
{
  showCantJoinSquadMsgBox(
    "revoke_non_accept_invitees",
    ::loc("squad/revoke_non_accept_invites"),
    [["revoke_invites", function() { ::g_squad_manager.revokeAllInvites(okFunc) } ],
     ["cancel", cancelFunc]
    ],
    "cancel",
    { cancel_fn = cancelFunc }
  )
}

g_squad_utils.showLeaveSquadMsgBox <- function showLeaveSquadMsgBox(msgId, okFunc = null, cancelFunc = null)
{
  showCantJoinSquadMsgBox(
    "cant_join",
    ::loc(msgId),
    [
      [ "leaveSquad",
        function() { ::g_squad_manager.leaveSquad(okFunc) }
      ],
      ["cancel", cancelFunc]
    ],
    "cancel",
    { cancel_fn = cancelFunc }
  )
}

::showCantJoinSquadMsgBox <- function showCantJoinSquadMsgBox(id, msg, buttons, defBtn, options)
{
  ::scene_msg_box(id, null, msg, buttons, defBtn, options)
}

g_squad_utils.checkSquadUnreadyAndDo <- function checkSquadUnreadyAndDo(func, cancelFunc = null,
                                               shouldCheckCrewsReady = false)
{
  if (!::g_squad_manager.isSquadMember() ||
      !::g_squad_manager.isMeReady() ||
      (!::g_squad_manager.isMyCrewsReady && shouldCheckCrewsReady))
    return func()

  local messageText = (::g_squad_manager.isMyCrewsReady && shouldCheckCrewsReady)
    ? ::loc("msg/switch_off_crews_ready_flag")
    : ::loc("msg/switch_off_ready_flag")

  local onOkFunc = function() {
    if (::g_squad_manager.isMyCrewsReady && shouldCheckCrewsReady)
      ::g_squad_manager.setCrewsReadyFlag(false)
    else
      ::g_squad_manager.setReadyFlag(false)

    func()
  }
  local onCancelFunc = function() {
    if (cancelFunc)
      cancelFunc()
  }

  ::scene_msg_box("msg_need_unready", null, messageText,
    [
      ["ok", onOkFunc],
      ["no", onCancelFunc]
    ],
    "ok", { cancel_fn = function() {}})
}

g_squad_utils.updateMyCountryData <- function updateMyCountryData(needUpdateSessionLobbyData = true)
{
  local memberData = ::g_user_utils.getMyStateData()
  ::g_squad_manager.updateMyMemberData(memberData)

  //Update Skirmish Lobby info
  if (needUpdateSessionLobbyData)
    ::SessionLobby.setCountryData({
      country = memberData.country
      crewAirs = memberData.crewAirs
      selAirs = memberData.selAirs  //!!FIX ME need to remove this and use slots in client too.
      slots = memberData.selSlots
    })
}

g_squad_utils.getMembersFlyoutData <- function getMembersFlyoutData(teamData, event, canChangeMemberCountry = true)
{
  local res = {
    canFlyout = true,
    haveRestrictions = false
    members = []
    countriesChanged = 0
  }

  if (!::g_squad_manager.isInSquad() || !teamData)
    return res

  local ediff = ::events.getEDiffByEvent(event)
  local respawn = ::events.isEventMultiSlotEnabled(event)
  local shouldUseEac = antiCheat.shouldUseEac(event)
  local squadMembers = ::g_squad_manager.getMembers()
  foreach(uid, memberData in squadMembers)
  {
    if (!memberData.online || ::g_squad_manager.getPlayerStatusInMySquad(uid) == squadMemberState.SQUAD_LEADER)
      continue

    if (memberData.country == "")
      continue

    local mData = {
            uid = memberData.uid
            name = memberData.name
            status = memberStatus.READY
            countries = []
            selAirs = memberData.selAirs
            selSlots = memberData.selSlots
            isSelfCountry = false
            dislikedMissions = memberData?.dislikedMissions ?? []
            bannedMissions = memberData?.bannedMissions ?? []
          }

    local haveAvailCountries = false
    local isAnyRequiredAndAvailableFound = false

    local checkOnlyMemberCountry = !canChangeMemberCountry
                                   || ::isInArray(memberData.country, teamData.countries)
    if (checkOnlyMemberCountry)
      mData.isSelfCountry = true
    else
      res.countriesChanged++

    local brokenUnits = []
    local haveNotBroken = false
    local needCheckRequired = ::events.getRequiredCrafts(teamData).len() > 0
    foreach(country in teamData.countries)
    {
      if (checkOnlyMemberCountry && country != memberData.country)
        continue

      local haveAvailable = false
      local haveRequired  = !needCheckRequired

      if (!respawn)
      {
        if (!(country in memberData.selAirs))
          continue

        local unitName = memberData.selAirs[country]
        haveAvailable = ::events.isUnitAllowedByTeamData(teamData, unitName, ediff)
        local isBroken = ::isInArray(unitName, memberData.brokenAirs)
        if (isBroken)
          brokenUnits.append(unitName)
        haveNotBroken = haveAvailable && !isBroken
        haveRequired  = haveRequired || ::events.isAirRequiredAndAllowedByTeamData(teamData, unitName, ediff)
      }
      else
      {
        if (!(country in memberData.crewAirs))
          continue

        foreach(unitName in memberData.crewAirs[country])
        {
          haveAvailable = haveAvailable || ::events.isUnitAllowedByTeamData(teamData, unitName, ediff)
          local isBroken = ::isInArray(unitName, memberData.brokenAirs)
          if (isBroken)
            brokenUnits.append(unitName)
          haveNotBroken = haveNotBroken || (haveAvailable && !isBroken)
          haveRequired  = haveRequired  || ::events.isAirRequiredAndAllowedByTeamData(teamData, unitName, ediff)
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

g_squad_utils.getMembersAvailableUnitsCheckingData <- function getMembersAvailableUnitsCheckingData(remainUnits, country)
{
  local res = []
  foreach (uid, memberData in ::g_squad_manager.getMembers())
    res.append(getMemberAvailableUnitsCheckingData(memberData, remainUnits, country))

  return res
}

g_squad_utils.getMemberAvailableUnitsCheckingData <- function getMemberAvailableUnitsCheckingData(memberData, remainUnits, country)
{
  local memberCantJoinData = {
                               canFlyout = true
                               joinStatus = memberStatus.READY
                               unbrokenAvailableUnits = []
                               memberData = memberData
                             }

  if (!(country in memberData.crewAirs))
  {
    memberCantJoinData.canFlyout = false
    memberCantJoinData.joinStatus = memberStatus.AIRS_NOT_AVAILABLE
    return memberCantJoinData
  }

  local memberAvailableUnits = memberCantJoinData.unbrokenAvailableUnits
  local brokenUnits = []
  foreach (idx, name in memberData.crewAirs[country])
    if (name in remainUnits)
      if (::isInArray(name, memberData.brokenAirs))
        brokenUnits.append(name)
      else
        memberAvailableUnits.append(name)

  if (remainUnits && memberAvailableUnits.len() == 0)
  {
    memberCantJoinData.canFlyout = false
    memberCantJoinData.joinStatus = brokenUnits.len() ? memberStatus.ALL_AVAILABLE_AIRS_BROKEN
                                                      : memberStatus.AIRS_NOT_AVAILABLE
  }

  return memberCantJoinData
}

g_squad_utils.checkAndShowHasOfflinePlayersPopup <- function checkAndShowHasOfflinePlayersPopup()
{
  if (!::g_squad_manager.isSquadLeader())
    return

  local offlineMembers = ::g_squad_manager.getOfflineMembers()
  if (offlineMembers.len() == 0)
    return

  local text = ::loc("squad/has_offline_members") + ::loc("ui/colon")
  text += ::g_string.implode(::u.map(offlineMembers,
                            @(memberData) ::colorize("warningTextColor", platformModule.getPlayerName(memberData.name))
                           ),
                    ::loc("ui/comma")
                   )

  ::g_popups.add("", text)
}

g_squad_utils.checkSquadsVersion <- function checkSquadsVersion(memberSquadsVersion)
{
  if (memberSquadsVersion <= SQUADS_VERSION)
    return

  local message = ::loc("squad/need_reload")
  ::scene_msg_box("need_update_squad_version", null, message,
                  [["relogin", function() {
                     ::save_short_token()
                     startLogout()
                   } ],
                   ["cancel", function() {}]
                  ],
                  "cancel", { cancel_fn = function() {}}
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
g_squad_utils.checkAvailableUnits <- function checkAvailableUnits(availableUnitsArrays, controlUnits, availableUnitsArrayIndex = 0)
{
  if (availableUnitsArrays.len() >= availableUnitsArrayIndex)
    return true

  local units = availableUnitsArrays[availableUnitsArrayIndex]
  foreach(idx, name in units)
  {
    if (controlUnits[name] <= 0)
      continue

    controlUnits[name]--
    if (checkAvailableUnits(availableUnitsArrays, controlUnits, availableUnitsArrayIndex++))
      return true

    controlUnits[name]++
  }

  return false
}

g_squad_utils.canJoinByMySquad <- function canJoinByMySquad(operationId = null, controlCountry = "")
{
  if (operationId == null)
    operationId = ::g_squad_manager.getWwOperationId()

  local squadMembers = ::g_squad_manager.getMembers()
  foreach(uid, member in squadMembers)
  {
    if (!member.online)
      continue

    local memberCountry = member.getWwOperationCountryById(operationId)
    if (!::u.isEmpty(memberCountry))
      if (controlCountry == "")
        controlCountry = memberCountry
      else if (controlCountry != memberCountry)
        return false
  }

  return true
}

g_squad_utils.isEventAllowedForAllMembers <- function isEventAllowedForAllMembers(eventEconomicName, isSilent = false)
{
  if (!::g_squad_manager.isInSquad())
    return true

  local notAvailableMemberNames= []
  foreach(member in ::g_squad_manager.getMembers())
    if (!member.isEventAllowed(eventEconomicName))
      notAvailableMemberNames.append(member.name)

  local res = !notAvailableMemberNames.len()
  if (res || isSilent)
    return res

  local mText = ::g_string.implode(
    ::u.map(notAvailableMemberNames, @(name) ::colorize("userlogColoredText", platformModule.getPlayerName(name)))
    ", "
  )
  local msg = ::loc("msg/members_no_access_to_mode", {  members = mText  })
  ::showInfoMsgBox(msg, "members_req_new_content")
  return res
}

g_squad_utils.showMemberMenu <- function showMemberMenu(obj)
{
  if (!::checkObj(obj))
    return

  local member = obj.getUserData()
  if (member == null)
      return

  local position = obj.getPosRC()
  playerContextMenu.showMenu(
    null,
    this,
    {
      playerName = member.name
      uid = member.uid
      clanTag = member.clanTag
      squadMemberData = member
      position = position
  })
}

/*use by client .cpp code*/
::is_in_my_squad <- function is_in_my_squad(name, checkAutosquad = true)
{
  return ::g_squad_manager.isInMySquad(name, checkAutosquad)
}

::is_in_squad <- function is_in_squad(forChat = false)
{
  return ::g_squad_manager.isInSquad(forChat)
}
