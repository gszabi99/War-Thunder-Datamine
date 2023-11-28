from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadState, SQUADS_VERSION, squadMemberState

let u = require("%sqStdLibs/helpers/u.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { format } = require("string")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { hasAnyFeature } = require("%scripts/user/features.nut")
let squadApplications = require("%scripts/squads/squadApplications.nut")
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
let { registerPersistentDataFromRoot, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { get_game_settings_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { userIdStr, userIdInt64 } = require("%scripts/user/myUser.nut")
let { wwGetOperationId } = require("worldwar")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")

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

let DEFAULT_SQUAD_PRESENCE = ::g_presence_type.IDLE.getParams()
let DEFAULT_SQUAD_CHAT_INFO = { name = "", password = "" }
let DEFAULT_SQUAD_WW_OPERATION_INFO = { id = -1, country = "", battle = null }

let convertIdToInt = @(id) u.isString(id) ? id.tointeger() : id

let requestSquadInfo = @(successCallback, errorCallback = null, requestOptions = null)
  ::request_matching("msquad.get_info", successCallback, errorCallback, null, requestOptions)

let leaveSquadImpl = @(successCallback = null) ::request_matching("msquad.leave_squad", successCallback)

::g_squad_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["squadData", "meReady", "isMyCrewsReady", "lastUpdateStatus", "state",
   "COMMON_SQUAD_SIZE", "MAX_SQUAD_SIZE", "squadSizesList", "delayedInvites"]

  COMMON_SQUAD_SIZE = 4
  MAX_SQUAD_SIZE = 4 //max available squad size to choose
  maxInvitesCount = 9
  squadSizesList = []

  cyberCafeSquadMembersNum = -1
  state = squadState.NOT_IN_SQUAD
  lastStateChangeTime = -SQUAD_REQEST_TIMEOUT
  squadData = {
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
  }
  membersNames = {}
  meReady = false
  isMyCrewsReady = false
  lastUpdateStatus = squadStatusUpdateState.NONE
  roomCreateInProgress = false
  hasNewApplication = false
  delayedInvites = []

  canStartStateChanging = @() !this.isStateInTransition()
  canJoinSquad = @() !this.isInSquad() && this.canStartStateChanging()
  canLeaveSquad = @() this.isInSquad() && this.canManageSquad()
  canManageSquad = @() hasFeature("Squad") && isInMenu()
  canChangeReceiveApplications = @(shouldCheckLeader = true) hasFeature("ClanSquads")
    && (!shouldCheckLeader || this.isSquadLeader())

  canInviteMember = @(uid = null) !this.isMe(uid)
    && this.canManageSquad()
    && (this.canJoinSquad() || this.isSquadLeader())
    && !this.isInvitedMaxPlayers()
    && (!uid || !this.getMemberData(uid))

  canDismissMember = @(uid = null) this.isSquadLeader()
    && this.canManageSquad()
    && !this.isMe(uid)
    && this.getPlayerStatusInMySquad(uid) >= squadMemberState.SQUAD_MEMBER

  canSwitchReadyness = @() ::g_squad_manager.isSquadMember() && ::g_squad_manager.canManageSquad()
    && !::checkIsInQueue()

  canChangeSquadSize = @(shouldCheckLeader = true) hasFeature("SquadSizeChange")
    && (!shouldCheckLeader || ::g_squad_manager.isSquadLeader())
    && this.squadSizesList.len() > 1

  getLeaderUid = @() this.squadData.id
  getSquadLeaderData = @() this.getMemberData(this.getLeaderUid())
  getMembers = @() this.squadData.members
  getPsnSessionId = @() this.squadData?.psnSessionId ?? ""
  getInvitedPlayers = @() this.squadData.invitedPlayers
  getPlatformInfo = @() this.squadData.platformInfo
  getApplicationsToSquad = @() this.squadData.applications
  getLeaderNick = @() !this.isInSquad() ? "" : this.getSquadLeaderData()?.name ?? ""
  getSquadRoomName = @() this.squadData.chatInfo.name
  getSquadRoomPassword = @() this.squadData.chatInfo.password
  getWwOperationId = @() this.squadData.wwOperationInfo?.id ?? -1
  getWwOperationCountry = @() this.squadData.wwOperationInfo?.country ?? ""
  getWwOperationBattle = @() this.squadData.wwOperationInfo?.battle
  getLeaderGameModeId = @() this.squadData?.leaderGameModeId ?? ""
  getLeaderBattleRating = @() this.squadData?.leaderBattleRating ?? 0
  getMaxSquadSize = @() this.squadData.properties.maxMembers
  getOfflineMembers = @() this.getMembersByOnline(false)
  getOnlineMembers = @() this.getMembersByOnline(true)
  getMemberData = @(uid) !this.isInSquad() ? null : this.squadData.members?[uid]
  getSquadMemberNameByUid = @(uid) (this.isInSquad() && uid in this.squadData.members) ?
    this.squadData.members[uid].name : ""
  getSquadRoomId = @() this.getSquadLeaderData()?.sessionRoomId ?? ""
  getPresence = @() ::g_presence_type.getByPresenceParams(this.squadData?.presence ?? {})

  function getMembersNotAllowedInWorldWar() {
    let res = []
    foreach (_uid, member in this.getMembers())
      if (!member.isWorldWarAvailable)
        res.append(member)

    return res
  }

  function getSameCyberCafeMembersNum() {
    if (this.cyberCafeSquadMembersNum >= 0)
      return this.cyberCafeSquadMembersNum

    local num = 0
    if (this.isInSquad() && this.squadData.members && ::get_cyber_cafe_level() > 0) {
      let myCyberCafeId = ::get_cyber_cafe_id()
      foreach (_uid, memberData in this.squadData.members)
        if (myCyberCafeId == memberData.cyberCafeId)
          num++
    }

    this.cyberCafeSquadMembersNum = num
    return num
  }

  function getSquadRank() {
    if (!this.isInSquad())
      return -1

    local squadRank = 0
    foreach (_uid, memberData in this.squadData.members)
      squadRank = max(memberData.rank, squadRank)

    return squadRank
  }

  function getDiffCrossPlayConditionMembers() {
    let res = []
    if (!this.isInSquad())
      return res

    let leaderCondition = this.squadData.members[this.getLeaderUid()].crossplay
    foreach (_uid, memberData in this.squadData.members)
      if (leaderCondition != memberData.crossplay)
        res.append(memberData)

    return res
  }

  function getMembersByOnline(online = true) {
    let res = []
    if (!this.isInSquad())
      return res

    foreach (_uid, memberData in this.squadData.members)
      if (memberData.online == online)
        res.append(memberData)

    return res
  }

  function getOnlineMembersCount() {
    if (!this.isInSquad())
      return 1
    local res = 0
    foreach (member in this.squadData.members)
      if (member.online)
        res++
    return res
  }

  function getSquadSize(includeInvites = false) {
    if (!this.isInSquad())
      return 0

    local res = this.squadData.members.len()
    if (includeInvites) {
      res += this.getInvitedPlayers().len()
      res += this.getApplicationsToSquad().len()
    }
    return res
  }

  function getPlayerStatusInMySquad(uid) {
    if (!this.isInSquad())
      return squadMemberState.NOT_IN_SQUAD

    let memberData = this.getMemberData(uid)
    if (memberData == null)
      return squadMemberState.NOT_IN_SQUAD

    if (this.getLeaderUid() == uid)
      return squadMemberState.SQUAD_LEADER

    if (!memberData.online)
      return squadMemberState.SQUAD_MEMBER_OFFLINE
    if (memberData.isReady)
      return squadMemberState.SQUAD_MEMBER_READY
    return squadMemberState.SQUAD_MEMBER
  }

  function setMaxSquadSize(newSize) {
    this.squadData.properties.maxMembers = newSize
  }

  function setSquadSize(newSize) {
    if (newSize == this.getMaxSquadSize())
      return

    this.setMaxSquadSize(newSize)
    this.setSquadData()
    broadcastEvent(squadEvent.SIZE_CHANGED)
  }

  function setReadyFlag(ready = null, needUpdateMemberData = true) {
    let isLeader = this.isSquadLeader()
    if (isLeader && ready != true)
      return

    let isSetNoReady = (ready == false || (ready == null && this.isMeReady() == true))
    let event = ::events.getEvent(this.getLeaderGameModeId())
    if (!isLeader && !isSetNoReady
      && (!antiCheat.showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event)))
      return

    if (::checkIsInQueue() && !isLeader && this.isInSquad() && isSetNoReady) {
      ::g_popups.add(null, loc("squad/cant_switch_off_readyness_in_queue"))
      return
    }

    if (ready == null)
      this.meReady = !this.isMeReady()
    else if (this.isMeReady() != ready)
      this.meReady = ready
    else
      return

    if (!this.meReady)
      this.isMyCrewsReady = false

    if (needUpdateMemberData)
      this.updateMyMemberDataAfterActualizeJwt()

    broadcastEvent(squadEvent.SET_READY)
  }

  function setCrewsReadyFlag(ready = null, needUpdateMemberData = true) {
    let isLeader = this.isSquadLeader()
    if (isLeader && ready != true)
      return

    if (ready == null)
      this.isMyCrewsReady = !this.isMyCrewsReady
    else if (this.isMyCrewsReady != ready)
      this.isMyCrewsReady = ready
    else
      return

    if (needUpdateMemberData)
      this.updateMyMemberData()
  }

  //It function will be use in future: Chat with password
  function setSquadData() {
    if (!this.isSquadLeader())
      return

    ::request_matching("msquad.set_squad_data", null, null, this.squadData)
  }

  function setPsnSessionId(id = null) {
    this.squadData.psnSessionId <- id
    this.setSquadData()
  }

  function setState(newState) {
    if (this.state == newState)
      return false
    this.state = newState
    this.lastStateChangeTime = get_time_msec()
    broadcastEvent(squadEvent.STATUS_CHANGED)
    return true
  }

  function setMemberOnlineStatus(uid, isOnline) {
    let memberData = this.getMemberData(uid)
    if (memberData == null)
      return

    if (memberData.online == isOnline)
      return

    memberData.online = isOnline
    if (!isOnline) {
      memberData.isReady = false
      if (this.isSquadLeader() && ::queues.isAnyQueuesActive())
        ::queues.leaveAllQueues()
    }

    ::updateContact(memberData.getData())
    broadcastEvent(squadEvent.DATA_UPDATED)
    broadcastEvent("SquadOnlineChanged")
  }

  hasApplicationInMySquad = @(uid, name = null) uid ? (uid in this.getApplicationsToSquad())
    : u.search(this.getApplicationsToSquad(), @(player) player.name == name) != null

  isSquadFull = @() this.getSquadSize() >= this.getMaxSquadSize()
  isInSquad = @(forChat = false) (forChat && !::SessionLobby.isMpSquadChatAllowed()) ? false
    : this.state == squadState.IN_SQUAD
  isMeReady = @() this.meReady
  isSquadLeader = @() this.isInSquad() && this.getLeaderUid() == userIdStr.value
  isPlayerInvited = @(uid, name = null) uid ? (uid in this.getInvitedPlayers())
    : u.search(this.getInvitedPlayers(), @(player) player.name == name) != null
  isMySquadLeader = @(uid) this.isInSquad() && uid != null && uid == this.getLeaderUid()
  isSquadMember = @() this.isInSquad() && !this.isSquadLeader()
  isMemberReady = @(uid) this.getMemberData(uid)?.isReady ?? false
  isInMySquad = @(name, checkAutosquad = true)
    (this.isInSquad() && this.isMySquadMember(name)) ? true
      : checkAutosquad && ::SessionLobby.isMemberInMySquadByName(name)

  isInMySquadById = @(userId, checkAutosquad = true)
    (this.isInSquad() && this.isMySquadMemberById(userId)) ? true
      : checkAutosquad && ::SessionLobby.isMemberInMySquadById(userId)

  isMe = @(uid) uid == userIdStr.value
  isStateInTransition = @() (this.state == squadState.JOINING || this.state == squadState.LEAVING)
    && this.lastStateChangeTime + SQUAD_REQEST_TIMEOUT > get_time_msec()
  isInvitedMaxPlayers = @() this.isSquadFull()
    || this.getInvitedPlayers().len() >= this.maxInvitesCount
  isApplicationsEnabled = @() this.squadData.properties.isApplicationsEnabled

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
    if (!this.isInSquad())
      return false

    if (this.squadData.members.len() == 1)
      return false

    foreach (uid, memberData in this.squadData.members)
      if (uid != userIdStr.value && memberData.online == true)
        return true

    return false
  }

  function updateLeaderGameModeId(newLeaderGameModeId) {
    if (this.squadData.leaderGameModeId == newLeaderGameModeId)
      return

    this.squadData.leaderGameModeId = newLeaderGameModeId
    if (this.isSquadMember()) {
      let event = ::events.getEvent(this.getLeaderGameModeId())
      if (this.isMeReady() && (!antiCheat.showMsgboxIfEacInactive(event) ||
                          !showMsgboxIfSoundModsNotAllowed(event)))
        this.setReadyFlag(false)
      this.updateMyMemberData()
    }
  }

  function updateMyMemberDataAfterActualizeJwt(myMemberData = null) {
    if (!this.isInSquad())
      return

    //no need force actualazie jwt profile data for leader or if not ready
    //on set ready status jwt profile data force actualaze
    if (!needActualizeQueueData.value || this.isSquadLeader() || !this.isMeReady()) {
      this.updateMyMemberData(myMemberData)
      return
    }

    actualizeQueueData(@(_) ::g_squad_manager.updateMyMemberData())
  }

  function updateMyMemberData(data = null) {
    if (!this.isInSquad())
      return

    let isWorldwarEnabled = ::is_worldwar_enabled()
    data = data ?? getMyStateData()
    data.__update({
      isReady = this.isMeReady()
      isCrewsReady = this.isMyCrewsReady
      canPlayWorldWar = isWorldwarEnabled
      isWorldWarAvailable = isWorldwarEnabled
      isEacInited = ::is_eac_inited()
      squadsVersion = SQUADS_VERSION
      platform = platformModule.targetPlatform
    })
    let wwOperations = []
    if (isWorldwarEnabled) {
      data.canPlayWorldWar = ::g_world_war.canPlayWorldwar()
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
    data.wwStartingBattle <- null
    data.sessionRoomId <- ::SessionLobby.canInviteIntoSession() ? ::SessionLobby.roomId : ""

    local memberData = this.getMemberData(userIdStr.value)
    if (!memberData) {
      memberData = SquadMember(userIdStr.value)
      this.squadData.members[userIdStr.value] <- memberData
    }

    memberData.update(data)
    memberData.online = true
    ::updateContact(memberData.getData())

    ::request_matching("msquad.set_member_data", null, null, { userId = userIdInt64.value, data })
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function updateLeaderData(isActualBR = true) {
    if (!this.isSquadLeader())
      return

    let currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
    if (!isActualBR && this.squadData.leaderGameModeId == currentGameModeId)
      return

    this.squadData.__update({
      leaderBattleRating = isActualBR ? battleRating.recentBR.value : 0
      leaderGameModeId = isActualBR ? battleRating.recentBrGameModeId.value : currentGameModeId
    })
  }

  function updateCurrentWWOperation() {
    if (!this.isSquadLeader() || !::is_worldwar_enabled())
      return

    let wwOperationId = wwGetOperationId()
    local country = profileCountrySq.value
    if (wwOperationId > -1)
      country = ::g_ww_global_status_actions.getOperationById(wwOperationId)?.getMyAssignCountry()
        ?? country

    this.squadData.wwOperationInfo.id = wwOperationId
    this.squadData.wwOperationInfo.country = country
  }

  function updateInvitedData(invites) {
    let newInvitedData = {}
    foreach (uidInt64 in invites) {
      if (!is_numeric(uidInt64))
        continue

      let uid = uidInt64.tostring()
      if (uid in this.squadData.invitedPlayers)
        newInvitedData[uid] <- this.squadData.invitedPlayers[uid]
      else
        newInvitedData[uid] <- SquadMember(uid, true)

      requestUsersInfo([uid])
    }

    this.squadData.invitedPlayers = newInvitedData
  }

  function updateApplications(applications) {
    let newApplicationsData = {}
    foreach (uid in applications) {
      if (uid in this.squadData.applications)
        newApplicationsData[uid] <- this.squadData.applications[uid]
      else {
        newApplicationsData[uid] <- SquadMember(uid.tostring(), false, true)
        this.hasNewApplication = true
      }
      requestUsersInfo([uid.tostring()])
    }
    if (!newApplicationsData)
      this.hasNewApplication = false
    this.squadData.applications = newApplicationsData
  }

  function updatePlatformInfo() {
    let playerPlatforms = []
    let checksArray = [this.getMembers(), this.getInvitedPlayers(), this.getApplicationsToSquad()]
    foreach (_idx, membersArray in checksArray)
      foreach (_uid, member in membersArray) {
        if (platformModule.isXBoxPlayerName(member.name))
          u.appendOnce("xboxOne", playerPlatforms)
        else if (platformModule.isPS4PlayerName(member.name))
          u.appendOnce("ps4", playerPlatforms)
        else
          u.appendOnce("pc", playerPlatforms)
      }

    this.squadData.platformInfo = playerPlatforms
  }

  function updatePresenceSquad() {
    if (!this.isSquadLeader())
      return

    let presence = ::g_presence_type.getCurrent()
    let presenceParams = presence.getParams()
    if (!u.isEqual(this.squadData.presence, presenceParams))
      this.squadData.presence = presenceParams
  }

  function canInviteMemberByPlatform(name) {
    let platformInfo = this.getPlatformInfo()
    if (!hasFeature("Ps4XboxOneInteraction")
        && ((platformModule.isPS4PlayerName(name) && isInArray("xboxOne", platformInfo))
          || (platformModule.isXBoxPlayerName(name) && isInArray("ps4", platformInfo))))
      return false

    return true
  }

  function initSquadSizes() {
    this.squadSizesList.clear()
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
      this.squadSizesList.append({
        name = name
        value = size
      })
      maxSize = max(maxSize, size)
    }

    if (!this.squadSizesList.len())
      return

    this.COMMON_SQUAD_SIZE = this.squadSizesList[0].value
    this.MAX_SQUAD_SIZE = maxSize
    this.setMaxSquadSize(this.COMMON_SQUAD_SIZE)
  }

  function enableApplications(shouldEnable) {
    if (shouldEnable == this.isApplicationsEnabled())
      return

    this.squadData.properties.isApplicationsEnabled = shouldEnable
    this.setSquadData()
  }

  function readyCheck(considerInvitedPlayers = false) {
    if (!this.isInSquad())
      return false

    foreach (_uid, memberData in this.squadData.members)
      if (memberData.online == true && memberData.isReady == false)
        return false

    if (considerInvitedPlayers && this.squadData.invitedPlayers.len() > 0)
      return false

    return  true
  }

  function crewsReadyCheck() {
    if (!this.isInSquad())
      return false

    foreach (_uid, memberData in this.squadData.members)
      if (memberData.online && !memberData.isCrewsReady)
        return false

    return  true
  }

  function createSquad(callback) {
    if (!hasFeature("Squad"))
      return

    if (!this.canJoinSquad() || !this.canManageSquad() || ::queues.isAnyQueuesActive())
      return

    this.setState(squadState.JOINING)
    ::request_matching("msquad.create_squad", @(_) ::g_squad_manager.requestSquadData(callback))
  }

  function joinSquadChatRoom() {
    if (!this.isNotAloneOnline())
      return

    if (!::gchat_is_connected())
      return

    if (::g_chat.isSquadRoomJoined())
      return

    if (this.roomCreateInProgress)
      return

    let name = this.getSquadRoomName()
    local password = this.getSquadRoomPassword()
    local callback = null

    if (u.isEmpty(name))
      return

    if (this.isSquadLeader() && u.isEmpty(password)) {
      password = ::gen_rnd_password(15)
      this.squadData.chatInfo.password = password

      this.roomCreateInProgress = true
      callback = function() {
        ::g_squad_manager.setSquadData()
        ::g_squad_manager.roomCreateInProgress = false
      }
    }

    if (u.isEmpty(password))
      return

    ::g_chat.joinSquadRoom(callback)
  }

  function disbandSquad() {
    if (!this.isSquadLeader())
      return

    this.setState(squadState.LEAVING)
    ::request_matching("msquad.disband_squad")
  }

  function checkForSquad() {
    if (!::g_login.isLoggedIn())
      return

    let callback = function(response) {
      if (response?.error_id != msquadErrorId.NOT_SQUAD_MEMBER)
        if (!::checkMatchingError(response, false))
          return

      if ("squad" in response) {
        broadcastEvent(squadEvent.DATA_RECEIVED, response?.squad)

        if (::g_squad_manager.getSquadSize(true) == 1)
          ::g_squad_manager.disbandSquad()
        else
          ::g_squad_manager.updateMyMemberData()

        broadcastEvent(squadEvent.STATUS_CHANGED)
      }

      let invites = response?.invites
      if (invites != null)
        foreach (squadId in invites)
          ::g_invites.addInviteToSquad(squadId, squadId.tostring())

      squadApplications.updateApplicationsList(response?.applications ?? [])
    }

    requestSquadInfo(callback, callback, { showError = false })
  }

  function requestSquadData(callback = null) {
    let fullCallback =  function(response) {
      if ("squad" in response) {
        broadcastEvent(squadEvent.DATA_RECEIVED, response?.squad)

        if (::g_squad_manager.getSquadSize(true) == 1)
          ::g_squad_manager.disbandSquad()
      }
      else if (::g_squad_manager.isInSquad())
        ::g_squad_manager.reset()

      if (callback != null)
        callback()
    }

    requestSquadInfo(fullCallback)
  }

  function leaveSquad(cb = null) {
    if (!this.isInSquad())
      return

    this.setState(squadState.LEAVING)
    leaveSquadImpl(
      function(_response) {
        ::g_squad_manager.reset()
        if (cb)
          cb()
      })
  }

  function joinToSquad(uid) {
    if (!this.canJoinSquad())
      return

    this.setState(squadState.JOINING)
    ::request_matching("msquad.join_player",
      @(_response) ::g_squad_manager.requestSquadData(),
      function(_response) {
        ::g_squad_manager.setState(squadState.NOT_IN_SQUAD)
        ::g_squad_manager.rejectSquadInvite(uid)
      },
      { userId = convertIdToInt(uid) })
  }

  function inviteToSquad(uid, name = null) {
    if (this.isInSquad() && !this.isSquadLeader())
      return

    if (this.isSquadFull())
      return ::g_popups.add(null, loc("matching/SQUAD_FULL"))

    if (this.isInvitedMaxPlayers())
      return ::g_popups.add(null, loc("squad/maximum_intitations_sent"))

    if (!this.canInviteMemberByPlatform(name))
      return ::g_popups.add(null, loc("msg/squad/noPlayersForDiffConsoles"))

    local isInvitingPsnPlayer = false
    if (platformModule.isPS4PlayerName(name)) {
      let contact = ::getContact(uid, name)
      isInvitingPsnPlayer = true
      if (u.isEmpty(::g_squad_manager.getPsnSessionId()))
        contact.updatePSNIdAndDo(function() {
          ::g_squad_manager.delayedInvites.append(contact.psnId)
        })
    }

    let callback = function(_response) {
      if (isInvitingPsnPlayer && u.isEmpty(::g_squad_manager.delayedInvites)) {
        let contact = ::getContact(uid, name)
        contact.updatePSNIdAndDo(function() {
          invite(::g_squad_manager.getPsnSessionId(), contact.psnId)
        })
      }

      sendSystemInvite(uid, name)
      ::g_squad_manager.requestSquadData()
    }

    ::request_matching("msquad.invite_player", callback, null, { userId = convertIdToInt(uid) })
  }

  function processDelayedInvitations() {
    if (u.isEmpty(this.getPsnSessionId()) || u.isEmpty(this.delayedInvites))
      return

    foreach (invitee in this.delayedInvites)
      invite(this.getPsnSessionId(), invitee)
    this.delayedInvites.clear()
  }

  function revokeAllInvites(callback) {
    if (!this.isSquadLeader())
      return

    local fullCallback = null
    if (callback != null) {
      let counterTbl = { invitesLeft = ::g_squad_manager.getInvitedPlayers().len() }
      fullCallback = function() {
        if (!--counterTbl.invitesLeft)
          callback()
      }
    }

    foreach (uid, _memberData in this.getInvitedPlayers())
      this.revokeSquadInvite(uid, fullCallback)
  }

  function revokeSquadInvite(uid, callback = null) {
    if (!this.isSquadLeader())
      return

    let fullCallback = @(_response) ::g_squad_manager.requestSquadData(@() callback?())
    ::request_matching("msquad.revoke_invite", fullCallback, null, { userId = convertIdToInt(uid) })
  }

  function membershipAplication(sid) {
    let callback = Callback(@(_response) squadApplications.addApplication(sid, sid), this)
    let cb = function() {
      ::request_matching("msquad.request_membership",
        callback,
        null, { squadId = sid }, null)
    }
    let canJoin = ::g_squad_utils.canJoinFlightMsgBox(
      { allowWhenAlone = false, msgId = "squad/leave_squad_for_application" },
      cb)

    if (canJoin)
      cb()
  }

  function revokeMembershipAplication(sid) {
    squadApplications.deleteApplication(sid)
    ::request_matching("msquad.revoke_membership_request", null, null, { squadId = sid }, null)
  }

  function acceptMembershipAplication(uid) {
    if (this.isInSquad() && !this.isSquadLeader())
      return

    if (this.isSquadFull())
      return ::g_popups.add(null, loc("matching/SQUAD_FULL"))

    let callback = Callback(@(_response) this.addMember(uid.tostring()), this)
    ::request_matching("msquad.accept_membership", callback, null, { userId = uid }, null)
  }

  function denyAllAplication() {
    if (!this.isSquadLeader())
      return

    ::request_matching("msquad.deny_all_membership_requests", null, null, null, null)
  }

  function denyMembershipAplication(uid, callback = null) {
    if (this.isInSquad() && !this.isSquadLeader())
      return

    ::request_matching("msquad.deny_membership", callback, null, { userId = uid }, null)
  }

  function dismissFromSquad(uid) {
    if (!this.isSquadLeader())
      return

    if (this.squadData.members?[uid])
      ::request_matching("msquad.dismiss_member", null, null, { userId = convertIdToInt(uid) })
  }

  function dismissFromSquadByName(name) {
    if (!this.isSquadLeader())
      return

    let memberData = this._getSquadMemberByName(name)
    if (memberData == null)
      return

    if (this.canDismissMember(memberData.uid))
      this.dismissFromSquad(memberData.uid)
  }

  function _getSquadMemberByName(name) {
    if (!this.isInSquad())
      return null

    foreach (_uid, memberData in this.squadData.members)
      if (memberData.name == name || memberData.name == getRealName(name))
        return memberData

    return null
  }

  isMySquadMember = @(name) (this.membersNames?[name] != null) || (this.membersNames?[getRealName(name)] != null)
  isMySquadMemberById = @(id) this.squadData.members?[id] != null


  function canTransferLeadership(uid) {
    if (!hasFeature("SquadTransferLeadership"))
      return false

    if (!this.canManageSquad())
      return false

    if (u.isEmpty(uid))
      return false

    if (uid == userIdStr.value)
      return false

    if (!this.isSquadLeader())
      return false

    let memberData = this.getMemberData(uid)
    if (memberData == null || memberData.isInvite)
      return false

    return memberData.online
  }

  function transferLeadership(uid) {
    if (!this.canTransferLeadership(uid))
      return

    ::request_matching("msquad.transfer_squad", null, null, { userId = convertIdToInt(uid) })
    broadcastEvent(squadEvent.LEADERSHIP_TRANSFER, { uid = uid })
  }

  function onLeadershipTransfered() {
    ::g_squad_manager.setReadyFlag(::g_squad_manager.isSquadLeader())
    ::g_squad_manager.setCrewsReadyFlag(::g_squad_manager.isSquadLeader())
    broadcastEvent(squadEvent.STATUS_CHANGED)
  }

  function acceptSquadInvite(sid) {
    if (!this.canJoinSquad())
      return

    this.setState(squadState.JOINING)
    ::request_matching("msquad.accept_invite",
      function(_response) {
        this.requestSquadData()
      }.bindenv(this),
      function(_response) {
        this.setState(squadState.NOT_IN_SQUAD)
        this.rejectSquadInvite(sid)
      }.bindenv(this),
      { squadId = convertIdToInt(sid) }
    )
  }

  function rejectSquadInvite(sid) {
    ::request_matching("msquad.reject_invite", null, null, { squadId = convertIdToInt(sid) })
  }

  function requestMemberData(uid) {
    let memberData = ::g_squad_manager.squadData.members?[uid]
    if (memberData) {
      memberData.isWaiting = true
      broadcastEvent(squadEvent.DATA_UPDATED)
    }

    let callback = @(response) ::g_squad_manager.requestMemberDataCallback(uid, response)
    ::request_matching("msquad.get_member_data", callback, null, { userId = convertIdToInt(uid) })
  }

  function requestMemberDataCallback(uid, response) {
    let receivedData = response?.data
    if (receivedData == null)
      return

    let memberData = ::g_squad_manager.getMemberData(uid)
    if (memberData == null)
      return

    let currentMemberData = memberData.getData()
    let receivedMemberData = receivedData?.data
    let isMemberDataChanged = memberData.update(receivedMemberData)
    let isMemberVehicleDataChanged = isMemberDataChanged
      && ::g_squad_manager.isMemberDataVehicleChanged(currentMemberData, memberData)
    let contact = ::getContact(memberData.uid, memberData.name)
    contact.online = response.online
    memberData.online = response.online
    if (!response.online)
      memberData.isReady = false

    ::update_contacts_by_list([memberData.getData()])

    if (::g_squad_manager.isSquadLeader()) {
      if (!::g_squad_manager.readyCheck())
        ::queues.leaveAllQueues()

      if (::SessionLobby.canInviteIntoSession() && memberData.canJoinSessionRoom())
        ::SessionLobby.invitePlayer(memberData.uid)
    }

    ::g_squad_manager.joinSquadChatRoom()

    broadcastEvent(squadEvent.DATA_UPDATED)
    if (isMemberVehicleDataChanged)
      broadcastEvent("SquadMemberVehiclesChanged")

    let memberSquadsVersion = receivedMemberData?.squadsVersion ?? DEFAULT_SQUADS_VERSION
    ::g_squad_utils.checkSquadsVersion(memberSquadsVersion)
  }

  function reset() {
    if (this.state == squadState.IN_SQUAD)
      this.setState(squadState.LEAVING)

    ::queues.leaveAllQueues()
    ::g_chat.leaveSquadRoom()

    this.cyberCafeSquadMembersNum = -1

    this.squadData.id = ""
    let contactsUpdatedList = []
    foreach (_id, memberData in this.squadData.members)
      contactsUpdatedList.append(memberData.getData())

    this.squadData.members.clear()
    this.squadData.invitedPlayers.clear()
    this.squadData.applications.clear()
    this.squadData.platformInfo.clear()
    this.squadData.chatInfo.__update(DEFAULT_SQUAD_CHAT_INFO)
    this.squadData.wwOperationInfo.__update(DEFAULT_SQUAD_WW_OPERATION_INFO)
    this.squadData.properties.__update(DEFAULT_SQUAD_PROPERTIES)
    this.squadData.presence.__update(DEFAULT_SQUAD_PRESENCE)
    this.squadData.psnSessionId = ""
    this.squadData.leaderBattleRating = 0
    this.squadData.leaderGameModeId = ""
    this.setMaxSquadSize(this.COMMON_SQUAD_SIZE)

    this.lastUpdateStatus = squadStatusUpdateState.NONE
    if (this.meReady)
      this.setReadyFlag(false, false)

    ::update_contacts_by_list(contactsUpdatedList)

    this.setState(squadState.NOT_IN_SQUAD)
    broadcastEvent(squadEvent.DATA_UPDATED)
    broadcastEvent(squadEvent.INVITES_CHANGED)
  }

  function addInvitedPlayers(uid) {
    if (uid in this.squadData.invitedPlayers)
      return

    this.squadData.invitedPlayers[uid] <- SquadMember(uid, true)

    requestUsersInfo([uid])

    broadcastEvent(squadEvent.PLAYER_INVITED, { uid = uid })
    broadcastEvent(squadEvent.INVITES_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function removeInvitedPlayers(uid) {
    if (!(uid in this.squadData.invitedPlayers))
      return

    this.squadData.invitedPlayers.rawdelete(uid)
    broadcastEvent(squadEvent.INVITES_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function addApplication(uid) {
    if (uid in this.squadData.applications)
      return

    this.squadData.applications[uid] <- SquadMember(uid.tostring(), false, true)
    requestUsersInfo([uid.tostring()])
    this.checkNewApplications()
    if (this.isSquadLeader())
      ::g_popups.add(null, colorize("chatTextInviteColor",
        format(loc("squad/player_application"),
          getPlayerName(this.squadData.applications[uid]?.name ?? ""))))

    broadcastEvent(squadEvent.APPLICATIONS_CHANGED, { uid = uid })
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function removeApplication(applications) {
    if (!u.isArray(applications))
      applications = [applications]
    local isApplicationsChanged = false
    foreach (uid in applications) {
      if (!(uid in this.squadData.applications))
        continue
      this.squadData.applications.rawdelete(uid)
      isApplicationsChanged = true
    }

    if (!isApplicationsChanged)
      return

    if (this.getSquadSize(true) == 1)
      ::g_squad_manager.disbandSquad()
    this.checkNewApplications()
    broadcastEvent(squadEvent.APPLICATIONS_CHANGED, {})
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function markAllApplicationsSeen() {
    foreach (application in this.squadData.applications)
      application.isNewApplication = false
    this.checkNewApplications()
  }

  function checkNewApplications() {
    let curHasNewApplication = this.hasNewApplication
    this.hasNewApplication = false
    foreach (application in this.squadData.applications)
      if (application.isNewApplication == true) {
        this.hasNewApplication = true
        break
      }
    if (curHasNewApplication != this.hasNewApplication)
      broadcastEvent(squadEvent.NEW_APPLICATIONS)
  }

  function addMember(uid) {
    this.removeInvitedPlayers(uid)
    let memberData = SquadMember(uid)
    this.squadData.members[uid] <- memberData
    this.removeApplication(uid.tointeger())
    this.requestMemberData(uid)

    broadcastEvent(squadEvent.STATUS_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function removeMember(uid) {
    let memberData = this.getMemberData(uid)
    if (memberData == null)
      return

    this.squadData.members.rawdelete(memberData.uid)
    ::update_contacts_by_list([memberData.getData()])

    broadcastEvent(squadEvent.STATUS_CHANGED)
    broadcastEvent(squadEvent.DATA_UPDATED)
  }

  function onEventSquadDataReceived(resSquadData) {
    let alreadyInSquad = this.isInSquad()

    let newSquadId = resSquadData?.id
    if (is_numeric(newSquadId)) //bad squad data
      this.squadData.id = newSquadId.tostring() //!!FIX ME: why this convertion to string?
    else if (!alreadyInSquad) {
      script_net_assert_once("no squad id", "Error: received squad data without squad id")
      leaveSquadImpl() //leave broken squad
      this.setState(squadState.NOT_IN_SQUAD)
      return
    }

    let resMembers = resSquadData?.members ?? []
    let newMembersData = {}
    this.membersNames.clear()
    foreach (uidInt64 in resMembers) {
      if (!is_numeric(uidInt64))
        continue

      let uid = uidInt64.tostring()
      if (uid in this.squadData.members)
        newMembersData[uid] <- this.squadData.members[uid]
      else
        newMembersData[uid] <- SquadMember(uid)

      this.membersNames[newMembersData[uid].name] <- uid
      if (uid != userIdStr.value)
        this.requestMemberData(uid)
    }
    this.squadData.members = newMembersData

    this.updateInvitedData(resSquadData?.invites ?? [])

    this.updateApplications(resSquadData?.applications ?? [])

    this.updatePlatformInfo()

    this.cyberCafeSquadMembersNum = this.getSameCyberCafeMembersNum()
    this._parseCustomSquadData(resSquadData?.data)
    let chatInfo = resSquadData?.chat
    if (chatInfo != null) {
      let chatName = chatInfo?.id ?? ""
      if (!u.isEmpty(chatName))
        this.squadData.chatInfo.name = chatName
    }

    if (this.setState(squadState.IN_SQUAD)) {
      this.updateMyMemberData()
      if (this.isSquadLeader()) {
      // !!!FIX Looks like some kind of hack to baypass checks on leadership in update functions below.
      // Actually all updates below needs to do once on invite in squad.
      // Otherwithe here we additional reload already received data just because of
      // inviter was not formally the leader when invite been sent.
        this.updateCurrentWWOperation()
        this.updatePresenceSquad()
        this.updateLeaderData()
        this.setSquadData()
        return
      }
      if (this.getPresence().isInBattle)
        ::g_popups.add(loc("squad/name"), loc("squad/wait_until_battle_end"))
    }

    this.joinSquadChatRoom()

    if (this.isSquadLeader() && !this.readyCheck())
      ::queues.leaveAllQueues()

    if (!alreadyInSquad)
      this.checkUpdateStatus(squadStatusUpdateState.MENU)

    this.updateLeaderGameModeId(resSquadData?.data.leaderGameModeId ?? "")
    this.squadData.leaderBattleRating = resSquadData?.data?.leaderBattleRating ?? 0

    broadcastEvent(squadEvent.DATA_UPDATED)

    let lastReadyness = this.isMeReady()
    let currentReadyness = lastReadyness || this.isSquadLeader()
    if (lastReadyness != currentReadyness || !alreadyInSquad)
      this.setReadyFlag(currentReadyness)

    let lastCrewsReadyness = this.isMyCrewsReady
    let currentCrewsReadyness = lastCrewsReadyness || this.isSquadLeader()
    if (lastCrewsReadyness != currentCrewsReadyness || !alreadyInSquad)
      this.setCrewsReadyFlag(currentCrewsReadyness)
  }

  function _parseCustomSquadData(data) {
    this.squadData.chatInfo.__update(data?.chatInfo ?? DEFAULT_SQUAD_CHAT_INFO)

    let properties = data?.properties
    local isPropertyChange = false
    if (!properties) {
      this.squadData.properties.__update(DEFAULT_SQUAD_PROPERTIES)
      isPropertyChange = true
    }
    if (u.isTable(properties))
      foreach (key, value in properties) {
        if (u.isEqual(this.squadData?.properties?[key], value))
          continue

        this.squadData.properties[key] <- value
        isPropertyChange = true
      }
    if (isPropertyChange)
      broadcastEvent(squadEvent.PROPERTIES_CHANGED)
    this.squadData.presence = data?.presence ?? clone DEFAULT_SQUAD_PRESENCE
    this.squadData.psnSessionId = data?.psnSessionId ?? ""
  }

  function checkMembersPkg(pack) { //return list of members dont have this pack
    let res = []
    if (!this.isInSquad())
      return res

    foreach (uid, memberData in this.squadData.members)
      if (memberData.missedPkg != null && isInArray(pack, memberData.missedPkg))
        res.append({ uid = uid, name = memberData.name })

    return res
  }

  function getSquadMembersDataForContact() {
    let contactsData = []

    if (this.isInSquad()) {
      foreach (uid, memberData in this.squadData.members)
        if (uid != userIdStr.value)
          contactsData.append(memberData.getData())
    }

    return contactsData
  }

  function checkUpdateStatus(newStatus) {
    if (this.lastUpdateStatus == newStatus || !this.isInSquad())
      return

    this.lastUpdateStatus = newStatus
    ::g_squad_utils.updateMyCountryData()
  }

  function startWWBattlePrepare(battleId = null) {
    if (!this.isSquadLeader())
      return

    if (this.getWwOperationBattle() == battleId)
      return

    this.squadData.wwOperationInfo.battle <- battleId
    this.squadData.wwOperationInfo.id = wwGetOperationId()
    this.squadData.wwOperationInfo.country = profileCountrySq.value

    this.updatePresenceSquad()
    this.setSquadData()
  }

  function cancelWwBattlePrepare() {
    this.startWWBattlePrepare() // cancel battle prepare if no args
    ::request_matching("msquad.send_event", null, null, { eventName = "CancelBattlePrepare" })
  }

  onEventPresetsByGroupsChanged = @(_params) this.updateMyMemberData()
  onEventBeforeProfileInvalidation = @(_p) this.reset()
  onEventUpdateEsFromHost = @(_p) this.checkUpdateStatus(squadStatusUpdateState.BATTLE)
  onEventNewSceneLoaded = @(_p) isInMenu()
    ? this.checkUpdateStatus(squadStatusUpdateState.MENU) : null
  onEventBattleEnded = @(_p) isInMenu()
    ? this.checkUpdateStatus(squadStatusUpdateState.MENU) : null
  onEventSessionDestroyed = @(_p) isInMenu()
    ? this.checkUpdateStatus(squadStatusUpdateState.MENU) : null
  onEventChatConnected = @(_params) this.joinSquadChatRoom()
  onEventAvatarChanged = @(_p) this.updateMyMemberData()
  onEventCrewTakeUnit = @(_p) this.updateMyMemberData()
  onEventUnitRepaired = @(_p) ::g_squad_utils.updateMyCountryData()
  onEventCrossPlayOptionChanged = @(_p) this.updateMyMemberData()
  onEventMatchingDisconnect = @(_p) this.reset()

  function onEventContactsUpdated(_params) {
    local isChanged = false
    local contact = null
    foreach (uid, memberData in this.getInvitedPlayers()) {
      contact = ::getContact(uid)
      if (contact == null)
        continue

      memberData.update(contact)
      isChanged = true
    }

    if (isChanged)
      broadcastEvent(squadEvent.INVITES_CHANGED)

    isChanged = false
    foreach (uid, memberData in this.getApplicationsToSquad()) {
      contact = ::getContact(uid.tostring())
      if (contact == null)
        continue

      if (memberData.update(contact))
        isChanged = true
    }
    if (isChanged)
      broadcastEvent(squadEvent.APPLICATIONS_CHANGED {})
  }

  function onEventMatchingConnect(_params) {
    this.reset()
    this.checkForSquad()
  }

  function onEventLoginComplete(_params) {
    this.initSquadSizes()
    this.reset()
    this.checkForSquad()
  }

  function onEventLoadingStateChange(_params) {
    if (isInFlight())
      this.setReadyFlag(false)

    this.updatePresenceSquad()
    this.setSquadData()
  }

  function onEventLobbyStatusChange(_params) {
    if (!isInSessionRoom.get())
      this.setReadyFlag(false)

    this.updateMyMemberData()
    this.updatePresenceSquad()
    this.setSquadData()
  }

  function onEventQueueChangeState(_params) {
    if (!::queues.hasActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE))
      this.setCrewsReadyFlag(false)

    this.updatePresenceSquad()
    this.setSquadData()
  }

  function onEventBattleRatingChanged(_params) {
    this.updateLeaderData()
    this.setSquadData()
  }

  function onEventCurrentGameModeIdChanged(_params) {
    this.updateLeaderData(false)
    this.setSquadData()
  }

  function onEventEventsDataUpdated(_params) {
    this.updateLeaderData(false)
    this.setSquadData()
  }
}

::cross_call_api.squad_manger <- ::g_squad_manager

registerPersistentDataFromRoot("g_squad_manager")

subscribe_handler(::g_squad_manager, ::g_listener_priority.DEFAULT_HANDLER)
