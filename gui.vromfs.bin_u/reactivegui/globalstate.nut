local interopGen = require("daRg/helpers/interopGen.nut")

local state = persist("globalState", @() {
  isInFlight = Watched(false)
})


interopGen({
  postfix = "Update"
  stateTable = state
})


return state