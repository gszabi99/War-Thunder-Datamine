from "%scripts/dagui_library.nut" import *

let { is_myself_anyof_moderators } = require("%scripts/utils_sa.nut")
let { get_time_msec } = require("dagor.time")
let { get_mp_session_id_str } = require("multiplayer")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")

const timeToComplainExpiredMS = 900000 

enum canComplainCheckResults {
  CAN_COMPLAIN = 0
  TIME_NOT_EXPIRED = 1
  ALREADY_COMPLAIN_IN_BATTLE= 2
}

let complaintsCache = {






}

let isComplaintTimerExpired = @(uid) ( get_time_msec() - complaintsCache[uid].lastComplaintTime ) > timeToComplainExpiredMS

function getCanComplainOnUser(uid) {
  if (is_myself_anyof_moderators() || !complaintsCache?[uid])
    return canComplainCheckResults.CAN_COMPLAIN
  let curSessionId = isInBattleState.get() ? get_mp_session_id_str() : null
  if (curSessionId && curSessionId != "")
    return complaintsCache[uid].sessionIds.contains(curSessionId) ? canComplainCheckResults.ALREADY_COMPLAIN_IN_BATTLE
      : canComplainCheckResults.CAN_COMPLAIN
  return isComplaintTimerExpired(uid) ? canComplainCheckResults.CAN_COMPLAIN
    : canComplainCheckResults.TIME_NOT_EXPIRED
}

function cacheComplaintOnUser(uid, sessionId) {
  if (!complaintsCache?[uid])
    complaintsCache[uid] <- { sessionIds = [], lastComplaintTime = 0 }
  if (sessionId)
    complaintsCache[uid].sessionIds.append(sessionId)
  complaintsCache[uid].lastComplaintTime = get_time_msec()
}

function showModalWndCantComplainReason(reasonId) {
  let reasonLocId = reasonId == canComplainCheckResults.TIME_NOT_EXPIRED ? "time_not_expired"
    : reasonId == canComplainCheckResults.ALREADY_COMPLAIN_IN_BATTLE ? "already_complained_in_battle"
    : ""
  if (reasonLocId != "")
    showInfoMsgBox(loc($"msgbox/complaint/{reasonLocId}"))
}

function checkCanComplainAndProceed(uid, isOkFunction) {
  let canComplain = getCanComplainOnUser(uid)
  if(canComplain == canComplainCheckResults.CAN_COMPLAIN)
    isOkFunction()
  else
    showModalWndCantComplainReason(canComplain)
}

return {
  cacheComplaintOnUser
  checkCanComplainAndProceed
}