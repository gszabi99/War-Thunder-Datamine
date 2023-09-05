from "%rGui/globals/ui_library.nut" import *
let interopGen = require("%rGui/interopGen.nut")

let tankDebugState = {
  Visible = Watched(false)
  Rpm = Watched(0)
  Omega = Watched(0)
  MaxOmega = Watched(0)
  MaxRpm = Watched(0)
  MinRpm = Watched(0)
  Speed = Watched(0.0)
  GearCount = Watched(0)
  NeutralGearIdx = Watched(0)
  CurrentGear = Watched(0)
  GearMaxSpeed = Watched([])
  GearRatio = Watched([])
  DDGearRatio = Watched(0.0)
  LTrackSpeed = Watched(0.0)
  RTrackSpeed = Watched(0.0)
  HillClimbKx = Watched(0.0)
  HillClimbKy = Watched(0.0)
  TrackFricFront = Watched(0.0)
  TrackFricFrontSlide = Watched(0.0)
  TrackFricSideX = Watched(0.0)
  TrackFricSideY = Watched(0.0)
  TrackFricSideZ = Watched(0.0)
  TrackFricSideW = Watched(0.0)
  TrackFricSideProjLerp = Watched(0.0)
  TrackForceVal = Watched(0.0)
  TrackForceDirUp = Watched(0.0)
  TrackForceDirForward = Watched(0.0)
  WorldForceVal = Watched(0.0)
  WorldForceDirUp = Watched(0.0)
  WorldForceDirForward = Watched(0.0)
  LeftTrackSlide = Watched(false)
  RightTrackSlide = Watched(false)
  Throttle = Watched(0.0)
  Steering = Watched(0.0)
  LeftBrake = Watched(0.0)
  RightBrake = Watched(0.0)
  ClutchLeft = Watched(0.0)
  ClutchRight = Watched(0.0)
  TorqArray = Watched([])
  MaxTorq = Watched(0.0)
}

interopGen({
  stateTable = tankDebugState
  prefix = "tds"
  postfix = "Update"
})

return tankDebugState