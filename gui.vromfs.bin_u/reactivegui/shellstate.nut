local interopGet = require("daRg/helpers/interopGen.nut")

local shellState = {
  altitude = Watched(0)
  remainingDist = Watched(-1)
  isAimCamera = Watched(false)
  isOperated = Watched(false)
  isActiveSensor = Watched(false)
}


interopGet({
  stateTable = shellState
  prefix = "shell"
  postfix = "Update"
})


return shellState
