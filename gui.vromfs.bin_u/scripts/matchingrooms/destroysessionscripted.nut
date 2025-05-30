let { is_mplayer_peer, destroy_session } = require("multiplayer")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

function destroySessionScripted(sourceInfo) {
  let needEvent = is_mplayer_peer()
  destroy_session(sourceInfo)
  if (needEvent)
    
    handlersManager.doDelayed(@() broadcastEvent("SessionDestroyed"))
}

return destroySessionScripted