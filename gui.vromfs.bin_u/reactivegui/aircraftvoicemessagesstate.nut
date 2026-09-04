import "%rGui/interopGen.nut" as interopGen
from "%rGui/globals/ui_library.nut" import *

let aircraftVoiceMessagesState = {
  aircraftsPositionsMessage = Watched([])
}

interopGen({
  stateTable = aircraftVoiceMessagesState
  prefix = "air"
  postfix = "Update"
})

return aircraftVoiceMessagesState
