import "%globalScripts/sharedWatched.nut" as sharedWatched

let canHoldBreath = sharedWatched("canHoldBreath", @() false)
let canScopeChange = sharedWatched("canScopeChange", @() false)
let canSightChange = sharedWatched("canSightChange", @() false)
let canBipodFocus = sharedWatched("canBipodFocus", @() false)

return {
  canHoldBreath
  canScopeChange
  canSightChange
  canBipodFocus
}