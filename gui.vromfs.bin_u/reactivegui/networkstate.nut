from "%rGui/globals/ui_library.nut" import *

let interopGen = require("interopGen.nut")

let state = persist("networkState", @(){
  isMultiplayer = Watched(false)
})

interopGen({
  stateTable = state
  prefix = "network"
  postfix = "Update"
})

return state