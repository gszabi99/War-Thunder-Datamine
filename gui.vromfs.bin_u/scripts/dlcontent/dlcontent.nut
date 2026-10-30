from "%scripts/matchingRooms/sessionLobbyState.nut" import isInJoiningGame
from "%scripts/queue/queueState.nut" import isAnyQueuesActive
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "hangarEventCommand" import set_restricted_downloads_mode
from "%scripts/dagui_library.nut" import *

addListenersWithoutEnv({
  BeforeJoinQueue = @(_p) set_restricted_downloads_mode(true)
  QueueChangeState = @(_p) !isInJoiningGame.get() ? set_restricted_downloads_mode(isAnyQueuesActive()) : null
})