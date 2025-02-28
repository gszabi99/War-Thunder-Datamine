from "%scripts/dagui_library.nut" import *
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { set_restricted_downloads_mode } = require("hangarEventCommand")
let { isInJoiningGame } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { queues } = require("%scripts/queue/queueManager.nut")

addListenersWithoutEnv({
  BeforeJoinQueue = @(_p) set_restricted_downloads_mode(true)
  QueueChangeState = @(_p) !isInJoiningGame.get() ? set_restricted_downloads_mode(queues.isAnyQueuesActive()) : null
})