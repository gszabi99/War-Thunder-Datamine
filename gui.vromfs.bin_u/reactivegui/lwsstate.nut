import "%rGui/interopGen.nut" as interopGen
from "%rGui/globals/ui_library.nut" import *

let lwsState = {
  LwsDirections = Watched([])
}

interopGen({
  stateTable = lwsState
  prefix = "air"
  postfix = "Update"
})

return lwsState
