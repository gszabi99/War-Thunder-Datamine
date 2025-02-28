let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")


return {
  on_gamertag_change = @() broadcastEvent("XboxActiveUserGamertagChanged")
  on_return_from_system_ui = @() broadcastEvent("XboxSystemUIReturn")
  on_xbox_logout = @() broadcastEvent("XboxSignOut")
}