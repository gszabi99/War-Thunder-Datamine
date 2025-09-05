from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")

let compassState = {
  HasCompass = Watched(true)
  CompassValue = Watched(0)
}

interopGen({
  stateTable = compassState
  prefix = "compass"
  postfix = "Update"
})

return compassState
