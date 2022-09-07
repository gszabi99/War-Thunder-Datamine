let { format } = require("string")
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

enum squadEvent
{
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
global const SQUADS_VERSION = 2
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

  getLeaderGameModeId = @() squadData?.leaderGameModeId ?? ""
  getLeaderBattleRating = @() squadData?.leaderBattleRating ?? 0

  function updateLeaderGameModeId(newLeaderGameModeId) {
    if (squadData.leaderGameModeId == newLeaderGameModeId)
      return

    squadData.leaderGameModeId = newLeaderGameModeId
    if (isSquadMember())
    {
      let event = ::events.getEvent(getLeaderGameModeId())
      if (isMeReady() && (!antiCheat.showMsgboxIfEacInactive(event) ||
                          !showMsgboxIfSoundModsNotAllowed(event)))
        setReadyFlag(false)
      updateMyMemberData(getMyStateData())
    }
  }

  onEventPresetsByGroupsChanged = @(params) updateMyMemberData()
  onEventBeforeProfileInvalidation = @(p) reset()
}

g_squad_manager.setState <- function setState(newState)
{
  if (state == newState)
    return false
  state = newState
  lastStateChangeTime = ::dagor.getCurTime()
  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  return true
}

g_squad_manager.isStateInTransition <- function isStateInTransition()
{
  return (state == squadState.JOINING || state == squadState.LEAVING)
    && lastStateChangeTime + SQUAD_REQEST_TIMEOUT > ::dagor.getCurTime()
}

g_squad_manager.canStartStateChanging <- function canStartStateChanging()
{
  return !isStateInTransition()
}

g_squad_manager.canJoinSquad <- function canJoinSquad()
{
  return !isInSquad() && canStartStateChanging()
}

g_squad_manager.updateMyMemberData <- function updateMyMemberData(data = null)
{
  if (!isInSquad())
    return

  if (data == null)
    data = getMyStateData()

  let isWorldwarEnabled = ::is_worldwar_enabled()
  data.__update({
    isReady = isMeReady()
    isCrewsReady = isMyCrewsReady
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

  local memberData = getMemberData(::my_user_id_str)
  if (!memberData)
  {
    memberData = SquadMember(::my_user_id_str)
    squadData.members[::my_user_id_str] <- memberData
  }

  memberData.update(data)
  memberData.online = true
  ::updateContact(memberData.getData())

  ::msquad.setMyMemberData(::my_user_id_str, data)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

g_squad_manager.isInSquad <- function isInSquad(forChat = false)
{
  if (forChat && !::SessionLobby.isMpSquadChatAllowed())
    return false

  return state == squadState.IN_SQUAD
}

g_squad_manager.isMeReady <- function isMeReady()
{
  return meReady
}

g_squad_manager.getLeaderUid <- function getLeaderUid()
{
  return squadData.id
}

g_squad_manager.isSquadLeader <- function isSquadLeader()
{
  return isInSquad() && getLeaderUid() == ::my_user_id_str
}

g_squad_manager.getSquadLeaderData <- function getSquadLeaderData()
{
  return getMemberData(getLeaderUid())
}

g_squad_manager.getMembers <- function getMembers()
{
  return squadData.members
}

g_squad_manager.setPsnSessionId <- function setPsnSessionId(id = null)
{
  squadData.psnSessionId <- id
  updateSquadData()
}

g_squad_manager.getPsnSessionId <- function getPsnSessionId()
{
  return squadData?.psnSessionId ?? ""
}

g_squad_manager.getInvitedPlayers <- function getInvitedPlayers()
{
  return squadData.invitedPlayers
}

g_squad_manager.getPlatformInfo <- function getPlatformInfo()
{
  return squadData.platformInfo
}

g_squad_manager.isPlayerInvited <- function isPlayerInvited(uid, name = null)
{
  if (uid)
    return uid in getInvitedPlayers()

  return ::u.search(getInvitedPlayers(), @(player) player.name == name) != null
}

g_squad_manager.getApplicationsToSquad <- function getApplicationsToSquad()
{
  return squadData.applications
}

g_squad_manager.hasApplicationInMySquad <- function hasApplicationInMySquad(uid, name = null)
{
  if (uid)
    return uid in getApplicationsToSquad()

  return ::u.search(getApplicationsToSquad(), @(player) player.name == name) != null
}

g_squad_manager.getLeaderNick <- function getLeaderNick()
{
  if (!isInSquad())
    return ""

  let leaderData = getSquadLeaderData()
  if (leaderData == null)
    return ""

  return leaderData.name
}

g_squad_manager.getSquadRoomName <- function getSquadRoomName()
{
  return squadData.chatInfo.name
}

g_squad_manager.getSquadRoomPassword <- function getSquadRoomPassword()
{
  return squadData.chatInfo.password
}

g_squad_manager.getWwOperationId <- function getWwOperationId()
{
  return ::getTblValue("id", squadData.wwOperationInfo, -1)
}

g_squad_manager.getWwOperationCountry <- function getWwOperationCountry()
{
  return ::getTblValue("country", squadData.wwOperationInfo, "")
}

g_squad_manager.getWwOperationBattle <- function getWwOperationBattle()
{
  return ::getTblValue("battle", squadData.wwOperationInfo)
}

g_squad_manager.isNotAloneOnline <- function isNotAloneOnline()
{
  if (!isInSquad())
    return false

  if (squadData.members.len() == 1)
    return false

  foreach(uid, memberData in squadData.members)
    if (uid != ::my_user_id_str && memberData.online == true)
      return true

  return false
}

g_squad_manager.isMySquadLeader <- function isMySquadLeader(uid)
{
  return isInSquad() && uid != null && uid == getLeaderUid()
}

g_squad_manager.isSquadMember <- function isSquadMember()
{
  return isInSquad() && !isSquadLeader()
}

g_squad_manager.isMemberReady <- function isMemberReady(uid)
{
  let memberData = getMemberData(uid)
  return memberData ? memberData.isReady : false
}

g_squad_manager.isInMySquad <- function isInMySquad(name, checkAutosquad = true)
{
  if (isInSquad() && _getSquadMemberByName(name) != null)
    return true
  return checkAutosquad && ::SessionLobby.isMemberInMySquadByName(name)
}

g_squad_manager.isMe <- function isMe(uid)
{
  return uid == ::my_user_id_str
}

g_squad_manager.canInviteMember <- function canInviteMember(uid = null)
{
  return !isMe(uid)
    && canManageSquad()
    && (canJoinSquad() || isSquadLeader())
    && !isInvitedMaxPlayers()
    && (!uid || !getMemberData(uid))
}

g_squad_manager.canDismissMember <- function canDismissMember(uid = null)
{
  return isSquadLeader()
         && canManageSquad()
         && !isMe(uid)
         && getPlayerStatusInMySquad(uid) >= squadMemberState.SQUAD_MEMBER
}

g_squad_manager.canSwitchReadyness <- function canSwitchReadyness()
{
  return ::g_squad_manager.isSquadMember() && ::g_squad_manager.canManageSquad() && !checkIsInQueue()
}

g_squad_manager.canLeaveSquad <- function canLeaveSquad()
{
  return isInSquad() && canManageSquad()
}

g_squad_manager.canManageSquad <- function canManageSquad()
{
  return ::has_feature("Squad") && ::isInMenu()
}

g_squad_manager.canInviteMemberByPlatform <- function canInviteMemberByPlatform(name)
{
  let platformInfo = getPlatformInfo()
  if (!::has_feature("Ps4XboxOneInteraction")
      && ((platformModule.isPS4PlayerName(name) && ::isInArray("xboxOne", platformInfo))
         || (platformModule.isXBoxPlayerName(name) && ::isInArray("ps4", platformInfo))))
    return false

  return true
}

g_squad_manager.getMaxSquadSize <- function getMaxSquadSize()
{
  return squadData.properties.maxMembers
}

g_squad_manager.setMaxSquadSize <- function setMaxSquadSize(newSize)
{
  squadData.properties.maxMembers = newSize
}

g_squad_manager.getSquadSize <- function getSquadSize(includeInvites = false)
{
  if (!isInSquad())
    return 0

  local res = squadData.members.len()
  if (includeInvites)
  {
    res += getInvitedPlayers().len()
    res += getApplicationsToSquad().len()
  }
  return res
}

g_squad_manager.isSquadFull <- function isSquadFull()
{
  return getSquadSize() >= getMaxSquadSize()
}

g_squad_manager.canChangeSquadSize <- function canChangeSquadSize(shouldCheckLeader = true)
{
  return ::has_feature("SquadSizeChange")
         && (!shouldCheckLeader || ::g_squad_manager.isSquadLeader())
         && squadSizesList.len() > 1
}

g_squad_manager.setSquadSize <- function setSquadSize(newSize)
{
  if (newSize == getMaxSquadSize())
    return

  setMaxSquadSize(newSize)
  updateSquadData()
  ::broadcastEvent(squadEvent.SIZE_CHANGED)
}

g_squad_manager.initSquadSizes <- function initSquadSizes()
{
  squadSizesList.clear()
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
    squadSizesList.append({
      name = name
      value = size
    })
    maxSize = max(maxSize, size)
  }

  if (!squadSizesList.len())
    return

  COMMON_SQUAD_SIZE = squadSizesList[0].value
  MAX_SQUAD_SIZE = maxSize
  setMaxSquadSize(COMMON_SQUAD_SIZE)
}

g_squad_manager.isInvitedMaxPlayers <- function isInvitedMaxPlayers()
{
  return isSquadFull() || getInvitedPlayers().len() >= maxInvitesCount
}

g_squad_manager.isApplicationsEnabled <- function isApplicationsEnabled()
{
  return squadData.properties.isApplicationsEnabled
}

g_squad_manager.enableApplications <- function enableApplications(shouldEnable)
{
  if (shouldEnable == isApplicationsEnabled())
    return

  squadData.properties.isApplicationsEnabled = shouldEnable

  updateSquadData()
}

g_squad_manager.canChangeReceiveApplications <- function canChangeReceiveApplications(shouldCheckLeader = true)
{
  return ::has_feature("ClanSquads") && (!shouldCheckLeader || isSquadLeader())
}

g_squad_manager.getPlayerStatusInMySquad <- function getPlayerStatusInMySquad(uid)
{
  if (!isInSquad())
    return squadMemberState.NOT_IN_SQUAD

  let memberData = getMemberData(uid)
  if (memberData == null)
    return squadMemberState.NOT_IN_SQUAD

  if (getLeaderUid() == uid)
    return squadMemberState.SQUAD_LEADER

  if (!memberData.online)
    return squadMemberState.SQUAD_MEMBER_OFFLINE
  if (memberData.isReady)
    return squadMemberState.SQUAD_MEMBER_READY
  return squadMemberState.SQUAD_MEMBER
}

g_squad_manager.readyCheck <- function readyCheck(considerInvitedPlayers = false)
{
  if (!isInSquad())
    return false

  foreach(uid, memberData in squadData.members)
    if (memberData.online == true && memberData.isReady == false)
      return false

  if (considerInvitedPlayers && squadData.invitedPlayers.len() > 0)
    return false

  return  true
}

g_squad_manager.crewsReadyCheck <- function crewsReadyCheck()
{
  if (!isInSquad())
    return false

  foreach(uid, memberData in squadData.members)
    if (memberData.online && !memberData.isCrewsReady)
      return false

  return  true
}

g_squad_manager.getDiffCrossPlayConditionMembers <- function getDiffCrossPlayConditionMembers()
{
  let res = []
  if (!isInSquad())
    return res

  let leaderCondition = squadData.members[getLeaderUid()].crossplay
  foreach (uid, memberData in squadData.members)
    if (leaderCondition != memberData.crossplay)
      res.append(memberData)

  return res
}

g_squad_manager.getOfflineMembers <- function getOfflineMembers()
{
  return getMembersByOnline(false)
}

g_squad_manager.getOnlineMembers <- function getOnlineMembers()
{
  return getMembersByOnline(true)
}

g_squad_manager.getMembersByOnline <- function getMembersByOnline(online = true)
{
  let res = []
  if (!isInSquad())
    return res

  foreach(uid, memberData in squadData.members)
    if (memberData.online == online)
      res.append(memberData)

  return res
}

g_squad_manager.getOnlineMembersCount <- function getOnlineMembersCount()
{
  if (!isInSquad())
    return 1
  local res = 0
  foreach(member in squadData.members)
    if (member.online)
      res++
  return res
}

g_squad_manager.setReadyFlag <- function setReadyFlag(ready = null, needUpdateMemberData = true)
{
  let isLeader = isSquadLeader()
  if (isLeader && ready != true)
    return

  let isSetNoReady = (ready == false || (ready == null && isMeReady() == true))
  let event = ::events.getEvent(getLeaderGameModeId())
  if (!isLeader && !isSetNoReady
    && (!antiCheat.showMsgboxIfEacInactive(event) || !showMsgboxIfSoundModsNotAllowed(event)))
    return

  if (::checkIsInQueue() && !isLeader && isInSquad() && isSetNoReady)
  {
    ::g_popups.add(null, ::loc("squad/cant_switch_off_readyness_in_queue"))
    return
  }

  if (ready == null)
    meReady = !isMeReady()
  else if (isMeReady() != ready)
    meReady = ready
  else
    return

  if (!meReady)
    isMyCrewsReady = false

  if (needUpdateMemberData)
    updateMyMemberData(getMyStateData())

  ::broadcastEvent(squadEvent.SET_READY)
}

g_squad_manager.setCrewsReadyFlag <- function setCrewsReadyFlag(ready = null, needUpdateMemberData = true)
{
  let isLeader = isSquadLeader()
  if (isLeader && ready != true)
    return

  if (ready == null)
    isMyCrewsReady = !isMyCrewsReady
  else if (isMyCrewsReady != ready)
    isMyCrewsReady = ready
  else
    return

  if (needUpdateMemberData)
    updateMyMemberData(getMyStateData())
}

g_squad_manager.createSquad <- function createSquad(callback)
{
  if (!::has_feature("Squad"))
    return

  if (!canJoinSquad() || !canManageSquad() || ::queues.isAnyQueuesActive())
    return

  setState(squadState.JOINING)
  ::msquad.create(function(response) { ::g_squad_manager.requestSquadData(callback) })
}

g_squad_manager.joinSquadChatRoom <- function joinSquadChatRoom()
{
  if (!isNotAloneOnline())
    return

  if (!::gchat_is_connected())
    return

  if (::g_chat.isSquadRoomJoined())
    return

  if (roomCreateInProgress)
    return

  let name = getSquadRoomName()
  local password = getSquadRoomPassword()
  local callback = null

  if (::u.isEmpty(name))
    return

  if (isSquadLeader() && ::u.isEmpty(password))
  {
    password = ::gen_rnd_password(15)
    squadData.chatInfo.password = password

    roomCreateInProgress = true
    callback = function() {
                 ::g_squad_manager.updateSquadData()
                 ::g_squad_manager.roomCreateInProgress = false
               }
  }

  if (::u.isEmpty(password))
    return

  ::g_chat.joinSquadRoom(callback)
}

g_squad_manager.updateSquadData <- function updateSquadData()
{
  let data = {}
  data.chatInfo <- { name = getSquadRoomName(), password = getSquadRoomPassword() }
  data.wwOperationInfo <- {
    id = getWwOperationId()
    country = getWwOperationCountry()
    battle = getWwOperationBattle() }
  data.properties <- clone squadData.properties
  data.presence <- clone squadData.presence
  data.psnSessionId <- squadData?.psnSessionId ?? ""
  data.leaderBattleRating <- squadData?.leaderBattleRating ?? 0
  data.leaderGameModeId <- squadData?.leaderGameModeId ?? ""

  ::g_squad_manager.setSquadData(data)
}

g_squad_manager.disbandSquad <- function disbandSquad()
{
  if (!isSquadLeader())
    return

  setState(squadState.LEAVING)
  ::msquad.disband()
}

//It function will be use in future: Chat with password
g_squad_manager.setSquadData <- function setSquadData(newSquadData)
{
  if (!isSquadLeader())
    return

  ::msquad.setData(newSquadData)
}

g_squad_manager.checkForSquad <- function checkForSquad()
{
  if (!::g_login.isLoggedIn())
    return

  let callback = function(response) {
                     if (::getTblValue("error_id", response, null) != msquadErrorId.NOT_SQUAD_MEMBER)
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

                     let invites = ::getTblValue("invites", response, null)
                     if (invites != null)
                       foreach (squadId in invites)
                         ::g_invites.addInviteToSquad(squadId, squadId.tostring())

                     squadApplications.updateApplicationsList(response?.applications ?? [])
                   }

  ::msquad.requestInfo(callback, callback, {showError = false})
}

g_squad_manager.requestSquadData <- function requestSquadData(callback = null)
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

g_squad_manager.leaveSquad <- function leaveSquad(cb = null)
{
  if (!isInSquad())
    return

  setState(squadState.LEAVING)
  ::msquad.leave(function(response)
  {
    ::g_squad_manager.reset()
    if (cb)
      cb()
  })

  ::xbox_on_local_player_leave_squad()
}

g_squad_manager.inviteToSquad <- function inviteToSquad(uid, name = null, cb = null)
{
  if (isInSquad() && !isSquadLeader())
    return

  if (isSquadFull())
    return ::g_popups.add(null, ::loc("matching/SQUAD_FULL"))

  if (isInvitedMaxPlayers())
    return ::g_popups.add(null, ::loc("squad/maximum_intitations_sent"))

  if (!canInviteMemberByPlatform(name))
    return ::g_popups.add(null, ::loc("msg/squad/noPlayersForDiffConsoles"))

  local isInvitingPsnPlayer = false
  if (platformModule.isPS4PlayerName(name)) {
    let contact = ::getContact(uid, name)
    isInvitingPsnPlayer = true
    if (u.isEmpty(::g_squad_manager.getPsnSessionId()))
      contact.updatePSNIdAndDo(function() {
        ::g_squad_manager.delayedInvites.append(contact.psnId)
      })
  }

  let callback = function(response) {
    if (isInvitingPsnPlayer && u.isEmpty(::g_squad_manager.delayedInvites)) {
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

g_squad_manager.processDelayedInvitations <- function processDelayedInvitations()
{
  if (u.isEmpty(getPsnSessionId()) || u.isEmpty(delayedInvites))
    return

  foreach (invitee in delayedInvites)
    invite(getPsnSessionId(), invitee)
  delayedInvites.clear()
}

g_squad_manager.revokeAllInvites <- function revokeAllInvites(callback)
{
  if (!isSquadLeader())
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

  foreach (uid, memberData in getInvitedPlayers())
    revokeSquadInvite(uid, fullCallback)
}

g_squad_manager.revokeSquadInvite <- function revokeSquadInvite(uid, callback = null)
{
  if (!isSquadLeader())
    return

  let fullCallback = @(response) ::g_squad_manager.requestSquadData(function() {
                         if (callback)
                           callback()
                       }.bindenv(this))

  ::msquad.revokeInvite(uid, fullCallback)
}

g_squad_manager.membershipAplication <- function membershipAplication(sid)
{
  let callback = ::Callback(@(response) squadApplications.addApplication(sid, sid), this)
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

g_squad_manager.revokeMembershipAplication <- function revokeMembershipAplication(sid)
{
  squadApplications.deleteApplication(sid)
  ::request_matching("msquad.revoke_membership_request", null, null,{squadId = sid}, null)
}

g_squad_manager.acceptMembershipAplication <- function acceptMembershipAplication(uid)
{
  if (isInSquad() && !isSquadLeader())
    return

  if (isSquadFull())
    return ::g_popups.add(null, ::loc("matching/SQUAD_FULL"))

  let callback = ::Callback(@(response) addMember(uid.tostring()), this)
  ::request_matching("msquad.accept_membership", callback, null,{userId = uid}, null)
}

g_squad_manager.denyAllAplication <- function denyAllAplication()
{
  if (!isSquadLeader())
    return

  ::request_matching("msquad.deny_all_membership_requests", null, null, null, null)
}

g_squad_manager.denyMembershipAplication <- function denyMembershipAplication(uid, callback = null)
{
  if (isInSquad() && !isSquadLeader())
    return

  ::request_matching("msquad.deny_membership", callback, null,{userId = uid}, null)
}

g_squad_manager.dismissFromSquad <- function dismissFromSquad(uid)
{
  if (!isSquadLeader())
    return

  if (squadData.members?[uid])
    ::msquad.dismissMember(uid)
}

g_squad_manager.dismissFromSquadByName <- function dismissFromSquadByName(name)
{
  if (!isSquadLeader())
    return

  let memberData = _getSquadMemberByName(name)
  if (memberData == null)
    return

  if (canDismissMember(memberData.uid))
    dismissFromSquad(memberData.uid)
}

g_squad_manager._getSquadMemberByName <- function _getSquadMemberByName(name)
{
  if (!isInSquad())
    return null

  foreach(uid, memberData in squadData.members)
    if (memberData.name == name || memberData.name == getRealName(name))
      return memberData

  return null
}

g_squad_manager.canTransferLeadership <- function canTransferLeadership(uid)
{
  if (!::has_feature("SquadTransferLeadership"))
    return false

  if (!canManageSquad())
    return false

  if (::u.isEmpty(uid))
    return false

  if (uid == ::my_user_id_str)
    return false

  if (!isSquadLeader())
    return false

  let memberData = getMemberData(uid)
  if (memberData == null || memberData.isInvite)
    return false

  return memberData.online
}

g_squad_manager.transferLeadership <- function transferLeadership(uid)
{
  if (!canTransferLeadership(uid))
    return

  ::msquad.transferLeadership(uid)
  ::broadcastEvent(squadEvent.LEADERSHIP_TRANSFER, {uid = uid})
}

g_squad_manager.onLeadershipTransfered <- function onLeadershipTransfered()
{
  ::g_squad_manager.setReadyFlag(::g_squad_manager.isSquadLeader())
  ::g_squad_manager.setCrewsReadyFlag(::g_squad_manager.isSquadLeader())
  ::broadcastEvent(squadEvent.STATUS_CHANGED)
}

g_squad_manager.acceptSquadInvite <- function acceptSquadInvite(sid)
{
  if (!canJoinSquad())
    return

  setState(squadState.JOINING)
  ::msquad.acceptInvite(sid,
    function(response)
    {
      requestSquadData()
    }.bindenv(this),
    function(response)
    {
      setState(squadState.NOT_IN_SQUAD)
      rejectSquadInvite(sid)
      ::xbox_on_local_player_leave_squad()
    }.bindenv(this)
  )
}

g_squad_manager.rejectSquadInvite <- function rejectSquadInvite(sid)
{
  ::msquad.rejectInvite(sid)
}

g_squad_manager.requestMemberData <- function requestMemberData(uid)
{
  let memberData = ::getTblValue(uid, ::g_squad_manager.squadData.members, null)
  if (memberData)
  {
    memberData.isWaiting = true
    ::broadcastEvent(squadEvent.DATA_UPDATED)
  }

  let callback = @(response) ::g_squad_manager.requestMemberDataCallback(uid, response)
  ::msquad.requestMemberData(uid, callback)
}

g_squad_manager.requestMemberDataCallback <- function requestMemberDataCallback(uid, response)
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

g_squad_manager.setMemberOnlineStatus <- function setMemberOnlineStatus(uid, isOnline)
{
  let memberData = getMemberData(uid)
  if (memberData == null)
    return

  if (memberData.online == isOnline)
    return

  memberData.online = isOnline
  if (!isOnline)
  {
    memberData.isReady = false
    if (isSquadLeader() && ::queues.isAnyQueuesActive())
      ::queues.leaveAllQueues()
  }

  ::updateContact(memberData.getData())
  ::broadcastEvent(squadEvent.DATA_UPDATED)
  ::broadcastEvent("SquadOnlineChanged")
}

g_squad_manager.getMemberData <- function getMemberData(uid)
{
  if (!isInSquad())
    return null

  return ::getTblValue(uid, squadData.members, null)
}

g_squad_manager.getSquadMemberNameByUid <- function getSquadMemberNameByUid(uid)
{
  if (isInSquad() && uid in squadData.members)
    return squadData.members[uid].name
  return ""
}

g_squad_manager.getSameCyberCafeMembersNum <- function getSameCyberCafeMembersNum()
{
  if (cyberCafeSquadMembersNum >= 0)
    return cyberCafeSquadMembersNum

  local num = 0
  if (isInSquad() && squadData.members && ::get_cyber_cafe_level() > 0)
  {
    let myCyberCafeId = ::get_cyber_cafe_id()
    foreach (uid, memberData in squadData.members)
      if (myCyberCafeId == memberData.cyberCafeId)
        num++
  }

  cyberCafeSquadMembersNum = num
  return num
}

g_squad_manager.getSquadRank <- function getSquadRank()
{
  if (!isInSquad())
    return -1

  local squadRank = 0
  foreach (uid, memberData in squadData.members)
    squadRank = max(memberData.rank, squadRank)

  return squadRank
}

g_squad_manager.reset <- function reset()
{
  if (state == squadState.IN_SQUAD)
    setState(squadState.LEAVING)

  ::queues.leaveAllQueues()
  ::g_chat.leaveSquadRoom()

  cyberCafeSquadMembersNum = -1

  squadData.id = ""
  let contactsUpdatedList = []
  foreach(id, memberData in squadData.members)
    contactsUpdatedList.append(memberData.getData())

  squadData.members.clear()
  squadData.invitedPlayers.clear()
  squadData.applications.clear()
  squadData.platformInfo.clear()
  squadData.chatInfo = { name = "", password = "" }
  squadData.wwOperationInfo = { id = -1, country = "", battle = null }
  squadData.properties = clone DEFAULT_SQUAD_PROPERTIES
  squadData.presence = clone DEFAULT_SQUAD_PRESENCE
  squadData.psnSessionId = ""
  squadData.leaderBattleRating = 0
  squadData.leaderGameModeId = ""
  setMaxSquadSize(COMMON_SQUAD_SIZE)

  lastUpdateStatus = squadStatusUpdateState.NONE
  if (meReady)
    setReadyFlag(false, false)

  ::update_contacts_by_list(contactsUpdatedList)

  setState(squadState.NOT_IN_SQUAD)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
}

g_squad_manager.updateInvitedData <- function updateInvitedData(invites)
{
  let newInvitedData = {}
  foreach(uidInt64 in invites)
  {
    if (!::is_numeric(uidInt64))
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

g_squad_manager.addInvitedPlayers <- function addInvitedPlayers(uid)
{
  if (uid in squadData.invitedPlayers)
    return

  squadData.invitedPlayers[uid] <- SquadMember(uid, true)

  requestUsersInfo([uid])

  ::broadcastEvent(squadEvent.PLAYER_INVITED, { uid = uid })
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

g_squad_manager.removeInvitedPlayers <- function removeInvitedPlayers(uid)
{
  if (!(uid in squadData.invitedPlayers))
    return

  squadData.invitedPlayers.rawdelete(uid)
  ::broadcastEvent(squadEvent.INVITES_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

g_squad_manager.updateApplications <- function updateApplications(applications)
{
  let newApplicationsData = {}
  foreach(uid in applications)
  {
    if (uid in squadData.applications)
      newApplicationsData[uid] <- squadData.applications[uid]
    else
    {
      newApplicationsData[uid] <- SquadMember(uid.tostring(), false, true)
      hasNewApplication = true
    }
    requestUsersInfo([uid.tostring()])
  }
  if (!newApplicationsData)
    hasNewApplication = false
  squadData.applications = newApplicationsData
}

g_squad_manager.addApplication <- function addApplication(uid)
{
  if (uid in squadData.applications)
    return

  squadData.applications[uid] <- SquadMember(uid.tostring(), false, true)
  requestUsersInfo([uid.tostring()])
  checkNewApplications()
  if (isSquadLeader())
    ::g_popups.add(null, ::colorize("chatTextInviteColor",
      format(::loc("squad/player_application"),
        platformModule.getPlayerName(squadData.applications[uid]?.name ?? ""))))

  ::broadcastEvent(squadEvent.APPLICATIONS_CHANGED, { uid = uid })
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

g_squad_manager.removeApplication <- function removeApplication(applications)
{
  if (!::u.isArray(applications))
    applications = [applications]
  local isApplicationsChanged = false
  foreach (uid in applications)
  {
    if (!(uid in squadData.applications))
      continue
    squadData.applications.rawdelete(uid)
    isApplicationsChanged = true
  }

  if (!isApplicationsChanged)
    return

  if (getSquadSize(true) == 1)
    ::g_squad_manager.disbandSquad()
  checkNewApplications()
  ::broadcastEvent(squadEvent.APPLICATIONS_CHANGED, {})
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

g_squad_manager.markAllApplicationsSeen <- function markAllApplicationsSeen()
{
  foreach (application in squadData.applications)
    application.isNewApplication = false
  checkNewApplications()
}

g_squad_manager.checkNewApplications <- function checkNewApplications()
{
  let curHasNewApplication = hasNewApplication
  hasNewApplication = false
  foreach (application in squadData.applications)
    if (application.isNewApplication == true)
      {
        hasNewApplication = true
        break
      }
  if (curHasNewApplication != hasNewApplication)
    ::broadcastEvent(squadEvent.NEW_APPLICATIONS)
}

g_squad_manager.addMember <- function addMember(uid)
{
  removeInvitedPlayers(uid)
  let memberData = SquadMember(uid)
  squadData.members[uid] <- memberData
  removeApplication(uid.tointeger())
  requestMemberData(uid)

  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

g_squad_manager.removeMember <- function removeMember(uid)
{
  let memberData = getMemberData(uid)
  if (memberData == null)
    return

  squadData.members.rawdelete(memberData.uid)
  ::update_contacts_by_list([memberData.getData()])

  ::broadcastEvent(squadEvent.STATUS_CHANGED)
  ::broadcastEvent(squadEvent.DATA_UPDATED)
}

g_squad_manager.updatePlatformInfo <- function updatePlatformInfo()
{
  let playerPlatforms = []
  let checksArray = [getMembers(), getInvitedPlayers(), getApplicationsToSquad()]
  foreach (idx, membersArray in checksArray)
    foreach (uid, member in membersArray)
    {
      if (platformModule.isXBoxPlayerName(member.name))
        ::u.appendOnce("xboxOne", playerPlatforms)
      else if (platformModule.isPS4PlayerName(member.name))
        ::u.appendOnce("ps4", playerPlatforms)
      else
        ::u.appendOnce("pc", playerPlatforms)
    }

  squadData.platformInfo = playerPlatforms
}

g_squad_manager.onSquadDataChanged <- function onSquadDataChanged(data = null)
{
  let alreadyInSquad = isInSquad()
  let resSquadData = ::getTblValue("squad", data)

  let newSquadId = ::getTblValue("id", resSquadData)
  if (::is_numeric(newSquadId)) //bad squad data
    squadData.id = newSquadId.tostring() //!!FIX ME: why this convertion to string?
  else if (!alreadyInSquad)
  {
    ::script_net_assert_once("no squad id", "Error: received squad data without squad id")
    ::msquad.leave() //leave broken squad
    setState(squadState.NOT_IN_SQUAD)
    return
  }

  let resMembers = ::getTblValue("members", resSquadData, [])
  let newMembersData = {}
  foreach(uidInt64 in resMembers)
  {
    if (!::is_numeric(uidInt64))
      continue

    let uid = uidInt64.tostring()
    if (uid in squadData.members)
      newMembersData[uid] <- squadData.members[uid]
    else
      newMembersData[uid] <- SquadMember(uid)

    if (uid != ::my_user_id_str)
      requestMemberData(uid)
  }
  squadData.members = newMembersData

  updateInvitedData(::getTblValue("invites", resSquadData, []))

  updateApplications(::getTblValue("applications", resSquadData, []))

  updatePlatformInfo()

  cyberCafeSquadMembersNum = getSameCyberCafeMembersNum()
  _parseCustomSquadData(::getTblValue("data", resSquadData, null))
  let chatInfo = ::getTblValue("chat", resSquadData, null)
  if (chatInfo != null)
  {
    let chatName = ::getTblValue("id", chatInfo, "")
    if (!::u.isEmpty(chatName))
      squadData.chatInfo.name = chatName
  }

  if (setState(squadState.IN_SQUAD)) {
    updateMyMemberData(getMyStateData())
    if (isSquadLeader()) {
      updatePresenceSquad()
      updateSquadData()
      setLeaderData(true)
    }
    if (getPresence().isInBattle)
      ::g_popups.add(::loc("squad/name"), ::loc("squad/wait_until_battle_end"))
  }
  updateCurrentWWOperation()
  joinSquadChatRoom()

  if (isSquadLeader() && !readyCheck())
    ::queues.leaveAllQueues()

  if (!alreadyInSquad)
    checkUpdateStatus(squadStatusUpdateState.MENU)

  updateLeaderGameModeId(resSquadData?.data.leaderGameModeId ?? "")
  squadData.leaderBattleRating = resSquadData?.data?.leaderBattleRating ?? 0

  ::broadcastEvent(squadEvent.DATA_UPDATED)

  let lastReadyness = isMeReady()
  let currentReadyness = lastReadyness || isSquadLeader()
  if (lastReadyness != currentReadyness || !alreadyInSquad)
    setReadyFlag(currentReadyness)

  let lastCrewsReadyness = isMyCrewsReady
  let currentCrewsReadyness = lastCrewsReadyness || isSquadLeader()
  if (lastCrewsReadyness != currentCrewsReadyness || !alreadyInSquad)
    setCrewsReadyFlag(currentCrewsReadyness)
}

g_squad_manager._parseCustomSquadData <- function _parseCustomSquadData(data)
{
  let chatInfo = ::getTblValue("chatInfo", data, null)
  if (chatInfo != null)
    squadData.chatInfo = chatInfo
  else
    squadData.chatInfo = {name = "", password = ""}

  let wwOperationInfo = ::getTblValue("wwOperationInfo", data, null)
  if (wwOperationInfo != null)
    squadData.wwOperationInfo = wwOperationInfo
  else
    squadData.wwOperationInfo = { id = -1, country = "", battle = null }

  let properties = ::getTblValue("properties", data)
  local property = null
  local isPropertyChange = false
  if (::u.isTable(properties))
    foreach(key, value in properties)
    {
      property = squadData?.properties?[key]
      if (::u.isEqual(property, value))
        continue

      squadData.properties[key] <- value
      isPropertyChange = true
    }
  if (isPropertyChange)
    ::broadcastEvent(squadEvent.PROPERTIES_CHANGED)
  squadData.presence = data?.presence ?? clone DEFAULT_SQUAD_PRESENCE
  squadData.psnSessionId = data?.psnSessionId ?? ""
}

g_squad_manager.checkMembersPkg <- function checkMembersPkg(pack) //return list of members dont have this pack
{
  let res = []
  if (!isInSquad())
    return res

  foreach(uid, memberData in squadData.members)
    if (memberData.missedPkg != null && ::isInArray(pack, memberData.missedPkg))
      res.append({ uid = uid, name = memberData.name })

  return res
}

g_squad_manager.getSquadMembersDataForContact <- function getSquadMembersDataForContact()
{
  let contactsData = []

  if (isInSquad())
  {
    foreach(uid, memberData in squadData.members)
      if (uid != ::my_user_id_str)
        contactsData.append(memberData.getData())
  }

  return contactsData
}

g_squad_manager.checkUpdateStatus <- function checkUpdateStatus(newStatus)
{
  if (lastUpdateStatus == newStatus || !isInSquad())
    return

  lastUpdateStatus = newStatus
  ::g_squad_utils.updateMyCountryData()
}

g_squad_manager.getSquadRoomId <- function getSquadRoomId()
{
  return ::getTblValue("sessionRoomId", getSquadLeaderData(), "")
}

g_squad_manager.updatePresenceSquad <- function updatePresenceSquad(shouldUpdateSquadData = false)
{
  if (!isSquadLeader())
    return

  let presence = ::g_presence_type.getCurrent()
  let presenceParams = presence.getParams()
  if (!::u.isEqual(squadData.presence, presenceParams))
  {
    squadData.presence = presenceParams
    if (shouldUpdateSquadData)
      updateSquadData()
  }
}

g_squad_manager.getPresence <- function getPresence()
{
  return ::g_presence_type.getByPresenceParams(squadData?.presence ?? {})
}

g_squad_manager.onEventUpdateEsFromHost <- function onEventUpdateEsFromHost(p)
{
  checkUpdateStatus(squadStatusUpdateState.BATTLE)
}

g_squad_manager.onEventNewSceneLoaded <- function onEventNewSceneLoaded(p)
{
  if (::isInMenu())
    checkUpdateStatus(squadStatusUpdateState.MENU)
}

g_squad_manager.onEventBattleEnded <- function onEventBattleEnded(p)
{
  if (::isInMenu())
    checkUpdateStatus(squadStatusUpdateState.MENU)
}

g_squad_manager.onEventSessionDestroyed <- function onEventSessionDestroyed(p)
{
  if (::isInMenu())
    checkUpdateStatus(squadStatusUpdateState.MENU)
}

g_squad_manager.onEventChatConnected <- function onEventChatConnected(params)
{
  joinSquadChatRoom()
}

g_squad_manager.onEventContactsUpdated <- function onEventContactsUpdated(params)
{
  local isChanged = false
  local contact = null
  foreach (uid, memberData in getInvitedPlayers())
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
  foreach (uid, memberData in getApplicationsToSquad())
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

g_squad_manager.onEventAvatarChanged <- function onEventAvatarChanged(params)
{
  updateMyMemberData()
}

g_squad_manager.onEventCrewTakeUnit <- function onEventCrewTakeUnit(params)
{
  updateMyMemberData()
}

g_squad_manager.onEventUnitRepaired <- function onEventUnitRepaired(p)
{
  ::g_squad_utils.updateMyCountryData()
}

g_squad_manager.onEventCrossPlayOptionChanged <- function onEventCrossPlayOptionChanged(p)
{
  updateMyMemberData()
}

g_squad_manager.onEventMatchingDisconnect <- function onEventMatchingDisconnect(params)
{
  reset()
}

g_squad_manager.onEventMatchingConnect <- function onEventMatchingConnect(params)
{
  reset()
  checkForSquad()
}

g_squad_manager.onEventLoginComplete <- function onEventLoginComplete(params)
{
  initSquadSizes()
  reset()
  checkForSquad()
}

g_squad_manager.onEventLoadingStateChange <- function onEventLoadingStateChange(params)
{
  if (::is_in_flight())
    setReadyFlag(false)

  updatePresenceSquad(true)
}

g_squad_manager.onEventWWLoadOperation <- function onEventWWLoadOperation(params)
{
  updateCurrentWWOperation()
  updatePresenceSquad()
  updateSquadData()
}

g_squad_manager.updateCurrentWWOperation <- function updateCurrentWWOperation()
{
  if (!isSquadLeader() || !::is_worldwar_enabled())
    return

  let wwOperationId = ::ww_get_operation_id()
  local country = ::get_profile_country_sq()
  if (wwOperationId > -1)
  {
    let wwOperation = ::g_ww_global_status_actions.getOperationById(wwOperationId)
    if (wwOperation)
      country = wwOperation.getMyAssignCountry() || country
  }

  squadData.wwOperationInfo.id = wwOperationId
  squadData.wwOperationInfo.country = country
}

g_squad_manager.startWWBattlePrepare <- function startWWBattlePrepare(battleId = null)
{
  if (!isSquadLeader())
    return

  if (getWwOperationBattle() == battleId)
    return

  squadData.wwOperationInfo.battle <- battleId
  squadData.wwOperationInfo.id = ::ww_get_operation_id()
  squadData.wwOperationInfo.country = ::get_profile_country_sq()

  updatePresenceSquad()
  updateSquadData()
}

g_squad_manager.cancelWwBattlePrepare <- function cancelWwBattlePrepare()
{
  startWWBattlePrepare() // cancel battle prepare if no args
}

g_squad_manager.onEventWWStopWorldWar <- function onEventWWStopWorldWar(params)
{
  if (getWwOperationId() == -1)
    return

  if (!isInSquad() || isSquadLeader()) {
    squadData.wwOperationInfo = { id = -1, country = "", battle = null }
  }
  updatePresenceSquad()
  updateSquadData()
}

g_squad_manager.onEventLobbyStatusChange <- function onEventLobbyStatusChange(params)
{
  if (!::SessionLobby.isInRoom())
    setReadyFlag(false)

  updateMyMemberData()
  updatePresenceSquad(true)
}

g_squad_manager.onEventQueueChangeState <- function onEventQueueChangeState(params)
{
  if (!::queues.hasActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE))
    setCrewsReadyFlag(false)

  updatePresenceSquad(true)
}

g_squad_manager.isMemberDataVehicleChanged <- function isMemberDataVehicleChanged(currentData, receivedData)
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

g_squad_manager.onEventBattleRatingChanged <- function onEventBattleRatingChanged(params)
{
  setLeaderData()
}

g_squad_manager.onEventCurrentGameModeIdChanged <- function onEventCurrentGameModeIdChanged(params)
{
  setLeaderData(false)
}

g_squad_manager.onEventEventsDataUpdated <- function onEventEventsDataUpdated(params)
{
  setLeaderData(false)
}

g_squad_manager.setLeaderData <- function setLeaderData(isActualBR = true)
{
  if (!isSquadLeader())
    return

  let currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
  if (!isActualBR && squadData.leaderGameModeId == currentGameModeId)
    return

  let data = clone squadData
  data.leaderBattleRating = isActualBR ? battleRating.recentBR.value : 0
  data.leaderGameModeId = isActualBR ? battleRating.recentBrGameModeId.value : currentGameModeId
  setSquadData(data)
}

g_squad_manager.getMembersNotAllowedInWorldWar <- function getMembersNotAllowedInWorldWar()
{
  let res = []
  foreach (uid, member in getMembers())
    if (!member.isWorldWarAvailable)
      res.append(member)

  return res
}

::cross_call_api.squad_manger <- ::g_squad_manager

::g_script_reloader.registerPersistentDataFromRoot("g_squad_manager")

::subscribe_handler(::g_squad_manager, ::g_listener_priority.DEFAULT_HANDLER)
