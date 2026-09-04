from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent

return {
  on_gamertag_change = @() broadcastEvent("XboxActiveUserGamertagChanged")
  on_return_from_system_ui = @() broadcastEvent("XboxSystemUIReturn")
}