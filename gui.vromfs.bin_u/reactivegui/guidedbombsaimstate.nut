let interopGen = require("interopGen.nut")

let guidedBombsAimState = {
  TrackerX = Watched(0.0)
  TrackerY = Watched(0.0)
  TrackerSize = Watched(0.0)
  TrackerVisible = Watched(false)
  TrackerAngle = Watched(0.0)

  GuidanceLockState = Watched(-1)
}

interopGen({
  stateTable = guidedBombsAimState
  prefix = "guidedBombsAim"
  postfix = "Update"
})

return guidedBombsAimState
