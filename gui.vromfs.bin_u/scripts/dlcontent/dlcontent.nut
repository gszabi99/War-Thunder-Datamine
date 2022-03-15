local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { set_restricted_downloads_mode } = require("hangarEventCommand")

addListenersWithoutEnv({
  BeforeJoinQueue = @(p) set_restricted_downloads_mode(true)
  QueueChangeState = @(p) !::SessionLobby.isInJoiningGame() ? set_restricted_downloads_mode(::queues.isAnyQueuesActive()) : null
})