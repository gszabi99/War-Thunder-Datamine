from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")

let agmAimState = {
  TrackerX = Watched(0.0)
  TrackerY = Watched(0.0)
  TrackerSize = Watched(0.0)
  TrackerVisible = Watched(false)
  TrackerAngle = Watched(0.0)
  TrackedTargetName = Watched("")
  IsTrackerLoosingIcon = Watched(false)

  IsAntiRadiation = Watched(false)
  SightX = Watched(0.0)
  SightY = Watched(0.0)
  SightSize = Watched(0.0)
  SightVisible = Watched(false)

  GuidanceLockState = Watched(-1)
  GuidanceLockStateBlinked = Watched(-1)
  PointIsTarget = Watched(false)

  ReleaseTargetCursorX = Watched(0.0)
  ReleaseTargetCursorY = Watched(0.0)
  LockReleaseRadiusH = Watched(0.0)
  LockReleaseRadiusW = Watched(0.0)

  MinSightFovScrSize = Watched(0.0)
}

interopGen({
  stateTable = agmAimState
  prefix = "agmAim"
  postfix = "Update"
})

return agmAimState
