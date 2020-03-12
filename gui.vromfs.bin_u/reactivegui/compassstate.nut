local interopGen = require("daRg/helpers/interopGen.nut")

local compassState = {
  CompassValue = Watched(0)
}

interopGen({
  stateTable = compassState
  prefix = "compass"
  postfix = "Update"
})

return compassState
