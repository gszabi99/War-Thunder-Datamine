local interopGen = require("reactiveGui/interopGen.nut")

local IsCommanderViewAimModeActive = Watched(false)

local tankState = {
  IsCommanderViewAimModeActive
}

interopGen({
  stateTable = tankState
  prefix = "tank"
  postfix = "Update"
})

return tankState
