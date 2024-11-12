let { isWorldWarEnabled = @() false, canPlayWorldwar = @() false,
  getCantPlayWorldwarReasonText = @() ""
} = require_optional("%scripts/worldWar/worldWarGlobalStates.nut")

return {
  isWorldWarEnabled
  canPlayWorldwar
  getCantPlayWorldwarReasonText
}
