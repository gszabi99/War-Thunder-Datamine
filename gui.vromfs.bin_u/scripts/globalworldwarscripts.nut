let { isWorldWarEnabled = @() false, canPlayWorldwar = @() false,
  getCantPlayWorldwarReasonText = @() ""
} = require_optional("%scripts/worldWar/worldWarGlobalStates.nut")
let { isWWSeasonActive = @() false, isWwOperationInviteEnable = @() false
} = require_optional("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { saveLastPlayed = @(_opId, _opCountry) null } = require_optional("%scripts/worldWar/worldWarStates.nut")

return {
  isWorldWarEnabled
  canPlayWorldwar
  getCantPlayWorldwarReasonText
  isWWSeasonActive
  isWwOperationInviteEnable
  saveLastPlayed
}
