let sharedWatched = require("%globalScripts/sharedWatched.nut")

let canHoldBreath = sharedWatched("canHoldBreath", @() false)
let canScopeChange = sharedWatched("canScopeChange", @() false)

return {
  canHoldBreath
  canScopeChange
}