import "%sqStdLibs/helpers/u.nut" as u
import "%scripts/squads/squadApplications.nut" as squadApplications
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler, broadcastEvent, addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "%globalScripts/clientState/initialState.nut" import disableNetwork
from "string" import format
from "dagor.time" import get_time_msec
from "%sqstd/platform.nut" import is_gdk
from "blkGetters" import get_game_settings_blk
from "gameplayBinding" import isInFlight
from "worldwar" import wwGetOperationId
from "%scripts/dagui_natives.nut" import gchat_is_connected, is_eac_inited, save_short_token
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadState, SQUADS_VERSION, squadMemberState, squadStatusUpdateState, SQUAD_REQEST_TIMEOUT
from "%scripts/utils_sa.nut" import gen_rnd_password

let { joinSquadRoom, leaveSquadRoom, isSquadRoomJoined } = require("%scripts/chat/squadChatRoom.nut")


require("%scripts/gameModes/leaderGameModeReadyCheck.nut")
let {
  processSmDataDelayedInvites,
  processSmDataMembersNames,
  processSmDataSquadSizesList,
  processSquadDataPresence,
  processSquadDataProperties,
  processSquadDataMembers,
  processSquadDataWwOperationInfo,
  processSquadDataChatInfo,
  processSquadDataPlatformInfo,
  processSquadDataApplications,
  processSquadDataInvitedPlayers,
  getSquadData, updSquadData, getSmData, updSmData, DEFAULT_SQUAD_PROPERTIES, DEFAULT_SQUAD_CHAT_INFO,
  DEFAULT_SQUAD_WW_OPERATION_INFO, isInSquad, isMeReady, isSquadLeader, isSquadMember, isNotAloneOnline, getState,
  getIsMyCrewsReady, getLeaderUid, getMembers, getInvitedPlayers, getApplicationsToSquad, getSquadRoomName,
  getSquadRoomPassword, getWwOperationId, getWwOperationCountry, getWwOperationBattle, getLeaderGameModeId, getLeaderBattleRating, getMaxSquadSize,
  getMemberData, getMembersByOnline, getOfflineMembers, getOnlineMembers, getOnlineMembersCount, getSquadSize, getSquadMembersDataForContact,
  checkMembersPkg, readyCheck, isMySquadMember, isMySquadMemberById, getPlayerStatusInMySquad, getSameCyberCafeMembersNum,
  getDiffCrossPlayConditionMembers
} = require("%scripts/squads/squadState.nut")
let { checkMatchingError, request_matching } = require("%scripts/matching/api.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { SQUAD_LEAVE_REQUESTED, SQUAD_REVOKE_ALL_INVITES_REQUESTED, SQUAD_SET_READY_REQUESTED, SQUAD_SET_CREWS_READY_REQUESTED, SQUAD_MY_MEMBER_DATA_UPDATE_REQUESTED, SQUAD_JOIN_REQUESTED } = require("%scripts/crossModuleEvents.nut")
let { hasAnyFeature } = require("%scripts/user/features.nut")
let platformModule = require("%scripts/clientState/platform.nut")
let battleRating = require("%scripts/battleRating.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { showMsgboxIfSoundModsNotAllowed } = require("%scripts/penitentiary/soundMods.nut")
let { invite } = require("%scripts/social/psnSessionManager/getPsnSessionManagerApi.nut")
let { getMyStateData } = require("%scripts/user/userUtils.nut")
let { getRealName } = require("%scripts/user/nameMapping.nut")
let { requestUsersInfo } = require("%scripts/user/usersInfoManager.nut")
let { sendSystemInvite } = require("%scripts/social/xboxSquadManager/xboxSquadManager.nut")
let SquadMember = require("%scripts/squads/squadMember.nut")
let { needActualizeQueueData, actualizeQueueData } = require("%scripts/queue/queueBattleData.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { isInSessionRoom, getSessionLobbyRoomId, canInviteIntoSession } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { getEvent } = require("%scripts/events/eventsState.nut")
let { getCurrentGameModeId, setCurrentGameModeById, getUserGameModeId } = require("%scripts/gameModes/gameModeManagerState.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { checkShowMultiplayerAasWarningMsg } = require("%scripts/user/antiAddictSystem.nut")
let { isWorldWarEnabled, canPlayWorldwar } = require("%scripts/globalWorldWarScripts.nut")
let { updateContact, update_contacts_by_list } = require("%scripts/contacts/contactsActions.nut")
let { invitePlayerToSessionRoom } = require("%scripts/matchingRooms/sessionLobbyMembersInfo.nut")
let { isMemberInMySquadByName, isMemberInMySquadById } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { getContact } = require("%scripts/contacts/contacts.nut")
let { leaveAllQueues } = require("%scripts/queue/queueManager.nut")
let { presenceTypes, getByPresenceParams, getCurrentPresenceType } = require("%scripts/user/presenceType.nut")
let { addInviteToSquad } = require("%scripts/invites/invites.nut")
let { isAnyQueuesActive, hasActiveQueueWithType } = require("%scripts/queue/queueState.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { canJoinFlightMsgBox, updateMyCountryData } = require("%scripts/squads/squadUtils.nut")
let { sendMemberDataToMatching } = require("%scripts/squads/sendMemberData.nut")
let { wwGlobalStatusActions } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { wwStatusType } = require("%scripts/worldWar/operations/model/wwGlobalStatusType.nut")

enum squadEvent {
  DATA_RECEIVED = "SquadDataReceived"
  DATA_UPDATED = "SquadDataUpdated"
  SET_READY = "SquadSetReady"
  STATUS_CHANGED = "SquadStatusChanged"
  PLAYER_INVITED = "SquadPlayerInvited"
  INVITES_CHANGED = "SquadInvitesChanged"
  APPLICATIONS_CHANGED = "SquadApplicationsChanged"
  SIZE_CHANGED = "SquadSizeChanged"
  NEW_APPLICATIONS = "SquadHasNewApplications"
  PROPERTIES_CHANGED = "SquadPropertiesChanged"
  LEADERSHIP_TRANSFER = "SquadLeadershipTransfer"
}

enum msquadErrorId {
  ALREADY_IN_SQUAD = "ALREADY_IN_SQUAD"
  NOT_SQUAD_LEADER = "NOT_SQUAD_LEADER"
  NOT_SQUAD_MEMBER = "NOT_SQUAD_MEMBER"
  SQUAD_FULL = "SQUAD_FULL"
  SQUAD_NOT_INVITED = "SQUAD_NOT_INVITED"
}

const DEFAULT_SQUADS_VERSION = 1

const skipSetSquadDataParams = ["members", "invitedPlayers", "applications"] 

let SQUAD_SIZE_FEATURES_CHECK = {
  squad = ["Squad"]
  platoon = ["Clans", "WorldWar"]
  battleGroup = ["WorldWar"]
}

let DEFAULT_SQUAD_PRESENCE = presenceTypes.IDLE.getParams()


if (getSquadData().presence.len() == 0)
  processSquadDataPresence(@(presence) presence.__update(DEFAULT_SQUAD_PRESENCE))

let convertIdToInt = @(id) u.isString(id) ? id.tointeger() : id

let requestSquadInfo = @(successCallback, errorCallback = null, requestOptions = null)
  request_matching("msquad.get_info", successCallback, errorCallback, null, requestOptions)

let leaveSquadImpl = @(successCallback = null) request_matching("msquad.leave_squad", successCallback)

function checkSquadsVersion(memberSquadsVersion) {
  if (memberSquadsVersion <= SQUADS_VERSION)
    return

  scene_msg_box("need_update_squad_version", null, loc("squad/need_reload"),
    [["relogin", function() {
      save_short_token()
      startLogout()
    } ],
    ["cancel", function() {}]],
    "cancel", { cancel_fn = function() {} }
  )
}

local g_squad_manager

function setSquadData() {
  if (!g_squad_manager.isSquadLeader())
    return

  let data = clone getSquadData()
  foreach (key in skipSetSquadDataParams)
    data.$rawdelete(key)

  request_matching("msquad.set_squad_data", null, null, data)
}

g_squad_manager = {

  getSquadData
  setSquadData

  getSMMaxSquadSize = @() getSmData().MAX_SQUAD_SIZE
  getSquadSizesList = @() getSmData().squadSizesList
  getIsMyCrewsReady
  getHasNewApplication = @() getSmData().hasNewApplication
  getState

  canStartStateChanging = @() !g_squad_manager.isStateInTransition()
  canJoinSquad = @() !g_squad_manager.isInSquad() && g_squad_manager.canStartStateChanging()
  canLeaveSquad = @() g_squad_manager.isInSquad() && g_squad_manager.canManageSquad()
  canManageSquad = @() hasFeature("Squad") && isInMenu.get()
  canChangeReceiveApplications = @(shouldCheckLeader = true) hasFeature("ClanSquads")
    && (!shouldCheckLeader || g_squad_manager.isSquadLeader())

  canInviteMember = @(uid = null) !g_squad_manager.isMe(uid)
    && g_squad_manager.canManageSquad()
    && (g_squad_manager.canJoinSquad() || g_squad_manager.isSquadLeader())
    && !g_squad_manager.isInvitedMaxPlayers()
    && (!uid || !g_squad_manager.getMemberData(uid))

  canDismissMember = @(uid = null) g_squad_manager.isSquadLeader()
    && g_squad_manager.canManageSquad()
    && !g_squad_manager.isMe(uid)
    && g_squad_manager.getPlayerStatusInMySquad(uid) >= squadMemberState.SQUAD_MEMBER

  canSwitchReadyness = @() g_squad_manager.isSquadMember() && g_squad_manager.canManageSquad()
    && !isAnyQueuesActive()

  canChangeSquadSize = @(shouldCheckLeader = true) hasFeature("SquadSizeChange")
    && (!shouldCheckLeader || g_squad_manager.isSquadLeader())
    && getSmData().squadSizesList.len() > 1

  isImInvitePlayer = @(inviteId) u.isEmpty(getSquadData().id) && getSquadData()?.invitedPlayers[inviteId] != null
    && getSquadData()?.invitedPlayers[userIdStr.get()] == null
  getLeaderUid
  getSquadLeaderData = @() g_squad_manager.getMemberData(g_squad_manager.getLeaderUid())
  getMembers
  getPsnSessionId = @() getSquadData()?.psnSessionId ?? ""
  getInvitedPlayers
  getPlatformInfo = @() getSquadData().platformInfo
  getApplicationsToSquad
  getLeaderNick = @() !g_squad_manager.isInSquad() ? "" : g_squad_manager.getSquadLeaderData()?.name ?? ""
  getSquadRoomName
  getSquadRoomPassword
  getWwOperationId
  getWwOperationCountry
  getWwOperationBattle
  getLeaderGameModeId
  getLeaderBattleRating
  getMaxSquadSize
  getOfflineMembers
  getOnlineMembers
  getMemberData
  getSquadMemberNameByUid = @(uid) (g_squad_manager.isInSquad() && uid in getSquadData().members) ?
    getSquadData().members[uid].name : ""
  getSquadRoomId = @() g_squad_manager.getSquadLeaderData()?.sessionRoomId ?? ""
  getPresence = @() getByPresenceParams(getSquadData()?.presence ?? {})

  function getMembersNotAllowedInWorldWar() {
    let res = []
    foreach (_uid, member in g_squad_manager.getMembers())
      if (!member.isWorldWarAvailable)
        res.append(member)

    return res
  }

  getSameCyberCafeMembersNum

  function getSquadRank() {
    if (!g_squad_manager.isInSquad())
      return -1

    local squadRank = 0
    foreach (_uid, memberData in getSquadData().members)
      squadRank = max(memberData.rank, squadRank)

    return squadRank
  }

  getDiffCrossPlayConditionMembers

  getMembersByOnline

  getOnlineMembersCount

  getSquadSize

  getPlayerStatusInMySquad

  function setMaxSquadSize(newSize) {
    processSquadDataProperties(@(properties) properties.maxMembers = newSize)
  }

  function setSquadSize(newSize) {
    if (newSize == g_squad_manager.getMaxSquadSize())
      return

    g_squad_manager.setMaxSquadSize(newSize)
    setSquadData()
    broadcastEvent(squadEvent.SIZE_CHANGED)
  }

  function setReadyFlag(ready = null, needUpdateMemberData = true) {
    let isLeader = g_squad_manager.isSquadLeader()
    if (isLeader && ready != true)
      return

    let meReady = g_squad_manager.isMeReady()
    if (ready != null && meReady == ready)
      return
    let isSetNoReady = (ready == false || (ready == null && meReady))
    let inSquad = g_squad_manager.isInSquad()
    if (!isSetNoReady && !inSquad)
      return

    if (isAnyQueuesActive() && !isLeader && inSquad && isSetNoReady) {
      addPopup(null, loc("squad/cant_switch_off_readyness_in_queue"))
      return
    }

    function cb() {
      updSmData("meReady", ready == null ? !meReady : ready)
      if (!getSmData().meReady)
        updSmData("isMyCrewsReady", false)

      if (needUpdateMemberData)
        g_squad_manager.updateMyMemberDataAfterActualizeJwt()

      broadcastEvent(squadEvent.SET_READY)
    }

    let event = getEvent(g_squad_manager.getLeaderGameModeId())
    if (!isLeader && !isSetNoReady) {
      if (!antiCheat.showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event))
        return

      checkShowMultiplayerAasWarningMsg(cb)
      return
    }

    cb()
  }

  function setCrewsReadyFlag(ready = null, needUpdateMemberData = true) {
    let isLeader = g_squad_manager.isSquadLeader()
    if (isLeader && ready != true)
      return

    if (ready == null)
      updSmData("isMyCrewsReady",!getSmData().isMyCrewsReady)
    else if (getSmData().isMyCrewsReady != ready)
      updSmData("isMyCrewsReady", ready)
    else
      return

    if (needUpdateMemberData)
      g_squad_manager.updateMyMemberData()
  }

  function setPsnSessionId(id = null) {
    updSquadData("psnSessionId", id)
    setSquadData()
  }

  function setState(newState) {
    if (getSmData().state == newState)
      return false
    updSmData("state", newState)
    updSmData("lastStateChangeTime", get_time_msec())
    broadcastEvent(squadEvent.STATUS_CHANGED)
    return true
  }

  function setMemberOnlineStatus(uid, isOnline) {
    let memberData = g_squad_manager.getMemberData(uid)
    if (memberData == null)
      return

    if (memberData.online == isOnline)
      return

    memberData.online = isOnline
    if (!isOnline) {
      memberData.isReady = false
      if (g_squad_manager.isSquadLeader() && isAnyQueuesActive())
        leaveAllQueues()
    }

    updateContact(memberData.getData())
    broadcastEvent(squadEvent.DATA_UPDATED)
    broadcastEvent("SquadOnlineChanged")
  }

  hasApplicationInMySquad = @(uid, name = null) uid ? (uid.tostring() in g_squad_manager.getApplicationsToSquad())
    : u.search(g_squad_manager.getApplicationsToSquad(), @(player) player.name == name) != null

  isSquadFull = @() g_squad_manager.getSquadSize() >= g_squad_manager.getMaxSquadSize()
  isInSquad
  isMeReady
  isSquadLeader
  isPlayerInvited = @(uid, name = null) uid ? (uid in g_squad_manager.getInvitedPlayers())
    : u.search(g_squad_manager.getInvitedPlayers(), @(player) player.name == name) != null
  isMySquadLeader = @(uid) g_squad_manager.isInSquad() && uid != null && uid == g_squad_manager.getLeaderUid()
  isSquadMember
  isMemberReady = @(uid) g_squad_manager.getMemberData(uid)?.isReady ?? false
  isInMySquad = @(name, checkAutosquad = true)
    (g_squad_manager.isInSquad() && g_squad_manager.isMySquadMember(name)) ? true
      : checkAutosquad && isMemberInMySquadByName(name)

  isInMySquadById = @(userId, checkAutosquad = true)
    (g_squad_manager.isInSquad() && g_squad_manager.isMySquadMemberById(userId)) ? true
      : checkAutosquad && isMemberInMySquadById(userId)

  isMe = @(uid) uid == userIdStr.get()
  isStateInTransition = @() (getSmData().state == squadState.JOINING || getSmData().state == squadState.LEAVING)
    && getSmData().lastStateChangeTime + SQUAD_REQEST_TIMEOUT > get_time_msec()
  isInvitedMaxPlayers = @() g_squad_manager.isSquadFull()
    || g_squad_manager.getInvitedPlayers().len() >= getSmData().maxInvitesCount
  isApplicationsEnabled = @() getSquadData().properties.isApplicationsEnabled

  function isMemberDataVehicleChanged(currentData, receivedData) {
    let currentCountry = currentData?.country ?? ""
    let receivedCountry = receivedData?.country ?? ""
    if (currentCountry != receivedCountry)
      return true

    if (currentData?.selSlots?[currentCountry] != receivedData?.selSlots?[receivedCountry])
      return true

    if (!u.isEqual(battleRating.getCrafts(currentData), battleRating.getCrafts(receivedData)))
      return true

    return false
  }

  isNotAloneOnline

  function updateLeaderGameModeId(newLeaderGameModeId) {
    if (getSquadData().leaderGameModeId == newLeaderGameModeId)
      return

    updSquadData("leaderGameModeId", newLeaderGameModeId)
    if (g_squad_manager.isSquadMember()) {
      let event = getEvent(g_squad_manager.getLeaderGameModeId())
      if (g_squad_manager.isMeReady() && (!antiCheat.showMsgboxIfEacInactive(event) ||
                          !showMsgboxIfSoundModsNotAllowed(event)))
        g_squad_manager.setReadyFlag(false)
      g_squad_manager.updateMyMemberData()
    }
  }

  function updateMyMemberDataAfterActualizeJwt(myMemberData = null) {
    if (!g_squad_manager.isInSquad())
      return

    
    
    if (!needActualizeQueueData.get() || g_squad_manager.isSquadLeader() || !g_squad_manager.isMeReady()) {
      g_squad_manager.updateMyMemberData(myMemberData)
      return
    }

    actualizeQueueData(@(_) g_squad_manager.updateMyMemberData())
  }

  function updateMyPresence() {
    if (!g_squad_manager.isInSquad())
      return

    let data = {
      presenceStatus = getCurrentPresenceType().getParams()
    }

    local memberData = g_squad_manager.getMemberData(userIdStr.get())
    if (!memberData) {
      memberData = SquadMember(userIdStr.get())
      processSquadDataMembers(@(members) members[userIdStr.get()] <- memberData)
    }

    let { isChanged, updatedData } = memberData.update(data)
    memberData.online = true
    if (!isChanged)
      return

    sendMemberDataToMatching(updatedData, false)
    updateContact(memberData.getData())
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function updateMyMemberData(data = null) {
    if (!g_squad_manager.isInSquad())
      return

    let isWorldwarEnabled = isWorldWarEnabled()
    data = data ?? getMyStateData()
    data.__update({
      isReady = g_squad_manager.isMeReady()
      isCrewsReady = getSmData().isMyCrewsReady
      canPlayWorldWar = isWorldwarEnabled
      isWorldWarAvailable = isWorldwarEnabled
      isEacInited = is_eac_inited()
      squadsVersion = SQUADS_VERSION
      platform = platformModule.targetPlatform
      isGdkClient = is_gdk
    })
    let wwOperations = []
    if (isWorldwarEnabled) {
      data.canPlayWorldWar = canPlayWorldwar()
      foreach (wwOperation in wwStatusType.ACTIVE_OPERATIONS.getList()) {
        if (!wwOperation.isValid())
          continue

        let country = wwOperation.getMyAssignCountry() || wwOperation.getMyClanCountry()
        if (country != null)
          wwOperations.append({
            id = wwOperation.id
            country = country
          })
      }
    }
    data.wwOperations <- wwOperations
    data.presenceStatus <- getCurrentPresenceType().getParams()
    data.wwStartingBattle <- null
    data.sessionRoomId <- canInviteIntoSession() ? getSessionLobbyRoomId() : ""

    local memberData = g_squad_manager.getMemberData(userIdStr.get())
    if (!memberData) {
      memberData = SquadMember(userIdStr.get())
      processSquadDataMembers(@(members) members[userIdStr.get()] <- memberData)
    }

    let { isChanged, updatedData } = memberData.update(data)
    memberData.online = true
    if (!isChanged)
      return

    sendMemberDataToMatching(updatedData, memberData.needSendFullData)
    memberData.needSendFullData = false
    updateContact(memberData.getData())
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function updateLeaderData(isActualBR = true) {
    if (!g_squad_manager.isSquadLeader())
      return

    let currentGameModeId = getCurrentGameModeId()
    if (!isActualBR && getSquadData().leaderGameModeId == currentGameModeId)
      return

    updSquadData("leaderBattleRating", isActualBR ? battleRating.recentBR.get() : 0)
    updSquadData("leaderGameModeId", isActualBR ? battleRating.recentBrGameModeId.get() : currentGameModeId)
  }

  function updateCurrentWWOperation() {
    if (!g_squad_manager.isSquadLeader() || !isWorldWarEnabled())
      return

    let wwOperationId = wwGetOperationId()
    local country = profileCountrySq.get()
    if (wwOperationId > -1)
      country = wwGlobalStatusActions.getOperationById(wwOperationId)?.getMyAssignCountry()
        ?? country

    processSquadDataWwOperationInfo(function(wwOperationInfo) {
      wwOperationInfo.id = wwOperationId
      wwOperationInfo.country = country
    })
  }

  function updateInvitedData(invites) {
    let newInvitedData = {}
    foreach (uidInt64 in invites) {
      if (!is_numeric(uidInt64))
        continue

      let uid = uidInt64.tostring()
      if (uid in getSquadData().invitedPlayers)
        newInvitedData[uid] <- getSquadData().invitedPlayers[uid]
      else
        newInvitedData[uid] <- SquadMember(uid, true)

      requestUsersInfo([uid])
    }

    updSquadData("invitedPlayers", newInvitedData)
  }

  function updateApplications(applications) {
    let newApplicationsData = {}
    foreach (uidInt64 in applications) {
      let uid = uidInt64.tostring()
      if (uid in getSquadData().applications)
        newApplicationsData[uid] <- getSquadData().applications[uid]
      else {
        newApplicationsData[uid] <- SquadMember(uid, false, true)
        updSmData("hasNewApplication", true)
      }
      requestUsersInfo([uid])
    }
    if (newApplicationsData.len() == 0)
      updSmData("hasNewApplication", false)
    updSquadData("applications", newApplicationsData)
  }

  function updatePlatformInfo() {
    let playerPlatforms = []
    let checksArray = [g_squad_manager.getMembers(), g_squad_manager.getInvitedPlayers(), g_squad_manager.getApplicationsToSquad()]
    foreach (_idx, membersArray in checksArray)
      foreach (_uid, member in membersArray) {
        if (platformModule.isXBoxPlayerName(member.name))
          u.appendOnce("xboxOne", playerPlatforms)
        else if (platformModule.isPS4PlayerName(member.name))
          u.appendOnce("ps4", playerPlatforms)
        else
          u.appendOnce("pc", playerPlatforms)
      }

    updSquadData("platformInfo", playerPlatforms)
  }

  function updatePresenceSquad() {
    g_squad_manager.updateMyPresence()
    if (!g_squad_manager.isSquadLeader())
      return

    let presenceParams = getCurrentPresenceType().getParams()
    if (!u.isEqual(getSquadData().presence, presenceParams))
      updSquadData("presence", presenceParams)
  }

  function canInviteMemberByPlatform(name) {
    let platformInfo = g_squad_manager.getPlatformInfo()
    if (!hasFeature("Ps4XboxOneInteraction")
        && ((platformModule.isPS4PlayerName(name) && isInArray("xboxOne", platformInfo))
          || (platformModule.isXBoxPlayerName(name) && isInArray("ps4", platformInfo))))
      return false

    return true
  }

  function initSquadSizes() {
    processSmDataSquadSizesList( @(v) v.clear())
    let sizesBlk = get_game_settings_blk()?.squad?.sizes
    if (!u.isDataBlock(sizesBlk))
      return

    local maxSize = 0
    for (local i = 0; i < sizesBlk.paramCount(); i++) {
      let name = sizesBlk.getParamName(i)
      let needAddSize = hasAnyFeature(SQUAD_SIZE_FEATURES_CHECK?[name] ?? [])
      if (!needAddSize)
        continue

      let size = sizesBlk.getParamValue(i)
      processSmDataSquadSizesList(@(squadSizesList) squadSizesList.append({
        name = name
        value = size
      }))
      maxSize = max(maxSize, size)
    }

    if (!getSmData().squadSizesList.len())
      return

    updSmData("COMMON_SQUAD_SIZE", getSmData().squadSizesList[0].value)
    updSmData("MAX_SQUAD_SIZE", maxSize)
    g_squad_manager.setMaxSquadSize(getSmData().COMMON_SQUAD_SIZE)
  }

  function enableApplications(shouldEnable) {
    if (shouldEnable == g_squad_manager.isApplicationsEnabled())
      return

    processSquadDataProperties(@(properties) properties.isApplicationsEnabled = shouldEnable)
    setSquadData()
  }

  readyCheck

  function crewsReadyCheck() {
    if (!g_squad_manager.isInSquad())
      return false

    foreach (_uid, memberData in getSquadData().members)
      if (memberData.online && !memberData.isCrewsReady)
        return false

    return  true
  }

  function createSquad(callback) {
    if (!hasFeature("Squad") || disableNetwork)
      return

    if (!g_squad_manager.canJoinSquad() || !g_squad_manager.canManageSquad() || isAnyQueuesActive())
      return

    g_squad_manager.setState(squadState.JOINING)
    request_matching("msquad.create_squad", @(_) g_squad_manager.requestSquadData(callback))
  }

  function joinSquadChatRoom() {
    if (!g_squad_manager.isNotAloneOnline())
      return

    if (!gchat_is_connected())
      return

    if (isSquadRoomJoined(g_squad_manager.getSquadRoomName()))
      return

    if (getSmData().roomCreateInProgress)
      return

    let name = g_squad_manager.getSquadRoomName()
    local password = g_squad_manager.getSquadRoomPassword()
    local callback = null

    if (u.isEmpty(name))
      return

    if (g_squad_manager.isSquadLeader() && u.isEmpty(password)) {
      password = gen_rnd_password(15)
      processSquadDataChatInfo(@(chatInfo) chatInfo.password = password)

      updSmData("roomCreateInProgress", true)
      callback = function() {
        setSquadData()
        updSmData("roomCreateInProgress", false)
      }
    }

    if (u.isEmpty(password))
      return

    joinSquadRoom(name, password, callback)
  }

  function disbandSquad() {
    if (!g_squad_manager.isSquadLeader())
      return

    g_squad_manager.setState(squadState.LEAVING)
    request_matching("msquad.disband_squad")
  }

  function checkForSquad() {
    if (!isLoggedIn.get() || disableNetwork)
      return

    let callback = function(response) {
      if (response?.error_id != msquadErrorId.NOT_SQUAD_MEMBER)
        if (!checkMatchingError(response, false))
          return

      if ("squad" in response) {
        broadcastEvent(squadEvent.DATA_RECEIVED, response?.squad)

        if (g_squad_manager.getSquadSize(true) == 1)
          g_squad_manager.disbandSquad()
        else
          g_squad_manager.updateMyMemberData()

        broadcastEvent(squadEvent.STATUS_CHANGED)
      }

      let invites = response?.invites
      if (invites != null)
        foreach (squadId in invites)
          addInviteToSquad(squadId, squadId.tostring())

      squadApplications.updateApplicationsList(response?.applications ?? [])
    }

    requestSquadInfo(callback, callback, { showError = false })
  }

  function requestSquadData(callback = null) {
    let fullCallback =  function(response) {
      if ("squad" in response) {
        broadcastEvent(squadEvent.DATA_RECEIVED, response?.squad)

        if (g_squad_manager.getSquadSize(true) == 1)
          g_squad_manager.disbandSquad()
      }
      else if (g_squad_manager.isInSquad())
        g_squad_manager.reset()

      if (callback != null)
        callback()
    }

    requestSquadInfo(fullCallback)
  }

  function leaveSquad(cb = null) {
    if (!g_squad_manager.isInSquad())
      return

    g_squad_manager.setState(squadState.LEAVING)
    leaveSquadImpl(
      function(_response) {
        g_squad_manager.reset()
        if (cb)
          cb()
      })
  }

  function joinToSquad(uid) {
    if (!g_squad_manager.canJoinSquad() || disableNetwork)
      return

    g_squad_manager.setState(squadState.JOINING)
    request_matching("msquad.join_player",
      @(_response) g_squad_manager.requestSquadData(),
      function(_response) {
        g_squad_manager.setState(squadState.NOT_IN_SQUAD)
        g_squad_manager.rejectSquadInvite(uid)
      },
      { userId = convertIdToInt(uid) })
  }

  function inviteToSquad(uid, name = null) {
    if (disableNetwork)
      return
    if (g_squad_manager.isInSquad() && !g_squad_manager.isSquadLeader())
      return

    if (g_squad_manager.isSquadFull())
      return addPopup(null, loc("matching/SQUAD_FULL"))

    if (g_squad_manager.isInvitedMaxPlayers())
      return addPopup(null, loc("squad/maximum_intitations_sent"))

    if (!g_squad_manager.canInviteMemberByPlatform(name))
      return addPopup(null, loc("msg/squad/noPlayersForDiffConsoles"))

    local isInvitingPsnPlayer = false
    if (platformModule.isPS4PlayerName(name)) {
      let contact = getContact(uid, name)
      isInvitingPsnPlayer = true
      if (u.isEmpty(g_squad_manager.getPsnSessionId()))
        contact.updatePSNIdAndDo(function() {
          processSmDataDelayedInvites(@(delayedInvites) delayedInvites.append(contact.psnId))
        })
    }

    let callback = function(_response) {
      if (isInvitingPsnPlayer && u.isEmpty(getSmData().delayedInvites)) {
        let contact = getContact(uid, name)
        contact.updatePSNIdAndDo(function() {
          invite(g_squad_manager.getPsnSessionId(), contact.psnId)
        })
      }

      sendSystemInvite(uid, name)
      g_squad_manager.requestSquadData()
    }

    request_matching("msquad.invite_player", callback, null, { userId = convertIdToInt(uid) })
  }

  function processDelayedInvitations() {
    if (u.isEmpty(g_squad_manager.getPsnSessionId()) || u.isEmpty(getSmData().delayedInvites))
      return

    foreach (invitee in getSmData().delayedInvites)
      invite(g_squad_manager.getPsnSessionId(), invitee)
    processSmDataDelayedInvites(@(delayedInvites) delayedInvites.clear())
  }

  function revokeAllInvites(callback) {
    if (!g_squad_manager.isSquadLeader())
      return

    local fullCallback = null
    if (callback != null) {
      let counterTbl = { invitesLeft = g_squad_manager.getInvitedPlayers().len() }
      fullCallback = function() {
        if (!--counterTbl.invitesLeft)
          callback()
      }
    }

    foreach (uid, _memberData in g_squad_manager.getInvitedPlayers())
      g_squad_manager.revokeSquadInvite(uid, fullCallback)
  }

  function revokeSquadInvite(uid, callback = null) {
    if (!g_squad_manager.isSquadLeader() || disableNetwork)
      return

    let fullCallback = @(_response) g_squad_manager.requestSquadData(@() callback?())
    request_matching("msquad.revoke_invite", fullCallback, null, { userId = convertIdToInt(uid) })
  }

  function membershipAplication(sid) {
    let callback = Callback(@(_response) squadApplications.addApplication(sid, sid), this)
    let cb = function() {
      request_matching("msquad.request_membership",
        callback,
        null, { squadId = sid }, null)
    }
    let canJoin = canJoinFlightMsgBox(
      { allowWhenAlone = false, msgId = "squad/leave_squad_for_application" },
      cb)

    if (canJoin)
      cb()
  }

  function revokeMembershipAplication(sid) {
    squadApplications.deleteApplication(sid)
    request_matching("msquad.revoke_membership_request", null, null, { squadId = sid }, null)
  }

  function acceptMembershipAplication(uid) {
    if (g_squad_manager.isInSquad() && !g_squad_manager.isSquadLeader())
      return

    if (g_squad_manager.isSquadFull())
      return addPopup(null, loc("matching/SQUAD_FULL"))

    let callback = Callback(@(_response) g_squad_manager.addMember(uid.tostring()), this)
    request_matching("msquad.accept_membership", callback, null, { userId = uid }, null)
  }

  function denyAllAplication() {
    if (!g_squad_manager.isSquadLeader() || getSmData().denyAllApplicationsInProgress)
      return

    updSmData("denyAllApplicationsInProgress", true)
    let onDone = @(_response) updSmData("denyAllApplicationsInProgress", false)
    request_matching("msquad.deny_all_membership_requests", onDone, onDone, null, null)
  }

  function denyMembershipAplication(uid, callback = null) {
    if (g_squad_manager.isInSquad() && !g_squad_manager.isSquadLeader())
      return

    request_matching("msquad.deny_membership", callback, null, { userId = uid }, null)
  }

  function dismissFromSquad(uid) {
    if (!g_squad_manager.isSquadLeader())
      return

    if (getSquadData().members?[uid])
      request_matching("msquad.dismiss_member", null, null, { userId = convertIdToInt(uid) })
  }

  function dismissFromSquadByName(name) {
    if (!g_squad_manager.isSquadLeader())
      return

    let memberData = g_squad_manager._getSquadMemberByName(name)
    if (memberData == null)
      return

    if (g_squad_manager.canDismissMember(memberData.uid))
      g_squad_manager.dismissFromSquad(memberData.uid)
  }

  function _getSquadMemberByName(name) {
    if (!g_squad_manager.isInSquad())
      return null

    foreach (_uid, memberData in getSquadData().members)
      if (memberData.name == name || memberData.name == getRealName(name))
        return memberData

    return null
  }

  isMySquadMember
  isMySquadMemberById


  function canTransferLeadership(uid) {
    if (!hasFeature("SquadTransferLeadership"))
      return false

    if (!g_squad_manager.canManageSquad())
      return false

    if (u.isEmpty(uid))
      return false

    if (uid == userIdStr.get())
      return false

    if (!g_squad_manager.isSquadLeader())
      return false

    let memberData = g_squad_manager.getMemberData(uid)
    if (memberData == null || memberData.isInvite)
      return false

    return memberData.online
  }

  function transferLeadership(uid) {
    if (!g_squad_manager.canTransferLeadership(uid))
      return

    request_matching("msquad.transfer_squad", null, null, { userId = convertIdToInt(uid) })
    broadcastEvent(squadEvent.LEADERSHIP_TRANSFER, { uid = uid })
  }

  function onLeadershipTransfered() {
    let isLeader = g_squad_manager.isSquadLeader()
    g_squad_manager.setReadyFlag(isLeader)
    g_squad_manager.setCrewsReadyFlag(isLeader)
    if (isLeader) {
      setCurrentGameModeById(getUserGameModeId() ?? getCurrentGameModeId())
      g_squad_manager.updateLeaderData()
    }
    broadcastEvent(squadEvent.STATUS_CHANGED, {isLeaderChanged = true})
  }

  function acceptSquadInvite(sid) {
    if (!g_squad_manager.canJoinSquad() || disableNetwork)
      return

    g_squad_manager.setState(squadState.JOINING)
    request_matching("msquad.accept_invite",
      function(_response) {
        g_squad_manager.requestSquadData()
      }.bindenv(this),
      function(_response) {
        g_squad_manager.setState(squadState.NOT_IN_SQUAD)
        g_squad_manager.rejectSquadInvite(sid)
      }.bindenv(this),
      { squadId = convertIdToInt(sid) }
    )
  }

  function rejectSquadInvite(sid) {
    request_matching("msquad.reject_invite", null, null, { squadId = convertIdToInt(sid) })
  }

  function requestMemberData(uid) {
    let memberData = getSquadData().members?[uid]
    if (memberData?.isFullDataReceived)
      return

    if (memberData) {
      memberData.isWaiting = true
      broadcastEvent(squadEvent.DATA_UPDATED)
    }

    let callback = @(response) g_squad_manager.requestMemberDataCallback(uid, response)
    request_matching("msquad.get_member_data", callback, null, { userId = convertIdToInt(uid) })
  }

  function requestMemberDataCallback(uid, response) {
    let receivedData = response?.data
    if (receivedData == null)
      return

    let receivedMemberData = receivedData?.data
    this.requestMemberDataCallbackImpl(uid, receivedMemberData, response.online)
  }

  function requestMemberDataCallbackImpl(uid, receivedMemberData, online = true) {
    let memberData = g_squad_manager.getMemberData(uid.tostring())
    if (memberData == null)
      return

    memberData.isFullDataReceived = true
    let currentMemberData = memberData.getData()
    let { isChanged } = memberData.update(receivedMemberData)
    let isMemberVehicleDataChanged = isChanged
      && g_squad_manager.isMemberDataVehicleChanged(currentMemberData, memberData)
    let contact = getContact(memberData.uid, memberData.name)
    contact.online = online
    memberData.online = online
    if (!online)
      memberData.isReady = false

    update_contacts_by_list([memberData.getData()])

    if (g_squad_manager.isSquadLeader()) {
      if (!g_squad_manager.readyCheck())
        leaveAllQueues()

      if (canInviteIntoSession() && memberData.canJoinSessionRoom())
        invitePlayerToSessionRoom(memberData.uid)
    }

    g_squad_manager.joinSquadChatRoom()

    broadcastEvent(squadEvent.DATA_UPDATED)
    if (isMemberVehicleDataChanged)
      broadcastEvent("SquadMemberVehiclesChanged")

    let memberSquadsVersion = receivedMemberData?.squadsVersion ?? DEFAULT_SQUADS_VERSION
    checkSquadsVersion(memberSquadsVersion)
  }

  function reset() {
    if (getSmData().state == squadState.IN_SQUAD)
      g_squad_manager.setState(squadState.LEAVING)

    leaveAllQueues()
    leaveSquadRoom()

    updSmData("cyberCafeSquadMembersNum", -1)
    updSmData("denyAllApplicationsInProgress", false)

    updSquadData("id", "")
    let contactsUpdatedList = []
    foreach (_id, memberData in getSquadData().members)
      contactsUpdatedList.append(memberData.getData())

    processSquadDataMembers(@(members) members.clear())
    processSquadDataInvitedPlayers(@(invitedPlayers) invitedPlayers.clear())
    processSquadDataApplications(@(applications) applications.clear())
    processSquadDataPlatformInfo(@(platformInfo) platformInfo.clear())
    processSquadDataChatInfo( @(chatInfo) chatInfo.__update(DEFAULT_SQUAD_CHAT_INFO))
    processSquadDataWwOperationInfo(@(wwOperationInfo) wwOperationInfo.__update(DEFAULT_SQUAD_WW_OPERATION_INFO))
    processSquadDataProperties(@(properties) properties.__update(DEFAULT_SQUAD_PROPERTIES))
    processSquadDataPresence(@(presence) presence.__update(DEFAULT_SQUAD_PRESENCE))
    updSquadData("psnSessionId", "")
    updSquadData("leaderBattleRating", 0)
    updSquadData("leaderGameModeId", "")
    g_squad_manager.setMaxSquadSize(getSmData().COMMON_SQUAD_SIZE)

    updSmData("lastUpdateStatus", squadStatusUpdateState.NONE)
    if (getSmData().meReady)
      g_squad_manager.setReadyFlag(false, false)

    update_contacts_by_list(contactsUpdatedList)

    g_squad_manager.setState(squadState.NOT_IN_SQUAD)
    broadcastEvent(squadEvent.DATA_UPDATED)
    broadcastEvent(squadEvent.INVITES_CHANGED)
  }

  function addInvitedPlayers(uid) {
    if (uid in getSquadData().invitedPlayers)
      return

    processSquadDataInvitedPlayers(@(invitedPlayers) invitedPlayers[uid] <- SquadMember(uid, true))

    requestUsersInfo([uid])

    broadcastEvent(squadEvent.PLAYER_INVITED, { uid = uid })
    broadcastEvent(squadEvent.INVITES_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function removeInvitedPlayers(uid) {
    if (!(uid in getSquadData().invitedPlayers))
      return

    processSquadDataInvitedPlayers(@(invitedPlayers) invitedPlayers.$rawdelete(uid))
    broadcastEvent(squadEvent.INVITES_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function addApplication(uid) {
    uid = uid.tostring()
    if (uid in getSquadData().applications)
      return

    processSquadDataApplications(@(applications) applications[uid] <- SquadMember(uid, false, true))
    requestUsersInfo([uid])
    g_squad_manager.checkNewApplications()
    if (g_squad_manager.isSquadLeader())
      addPopup(null, colorize("chatTextInviteColor",
        format(loc("squad/player_application"),
          getPlayerName(getSquadData().applications[uid]?.name ?? ""))))

    broadcastEvent(squadEvent.APPLICATIONS_CHANGED, { uid = uid })
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function removeApplication(applications) {
    if (!u.isArray(applications))
      applications = [applications]
    local isApplicationsChanged = false
    foreach (uidInt in applications) {
      let uid = uidInt.tostring()
      if (!(uid in getSquadData().applications))
        continue
      processSquadDataApplications(@(apps) apps.$rawdelete(uid))
      isApplicationsChanged = true
    }

    if (!isApplicationsChanged)
      return

    if (g_squad_manager.getSquadSize(true) == 1)
      g_squad_manager.disbandSquad()
    g_squad_manager.checkNewApplications()
    broadcastEvent(squadEvent.APPLICATIONS_CHANGED, {})
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function markAllApplicationsSeen() {
    foreach (application in getSquadData().applications)
      application.isNewApplication = false
    g_squad_manager.checkNewApplications()
  }

  function checkNewApplications() {
    let curHasNewApplication = getSmData().hasNewApplication
    updSmData("hasNewApplication", false)
    foreach (application in getSquadData().applications)
      if (application.isNewApplication == true) {
        updSmData("hasNewApplication", true)
        break
      }
    if (curHasNewApplication != getSmData().hasNewApplication)
      broadcastEvent(squadEvent.NEW_APPLICATIONS)
  }

  function addMember(uid) {
    g_squad_manager.removeInvitedPlayers(uid)
    let memberData = SquadMember(uid)
    processSquadDataMembers(@(members) members[uid] <- memberData)
    g_squad_manager.removeApplication(uid.tointeger())
    g_squad_manager.requestMemberData(uid)

    if (g_squad_manager.isSquadLeader() && g_squad_manager.isSquadFull())
      g_squad_manager.denyAllAplication()

    broadcastEvent(squadEvent.STATUS_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function removeMember(uid) {
    let memberData = g_squad_manager.getMemberData(uid)
    if (memberData == null)
      return

    processSquadDataMembers(@(members) members.$rawdelete(memberData.uid))
    update_contacts_by_list([memberData.getData()])

    broadcastEvent(squadEvent.STATUS_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function onEventSquadDataReceived(resSquadData) {
    let alreadyInSquad = g_squad_manager.isInSquad()

    let newSquadId = resSquadData?.id
    if (is_numeric(newSquadId)) {
      let isWasBeLeader = g_squad_manager.isSquadLeader()
      updSquadData("id", newSquadId.tostring()) 
      if (isWasBeLeader && !g_squad_manager.isSquadLeader())
        updSmData("meReady", false)
    } else if (!alreadyInSquad) {
      script_net_assert_once("no squad id", "Error: received squad data without squad id")
      leaveSquadImpl() 
      g_squad_manager.setState(squadState.NOT_IN_SQUAD)
      return
    }

    let resMembers = resSquadData?.members ?? []
    let newMembersData = {}
    processSmDataMembersNames(@(membersNames) membersNames.clear())
    foreach (uidInt64 in resMembers) {
      if (!is_numeric(uidInt64))
        continue

      let uid = uidInt64.tostring()
      if (uid in getSquadData().members)
        newMembersData[uid] <- getSquadData().members[uid]
      else
        newMembersData[uid] <- SquadMember(uid)
      processSmDataMembersNames(@(membersNames) membersNames[newMembersData[uid].name] <- uid)
      if (uid != userIdStr.get())
        g_squad_manager.requestMemberData(uid)
    }
    updSquadData("members", newMembersData)

    g_squad_manager.updateInvitedData(resSquadData?.invites ?? [])

    g_squad_manager.updateApplications(resSquadData?.applications ?? [])

    g_squad_manager.updatePlatformInfo()

    updSmData("cyberCafeSquadMembersNum", g_squad_manager.getSameCyberCafeMembersNum())
    g_squad_manager._parseCustomSquadData(resSquadData?.data)
    let chatInfo = resSquadData?.chat
    if (chatInfo != null) {
      let chatName = chatInfo?.id ?? ""
      if (!u.isEmpty(chatName))
        processSquadDataChatInfo(@(cInfo) cInfo.name = chatName)
    }

    if (g_squad_manager.setState(squadState.IN_SQUAD)) {
      g_squad_manager.updateMyMemberData()
      if (g_squad_manager.isSquadLeader()) {
      
      
      
      
        g_squad_manager.updateCurrentWWOperation()
        g_squad_manager.updatePresenceSquad()
        g_squad_manager.updateLeaderData()
        setSquadData()
        return
      }
      if (g_squad_manager.getPresence().isInBattle)
        addPopup(loc("squad/name"), loc("squad/wait_until_battle_end"))
    }

    g_squad_manager.joinSquadChatRoom()

    if (g_squad_manager.isSquadLeader() && !g_squad_manager.readyCheck())
      leaveAllQueues()

    if (!alreadyInSquad)
      g_squad_manager.checkUpdateStatus(squadStatusUpdateState.MENU)

    g_squad_manager.updateLeaderGameModeId(resSquadData?.data.leaderGameModeId ?? "")
    updSquadData("leaderBattleRating", resSquadData?.data.leaderBattleRating ?? 0)

    broadcastEvent(squadEvent.DATA_UPDATED)

    let lastReadyness = g_squad_manager.isMeReady()
    let currentReadyness = lastReadyness || g_squad_manager.isSquadLeader()
    if (lastReadyness != currentReadyness || !alreadyInSquad)
      g_squad_manager.setReadyFlag(currentReadyness)

    let lastCrewsReadyness = getSmData().isMyCrewsReady
    let currentCrewsReadyness = lastCrewsReadyness || g_squad_manager.isSquadLeader()
    if (lastCrewsReadyness != currentCrewsReadyness || !alreadyInSquad)
      g_squad_manager.setCrewsReadyFlag(currentCrewsReadyness)
  }

  function _parseCustomSquadData(data) {
    processSquadDataChatInfo(@(chatInfo) chatInfo.__update(data?.chatInfo ?? DEFAULT_SQUAD_CHAT_INFO))

    let properties = data?.properties
    local isPropertyChange = false
    if (!properties) {
      processSquadDataProperties(@(props) props.__update(DEFAULT_SQUAD_PROPERTIES))
      isPropertyChange = true
    }
    if (u.isTable(properties))
      foreach (key, value in properties) {
        if (u.isEqual(getSquadData()?.properties?[key], value))
          continue

        processSquadDataProperties(@(props) props[key] <- value)
        isPropertyChange = true
      }
    if (isPropertyChange)
      broadcastEvent(squadEvent.PROPERTIES_CHANGED)
    updSquadData("presence", data?.presence ?? clone DEFAULT_SQUAD_PRESENCE)
    updSquadData("psnSessionId", data?.psnSessionId ?? "")
  }

  checkMembersPkg

  getSquadMembersDataForContact

  function checkUpdateStatus(newStatus) {
    if (getSmData().lastUpdateStatus == newStatus || !g_squad_manager.isInSquad())
      return

    updSmData("lastUpdateStatus", newStatus)
    updateMyCountryData()
  }

  function startWWBattlePrepare(battleId = null) {
    if (!g_squad_manager.isSquadLeader())
      return

    if (g_squad_manager.getWwOperationBattle() == battleId)
      return

    processSquadDataWwOperationInfo(@(wwOperationInfo) wwOperationInfo.battle <- battleId)
    processSquadDataWwOperationInfo(@(wwOperationInfo) wwOperationInfo.id = wwGetOperationId())
    processSquadDataWwOperationInfo(@(wwOperationInfo) wwOperationInfo.country = profileCountrySq.get())

    g_squad_manager.updatePresenceSquad()
    setSquadData()
  }

  function cancelWwBattlePrepare() {
    if (!g_squad_manager.isInSquad())
      return
    g_squad_manager.startWWBattlePrepare() 
    request_matching("msquad.send_event", null, null, { eventName = "CancelBattlePrepare" })
  }

  function updateMemberData(params) {
    this.requestMemberDataCallbackImpl(params.userId, params.update.data)
  }

  onEventPresetsByGroupsChanged = @(_params) g_squad_manager.updateMyMemberData()
  onEventBeforeProfileInvalidation = @(_p) g_squad_manager.reset()
  onEventUpdateEsFromHost = @(_p) g_squad_manager.checkUpdateStatus(squadStatusUpdateState.BATTLE)
  onEventNewSceneLoaded = @(_p) isInMenu.get()
    ? g_squad_manager.checkUpdateStatus(squadStatusUpdateState.MENU) : null
  onEventBattleEnded = @(_p) isInMenu.get()
    ? g_squad_manager.checkUpdateStatus(squadStatusUpdateState.MENU) : null
  onEventSessionDestroyed = @(_p) isInMenu.get()
    ? g_squad_manager.checkUpdateStatus(squadStatusUpdateState.MENU) : null
  onEventChatConnected = @(_params) g_squad_manager.joinSquadChatRoom()
  onEventAvatarChanged = @(_p) g_squad_manager.updateMyMemberData()
  onEventCrewsListInvalidate = @(_p) g_squad_manager.updateMyMemberData()
  onEventUnitRepaired = @(_p) updateMyCountryData()
  onEventCrossPlayOptionChanged = @(_p) g_squad_manager.updateMyMemberData()
  onEventMatchingDisconnect = @(_p) g_squad_manager.reset()
  onEventSlotbarPresetLoaded = @(_params) g_squad_manager.updateMyMemberData()

  function onEventContactsUpdated(_params) {
    local isChanged = false
    local contact = null
    foreach (uid, memberData in g_squad_manager.getInvitedPlayers()) {
      contact = getContact(uid)
      if (contact == null)
        continue

      memberData.update(contact)
      isChanged = true
    }

    if (isChanged)
      broadcastEvent(squadEvent.INVITES_CHANGED)

    isChanged = false
    foreach (uid, memberData in g_squad_manager.getApplicationsToSquad()) {
      contact = getContact(uid.tostring())
      if (contact == null)
        continue

      if (memberData.update(contact))
        isChanged = true
    }
    if (isChanged)
      broadcastEvent(squadEvent.APPLICATIONS_CHANGED {})
  }

  function onEventMatchingConnect(_params) {
    g_squad_manager.reset()
    g_squad_manager.checkForSquad()
  }

  function onEventLoginComplete(_params) {
    g_squad_manager.initSquadSizes()
    g_squad_manager.reset()
    g_squad_manager.checkForSquad()
  }

  function onEventLoadingStateChange(_params) {
    if (isInFlight())
      g_squad_manager.setReadyFlag(false)

    g_squad_manager.updatePresenceSquad()
    setSquadData()
  }

  function onEventLobbyStatusChange(_params) {
    if (!isInSessionRoom.get())
      g_squad_manager.setReadyFlag(false)

    g_squad_manager.updateMyMemberData()
    g_squad_manager.updatePresenceSquad()
    setSquadData()
  }

  function onEventQueueChangeState(_params) {
    if (!hasActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE))
      g_squad_manager.setCrewsReadyFlag(false)

    g_squad_manager.updatePresenceSquad()
    setSquadData()
  }

  function onEventBattleRatingChanged(_params) {
    g_squad_manager.updateLeaderData()
    setSquadData()
  }

  function onEventCurrentGameModeIdChanged(_params) {
    g_squad_manager.updateLeaderData(false)
    setSquadData()
  }

  function onEventEventsDataUpdated(_params) {
    g_squad_manager.updateLeaderData(false)
    setSquadData()
  }
}

subscribe_handler(g_squad_manager, g_listener_priority.DEFAULT_HANDLER)



addListenersWithoutEnv({
  [SQUAD_LEAVE_REQUESTED] = @(p) g_squad_manager.leaveSquad(p?.onLeave),
  [SQUAD_REVOKE_ALL_INVITES_REQUESTED] = @(p) g_squad_manager.revokeAllInvites(p?.onDone),
  [SQUAD_SET_READY_REQUESTED] = @(p) g_squad_manager.setReadyFlag(p?.ready),
  [SQUAD_SET_CREWS_READY_REQUESTED] = @(p) g_squad_manager.setCrewsReadyFlag(p?.ready),
  [SQUAD_MY_MEMBER_DATA_UPDATE_REQUESTED] = @(p) g_squad_manager.updateMyMemberDataAfterActualizeJwt(p?.memberData),
  [SQUAD_JOIN_REQUESTED] = @(p) g_squad_manager.joinToSquad(p.uid),
}, g_listener_priority.DEFAULT_HANDLER)




g_squad_manager.checkForSquad()



g_squad_manager = freeze(g_squad_manager)

return {
  g_squad_manager
}