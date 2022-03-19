local interopGen = require("interopGen.nut")

local agmAimState = {
  TrackerX = Watched(0.0)
  TrackerY = Watched(0.0)
  TrackerSize = Watched(0.0)
  TrackerVisible = Watched(false)
  TrackerAngle = Watched(0.0)

  GuidanceLockState = Watched(-1)
}

interopGen({
  stateTable = agmAimState
  prefix = "agmAim"
  postfix = "Update"
})

return agmAimState
