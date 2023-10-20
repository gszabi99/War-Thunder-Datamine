from "%rGui/globals/ui_library.nut" import *

let interopGen = require("interopGen.nut")

let isInFlight = mkWatched(persist, "isInFlight", false)

let state = { isInFlight }

interopGen({
  postfix = "Update"
  stateTable = state
})


return state