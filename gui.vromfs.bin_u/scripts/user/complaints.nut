from "%scripts/dagui_library.nut" import *
let { get_time_msec } = require("dagor.time")

const timeToComplainExpiredMS = 900000 // 15 minutes

enum canComplainCheckResults {
  CAN_COMPLAIN = 0
  TIME_NOT_EXPIRED = 1
  ALREADY_COMPLAIN_IN_BATTLE= 2
}

let complaintsCache = {
/*
uid = {
  sessionIds = [sessionId1, sessionId2, ...] - user can complain on other user only once during each session
  // lastComplaintTime = 0 - if user not in battle he can complain on other user only once in 15 minutes
}
*/
}

let isComplaintTimerExpired = @(uid) ( get_time_msec() - complaintsCache[uid].lastComplaintTime ) > timeToComplainExpiredMS

function getCanComplainOnUser(uid, sessionId) {
  if (!complaintsCache?[uid])
    return canComplainCheckResults.CAN_COMPLAIN
  if (sessionId && sessionId != "")
    return complaintsCache[uid].sessionIds.contains(sessionId) ? canComplainCheckResults.ALREADY_COMPLAIN_IN_BATTLE
      : canComplainCheckResults.CAN_COMPLAIN
  return isComplaintTimerExpired(uid) ? canComplainCheckResults.CAN_COMPLAIN
    : canComplainCheckResults.TIME_NOT_EXPIRED
}

function cacheComplaintOnUser(uid, sessionId) {
  if (!complaintsCache?[uid])
    complaintsCache[uid] <- { sessionIds = [], lastComplaintTime = 0 }
  if (sessionId)
    complaintsCache[uid].sessionIds.append(sessionId)
  complaintsCache[uid].lastComplaintTime = get_time_msec()}

function showModalWndCantComplainReason(reasonId) {
  let reasonLocId = reasonId == canComplainCheckResults.TIME_NOT_EXPIRED ? "time_not_expired"
    : reasonId == canComplainCheckResults.ALREADY_COMPLAIN_IN_BATTLE ? "already_complained_in_battle"
    : ""
  if (reasonLocId != "")
    showInfoMsgBox(loc($"msgbox/complaint/{reasonLocId}"))
}

function checkCanComplainAndProceed(uid, sessionId, isOkFunction) {
  let canComplain = getCanComplainOnUser(uid, sessionId)
  if(canComplain == canComplainCheckResults.CAN_COMPLAIN)
    isOkFunction()
  else
    showModalWndCantComplainReason(canComplain)
}

return {
  cacheComplaintOnUser
  checkCanComplainAndProceed
}