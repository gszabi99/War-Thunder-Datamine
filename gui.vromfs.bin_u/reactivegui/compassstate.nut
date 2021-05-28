local interopGen = require("interopGen.nut")

local compassState = {
  CompassValue = Watched(0)
}

interopGen({
  stateTable = compassState
  prefix = "compass"
  postfix = "Update"
})

return compassState
