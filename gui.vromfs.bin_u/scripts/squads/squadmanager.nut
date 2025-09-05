from "%scripts/dagui_natives.nut" import get_cyber_cafe_level, gchat_is_connected, get_cyber_cafe_id, is_eac_inited, save_short_token
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadState, SQUADS_VERSION, squadMemberState
import "%scripts/squads/squadApplications.nut" as squadApplications
from "%scripts/utils_sa.nut" import gen_rnd_password

let { g_chat } = require("%scripts/chat/chat.nut")
let { isSquadRoomJoined } = require("%scripts/chat/chatRooms.nut")
let { checkMatchingError, request_matching } = require("%scripts/matching/api.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { format } = require("string")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { hasAnyFeature } = require("%scripts/user/features.nut")
let platformModule = require("%scripts/clientState/platform.nut")
let { getPlatformAlias, is_gdk } = require("%sqstd/platform.nut")
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
let { get_game_settings_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { isInSessionRoom, getSessionLobbyRoomId, canInviteIntoSession, isMpSquadChatAllowed
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { userIdStr, userIdInt64 } = require("%scripts/user/profileStates.nut")
let { wwGetOperationId } = require("worldwar")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { getGlobalModule, lateBindGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { getCurrentGameModeId, setCurrentGameModeById, getUserGameModeId
} = require("%scripts/gameModes/gameModeManagerState.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { checkShowMultiplayerAasWarningMsg } = require("%scripts/user/antiAddictSystem.nut")
let { isWorldWarEnabled, canPlayWorldwar } = require("%scripts/globalWorldWarScripts.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
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

enum squadStatusUpdateState {
  NONE
  MENU
  BATTLE
}

enum msquadErrorId {
  ALREADY_IN_SQUAD = "ALREADY_IN_SQUAD"
  NOT_SQUAD_LEADER = "NOT_SQUAD_LEADER"
  NOT_SQUAD_MEMBER = "NOT_SQUAD_MEMBER"
  SQUAD_FULL = "SQUAD_FULL"
  SQUAD_NOT_INVITED = "SQUAD_NOT_INVITED"
}

const DEFAULT_SQUADS_VERSION = 1
const SQUAD_REQEST_TIMEOUT = 45000

let DEFAULT_SQUAD_PROPERTIES = {
  maxMembers = 4
  isApplicationsEnabled = true
}

let SQUAD_SIZE_FEATURES_CHECK = {
  squad = ["Squad"]
  platoon = ["Clans", "WorldWar"]
  battleGroup = ["WorldWar"]
}

let DEFAULT_SQUAD_PRESENCE = presenceTypes.IDLE.getParams()
let DEFAULT_SQUAD_CHAT_INFO = { name = "", password = "" }
let DEFAULT_SQUAD_WW_OPERATION_INFO = { id = -1, country = "", battle = null }

let convertIdToInt = @(id) u.isString(id) ? id.tointeger() : id

let requestSquadInfo = @(successCallback, errorCallback = null, requestOptions = null)
  request_matching("msquad.get_info", successCallback, errorCallback, null, requestOptions)

let leaveSquadImpl = @(successCallback = null) request_matching("msquad.leave_squad", successCallback)


let squadData = persist("squadData", @() {
  id = ""
  members = {}
  invitedPlayers = {}
  applications = {}
  platformInfo = []
  chatInfo = clone DEFAULT_SQUAD_CHAT_INFO
  wwOperationInfo = clone DEFAULT_SQUAD_WW_OPERATION_INFO
  properties = clone DEFAULT_SQUAD_PROPERTIES
  presence = clone DEFAULT_SQUAD_PRESENCE
  psnSessionId = ""
  leaderBattleRating = 0
  leaderGameModeId = ""
})
let smData = persist("smData",@() {
  COMMON_SQUAD_SIZE = 4
  MAX_SQUAD_SIZE = 4 
  squadSizesList = []
  meReady = false
  isMyCrewsReady = false
  delayedInvites = []

  lastUpdateStatus = squadStatusUpdateState.NONE
  maxInvitesCount = 9
  cyberCafeSquadMembersNum = -1
  lastStateChangeTime = -SQUAD_REQEST_TIMEOUT
  hasNewApplication = false
  roomCreateInProgress = false
  membersNames = {}
  state = squadState.NOT_IN_SQUAD
})

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

g_squad_manager = {

  getSquadData = @() squadData

  getSMMaxSquadSize = @() smData.MAX_SQUAD_SIZE
  getSquadSizesList = @() smData.squadSizesList
  getIsMyCrewsReady = @() smData.isMyCrewsReady
  getHasNewApplication = @() smData.hasNewApplication
  getState = @() smData.state

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
    && smData.squadSizesList.len() > 1

  getLeaderUid = @() squadData.id
  getSquadLeaderData = @() g_squad_manager.getMemberData(g_squad_manager.getLeaderUid())
  getMembers = @() squadData.members
  getPsnSessionId = @() squadData?.psnSessionId ?? ""
  getInvitedPlayers = @() squadData.invitedPlayers
  getPlatformInfo = @() squadData.platformInfo
  getApplicationsToSquad = @() squadData.applications
  getLeaderNick = @() !g_squad_manager.isInSquad() ? "" : g_squad_manager.getSquadLeaderData()?.name ?? ""
  getSquadRoomName = @() squadData.chatInfo.name
  getSquadRoomPassword = @() squadData.chatInfo.password
  getWwOperationId = @() squadData.wwOperationInfo?.id ?? -1
  getWwOperationCountry = @() squadData.wwOperationInfo?.country ?? ""
  getWwOperationBattle = @() squadData.wwOperationInfo?.battle
  getLeaderGameModeId = @() squadData?.leaderGameModeId ?? ""
  getLeaderBattleRating = @() squadData?.leaderBattleRating ?? 0
  getMaxSquadSize = @() squadData.properties.maxMembers
  getOfflineMembers = @() g_squad_manager.getMembersByOnline(false)
  getOnlineMembers = @() g_squad_manager.getMembersByOnline(true)
  getMemberData = @(uid) !g_squad_manager.isInSquad() ? null : squadData.members?[uid]
  getSquadMemberNameByUid = @(uid) (g_squad_manager.isInSquad() && uid in squadData.members) ?
    squadData.members[uid].name : ""
  getSquadRoomId = @() g_squad_manager.getSquadLeaderData()?.sessionRoomId ?? ""
  getPresence = @() getByPresenceParams(squadData?.presence ?? {})

  function getMembersNotAllowedInWorldWar() {
    let res = []
    foreach (_uid, member in g_squad_manager.getMembers())
      if (!member.isWorldWarAvailable)
        res.append(member)

    return res
  }

  function getSameCyberCafeMembersNum() {
    if (smData.cyberCafeSquadMembersNum >= 0)
      return smData.cyberCafeSquadMembersNum

    local num = 0
    if (g_squad_manager.isInSquad() && squadData.members && get_cyber_cafe_level() > 0) {
      let myCyberCafeId = get_cyber_cafe_id()
      foreach (_uid, memberData in squadData.members)
        if (myCyberCafeId == memberData.cyberCafeId)
          num++
    }

    smData.cyberCafeSquadMembersNum = num
    return num
  }

  function getSquadRank() {
    if (!g_squad_manager.isInSquad())
      return -1

    local squadRank = 0
    foreach (_uid, memberData in squadData.members)
      squadRank = max(memberData.rank, squadRank)

    return squadRank
  }

  function getDiffCrossPlayConditionMembers() {
    let diffMembers = []
    if (!g_squad_manager.isInSquad())
      return { diffMembers }

    let leader = squadData.members[g_squad_manager.getLeaderUid()]
    let leaderPlatformGroup = getPlatformAlias(leader.platform)

    foreach (_uid, memberData in squadData.members) {
      if (leader.crossplay == true) {
        if (memberData.crossplay == false)
          diffMembers.append(memberData)
        continue
      }

      let memberPlatformGroup = getPlatformAlias(memberData.platform)
      if ((leader.isGdkClient && !memberData.isGdkClient)
        || memberPlatformGroup != leaderPlatformGroup)
          diffMembers.append(memberData)
    }
    return { diffMembers, isLeaderCrossplayOn = leader.crossplay }
  }

  function getMembersByOnline(online = true) {
    let res = []
    if (!g_squad_manager.isInSquad())
      return res

    foreach (_uid, memberData in squadData.members)
      if (memberData.online == online)
        res.append(memberData)

    return res
  }

  function getOnlineMembersCount() {
    if (!g_squad_manager.isInSquad())
      return 1
    local res = 0
    foreach (member in squadData.members)
      if (member.online)
        res++
    return res
  }

  function getSquadSize(includeInvites = false) {
    if (!g_squad_manager.isInSquad())
      return 0

    local res = squadData.members.len()
    if (includeInvites) {
      res += g_squad_manager.getInvitedPlayers().len()
      res += g_squad_manager.getApplicationsToSquad().len()
    }
    return res
  }

  function getPlayerStatusInMySquad(uid) {
    if (!g_squad_manager.isInSquad())
      return squadMemberState.NOT_IN_SQUAD

    let memberData = g_squad_manager.getMemberData(uid)
    if (memberData == null)
      return squadMemberState.NOT_IN_SQUAD

    if (g_squad_manager.getLeaderUid() == uid)
      return squadMemberState.SQUAD_LEADER

    if (!memberData.online)
      return squadMemberState.SQUAD_MEMBER_OFFLINE
    if (memberData.isReady)
      return squadMemberState.SQUAD_MEMBER_READY
    return squadMemberState.SQUAD_MEMBER
  }

  function setMaxSquadSize(newSize) {
    squadData.properties.maxMembers = newSize
  }

  function setSquadSize(newSize) {
    if (newSize == g_squad_manager.getMaxSquadSize())
      return

    g_squad_manager.setMaxSquadSize(newSize)
    g_squad_manager.setSquadData()
    broadcastEvent(squadEvent.SIZE_CHANGED)
  }

  function setReadyFlag(ready = null, needUpdateMemberData = true) {
    let isLeader = g_squad_manager.isSquadLeader()
    if (isLeader && ready != true)
      return

    let isMeReady = g_squad_manager.isMeReady()
    if (ready != null && isMeReady == ready)
      return
    let isSetNoReady = (ready == false || (ready == null && isMeReady))
    let isInSquad = g_squad_manager.isInSquad()
    if (!isSetNoReady && !isInSquad)
      return

    if (isAnyQueuesActive() && !isLeader && isInSquad && isSetNoReady) {
      addPopup(null, loc("squad/cant_switch_off_readyness_in_queue"))
      return
    }

    function cb() {
      smData.meReady = ready == null ? !isMeReady : ready
      if (!smData.meReady)
        smData.isMyCrewsReady = false

      if (needUpdateMemberData)
        g_squad_manager.updateMyMemberDataAfterActualizeJwt()

      broadcastEvent(squadEvent.SET_READY)
    }

    let event = events.getEvent(g_squad_manager.getLeaderGameModeId())
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
      smData.isMyCrewsReady = !smData.isMyCrewsReady
    else if (smData.isMyCrewsReady != ready)
      smData.isMyCrewsReady = ready
    else
      return

    if (needUpdateMemberData)
      g_squad_manager.updateMyMemberData()
  }

  
  function setSquadData() {
    if (!g_squad_manager.isSquadLeader())
      return

    request_matching("msquad.set_squad_data", null, null, squadData)
  }

  function setPsnSessionId(id = null) {
    squadData.psnSessionId <- id
    g_squad_manager.setSquadData()
  }

  function setState(newState) {
    if (smData.state == newState)
      return false
    smData.state = newState
    smData.lastStateChangeTime = get_time_msec()
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

  hasApplicationInMySquad = @(uid, name = null) uid ? (uid in g_squad_manager.getApplicationsToSquad())
    : u.search(g_squad_manager.getApplicationsToSquad(), @(player) player.name == name) != null

  isSquadFull = @() g_squad_manager.getSquadSize() >= g_squad_manager.getMaxSquadSize()
  isInSquad = @(forChat = false) (forChat && !isMpSquadChatAllowed()) ? false
    : smData.state == squadState.IN_SQUAD
  isMeReady = @() smData.meReady
  isSquadLeader = @() g_squad_manager.isInSquad() && g_squad_manager.getLeaderUid() == userIdStr.get()
  isPlayerInvited = @(uid, name = null) uid ? (uid in g_squad_manager.getInvitedPlayers())
    : u.search(g_squad_manager.getInvitedPlayers(), @(player) player.name == name) != null
  isMySquadLeader = @(uid) g_squad_manager.isInSquad() && uid != null && uid == g_squad_manager.getLeaderUid()
  isSquadMember = @() g_squad_manager.isInSquad() && !g_squad_manager.isSquadLeader()
  isMemberReady = @(uid) g_squad_manager.getMemberData(uid)?.isReady ?? false
  isInMySquad = @(name, checkAutosquad = true)
    (g_squad_manager.isInSquad() && g_squad_manager.isMySquadMember(name)) ? true
      : checkAutosquad && isMemberInMySquadByName(name)

  isInMySquadById = @(userId, checkAutosquad = true)
    (g_squad_manager.isInSquad() && g_squad_manager.isMySquadMemberById(userId)) ? true
      : checkAutosquad && isMemberInMySquadById(userId)

  isMe = @(uid) uid == userIdStr.get()
  isStateInTransition = @() (smData.state == squadState.JOINING || smData.state == squadState.LEAVING)
    && smData.lastStateChangeTime + SQUAD_REQEST_TIMEOUT > get_time_msec()
  isInvitedMaxPlayers = @() g_squad_manager.isSquadFull()
    || g_squad_manager.getInvitedPlayers().len() >= smData.maxInvitesCount
  isApplicationsEnabled = @() squadData.properties.isApplicationsEnabled

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

  function isNotAloneOnline() {
    if (!g_squad_manager.isInSquad())
      return false

    if (squadData.members.len() == 1)
      return false

    foreach (uid, memberData in squadData.members)
      if (uid != userIdStr.get() && memberData.online == true)
        return true

    return false
  }

  function updateLeaderGameModeId(newLeaderGameModeId) {
    if (squadData.leaderGameModeId == newLeaderGameModeId)
      return

    squadData.leaderGameModeId = newLeaderGameModeId
    if (g_squad_manager.isSquadMember()) {
      let event = events.getEvent(g_squad_manager.getLeaderGameModeId())
      if (g_squad_manager.isMeReady() && (!antiCheat.showMsgboxIfEacInactive(event) ||
                          !showMsgboxIfSoundModsNotAllowed(event)))
        g_squad_manager.setReadyFlag(false)
      g_squad_manager.updateMyMemberData()
    }
  }

  function updateMyMemberDataAfterActualizeJwt(myMemberData = null) {
    if (!g_squad_manager.isInSquad())
      return

    
    
    if (!needActualizeQueueData.value || g_squad_manager.isSquadLeader() || !g_squad_manager.isMeReady()) {
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
      squadData.members[userIdStr.get()] <- memberData
    }

    memberData.update(data)
    memberData.online = true
    updateContact(memberData.getData())

    request_matching("msquad.set_member_data", null, null, { userId = userIdInt64.get(), data })
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function updateMyMemberData(data = null) {
    if (!g_squad_manager.isInSquad())
      return

    let isWorldwarEnabled = isWorldWarEnabled()
    data = data ?? getMyStateData()
    data.__update({
      isReady = g_squad_manager.isMeReady()
      isCrewsReady = smData.isMyCrewsReady
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
      foreach (wwOperation in ::g_ww_global_status_type.ACTIVE_OPERATIONS.getList()) {
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
      squadData.members[userIdStr.get()] <- memberData
    }

    memberData.update(data)
    memberData.online = true
    updateContact(memberData.getData())

    request_matching("msquad.set_member_data", null, null, { userId = userIdInt64.get(), data })
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function updateLeaderData(isActualBR = true) {
    if (!g_squad_manager.isSquadLeader())
      return

    let currentGameModeId = getCurrentGameModeId()
    if (!isActualBR && squadData.leaderGameModeId == currentGameModeId)
      return

    squadData.__update({
      leaderBattleRating = isActualBR ? battleRating.recentBR.value : 0
      leaderGameModeId = isActualBR ? battleRating.recentBrGameModeId.value : currentGameModeId
    })
  }

  function updateCurrentWWOperation() {
    if (!g_squad_manager.isSquadLeader() || !isWorldWarEnabled())
      return

    let wwOperationId = wwGetOperationId()
    local country = profileCountrySq.get()
    if (wwOperationId > -1)
      country = ::g_ww_global_status_actions.getOperationById(wwOperationId)?.getMyAssignCountry()
        ?? country

    squadData.wwOperationInfo.id = wwOperationId
    squadData.wwOperationInfo.country = country
  }

  function updateInvitedData(invites) {
    let newInvitedData = {}
    foreach (uidInt64 in invites) {
      if (!is_numeric(uidInt64))
        continue

      let uid = uidInt64.tostring()
      if (uid in squadData.invitedPlayers)
        newInvitedData[uid] <- squadData.invitedPlayers[uid]
      else
        newInvitedData[uid] <- SquadMember(uid, true)

      requestUsersInfo([uid])
    }

    squadData.invitedPlayers = newInvitedData
  }

  function updateApplications(applications) {
    let newApplicationsData = {}
    foreach (uid in applications) {
      if (uid in squadData.applications)
        newApplicationsData[uid] <- squadData.applications[uid]
      else {
        newApplicationsData[uid] <- SquadMember(uid.tostring(), false, true)
        smData.hasNewApplication = true
      }
      requestUsersInfo([uid.tostring()])
    }
    if (newApplicationsData.len() == 0)
      smData.hasNewApplication = false
    squadData.applications = newApplicationsData
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

    squadData.platformInfo = playerPlatforms
  }

  function updatePresenceSquad() {
    g_squad_manager.updateMyPresence()
    if (!g_squad_manager.isSquadLeader())
      return

    let presenceParams = getCurrentPresenceType().getParams()
    if (!u.isEqual(squadData.presence, presenceParams))
      squadData.presence = presenceParams
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
    smData.squadSizesList.clear()
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
      smData.squadSizesList.append({
        name = name
        value = size
      })
      maxSize = max(maxSize, size)
    }

    if (!smData.squadSizesList.len())
      return

    smData.COMMON_SQUAD_SIZE = smData.squadSizesList[0].value
    smData.MAX_SQUAD_SIZE = maxSize
    g_squad_manager.setMaxSquadSize(smData.COMMON_SQUAD_SIZE)
  }

  function enableApplications(shouldEnable) {
    if (shouldEnable == g_squad_manager.isApplicationsEnabled())
      return

    squadData.properties.isApplicationsEnabled = shouldEnable
    g_squad_manager.setSquadData()
  }

  function readyCheck(considerInvitedPlayers = false) {
    if (!g_squad_manager.isInSquad())
      return false

    foreach (_uid, memberData in squadData.members)
      if (memberData.online == true && memberData.isReady == false)
        return false

    if (considerInvitedPlayers && squadData.invitedPlayers.len() > 0)
      return false

    return  true
  }

  function crewsReadyCheck() {
    if (!g_squad_manager.isInSquad())
      return false

    foreach (_uid, memberData in squadData.members)
      if (memberData.online && !memberData.isCrewsReady)
        return false

    return  true
  }

  function createSquad(callback) {
    if (!hasFeature("Squad"))
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

    if (isSquadRoomJoined())
      return

    if (smData.roomCreateInProgress)
      return

    let name = g_squad_manager.getSquadRoomName()
    local password = g_squad_manager.getSquadRoomPassword()
    local callback = null

    if (u.isEmpty(name))
      return

    if (g_squad_manager.isSquadLeader() && u.isEmpty(password)) {
      password = gen_rnd_password(15)
      squadData.chatInfo.password = password

      smData.roomCreateInProgress = true
      callback = function() {
        g_squad_manager.setSquadData()
        smData.roomCreateInProgress = false
      }
    }

    if (u.isEmpty(password))
      return

    g_chat.joinSquadRoom(callback)
  }

  function disbandSquad() {
    if (!g_squad_manager.isSquadLeader())
      return

    g_squad_manager.setState(squadState.LEAVING)
    request_matching("msquad.disband_squad")
  }

  function checkForSquad() {
    if (!isLoggedIn.get())
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
    if (!g_squad_manager.canJoinSquad())
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
          smData.delayedInvites.append(contact.psnId)
        })
    }

    let callback = function(_response) {
      if (isInvitingPsnPlayer && u.isEmpty(smData.delayedInvites)) {
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
    if (u.isEmpty(g_squad_manager.getPsnSessionId()) || u.isEmpty(smData.delayedInvites))
      return

    foreach (invitee in smData.delayedInvites)
      invite(g_squad_manager.getPsnSessionId(), invitee)
    smData.delayedInvites.clear()
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
    if (!g_squad_manager.isSquadLeader())
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
    if (!g_squad_manager.isSquadLeader())
      return

    request_matching("msquad.deny_all_membership_requests", null, null, null, null)
  }

  function denyMembershipAplication(uid, callback = null) {
    if (g_squad_manager.isInSquad() && !g_squad_manager.isSquadLeader())
      return

    request_matching("msquad.deny_membership", callback, null, { userId = uid }, null)
  }

  function dismissFromSquad(uid) {
    if (!g_squad_manager.isSquadLeader())
      return

    if (squadData.members?[uid])
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

    foreach (_uid, memberData in squadData.members)
      if (memberData.name == name || memberData.name == getRealName(name))
        return memberData

    return null
  }

  isMySquadMember = @(name) (smData.membersNames?[name] != null) || (smData.membersNames?[getRealName(name)] != null)
  isMySquadMemberById = @(id) squadData.members?[id] != null


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
    if (!g_squad_manager.canJoinSquad())
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
    let memberData = squadData.members?[uid]
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

    let memberData = g_squad_manager.getMemberData(uid)
    if (memberData == null)
      return

    let currentMemberData = memberData.getData()
    let receivedMemberData = receivedData?.data
    let isMemberDataChanged = memberData.update(receivedMemberData)
    let isMemberVehicleDataChanged = isMemberDataChanged
      && g_squad_manager.isMemberDataVehicleChanged(currentMemberData, memberData)
    let contact = getContact(memberData.uid, memberData.name)
    contact.online = response.online
    memberData.online = response.online
    if (!response.online)
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
    if (smData.state == squadState.IN_SQUAD)
      g_squad_manager.setState(squadState.LEAVING)

    leaveAllQueues()
    g_chat.leaveSquadRoom()

    smData.cyberCafeSquadMembersNum = -1

    squadData.id = ""
    let contactsUpdatedList = []
    foreach (_id, memberData in squadData.members)
      contactsUpdatedList.append(memberData.getData())

    squadData.members.clear()
    squadData.invitedPlayers.clear()
    squadData.applications.clear()
    squadData.platformInfo.clear()
    squadData.chatInfo.__update(DEFAULT_SQUAD_CHAT_INFO)
    squadData.wwOperationInfo.__update(DEFAULT_SQUAD_WW_OPERATION_INFO)
    squadData.properties.__update(DEFAULT_SQUAD_PROPERTIES)
    squadData.presence.__update(DEFAULT_SQUAD_PRESENCE)
    squadData.psnSessionId = ""
    squadData.leaderBattleRating = 0
    squadData.leaderGameModeId = ""
    g_squad_manager.setMaxSquadSize(smData.COMMON_SQUAD_SIZE)

    smData.lastUpdateStatus = squadStatusUpdateState.NONE
    if (smData.meReady)
      g_squad_manager.setReadyFlag(false, false)

    update_contacts_by_list(contactsUpdatedList)

    g_squad_manager.setState(squadState.NOT_IN_SQUAD)
    broadcastEvent(squadEvent.DATA_UPDATED)
    broadcastEvent(squadEvent.INVITES_CHANGED)
  }

  function addInvitedPlayers(uid) {
    if (uid in squadData.invitedPlayers)
      return

    squadData.invitedPlayers[uid] <- SquadMember(uid, true)

    requestUsersInfo([uid])

    broadcastEvent(squadEvent.PLAYER_INVITED, { uid = uid })
    broadcastEvent(squadEvent.INVITES_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function removeInvitedPlayers(uid) {
    if (!(uid in squadData.invitedPlayers))
      return

    squadData.invitedPlayers.$rawdelete(uid)
    broadcastEvent(squadEvent.INVITES_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function addApplication(uid) {
    if (uid in squadData.applications)
      return

    squadData.applications[uid] <- SquadMember(uid.tostring(), false, true)
    requestUsersInfo([uid.tostring()])
    g_squad_manager.checkNewApplications()
    if (g_squad_manager.isSquadLeader())
      addPopup(null, colorize("chatTextInviteColor",
        format(loc("squad/player_application"),
          getPlayerName(squadData.applications[uid]?.name ?? ""))))

    broadcastEvent(squadEvent.APPLICATIONS_CHANGED, { uid = uid })
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function removeApplication(applications) {
    if (!u.isArray(applications))
      applications = [applications]
    local isApplicationsChanged = false
    foreach (uid in applications) {
      if (!(uid in squadData.applications))
        continue
      squadData.applications.$rawdelete(uid)
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
    foreach (application in squadData.applications)
      application.isNewApplication = false
    g_squad_manager.checkNewApplications()
  }

  function checkNewApplications() {
    let curHasNewApplication = smData.hasNewApplication
    smData.hasNewApplication = false
    foreach (application in squadData.applications)
      if (application.isNewApplication == true) {
        smData.hasNewApplication = true
        break
      }
    if (curHasNewApplication != smData.hasNewApplication)
      broadcastEvent(squadEvent.NEW_APPLICATIONS)
  }

  function addMember(uid) {
    g_squad_manager.removeInvitedPlayers(uid)
    let memberData = SquadMember(uid)
    squadData.members[uid] <- memberData
    g_squad_manager.removeApplication(uid.tointeger())
    g_squad_manager.requestMemberData(uid)

    broadcastEvent(squadEvent.STATUS_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function removeMember(uid) {
    let memberData = g_squad_manager.getMemberData(uid)
    if (memberData == null)
      return

    squadData.members.$rawdelete(memberData.uid)
    update_contacts_by_list([memberData.getData()])

    broadcastEvent(squadEvent.STATUS_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function onEventSquadDataReceived(resSquadData) {
    let alreadyInSquad = g_squad_manager.isInSquad()

    let newSquadId = resSquadData?.id
    if (is_numeric(newSquadId)) {
      let isWasBeLeader = g_squad_manager.isSquadLeader()
      squadData.id = newSquadId.tostring() 
      if (isWasBeLeader && !g_squad_manager.isSquadLeader())
        smData.meReady = false
    } else if (!alreadyInSquad) {
      script_net_assert_once("no squad id", "Error: received squad data without squad id")
      leaveSquadImpl() 
      g_squad_manager.setState(squadState.NOT_IN_SQUAD)
      return
    }

    let resMembers = resSquadData?.members ?? []
    let newMembersData = {}
    smData.membersNames.clear()
    foreach (uidInt64 in resMembers) {
      if (!is_numeric(uidInt64))
        continue

      let uid = uidInt64.tostring()
      if (uid in squadData.members)
        newMembersData[uid] <- squadData.members[uid]
      else
        newMembersData[uid] <- SquadMember(uid)

      smData.membersNames[newMembersData[uid].name] <- uid
      if (uid != userIdStr.get())
        g_squad_manager.requestMemberData(uid)
    }
    squadData.members = newMembersData

    g_squad_manager.updateInvitedData(resSquadData?.invites ?? [])

    g_squad_manager.updateApplications(resSquadData?.applications ?? [])

    g_squad_manager.updatePlatformInfo()

    smData.cyberCafeSquadMembersNum = g_squad_manager.getSameCyberCafeMembersNum()
    g_squad_manager._parseCustomSquadData(resSquadData?.data)
    let chatInfo = resSquadData?.chat
    if (chatInfo != null) {
      let chatName = chatInfo?.id ?? ""
      if (!u.isEmpty(chatName))
        squadData.chatInfo.name = chatName
    }

    if (g_squad_manager.setState(squadState.IN_SQUAD)) {
      g_squad_manager.updateMyMemberData()
      if (g_squad_manager.isSquadLeader()) {
      
      
      
      
        g_squad_manager.updateCurrentWWOperation()
        g_squad_manager.updatePresenceSquad()
        g_squad_manager.updateLeaderData()
        g_squad_manager.setSquadData()
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
    squadData.leaderBattleRating = resSquadData?.data.leaderBattleRating ?? 0

    broadcastEvent(squadEvent.DATA_UPDATED)

    let lastReadyness = g_squad_manager.isMeReady()
    let currentReadyness = lastReadyness || g_squad_manager.isSquadLeader()
    if (lastReadyness != currentReadyness || !alreadyInSquad)
      g_squad_manager.setReadyFlag(currentReadyness)

    let lastCrewsReadyness = smData.isMyCrewsReady
    let currentCrewsReadyness = lastCrewsReadyness || g_squad_manager.isSquadLeader()
    if (lastCrewsReadyness != currentCrewsReadyness || !alreadyInSquad)
      g_squad_manager.setCrewsReadyFlag(currentCrewsReadyness)
  }

  function _parseCustomSquadData(data) {
    squadData.chatInfo.__update(data?.chatInfo ?? DEFAULT_SQUAD_CHAT_INFO)

    let properties = data?.properties
    local isPropertyChange = false
    if (!properties) {
      squadData.properties.__update(DEFAULT_SQUAD_PROPERTIES)
      isPropertyChange = true
    }
    if (u.isTable(properties))
      foreach (key, value in properties) {
        if (u.isEqual(squadData?.properties?[key], value))
          continue

        squadData.properties[key] <- value
        isPropertyChange = true
      }
    if (isPropertyChange)
      broadcastEvent(squadEvent.PROPERTIES_CHANGED)
    squadData.presence = data?.presence ?? clone DEFAULT_SQUAD_PRESENCE
    squadData.psnSessionId = data?.psnSessionId ?? ""
  }

  function checkMembersPkg(pack) { 
    let res = []
    if (!g_squad_manager.isInSquad())
      return res

    foreach (uid, memberData in squadData.members)
      if (memberData.missedPkg != null && isInArray(pack, memberData.missedPkg))
        res.append({ uid = uid, name = memberData.name })

    return res
  }

  function getSquadMembersDataForContact() {
    let contactsData = []

    if (g_squad_manager.isInSquad()) {
      foreach (uid, memberData in squadData.members)
        if (uid != userIdStr.get())
          contactsData.append(memberData.getData())
    }

    return contactsData
  }

  function checkUpdateStatus(newStatus) {
    if (smData.lastUpdateStatus == newStatus || !g_squad_manager.isInSquad())
      return

    smData.lastUpdateStatus = newStatus
    updateMyCountryData()
  }

  function startWWBattlePrepare(battleId = null) {
    if (!g_squad_manager.isSquadLeader())
      return

    if (g_squad_manager.getWwOperationBattle() == battleId)
      return

    squadData.wwOperationInfo.battle <- battleId
    squadData.wwOperationInfo.id = wwGetOperationId()
    squadData.wwOperationInfo.country = profileCountrySq.get()

    g_squad_manager.updatePresenceSquad()
    g_squad_manager.setSquadData()
  }

  function cancelWwBattlePrepare() {
    if (!g_squad_manager.isInSquad())
      return
    g_squad_manager.startWWBattlePrepare() 
    request_matching("msquad.send_event", null, null, { eventName = "CancelBattlePrepare" })
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
    g_squad_manager.setSquadData()
  }

  function onEventLobbyStatusChange(_params) {
    if (!isInSessionRoom.get())
      g_squad_manager.setReadyFlag(false)

    g_squad_manager.updateMyMemberData()
    g_squad_manager.updatePresenceSquad()
    g_squad_manager.setSquadData()
  }

  function onEventQueueChangeState(_params) {
    if (!hasActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE))
      g_squad_manager.setCrewsReadyFlag(false)

    g_squad_manager.updatePresenceSquad()
    g_squad_manager.setSquadData()
  }

  function onEventBattleRatingChanged(_params) {
    g_squad_manager.updateLeaderData()
    g_squad_manager.setSquadData()
  }

  function onEventCurrentGameModeIdChanged(_params) {
    g_squad_manager.updateLeaderData(false)
    g_squad_manager.setSquadData()
  }

  function onEventEventsDataUpdated(_params) {
    g_squad_manager.updateLeaderData(false)
    g_squad_manager.setSquadData()
  }
}

::cross_call_api.squad_manger <- g_squad_manager

subscribe_handler(g_squad_manager, g_listener_priority.DEFAULT_HANDLER)

lateBindGlobalModule("g_squad_manager", g_squad_manager)

return {
  g_squad_manager
}