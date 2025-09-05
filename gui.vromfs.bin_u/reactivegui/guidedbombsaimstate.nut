from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")

let guidedBombsAimState = {
  TrackerX = Watched(0.0)
  TrackerY = Watched(0.0)
  TrackerSize = Watched(0.0)
  TrackerVisible = Watched(false)
  TrackerAngle = Watched(0.0)

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
  stateTable = guidedBombsAimState
  prefix = "guidedBombsAim"
  postfix = "Update"
})

return guidedBombsAimState
