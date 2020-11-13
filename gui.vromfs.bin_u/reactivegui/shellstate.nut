local interopGet = require("daRg/helpers/interopGen.nut")

local shellState = {
  altitude = Watched(0)
  remainingDist = Watched(-1)
  isAimCamera = Watched(false)

  isOperated = Watched(false)
  isTrackingTarget = Watched(false)

  GimbalX = Watched(0.0)
  GimbalY = Watched(0.0)
  GimbalSize = Watched(0.0)
  IsGimbalVisible = Watched(false)

  TrackerX = Watched(0.0)
  TrackerY = Watched(0.0)
  TrackerSize = Watched(0.0)
  IsTrackerVisible = Watched(false)

  isActiveSensor = Watched(false)
  wireLoseTime = Watched(-1)
  isWireConnected = Watched(false)
}


interopGet({
  stateTable = shellState
  prefix = "shell"
  postfix = "Update"
})


return shellState
