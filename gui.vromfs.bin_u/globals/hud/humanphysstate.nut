let sharedWatched = require("%globalScripts/sharedWatched.nut")

let canHoldBreath = sharedWatched("canHoldBreath", @() false)
let canScopeChange = sharedWatched("canScopeChange", @() false)
let canSightChange = sharedWatched("canSightChange", @() false)

return {
  canHoldBreath
  canScopeChange
  canSightChange
}