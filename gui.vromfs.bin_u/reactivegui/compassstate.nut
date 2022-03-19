local interopGen = require("interopGen.nut")

local compassState = {
  HasCompass = Watched(true)
  CompassValue = Watched(0)
}

interopGen({
  stateTable = compassState
  prefix = "compass"
  postfix = "Update"
})

return compassState
