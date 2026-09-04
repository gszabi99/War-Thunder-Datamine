from "matching.errors" import INVALID_SQUAD_ID
from "%sqstd/platform.nut" import getPlatformAlias
from "%scripts/dagui_natives.nut" import get_cyber_cafe_level, get_cyber_cafe_id
from "%scripts/dagui_library.nut" import *
from "%scripts/squads/squadsConsts.nut" import squadState, squadMemberState, squadStatusUpdateState, SQUAD_REQEST_TIMEOUT

let { userIdStr } = require("%scripts/user/profileStates.nut")
let { getRealName } = require("%scripts/user/nameMapping.nut")
let { isMpSquadChatAllowed } = require("%scripts/matchingRooms/sessionLobbyState.nut")





let DEFAULT_SQUAD_PROPERTIES = {
  maxMembers = 4
  isApplicationsEnabled = true
}
let DEFAULT_SQUAD_CHAT_INFO = { name = "", password = "" }
let DEFAULT_SQUAD_WW_OPERATION_INFO = { id = -1, country = "", battle = null }

let squadData = persist("squadData", @() {
  id = ""
  members = {}
  invitedPlayers = {}
  applications = {}
  platformInfo = []
  chatInfo = clone DEFAULT_SQUAD_CHAT_INFO
  wwOperationInfo = clone DEFAULT_SQUAD_WW_OPERATION_INFO
  properties = clone DEFAULT_SQUAD_PROPERTIES
  presence = {} 
  psnSessionId = ""
  leaderBattleRating = 0
  leaderGameModeId = ""
})
let processSquadDataPresence = @(func) func(squadData.presence)
let processSquadDataProperties = @(func) func(squadData.properties)
let processSquadDataMembers = @(func) func(squadData.members)
let processSquadDataWwOperationInfo = @(func) func(squadData.wwOperationInfo)
let processSquadDataChatInfo = @(func) func(squadData.chatInfo)
let processSquadDataPlatformInfo = @(func) func(squadData.platformInfo)
let processSquadDataApplications = @(func) func(squadData.applications)
let processSquadDataInvitedPlayers = @(func) func(squadData.invitedPlayers)

let getSquadData = @() squadData
let updSquadData = @(k, v) squadData[k] = v

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
  denyAllApplicationsInProgress = false
  membersNames = {}
  state = squadState.NOT_IN_SQUAD
})

let getSmData = @() smData
let updSmData = @(k, v) smData[k] = v
let processSmDataDelayedInvites = @(func) func(smData.delayedInvites)
let processSmDataSquadSizesList = @(func) func(smData.squadSizesList)
let processSmDataMembersNames = @(func) func(smData.membersNames)

function isEqualSquadId(squadId1, squadId2) {
  return squadId1 != INVALID_SQUAD_ID && squadId1 == squadId2
}

let isInSquad = @(forChat = false) (forChat && !isMpSquadChatAllowed()) ? false
  : smData.state == squadState.IN_SQUAD
let isMeReady = @() smData.meReady
let getState = @() smData.state
let getIsMyCrewsReady = @() smData.isMyCrewsReady
let getLeaderUid = @() squadData.id
let isSquadLeader = @() isInSquad() && getLeaderUid() == userIdStr.get()
let isSquadMember = @() isInSquad() && !isSquadLeader()
let getMembers = @() squadData.members
let getInvitedPlayers = @() squadData.invitedPlayers
let getApplicationsToSquad = @() squadData.applications
let getSquadRoomName = @() squadData.chatInfo.name
let getSquadRoomPassword = @() squadData.chatInfo.password
let getWwOperationId = @() squadData.wwOperationInfo?.id ?? -1
let getWwOperationCountry = @() squadData.wwOperationInfo?.country ?? ""
let getWwOperationBattle = @() squadData.wwOperationInfo?.battle
let getLeaderGameModeId = @() squadData?.leaderGameModeId ?? ""
let getLeaderBattleRating = @() squadData?.leaderBattleRating ?? 0
let getMaxSquadSize = @() squadData.properties.maxMembers
let getMemberData = @(uid) !isInSquad() ? null : squadData.members?[uid]
let isMySquadMember = @(name) (smData.membersNames?[name] != null)
  || (smData.membersNames?[getRealName(name)] != null)
let isMySquadMemberById = @(id) squadData.members?[id] != null

function getMembersByOnline(online = true) {
  let res = []
  if (!isInSquad())
    return res

  foreach (_uid, memberData in squadData.members)
    if (memberData.online == online)
      res.append(memberData)

  return res
}

let getOfflineMembers = @() getMembersByOnline(false)
let getOnlineMembers = @() getMembersByOnline(true)

function getOnlineMembersCount() {
  if (!isInSquad())
    return 1
  local res = 0
  foreach (member in squadData.members)
    if (member.online)
      res++
  return res
}

function getSquadSize(includeInvites = false) {
  if (!isInSquad())
    return 0

  local res = squadData.members.len()
  if (includeInvites) {
    res += getInvitedPlayers().len()
    res += getApplicationsToSquad().len()
  }
  return res
}

function isNotAloneOnline() {
  if (!isInSquad())
    return false

  if (squadData.members.len() == 1)
    return false

  foreach (uid, memberData in squadData.members)
    if (uid != userIdStr.get() && memberData.online == true)
      return true

  return false
}

function readyCheck(considerInvitedPlayers = false) {
  if (!isInSquad())
    return false

  foreach (_uid, memberData in squadData.members)
    if (memberData.online == true && memberData.isReady == false)
      return false

  if (considerInvitedPlayers && squadData.invitedPlayers.len() > 0)
    return false

  return  true
}

function getPlayerStatusInMySquad(uid) {
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

function getSameCyberCafeMembersNum() {
  if (smData.cyberCafeSquadMembersNum >= 0)
    return smData.cyberCafeSquadMembersNum

  local num = 0
  if (isInSquad() && squadData.members && get_cyber_cafe_level() > 0) {
    let myCyberCafeId = get_cyber_cafe_id()
    foreach (_uid, memberData in squadData.members)
      if (myCyberCafeId == memberData.cyberCafeId)
        num++
  }

  smData.cyberCafeSquadMembersNum = num
  return num
}

function getDiffCrossPlayConditionMembers() {
  let diffMembers = []
  if (!isInSquad())
    return { diffMembers }

  let leader = squadData.members[getLeaderUid()]
  let leaderPlatformGroup = getPlatformAlias(leader.platform)

  foreach (_uid, memberData in squadData.members) {
    if (leader.crossplay == true) {
      if (memberData.crossplay == false)
        diffMembers.append(memberData)
      continue
    }
    if (leader.isGdkClient && memberData.isGdkClient)
      continue
    let memberPlatformGroup = getPlatformAlias(memberData.platform)
    if ((leader.isGdkClient && !memberData.isGdkClient)
      || memberPlatformGroup != leaderPlatformGroup)
        diffMembers.append(memberData)
  }
  return { diffMembers, isLeaderCrossplayOn = leader.crossplay }
}

function checkMembersPkg(pack) { 
  let res = []
  if (!isInSquad())
    return res

  foreach (uid, memberData in squadData.members)
    if (memberData.missedPkg != null && isInArray(pack, memberData.missedPkg))
      res.append({ uid = uid, name = memberData.name })

  return res
}

function getSquadMembersDataForContact() {
  let contactsData = []

  if (isInSquad()) {
    foreach (uid, memberData in squadData.members)
      if (uid != userIdStr.get())
        contactsData.append(memberData.getData())
  }

  return contactsData
}

return freeze({
  isEqualSquadId

  getSquadData
  updSquadData
  processSquadDataPresence
  processSquadDataProperties
  processSquadDataMembers
  processSquadDataWwOperationInfo
  processSquadDataChatInfo
  processSquadDataPlatformInfo
  processSquadDataApplications
  processSquadDataInvitedPlayers

  getSmData
  updSmData
  processSmDataDelayedInvites
  processSmDataMembersNames
  processSmDataSquadSizesList
  DEFAULT_SQUAD_PROPERTIES
  DEFAULT_SQUAD_CHAT_INFO
  DEFAULT_SQUAD_WW_OPERATION_INFO

  isInSquad
  isMeReady
  isSquadLeader
  isSquadMember
  isNotAloneOnline
  getState
  getIsMyCrewsReady
  getLeaderUid
  getMembers
  getInvitedPlayers
  getApplicationsToSquad
  getSquadRoomName
  getSquadRoomPassword
  getWwOperationId
  getWwOperationCountry
  getWwOperationBattle
  getLeaderGameModeId
  getLeaderBattleRating
  getMaxSquadSize
  getMemberData
  getMembersByOnline
  getOfflineMembers
  getOnlineMembers
  getOnlineMembersCount
  getSquadSize
  getSquadMembersDataForContact
  checkMembersPkg
  readyCheck
  isMySquadMember
  isMySquadMemberById
  getPlayerStatusInMySquad
  getSameCyberCafeMembersNum
  getDiffCrossPlayConditionMembers
})
