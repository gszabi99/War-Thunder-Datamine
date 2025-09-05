from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")

let lwsState = {
  LwsDirections = Watched([])
}

interopGen({
  stateTable = lwsState
  prefix = "air"
  postfix = "Update"
})

return lwsState
