local interopGen = require("interopGen.nut")

local state = persist("networkState", @(){
  isMultiplayer = Watched(false)
})

interopGen({
  stateTable = state
  prefix = "network"
  postfix = "Update"
})

return state