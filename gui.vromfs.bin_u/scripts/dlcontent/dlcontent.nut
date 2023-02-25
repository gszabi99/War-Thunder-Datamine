//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { set_restricted_downloads_mode } = require("hangarEventCommand")

addListenersWithoutEnv({
  BeforeJoinQueue = @(_p) set_restricted_downloads_mode(true)
  QueueChangeState = @(_p) !::SessionLobby.isInJoiningGame() ? set_restricted_downloads_mode(::queues.isAnyQueuesActive()) : null
})