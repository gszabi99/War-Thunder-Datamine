from "%rGui/globals/ui_library.nut" import *

let interopGen = require("interopGen.nut")

let aircraftVoiceMessagesState = {
  aircraftsPositionsMessage = Watched([])
}

interopGen({
  stateTable = aircraftVoiceMessagesState
  prefix = "air"
  postfix = "Update"
})

return aircraftVoiceMessagesState
