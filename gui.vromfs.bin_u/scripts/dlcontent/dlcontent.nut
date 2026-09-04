from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "hangarEventCommand" import set_restricted_downloads_mode
from "%scripts/dagui_library.nut" import *

let { isInJoiningGame } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { isAnyQueuesActive } = require("%scripts/queue/queueState.nut")

addListenersWithoutEnv({
  BeforeJoinQueue = @(_p) set_restricted_downloads_mode(true)
  QueueChangeState = @(_p) !isInJoiningGame.get() ? set_restricted_downloads_mode(isAnyQueuesActive()) : null
})