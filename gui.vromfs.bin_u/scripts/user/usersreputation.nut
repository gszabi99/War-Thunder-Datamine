from "%scripts/dagui_library.nut" import *
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { charRequestJson } = require("%scripts/tasker.nut")
let { get_charserver_time_sec } = require("chard")
let { get_time_msec } = require("dagor.time")
let timeBase = require("%appGlobals/timeLoc.nut")
let { get_gui_option } = require("guiOptions")
let { USEROPT_CHAT_REPUTATION_FILTER } = require("%scripts/options/optionsExtNames.nut")

const REQUEST_TIMEOUT = 1500
const USER_REPUTATION_UPDATE_PERIOD = 3600000 
const FORGET_CLAIMS_PERIOD = 30 

enum reputationType {
  REQUEST,
  UNKNOWN,
  GOOD,
  BAD
}

let claimsForBadReputation = {
  [1] = 20,
  [3] = 30,
  [7] = 50,
  [30] = 100
}

let userUpdateReputationEventName = "UserReputationUpdated"
let usersReputation = {}
let requests = {}
local requestRepTimeoutTimer = null

function generateDefaultReputation(userId) {
  let rep = {
    data = null,
    userId,
    updateTime = 0,
    reputation = reputationType.REQUEST
  }
  usersReputation[userId] <- rep
}


function calcReputaionByClaims(data) {
  let claimsArr = data?.amount
  if (claimsArr == null)
    return reputationType.GOOD

  local checkedDay = (get_charserver_time_sec() - data.day) / timeBase.TIME_DAY_IN_SECONDS
  let claimsDaysCount = min(claimsArr.len(), FORGET_CLAIMS_PERIOD - checkedDay)
  local claimsCount = 0
  for (local i = 0; i < FORGET_CLAIMS_PERIOD; i++) {
    claimsCount += claimsArr?[i] ?? 0
    checkedDay++
    if (claimsForBadReputation?[checkedDay] != null) {
      if (claimsCount >= claimsForBadReputation[checkedDay])
        return reputationType.BAD
      if (i >= claimsDaysCount)
        return reputationType.GOOD
    }
  }
  return reputationType.GOOD
}

function updateReputation(userId, data, forcedReputation = null) {
  let oldReputation = usersReputation[userId].reputation
  usersReputation[userId].updateTime = get_time_msec()
  let newReputation = data == null ? forcedReputation : calcReputaionByClaims(data)
  if (oldReputation == newReputation)
    return

  usersReputation[userId].reputation = newReputation
  usersReputation[userId].data = data
  broadcastEvent(userUpdateReputationEventName, {
    [userId] = {old = oldReputation, new = newReputation}
  })
}

function completeTimeoutRequests() {
  let isTimeoutEndForUsers = []
  foreach (uid, request in requests) {
    if (get_time_msec() - request.time < REQUEST_TIMEOUT)
      continue
    if (usersReputation[uid].reputation == reputationType.REQUEST)
      updateReputation(uid, null, reputationType.UNKNOWN)
    isTimeoutEndForUsers.append(uid)
  }
  foreach (uid in isTimeoutEndForUsers)
    requests.$rawdelete(uid)
}

function onRequestComplete(data, userId) {
  if (requests?[userId])
    requests.$rawdelete(userId)
  updateReputation(userId, data)
  completeTimeoutRequests()
}

function onRequestError(_error, userId) {
  if (requests?[userId])
    requests.$rawdelete(userId)
  completeTimeoutRequests()
  updateReputation(userId, null, reputationType.UNKNOWN)
  log($"Failed request reputation for {userId}")
}

function requestUserReputation(userId) {
  if (requests?[userId] != null)
    return

  clearTimer(requestRepTimeoutTimer)
  requestRepTimeoutTimer = setTimeout(1, completeTimeoutRequests)
  if (requests.len() > 0)
    completeTimeoutRequests()

  requests[userId] <- {time = get_time_msec()}

  let blk = DataBlock()
  blk.userid <- userId
  charRequestJson("ano_get_complaints_in_chat", blk, null, @(data) onRequestComplete(data, userId), @(data) onRequestError(data, userId))
}

function getUserReputation(userId) {
  let data = usersReputation?[userId]
  if (data == null) {
    generateDefaultReputation(userId)
    requestUserReputation(userId)
    return reputationType.REQUEST
  }
  if (data.reputation != reputationType.REQUEST
      && get_time_msec() - data.updateTime > USER_REPUTATION_UPDATE_PERIOD
      && requests?[userId] == null
    ) {
    requestUserReputation(userId)
  }

  return usersReputation[userId].reputation
}

function hasChatReputationFilter() {
  return hasFeature("ChatReputationFilter")
    && get_gui_option(USEROPT_CHAT_REPUTATION_FILTER).value
}

function gerReputationBlockMessage() {
  return loc("chat/blokedByChatRules")
}

return {
  userUpdateReputationEventName
  reputationType
  getUserReputation
  hasChatReputationFilter
  gerReputationBlockMessage
}