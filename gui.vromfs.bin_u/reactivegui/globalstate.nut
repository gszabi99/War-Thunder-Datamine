local interopGen = require("interopGen.nut")

local state = persist("globalState", @() {
  isInFlight = Watched(false)
})


interopGen({
  postfix = "Update"
  stateTable = state
})


return state