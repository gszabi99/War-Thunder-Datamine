from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")

let aamAimState = {
  GimbalX = Watched(0.0)
  GimbalY = Watched(0.0)
  GimbalSize = Watched(0.0)
  GimbalVisible = Watched(false)

  TrackerX = Watched(0.0)
  TrackerY = Watched(0.0)
  TrackerSize = Watched(0.0)
  TrackerVisible = Watched(false)

  TrackedTargetDistance = Watched(0.0)

  IlsTrackerX = Watched(0.0)
  IlsTrackerY = Watched(0.0)
  IlsTrackerVisible = Watched(false)

  GuidanceLockState = Watched(-1)
  GuidanceLockSnr = Watched(0.0)

  AamSightShadowOpacity = Watched(1.0)
  AamSightOpacity = Watched(1.0)
  AamSightLineWidthFactor = Watched(1.0)
  AamSightShadowLineWidthFactor = Watched(1.0)

  HmdVisibleAAM = Watched(false)
  HmdDesignation = Watched(false)
  HmdFovMult = Watched(1.0)

  HasTOFInHud = Watched(true)
}

interopGen({
  stateTable = aamAimState
  prefix = "aamAim"
  postfix = "Update"
})

return aamAimState
