from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
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
let { isQueueDataActual, actualizeQueueData } = require("%scripts/queue/queueBattleData.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

enum squadEvent {
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

::g_squad_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["squadData", "meReady", "isMyCrewsReady", "lastUpdateStatus", "state",
   "COMMON_SQUAD_SIZE", "MAX_SQUAD_SIZE", "squadSizesList", "delayedInvites"]

  COMMON_SQUAD_SIZE = 4
  MAX_SQUAD_SIZE = 4 //max available squad size to choose
  maxInvitesCount = 9
  squadSizesList = []

  cyberCafeSquadMembersNum = -1
  state = squadState.NOT_IN_SQUAD
  lastStateChangeTime = - SQUAD_REQEST_TIMEOUT
  squadData = {
    id = ""
    members = {}
    invitedPlayers = {}
    applications = {}
    platformInfo = []
    chatInfo = {
      name = ""
      password = ""
    }
    wwOperationInfo = {
      id = -1
      country = ""
      battle = null
    }
    properties = clone DEFAULT_SQUAD_PROPERTIES
    presence = clone DEFAULT_SQUAD_PRESENCE
    psnSessionId = ""
    leaderBattleRating = 0
    leaderGameModeId = ""
  }

  meReady = false
  isMyCrewsReady = false
  lastUpdateStatus = squadStatusUpdateState.NONE
  roomCreateInProgress = false
  hasNewApplication = false
  delayedInvites = []

  getLeaderGameModeId = @() this.squadData?.leaderGameModeId ?? ""
  getLeaderBattleRating = @() this.squadData?.leaderBattleRating ?? 0

  function updateLeaderGameModeId(newLeaderGameModeId) {
    if (this.squadData.leaderGameModeId == newLeaderGameModeId)
      return

    this.squadData.leaderGameModeId = newLeaderGameModeId
    if (this.isSquadMember())
    {
      let event = ::events.getEvent(this.getLeaderGameModeId())
      if (this.isMeReady() && (!antiCheat.showMsgboxIfEacInactive(event) ||
                          !showMsgboxIfSoundModsNotAllowed(event)))
        this.setReadyFlag(false)
      this.updateMyMemberData(getMyStateData())
    }
  }

  onEventPresetsByGroupsChanged = @(_params) this.updateMyMemberData()
  onEventBeforeProfileInvalidation = @(_p) this.reset()
}

::g_squad_manager.setState <- function setState(newState)
{
  if (this.state == newState)
    return false
  this.state = newState
  this.lastStateChangeTime = get_time_msec()
  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  return true
}

::g_squad_manager.isStateInTransition <- function isStateInTransition()
{
  return (this.state == squadState.JOINING || this.state == squadState.LEAVING)
    && this.lastStateChangeTime + SQUAD_REQEST_TIMEOUT > get_time_msec()
}

::g_squad_manager.canStartStateChanging <- function canStartStateChanging()
{
  return !this.isStateInTransition()
}

::g_squad_manager.canJoinSquad <- function canJoinSquad()
{
  return !this.isInSquad() && this.canStartStateChanging()
}

::g_squad_manager.updateMyMemberData <- function updateMyMemberData(data = null)
{
  if (!this.isInSquad())
    return

  if (data == null)
    data = getMyStateData()

  let isWorldwarEnabled = ::is_worldwar_enabled()
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
    foreach (wwOperation in ::g_ww_global_status_type.ACTIVE_OPERATIONS.getShortStatusList())
    {
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

  local memberData = this.getMemberData(::my_user_id_str)
  if (!memberData)
  {
    memberData = SquadMember(::my_user_id_str)
    this.squadData.members[::my_user_id_str] <- memberData
  }

  memberData.update(data)
  memberData.online = true
  ::updateContact(memberData.getData())

  ::msquad.setMyMemberData(::my_user_id_str, data)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

::g_squad_manager.isInSquad <- function isInSquad(forChat = false)
{
  if (forChat && !::SessionLobby.isMpSquadChatAllowed())
    return false

  return this.state == squadState.IN_SQUAD
}

::g_squad_manager.isMeReady <- function isMeReady()
{
  return this.meReady
}

::g_squad_manager.getLeaderUid <- function getLeaderUid()
{
  return this.squadData.id
}

::g_squad_manager.isSquadLeader <- function isSquadLeader()
{
  return this.isInSquad() && this.getLeaderUid() == ::my_user_id_str
}

::g_squad_manager.getSquadLeaderData <- function getSquadLeaderData()
{
  return this.getMemberData(this.getLeaderUid())
}

::g_squad_manager.getMembers <- function getMembers()
{
  return this.squadData.members
}

::g_squad_manager.setPsnSessionId <- function setPsnSessionId(id = null)
{
  this.squadData.psnSessionId <- id
  this.updateSquadData()
}

::g_squad_manager.getPsnSessionId <- function getPsnSessionId()
{
  return this.squadData?.psnSessionId ?? ""
}

::g_squad_manager.getInvitedPlayers <- function getInvitedPlayers()
{
  return this.squadData.invitedPlayers
}

::g_squad_manager.getPlatformInfo <- function getPlatformInfo()
{
  return this.squadData.platformInfo
}

::g_squad_manager.isPlayerInvited <- function isPlayerInvited(uid, name = null)
{
  if (uid)
    return uid in this.getInvitedPlayers()

  return ::u.search(this.getInvitedPlayers(), @(player) player.name == name) != null
}

::g_squad_manager.getApplicationsToSquad <- function getApplicationsToSquad()
{
  return this.squadData.applications
}

::g_squad_manager.hasApplicationInMySquad <- function hasApplicationInMySquad(uid, name = null)
{
  if (uid)
    return uid in this.getApplicationsToSquad()

  return ::u.search(this.getApplicationsToSquad(), @(player) player.name == name) != null
}

::g_squad_manager.getLeaderNick <- function getLeaderNick()
{
  if (!this.isInSquad())
    return ""

  let leaderData = this.getSquadLeaderData()
  if (leaderData == null)
    return ""

  return leaderData.name
}

::g_squad_manager.getSquadRoomName <- function getSquadRoomName()
{
  return this.squadData.chatInfo.name
}

::g_squad_manager.getSquadRoomPassword <- function getSquadRoomPassword()
{
  return this.squadData.chatInfo.password
}

::g_squad_manager.getWwOperationId <- function getWwOperationId()
{
  return getTblValue("id", this.squadData.wwOperationInfo, -1)
}

::g_squad_manager.getWwOperationCountry <- function getWwOperationCountry()
{
  return getTblValue("country", this.squadData.wwOperationInfo, "")
}

::g_squad_manager.getWwOperationBattle <- function getWwOperationBattle()
{
  return getTblValue("battle", this.squadData.wwOperationInfo)
}

::g_squad_manager.isNotAloneOnline <- function isNotAloneOnline()
{
  if (!this.isInSquad())
    return false

  if (this.squadData.members.len() == 1)
    return false

  foreach(uid, memberData in this.squadData.members)
    if (uid != ::my_user_id_str && memberData.online == true)
      return true

  return false
}

::g_squad_manager.isMySquadLeader <- function isMySquadLeader(uid)
{
  return this.isInSquad() && uid != null && uid == this.getLeaderUid()
}

::g_squad_manager.isSquadMember <- function isSquadMember()
{
  return this.isInSquad() && !this.isSquadLeader()
}

::g_squad_manager.isMemberReady <- function isMemberReady(uid)
{
  let memberData = this.getMemberData(uid)
  return memberData ? memberData.isReady : false
}

::g_squad_manager.isInMySquad <- function isInMySquad(name, checkAutosquad = true)
{
  if (this.isInSquad() && this._getSquadMemberByName(name) != null)
    return true
  return checkAutosquad && ::SessionLobby.isMemberInMySquadByName(name)
}

::g_squad_manager.isMe <- function isMe(uid)
{
  return uid == ::my_user_id_str
}

::g_squad_manager.canInviteMember <- function canInviteMember(uid = null)
{
  return !this.isMe(uid)
    && this.canManageSquad()
    && (this.canJoinSquad() || this.isSquadLeader())
    && !this.isInvitedMaxPlayers()
    && (!uid || !this.getMemberData(uid))
}

::g_squad_manager.canDismissMember <- function canDismissMember(uid = null)
{
  return this.isSquadLeader()
         && this.canManageSquad()
         && !this.isMe(uid)
         && this.getPlayerStatusInMySquad(uid) >= squadMemberState.SQUAD_MEMBER
}

::g_squad_manager.canSwitchReadyness <- function canSwitchReadyness()
{
  return ::g_squad_manager.isSquadMember() && ::g_squad_manager.canManageSquad() && !::checkIsInQueue()
}

::g_squad_manager.canLeaveSquad <- function canLeaveSquad()
{
  return this.isInSquad() && this.canManageSquad()
}

::g_squad_manager.canManageSquad <- function canManageSquad()
{
  return hasFeature("Squad") && ::isInMenu()
}

::g_squad_manager.canInviteMemberByPlatform <- function canInviteMemberByPlatform(name)
{
  let platformInfo = this.getPlatformInfo()
  if (!hasFeature("Ps4XboxOneInteraction")
      && ((platformModule.isPS4PlayerName(name) && isInArray("xboxOne", platformInfo))
         || (platformModule.isXBoxPlayerName(name) && isInArray("ps4", platformInfo))))
    return false

  return true
}

::g_squad_manager.getMaxSquadSize <- function getMaxSquadSize()
{
  return this.squadData.properties.maxMembers
}

::g_squad_manager.setMaxSquadSize <- function setMaxSquadSize(newSize)
{
  this.squadData.properties.maxMembers = newSize
}

::g_squad_manager.getSquadSize <- function getSquadSize(includeInvites = false)
{
  if (!this.isInSquad())
    return 0

  local res = this.squadData.members.len()
  if (includeInvites)
  {
    res += this.getInvitedPlayers().len()
    res += this.getApplicationsToSquad().len()
  }
  return res
}

::g_squad_manager.isSquadFull <- function isSquadFull()
{
  return this.getSquadSize() >= this.getMaxSquadSize()
}

::g_squad_manager.canChangeSquadSize <- function canChangeSquadSize(shouldCheckLeader = true)
{
  return hasFeature("SquadSizeChange")
         && (!shouldCheckLeader || ::g_squad_manager.isSquadLeader())
         && this.squadSizesList.len() > 1
}

::g_squad_manager.setSquadSize <- function setSquadSize(newSize)
{
  if (newSize == this.getMaxSquadSize())
    return

  this.setMaxSquadSize(newSize)
  this.updateSquadData()
  ::broadcastEvent(squadEvent.SIZE_CHANGED)
}

::g_squad_manager.initSquadSizes <- function initSquadSizes()
{
  this.squadSizesList.clear()
  let sizesBlk = ::get_game_settings_blk()?.squad?.sizes
  if (!::u.isDataBlock(sizesBlk))
    return

  local maxSize = 0
  for (local i = 0; i < sizesBlk.paramCount(); i++)
  {
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

::g_squad_manager.isInvitedMaxPlayers <- function isInvitedMaxPlayers()
{
  return this.isSquadFull() || this.getInvitedPlayers().len() >= this.maxInvitesCount
}

::g_squad_manager.isApplicationsEnabled <- function isApplicationsEnabled()
{
  return this.squadData.properties.isApplicationsEnabled
}

::g_squad_manager.enableApplications <- function enableApplications(shouldEnable)
{
  if (shouldEnable == this.isApplicationsEnabled())
    return

  this.squadData.properties.isApplicationsEnabled = shouldEnable

  this.updateSquadData()
}

::g_squad_manager.canChangeReceiveApplications <- function canChangeReceiveApplications(shouldCheckLeader = true)
{
  return hasFeature("ClanSquads") && (!shouldCheckLeader || this.isSquadLeader())
}

::g_squad_manager.getPlayerStatusInMySquad <- function getPlayerStatusInMySquad(uid)
{
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

::g_squad_manager.readyCheck <- function readyCheck(considerInvitedPlayers = false)
{
  if (!this.isInSquad())
    return false

  foreach(_uid, memberData in this.squadData.members)
    if (memberData.online == true && memberData.isReady == false)
      return false

  if (considerInvitedPlayers && this.squadData.invitedPlayers.len() > 0)
    return false

  return  true
}

::g_squad_manager.crewsReadyCheck <- function crewsReadyCheck()
{
  if (!this.isInSquad())
    return false

  foreach(_uid, memberData in this.squadData.members)
    if (memberData.online && !memberData.isCrewsReady)
      return false

  return  true
}

::g_squad_manager.getDiffCrossPlayConditionMembers <- function getDiffCrossPlayConditionMembers()
{
  let res = []
  if (!this.isInSquad())
    return res

  let leaderCondition = this.squadData.members[this.getLeaderUid()].crossplay
  foreach (_uid, memberData in this.squadData.members)
    if (leaderCondition != memberData.crossplay)
      res.append(memberData)

  return res
}

::g_squad_manager.getOfflineMembers <- function getOfflineMembers()
{
  return this.getMembersByOnline(false)
}

::g_squad_manager.getOnlineMembers <- function getOnlineMembers()
{
  return this.getMembersByOnline(true)
}

::g_squad_manager.getMembersByOnline <- function getMembersByOnline(online = true)
{
  let res = []
  if (!this.isInSquad())
    return res

  foreach(_uid, memberData in this.squadData.members)
    if (memberData.online == online)
      res.append(memberData)

  return res
}

::g_squad_manager.getOnlineMembersCount <- function getOnlineMembersCount()
{
  if (!this.isInSquad())
    return 1
  local res = 0
  foreach(member in this.squadData.members)
    if (member.online)
      res++
  return res
}

::g_squad_manager.setReadyFlag <- function setReadyFlag(ready = null, needUpdateMemberData = true)
{
  let isLeader = this.isSquadLeader()
  if (isLeader && ready != true)
    return

  let isSetNoReady = (ready == false || (ready == null && this.isMeReady() == true))
  let event = ::events.getEvent(this.getLeaderGameModeId())
  if (!isLeader && !isSetNoReady
    && (!antiCheat.showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event)))
    return

  if (::checkIsInQueue() && !isLeader && this.isInSquad() && isSetNoReady)
  {
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

  if (needUpdateMemberData) {
    if (isQueueDataActual.value)
      this.updateMyMemberData()
    else
      actualizeQueueData(@(_) ::g_squad_manager.updateMyMemberData())
  }

  ::broadcastEvent(squadEvent.SET_READY)
}

::g_squad_manager.setCrewsReadyFlag <- function setCrewsReadyFlag(ready = null, needUpdateMemberData = true)
{
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
    this.updateMyMemberData(getMyStateData())
}

::g_squad_manager.createSquad <- function createSquad(callback)
{
  if (!hasFeature("Squad"))
    return

  if (!this.canJoinSquad() || !this.canManageSquad() || ::queues.isAnyQueuesActive())
    return

  this.setState(squadState.JOINING)
  ::msquad.create(function(_response) { ::g_squad_manager.requestSquadData(callback) })
}

::g_squad_manager.joinSquadChatRoom <- function joinSquadChatRoom()
{
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

  if (::u.isEmpty(name))
    return

  if (this.isSquadLeader() && ::u.isEmpty(password))
  {
    password = ::gen_rnd_password(15)
    this.squadData.chatInfo.password = password

    this.roomCreateInProgress = true
    callback = function() {
                 ::g_squad_manager.updateSquadData()
                 ::g_squad_manager.roomCreateInProgress = false
               }
  }

  if (::u.isEmpty(password))
    return

  ::g_chat.joinSquadRoom(callback)
}

::g_squad_manager.updateSquadData <- function updateSquadData()
{
  let data = {}
  data.chatInfo <- { name = this.getSquadRoomName(), password = this.getSquadRoomPassword() }
  data.wwOperationInfo <- {
    id = this.getWwOperationId()
    country = this.getWwOperationCountry()
    battle = this.getWwOperationBattle() }
  data.properties <- clone this.squadData.properties
  data.presence <- clone this.squadData.presence
  data.psnSessionId <- this.squadData?.psnSessionId ?? ""
  data.leaderBattleRating <- this.squadData?.leaderBattleRating ?? 0
  data.leaderGameModeId <- this.squadData?.leaderGameModeId ?? ""

  ::g_squad_manager.setSquadData(data)
}

::g_squad_manager.disbandSquad <- function disbandSquad()
{
  if (!this.isSquadLeader())
    return

  this.setState(squadState.LEAVING)
  ::msquad.disband()
}

//It function will be use in future: Chat with password
::g_squad_manager.setSquadData <- function setSquadData(newSquadData)
{
  if (!this.isSquadLeader())
    return

  ::msquad.setData(newSquadData)
}

::g_squad_manager.checkForSquad <- function checkForSquad()
{
  if (!::g_login.isLoggedIn())
    return

  let callback = function(response) {
                     if (getTblValue("error_id", response, null) != msquadErrorId.NOT_SQUAD_MEMBER)
                       if (!::checkMatchingError(response))
                         return

                     if ("squad" in response)
                     {
                       ::g_squad_manager.onSquadDataChanged(response)

                       if (::g_squad_manager.getSquadSize(true) == 1)
                         ::g_squad_manager.disbandSquad()
                       else
                         ::g_squad_manager.updateMyMemberData(getMyStateData())

                      ::broadcastEvent(squadEvent.STATUS_CHANGED)
                     }

                     let invites = getTblValue("invites", response, null)
                     if (invites != null)
                       foreach (squadId in invites)
                         ::g_invites.addInviteToSquad(squadId, squadId.tostring())

                     squadApplications.updateApplicationsList(response?.applications ?? [])
                   }

  ::msquad.requestInfo(callback, callback, {showError = false})
}

::g_squad_manager.requestSquadData <- function requestSquadData(callback = null)
{
  let fullCallback = (@(callback) function(response) {
                         if ("squad" in response)
                         {
                           ::g_squad_manager.onSquadDataChanged(response)

                           if (::g_squad_manager.getSquadSize(true) == 1)
                             ::g_squad_manager.disbandSquad()
                         }
                         else if (::g_squad_manager.isInSquad())
                           ::g_squad_manager.reset()

                         if (callback != null)
                           callback()
                       })(callback)

  ::msquad.requestInfo(fullCallback)
}

::g_squad_manager.leaveSquad <- function leaveSquad(cb = null)
{
  if (!this.isInSquad())
    return

  this.setState(squadState.LEAVING)
  ::msquad.leave(function(_response)
  {
    ::g_squad_manager.reset()
    if (cb)
      cb()
  })

  ::xbox_on_local_player_leave_squad()
}

::g_squad_manager.joinToSquad <- function joinToSquad(uid)
{
  if (!this.canJoinSquad())
    return

  this.setState(squadState.JOINING)
  ::msquad.joinPlayerSquad(
    uid,
    @(_response) ::g_squad_manager.requestSquadData(),
    function(_response)
    {
      ::g_squad_manager.setState(squadState.NOT_IN_SQUAD)
      ::g_squad_manager.rejectSquadInvite(uid)
    }
  )
}

::g_squad_manager.inviteToSquad <- function inviteToSquad(uid, name = null, cb = null)
{
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
    if (::u.isEmpty(::g_squad_manager.getPsnSessionId()))
      contact.updatePSNIdAndDo(function() {
        ::g_squad_manager.delayedInvites.append(contact.psnId)
      })
  }

  let callback = function(_response) {
    if (isInvitingPsnPlayer && ::u.isEmpty(::g_squad_manager.delayedInvites)) {
      let contact = ::getContact(uid, name)
      contact.updatePSNIdAndDo(function() {
        invite(::g_squad_manager.getPsnSessionId(), contact.psnId)
      })
    }

    sendSystemInvite(uid, name)

    ::g_squad_manager.requestSquadData(cb)
  }

  ::msquad.invitePlayer(uid, callback.bindenv(this))
}

::g_squad_manager.processDelayedInvitations <- function processDelayedInvitations()
{
  if (::u.isEmpty(this.getPsnSessionId()) || ::u.isEmpty(this.delayedInvites))
    return

  foreach (invitee in this.delayedInvites)
    invite(this.getPsnSessionId(), invitee)
  this.delayedInvites.clear()
}

::g_squad_manager.revokeAllInvites <- function revokeAllInvites(callback)
{
  if (!this.isSquadLeader())
    return

  local fullCallback = null
  if (callback != null)
  {
    let counterTbl = { invitesLeft = ::g_squad_manager.getInvitedPlayers().len() }
    fullCallback = (@(callback, counterTbl) function() {
                     if (!--counterTbl.invitesLeft)
                       callback()
                   })(callback, counterTbl)
  }

  foreach (uid, _memberData in this.getInvitedPlayers())
    this.revokeSquadInvite(uid, fullCallback)
}

::g_squad_manager.revokeSquadInvite <- function revokeSquadInvite(uid, callback = null)
{
  if (!this.isSquadLeader())
    return

  let fullCallback = @(_response) ::g_squad_manager.requestSquadData(@() callback?())
  ::msquad.revokeInvite(uid, fullCallback)
}

::g_squad_manager.membershipAplication <- function membershipAplication(sid)
{
  let callback = Callback(@(_response) squadApplications.addApplication(sid, sid), this)
  let cb = function()
  {
    ::request_matching("msquad.request_membership",
      callback,
      null, {squadId = sid}, null)
  }
  let canJoin = ::g_squad_utils.canJoinFlightMsgBox(
    { allowWhenAlone = false, msgId = "squad/leave_squad_for_application" },
    cb)

  if (canJoin)
  {
    cb()
  }
}

::g_squad_manager.revokeMembershipAplication <- function revokeMembershipAplication(sid)
{
  squadApplications.deleteApplication(sid)
  ::request_matching("msquad.revoke_membership_request", null, null,{squadId = sid}, null)
}

::g_squad_manager.acceptMembershipAplication <- function acceptMembershipAplication(uid)
{
  if (this.isInSquad() && !this.isSquadLeader())
    return

  if (this.isSquadFull())
    return ::g_popups.add(null, loc("matching/SQUAD_FULL"))

  let callback = Callback(@(_response) this.addMember(uid.tostring()), this)
  ::request_matching("msquad.accept_membership", callback, null,{userId = uid}, null)
}

::g_squad_manager.denyAllAplication <- function denyAllAplication()
{
  if (!this.isSquadLeader())
    return

  ::request_matching("msquad.deny_all_membership_requests", null, null, null, null)
}

::g_squad_manager.denyMembershipAplication <- function denyMembershipAplication(uid, callback = null)
{
  if (this.isInSquad() && !this.isSquadLeader())
    return

  ::request_matching("msquad.deny_membership", callback, null,{userId = uid}, null)
}

::g_squad_manager.dismissFromSquad <- function dismissFromSquad(uid)
{
  if (!this.isSquadLeader())
    return

  if (this.squadData.members?[uid])
    ::msquad.dismissMember(uid)
}

::g_squad_manager.dismissFromSquadByName <- function dismissFromSquadByName(name)
{
  if (!this.isSquadLeader())
    return

  let memberData = this._getSquadMemberByName(name)
  if (memberData == null)
    return

  if (this.canDismissMember(memberData.uid))
    this.dismissFromSquad(memberData.uid)
}

::g_squad_manager._getSquadMemberByName <- function _getSquadMemberByName(name)
{
  if (!this.isInSquad())
    return null

  foreach(_uid, memberData in this.squadData.members)
    if (memberData.name == name || memberData.name == getRealName(name))
      return memberData

  return null
}

::g_squad_manager.canTransferLeadership <- function canTransferLeadership(uid)
{
  if (!hasFeature("SquadTransferLeadership"))
    return false

  if (!this.canManageSquad())
    return false

  if (::u.isEmpty(uid))
    return false

  if (uid == ::my_user_id_str)
    return false

  if (!this.isSquadLeader())
    return false

  let memberData = this.getMemberData(uid)
  if (memberData == null || memberData.isInvite)
    return false

  return memberData.online
}

::g_squad_manager.transferLeadership <- function transferLeadership(uid)
{
  if (!this.canTransferLeadership(uid))
    return

  ::msquad.transferLeadership(uid)
  ::broadcastEvent(squadEvent.LEADERSHIP_TRANSFER, {uid = uid})
}

::g_squad_manager.onLeadershipTransfered <- function onLeadershipTransfered()
{
  ::g_squad_manager.setReadyFlag(::g_squad_manager.isSquadLeader())
  ::g_squad_manager.setCrewsReadyFlag(::g_squad_manager.isSquadLeader())
  ::broadcastEvent(squadEvent.STATUS_CHANGED)
}

::g_squad_manager.acceptSquadInvite <- function acceptSquadInvite(sid)
{
  if (!this.canJoinSquad())
    return

  this.setState(squadState.JOINING)
  ::msquad.acceptInvite(sid,
    function(_response)
    {
      this.requestSquadData()
    }.bindenv(this),
    function(_response)
    {
      this.setState(squadState.NOT_IN_SQUAD)
      this.rejectSquadInvite(sid)
      ::xbox_on_local_player_leave_squad()
    }.bindenv(this)
  )
}

::g_squad_manager.rejectSquadInvite <- function rejectSquadInvite(sid)
{
  ::msquad.rejectInvite(sid)
}

::g_squad_manager.requestMemberData <- function requestMemberData(uid)
{
  let memberData = getTblValue(uid, ::g_squad_manager.squadData.members, null)
  if (memberData)
  {
    memberData.isWaiting = true
    ::broadcastEvent(squadEvent.DATA_UPDATED)
  }

  let callback = @(response) ::g_squad_manager.requestMemberDataCallback(uid, response)
  ::msquad.requestMemberData(uid, callback)
}

::g_squad_manager.requestMemberDataCallback <- function requestMemberDataCallback(uid, response)
{
  let receivedData = response?.data
  if (receivedData == null)
    return

  let memberData = ::g_squad_manager.getMemberData(uid)
  if (memberData == null)
    return

  let currentMemberData = memberData.getData()
  let receivedMemberData = receivedData?.data
  let isMemberDataChanged = memberData.update(receivedMemberData)
  let isMemberDataVehicleChanged = isMemberDataChanged
    && ::g_squad_manager.isMemberDataVehicleChanged(currentMemberData, memberData)
  let contact = ::getContact(memberData.uid, memberData.name)
  contact.online = response.online
  memberData.online = response.online
  if (!response.online)
    memberData.isReady = false

  ::update_contacts_by_list([memberData.getData()])

  if (::g_squad_manager.isSquadLeader())
  {
    if (!::g_squad_manager.readyCheck())
      ::queues.leaveAllQueues()

    if (::SessionLobby.canInviteIntoSession() && memberData.canJoinSessionRoom())
      ::SessionLobby.invitePlayer(memberData.uid)
  }

  ::g_squad_manager.joinSquadChatRoom()

  ::broadcastEvent(squadEvent.DATA_UPDATED)
  if (isMemberDataVehicleChanged)
    ::broadcastEvent("SquadMemberVehiclesChanged")

  let memberSquadsVersion = receivedMemberData?.squadsVersion ?? DEFAULT_SQUADS_VERSION
  ::g_squad_utils.checkSquadsVersion(memberSquadsVersion)
}

::g_squad_manager.setMemberOnlineStatus <- function setMemberOnlineStatus(uid, isOnline)
{
  let memberData = this.getMemberData(uid)
  if (memberData == null)
    return

  if (memberData.online == isOnline)
    return

  memberData.online = isOnline
  if (!isOnline)
  {
    memberData.isReady = false
    if (this.isSquadLeader() && ::queues.isAnyQueuesActive())
      ::queues.leaveAllQueues()
  }

  ::updateContact(memberData.getData())
  ::broadcastEvent(squadEvent.DATA_UPDATED)
  ::broadcastEvent("SquadOnlineChanged")
}

::g_squad_manager.getMemberData <- function getMemberData(uid)
{
  if (!this.isInSquad())
    return null

  return getTblValue(uid, this.squadData.members, null)
}

::g_squad_manager.getSquadMemberNameByUid <- function getSquadMemberNameByUid(uid)
{
  if (this.isInSquad() && uid in this.squadData.members)
    return this.squadData.members[uid].name
  return ""
}

::g_squad_manager.getSameCyberCafeMembersNum <- function getSameCyberCafeMembersNum()
{
  if (this.cyberCafeSquadMembersNum >= 0)
    return this.cyberCafeSquadMembersNum

  local num = 0
  if (this.isInSquad() && this.squadData.members && ::get_cyber_cafe_level() > 0)
  {
    let myCyberCafeId = ::get_cyber_cafe_id()
    foreach (_uid, memberData in this.squadData.members)
      if (myCyberCafeId == memberData.cyberCafeId)
        num++
  }

  this.cyberCafeSquadMembersNum = num
  return num
}

::g_squad_manager.getSquadRank <- function getSquadRank()
{
  if (!this.isInSquad())
    return -1

  local squadRank = 0
  foreach (_uid, memberData in this.squadData.members)
    squadRank = max(memberData.rank, squadRank)

  return squadRank
}

::g_squad_manager.reset <- function reset()
{
  if (this.state == squadState.IN_SQUAD)
    this.setState(squadState.LEAVING)

  ::queues.leaveAllQueues()
  ::g_chat.leaveSquadRoom()

  this.cyberCafeSquadMembersNum = -1

  this.squadData.id = ""
  let contactsUpdatedList = []
  foreach(_id, memberData in this.squadData.members)
    contactsUpdatedList.append(memberData.getData())

  this.squadData.members.clear()
  this.squadData.invitedPlayers.clear()
  this.squadData.applications.clear()
  this.squadData.platformInfo.clear()
  this.squadData.chatInfo = { name = "", password = "" }
  this.squadData.wwOperationInfo = { id = -1, country = "", battle = null }
  this.squadData.properties = clone DEFAULT_SQUAD_PROPERTIES
  this.squadData.presence = clone DEFAULT_SQUAD_PRESENCE
  this.squadData.psnSessionId = ""
  this.squadData.leaderBattleRating = 0
  this.squadData.leaderGameModeId = ""
  this.setMaxSquadSize(this.COMMON_SQUAD_SIZE)

  this.lastUpdateStatus = squadStatusUpdateState.NONE
  if (this.meReady)
    this.setReadyFlag(false, false)

  ::update_contacts_by_list(contactsUpdatedList)

  this.setState(squadState.NOT_IN_SQUAD)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
}

::g_squad_manager.updateInvitedData <- function updateInvitedData(invites)
{
  let newInvitedData = {}
  foreach(uidInt64 in invites)
  {
    if (!::is_numeric(uidInt64))
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

::g_squad_manager.addInvitedPlayers <- function addInvitedPlayers(uid)
{
  if (uid in this.squadData.invitedPlayers)
    return

  this.squadData.invitedPlayers[uid] <- SquadMember(uid, true)

  requestUsersInfo([uid])

  ::broadcastEvent(squadEvent.PLAYER_INVITED, { uid = uid })
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

::g_squad_manager.removeInvitedPlayers <- function removeInvitedPlayers(uid)
{
  if (!(uid in this.squadData.invitedPlayers))
    return

  this.squadData.invitedPlayers.rawdelete(uid)
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

::g_squad_manager.updateApplications <- function updateApplications(applications)
{
  let newApplicationsData = {}
  foreach(uid in applications)
  {
    if (uid in this.squadData.applications)
      newApplicationsData[uid] <- this.squadData.applications[uid]
    else
    {
      newApplicationsData[uid] <- SquadMember(uid.tostring(), false, true)
      this.hasNewApplication = true
    }
    requestUsersInfo([uid.tostring()])
  }
  if (!newApplicationsData)
    this.hasNewApplication = false
  this.squadData.applications = newApplicationsData
}

::g_squad_manager.addApplication <- function addApplication(uid)
{
  if (uid in this.squadData.applications)
    return

  this.squadData.applications[uid] <- SquadMember(uid.tostring(), false, true)
  requestUsersInfo([uid.tostring()])
  this.checkNewApplications()
  if (this.isSquadLeader())
    ::g_popups.add(null, colorize("chatTextInviteColor",
      format(loc("squad/player_application"),
        platformModule.getPlayerName(this.squadData.applications[uid]?.name ?? ""))))

  ::broadcastEvent(squadEvent.APPLICATIONS_CHANGED, { uid = uid })
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

::g_squad_manager.removeApplication <- function removeApplication(applications)
{
  if (!::u.isArray(applications))
    applications = [applications]
  local isApplicationsChanged = false
  foreach (uid in applications)
  {
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
  ::broadcastEvent(squadEvent.APPLICATIONS_CHANGED, {})
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

::g_squad_manager.markAllApplicationsSeen <- function markAllApplicationsSeen()
{
  foreach (application in this.squadData.applications)
    application.isNewApplication = false
  this.checkNewApplications()
}

::g_squad_manager.checkNewApplications <- function checkNewApplications()
{
  let curHasNewApplication = this.hasNewApplication
  this.hasNewApplication = false
  foreach (application in this.squadData.applications)
    if (application.isNewApplication == true)
      {
        this.hasNewApplication = true
        break
      }
  if (curHasNewApplication != this.hasNewApplication)
    ::broadcastEvent(squadEvent.NEW_APPLICATIONS)
}

::g_squad_manager.addMember <- function addMember(uid)
{
  this.removeInvitedPlayers(uid)
  let memberData = SquadMember(uid)
  this.squadData.members[uid] <- memberData
  this.removeApplication(uid.tointeger())
  this.requestMemberData(uid)

  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

::g_squad_manager.removeMember <- function removeMember(uid)
{
  let memberData = this.getMemberData(uid)
  if (memberData == null)
    return

  this.squadData.members.rawdelete(memberData.uid)
  ::update_contacts_by_list([memberData.getData()])

  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

::g_squad_manager.updatePlatformInfo <- function updatePlatformInfo()
{
  let playerPlatforms = []
  let checksArray = [this.getMembers(), this.getInvitedPlayers(), this.getApplicationsToSquad()]
  foreach (_idx, membersArray in checksArray)
    foreach (_uid, member in membersArray)
    {
      if (platformModule.isXBoxPlayerName(member.name))
        ::u.appendOnce("xboxOne", playerPlatforms)
      else if (platformModule.isPS4PlayerName(member.name))
        ::u.appendOnce("ps4", playerPlatforms)
      else
        ::u.appendOnce("pc", playerPlatforms)
    }

  this.squadData.platformInfo = playerPlatforms
}

::g_squad_manager.onSquadDataChanged <- function onSquadDataChanged(data = null)
{
  let alreadyInSquad = this.isInSquad()
  let resSquadData = getTblValue("squad", data)

  let newSquadId = getTblValue("id", resSquadData)
  if (::is_numeric(newSquadId)) //bad squad data
    this.squadData.id = newSquadId.tostring() //!!FIX ME: why this convertion to string?
  else if (!alreadyInSquad)
  {
    ::script_net_assert_once("no squad id", "Error: received squad data without squad id")
    ::msquad.leave() //leave broken squad
    this.setState(squadState.NOT_IN_SQUAD)
    return
  }

  let resMembers = getTblValue("members", resSquadData, [])
  let newMembersData = {}
  foreach(uidInt64 in resMembers)
  {
    if (!::is_numeric(uidInt64))
      continue

    let uid = uidInt64.tostring()
    if (uid in this.squadData.members)
      newMembersData[uid] <- this.squadData.members[uid]
    else
      newMembersData[uid] <- SquadMember(uid)

    if (uid != ::my_user_id_str)
      this.requestMemberData(uid)
  }
  this.squadData.members = newMembersData

  this.updateInvitedData(getTblValue("invites", resSquadData, []))

  this.updateApplications(getTblValue("applications", resSquadData, []))

  this.updatePlatformInfo()

  this.cyberCafeSquadMembersNum = this.getSameCyberCafeMembersNum()
  this._parseCustomSquadData(getTblValue("data", resSquadData, null))
  let chatInfo = getTblValue("chat", resSquadData, null)
  if (chatInfo != null)
  {
    let chatName = getTblValue("id", chatInfo, "")
    if (!::u.isEmpty(chatName))
      this.squadData.chatInfo.name = chatName
  }

  if (this.setState(squadState.IN_SQUAD)) {
    this.updateMyMemberData(getMyStateData())
    if (this.isSquadLeader()) {
      this.updatePresenceSquad()
      this.updateSquadData()
      this.setLeaderData(true)
    }
    if (this.getPresence().isInBattle)
      ::g_popups.add(loc("squad/name"), loc("squad/wait_until_battle_end"))
  }
  this.updateCurrentWWOperation()
  this.joinSquadChatRoom()

  if (this.isSquadLeader() && !this.readyCheck())
    ::queues.leaveAllQueues()

  if (!alreadyInSquad)
    this.checkUpdateStatus(squadStatusUpdateState.MENU)

  this.updateLeaderGameModeId(resSquadData?.data.leaderGameModeId ?? "")
  this.squadData.leaderBattleRating = resSquadData?.data?.leaderBattleRating ?? 0

  ::broadcastEvent(squadEvent.DATA_UPDATED)

  let lastReadyness = this.isMeReady()
  let currentReadyness = lastReadyness || this.isSquadLeader()
  if (lastReadyness != currentReadyness || !alreadyInSquad)
    this.setReadyFlag(currentReadyness)

  let lastCrewsReadyness = this.isMyCrewsReady
  let currentCrewsReadyness = lastCrewsReadyness || this.isSquadLeader()
  if (lastCrewsReadyness != currentCrewsReadyness || !alreadyInSquad)
    this.setCrewsReadyFlag(currentCrewsReadyness)
}

::g_squad_manager._parseCustomSquadData <- function _parseCustomSquadData(data)
{
  let chatInfo = getTblValue("chatInfo", data, null)
  if (chatInfo != null)
    this.squadData.chatInfo = chatInfo
  else
    this.squadData.chatInfo = {name = "", password = ""}

  let wwOperationInfo = getTblValue("wwOperationInfo", data, null)
  if (wwOperationInfo != null)
    this.squadData.wwOperationInfo = wwOperationInfo
  else
    this.squadData.wwOperationInfo = { id = -1, country = "", battle = null }

  let properties = getTblValue("properties", data)
  local property = null
  local isPropertyChange = false
  if (::u.isTable(properties))
    foreach(key, value in properties)
    {
      property = this.squadData?.properties?[key]
      if (::u.isEqual(property, value))
        continue

      this.squadData.properties[key] <- value
      isPropertyChange = true
    }
  if (isPropertyChange)
    ::broadcastEvent(squadEvent.PROPERTIES_CHANGED)
  this.squadData.presence = data?.presence ?? clone DEFAULT_SQUAD_PRESENCE
  this.squadData.psnSessionId = data?.psnSessionId ?? ""
}

::g_squad_manager.checkMembersPkg <- function checkMembersPkg(pack) //return list of members dont have this pack
{
  let res = []
  if (!this.isInSquad())
    return res

  foreach(uid, memberData in this.squadData.members)
    if (memberData.missedPkg != null && isInArray(pack, memberData.missedPkg))
      res.append({ uid = uid, name = memberData.name })

  return res
}

::g_squad_manager.getSquadMembersDataForContact <- function getSquadMembersDataForContact()
{
  let contactsData = []

  if (this.isInSquad())
  {
    foreach(uid, memberData in this.squadData.members)
      if (uid != ::my_user_id_str)
        contactsData.append(memberData.getData())
  }

  return contactsData
}

::g_squad_manager.checkUpdateStatus <- function checkUpdateStatus(newStatus)
{
  if (this.lastUpdateStatus == newStatus || !this.isInSquad())
    return

  this.lastUpdateStatus = newStatus
  ::g_squad_utils.updateMyCountryData()
}

::g_squad_manager.getSquadRoomId <- function getSquadRoomId()
{
  return getTblValue("sessionRoomId", this.getSquadLeaderData(), "")
}

::g_squad_manager.updatePresenceSquad <- function updatePresenceSquad(shouldUpdateSquadData = false)
{
  if (!this.isSquadLeader())
    return

  let presence = ::g_presence_type.getCurrent()
  let presenceParams = presence.getParams()
  if (!::u.isEqual(this.squadData.presence, presenceParams))
  {
    this.squadData.presence = presenceParams
    if (shouldUpdateSquadData)
      this.updateSquadData()
  }
}

::g_squad_manager.getPresence <- function getPresence()
{
  return ::g_presence_type.getByPresenceParams(this.squadData?.presence ?? {})
}

::g_squad_manager.onEventUpdateEsFromHost <- function onEventUpdateEsFromHost(_p)
{
  this.checkUpdateStatus(squadStatusUpdateState.BATTLE)
}

::g_squad_manager.onEventNewSceneLoaded <- function onEventNewSceneLoaded(_p)
{
  if (::isInMenu())
    this.checkUpdateStatus(squadStatusUpdateState.MENU)
}

::g_squad_manager.onEventBattleEnded <- function onEventBattleEnded(_p)
{
  if (::isInMenu())
    this.checkUpdateStatus(squadStatusUpdateState.MENU)
}

::g_squad_manager.onEventSessionDestroyed <- function onEventSessionDestroyed(_p)
{
  if (::isInMenu())
    this.checkUpdateStatus(squadStatusUpdateState.MENU)
}

::g_squad_manager.onEventChatConnected <- function onEventChatConnected(_params)
{
  this.joinSquadChatRoom()
}

::g_squad_manager.onEventContactsUpdated <- function onEventContactsUpdated(_params)
{
  local isChanged = false
  local contact = null
  foreach (uid, memberData in this.getInvitedPlayers())
  {
    contact = ::getContact(uid)
    if (contact == null)
      continue

    memberData.update(contact)
    isChanged = true
  }

  if (isChanged)
    ::broadcastEvent(squadEvent.INVITES_CHANGED)

  isChanged = false
  foreach (uid, memberData in this.getApplicationsToSquad())
  {
    contact = ::getContact(uid.tostring())
    if (contact == null)
      continue

    if (memberData.update(contact))
      isChanged = true
  }
  if (isChanged)
    ::broadcastEvent(squadEvent.APPLICATIONS_CHANGED {})
}

::g_squad_manager.onEventAvatarChanged <- function onEventAvatarChanged(_params)
{
  this.updateMyMemberData()
}

::g_squad_manager.onEventCrewTakeUnit <- function onEventCrewTakeUnit(_params)
{
  this.updateMyMemberData()
}

::g_squad_manager.onEventUnitRepaired <- function onEventUnitRepaired(_p)
{
  ::g_squad_utils.updateMyCountryData()
}

::g_squad_manager.onEventCrossPlayOptionChanged <- function onEventCrossPlayOptionChanged(_p)
{
  this.updateMyMemberData()
}

::g_squad_manager.onEventMatchingDisconnect <- function onEventMatchingDisconnect(_params)
{
  this.reset()
}

::g_squad_manager.onEventMatchingConnect <- function onEventMatchingConnect(_params)
{
  this.reset()
  this.checkForSquad()
}

::g_squad_manager.onEventLoginComplete <- function onEventLoginComplete(_params)
{
  this.initSquadSizes()
  this.reset()
  this.checkForSquad()
}

::g_squad_manager.onEventLoadingStateChange <- function onEventLoadingStateChange(_params)
{
  if (::is_in_flight())
    this.setReadyFlag(false)

  this.updatePresenceSquad(true)
}

::g_squad_manager.onEventWWLoadOperation <- function onEventWWLoadOperation(_params)
{
  this.updateCurrentWWOperation()
  this.updatePresenceSquad()
  this.updateSquadData()
}

::g_squad_manager.updateCurrentWWOperation <- function updateCurrentWWOperation()
{
  if (!this.isSquadLeader() || !::is_worldwar_enabled())
    return

  let wwOperationId = ::ww_get_operation_id()
  local country = profileCountrySq.value
  if (wwOperationId > -1)
  {
    let wwOperation = ::g_ww_global_status_actions.getOperationById(wwOperationId)
    if (wwOperation)
      country = wwOperation.getMyAssignCountry() || country
  }

  this.squadData.wwOperationInfo.id = wwOperationId
  this.squadData.wwOperationInfo.country = country
}

::g_squad_manager.startWWBattlePrepare <- function startWWBattlePrepare(battleId = null)
{
  if (!this.isSquadLeader())
    return

  if (this.getWwOperationBattle() == battleId)
    return

  this.squadData.wwOperationInfo.battle <- battleId
  this.squadData.wwOperationInfo.id = ::ww_get_operation_id()
  this.squadData.wwOperationInfo.country = profileCountrySq.value

  this.updatePresenceSquad()
  this.updateSquadData()
}

::g_squad_manager.cancelWwBattlePrepare <- function cancelWwBattlePrepare()
{
  this.startWWBattlePrepare() // cancel battle prepare if no args
}

::g_squad_manager.onEventWWStopWorldWar <- function onEventWWStopWorldWar(_params)
{
  if (this.getWwOperationId() == -1)
    return

  if (!this.isInSquad() || this.isSquadLeader()) {
    this.squadData.wwOperationInfo = { id = -1, country = "", battle = null }
  }
  this.updatePresenceSquad()
  this.updateSquadData()
}

::g_squad_manager.onEventLobbyStatusChange <- function onEventLobbyStatusChange(_params)
{
  if (!::SessionLobby.isInRoom())
    this.setReadyFlag(false)

  this.updateMyMemberData()
  this.updatePresenceSquad(true)
}

::g_squad_manager.onEventQueueChangeState <- function onEventQueueChangeState(_params)
{
  if (!::queues.hasActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE))
    this.setCrewsReadyFlag(false)

  this.updatePresenceSquad(true)
}

::g_squad_manager.isMemberDataVehicleChanged <- function isMemberDataVehicleChanged(currentData, receivedData)
{
  let currentCountry = currentData?.country ?? ""
  let receivedCountry = receivedData?.country ?? ""
  if (currentCountry != receivedCountry)
    return true

  if (currentData?.selSlots?[currentCountry] != receivedData?.selSlots?[receivedCountry])
    return true

  if (!::u.isEqual(battleRating.getCrafts(currentData), battleRating.getCrafts(receivedData)))
    return true

  return false
}

::g_squad_manager.onEventBattleRatingChanged <- function onEventBattleRatingChanged(_params)
{
  this.setLeaderData()
}

::g_squad_manager.onEventCurrentGameModeIdChanged <- function onEventCurrentGameModeIdChanged(_params)
{
  this.setLeaderData(false)
}

::g_squad_manager.onEventEventsDataUpdated <- function onEventEventsDataUpdated(_params)
{
  this.setLeaderData(false)
}

::g_squad_manager.setLeaderData <- function setLeaderData(isActualBR = true)
{
  if (!this.isSquadLeader())
    return

  let currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
  if (!isActualBR && this.squadData.leaderGameModeId == currentGameModeId)
    return

  let data = clone this.squadData
  data.leaderBattleRating = isActualBR ? battleRating.recentBR.value : 0
  data.leaderGameModeId = isActualBR ? battleRating.recentBrGameModeId.value : currentGameModeId
  this.setSquadData(data)
}

::g_squad_manager.getMembersNotAllowedInWorldWar <- function getMembersNotAllowedInWorldWar()
{
  let res = []
  foreach (_uid, member in this.getMembers())
    if (!member.isWorldWarAvailable)
      res.append(member)

  return res
}

::cross_call_api.squad_manger <- ::g_squad_manager

::g_script_reloader.registerPersistentDataFromRoot("g_squad_manager")

::subscribe_handler(::g_squad_manager, ::g_listener_priority.DEFAULT_HANDLER)
