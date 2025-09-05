from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")

let isInFlight = mkWatched(persist, "isInFlight", false)

let state = { isInFlight }

interopGen({
  postfix = "Update"
  stateTable = state
})


return state