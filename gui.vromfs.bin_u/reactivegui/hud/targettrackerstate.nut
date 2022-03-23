let interopGen = require("%rGui/interopGen.nut")

let HasTargetTracker = Watched(false)
let IsSightLocked = Watched(false)
let IsTargetTracked = Watched(false)
let AimCorrectionEnabled = Watched(false)

let TargetRadius = Watched(0.0)
let TargetAge = Watched(0.0)

let TargetX = Watched(0.0)
let TargetY = Watched(0.0)


let targetTrackerState = {
  HasTargetTracker
  IsSightLocked
  IsTargetTracked
  AimCorrectionEnabled

  TargetRadius
  TargetAge

  TargetX
  TargetY
}

interopGen({
  stateTable = targetTrackerState
  prefix = "targetTracker"
  postfix = "Update"
})

return targetTrackerState
