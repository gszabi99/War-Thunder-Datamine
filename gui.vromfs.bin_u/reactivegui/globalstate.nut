import "%rGui/interopGen.nut" as interopGen
from "%rGui/globals/ui_library.nut" import *

let isInFlight = mkWatched(persist, "isInFlight", false)

let state = { isInFlight }

interopGen({
  postfix = "Update"
  stateTable = state
})


return state