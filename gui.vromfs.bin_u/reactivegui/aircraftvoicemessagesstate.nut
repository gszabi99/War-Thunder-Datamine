from "%rGui/globals/ui_library.nut" import *

let interopGen = require("%rGui/interopGen.nut")

let aircraftVoiceMessagesState = {
  aircraftsPositionsMessage = Watched([])
}

interopGen({
  stateTable = aircraftVoiceMessagesState
  prefix = "air"
  postfix = "Update"
})

return aircraftVoiceMessagesState
