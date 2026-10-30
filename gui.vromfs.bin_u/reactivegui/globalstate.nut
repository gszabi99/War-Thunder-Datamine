import "%rGui/interopGen.nut" as interopGen
from "%sqstd/globalState.nut" import hardPersistWatched

let isInFlight = hardPersistWatched("rGui.globalState.isInFlight", false)

let state = { isInFlight }

interopGen({
  postfix = "Update"
  stateTable = state
})


return freeze(state)