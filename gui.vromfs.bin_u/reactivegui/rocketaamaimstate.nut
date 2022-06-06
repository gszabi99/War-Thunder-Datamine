let interopGen = require("interopGen.nut")

let aamAimState = {
  GimbalX = Watched(0.0)
  GimbalY = Watched(0.0)
  GimbalSize = Watched(0.0)
  GimbalVisible = Watched(false)

  TrackerX = Watched(0.0)
  TrackerY = Watched(0.0)
  TrackerSize = Watched(0.0)
  TrackerVisible = Watched(false)

  IlsTrackerX = Watched(0.0)
  IlsTrackerY = Watched(0.0)
  IlsTrackerVisible = Watched(false)

  GuidanceLockState = Watched(-1)
}

interopGen({
  stateTable = aamAimState
  prefix = "aamAim"
  postfix = "Update"
})

return aamAimState
