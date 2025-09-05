from "%scripts/dagui_library.nut" import *
let { isChatReputationFilterEnabled } = require("%scripts/options/optionsExt.nut")
let { ReputationType } = require("%globalScripts/chatState.nut")

let claimsForBadReputation = {
  [1] = 20,
  [3] = 30,
  [7] = 50,
  [30] = 100
}

let usersReputationById = {}

function calcReputaionByClaims(claimsData) {
  foreach (day, claimsCount in claimsData) {
    if (claimsCount >= claimsForBadReputation[day])
      return ReputationType.REP_BAD
  }
  return ReputationType.REP_GOOD
}

function getUserReputation(userId) {
  return usersReputationById?[userId].reputation ?? ReputationType.REP_GOOD
}


function updateUserReputationData(userId, stringData) {
  if (userId == null)
    return
  let needUpdateReputation = usersReputationById?[userId].stringData != stringData
  if (!needUpdateReputation)
    return

  if (stringData == null) {
    usersReputationById[userId] <- {stringData, reputation = ReputationType.REP_GOOD}
    return
  }

  let repByDays = stringData.split(", ")
  let claimsData = {}
  local idx = 0
  foreach ( day, _rep in claimsForBadReputation )
    claimsData[day] <- to_integer_safe(repByDays?[idx++], 0 , false)

  usersReputationById[userId] <- {stringData, reputation = calcReputaionByClaims(claimsData)}
}

function hasChatReputationFilter() {
  return isChatReputationFilterEnabled.get()
}

function getReputationBlockMessage() {
  return loc("chat/blokedByChatRules")
}

return {
  getUserReputation
  hasChatReputationFilter
  getReputationBlockMessage
  updateUserReputationData
}