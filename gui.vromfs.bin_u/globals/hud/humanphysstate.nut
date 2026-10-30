import "%globalScripts/sharedWatched.nut" as sharedWatched

let canHoldBreath = sharedWatched("canHoldBreath", @() false)
let canScopeChange = sharedWatched("canScopeChange", @() false)
let canSightChange = sharedWatched("canSightChange", @() false)
let canBipodFocus = sharedWatched("canBipodFocus", @() false)
let canChangeBipodMountPoint = sharedWatched("canChangeBipodMountPoint", @() false)
let canBoltActionObserve = sharedWatched("canBoltActionObserve", @() false)

return freeze({
  canHoldBreath
  canScopeChange
  canSightChange
  canBipodFocus
  canChangeBipodMountPoint
  canBoltActionObserve
})