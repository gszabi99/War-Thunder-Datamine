from "%rGui/globals/ui_library.nut" import *

let interopGen = require("interopGen.nut")

let state = persist("globalState", @() {
  isInFlight = Watched(false)
})


interopGen({
  postfix = "Update"
  stateTable = state
})


return state