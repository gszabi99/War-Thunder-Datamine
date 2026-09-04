from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "multiplayer" import is_mplayer_peer, destroy_session

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

function destroySessionScripted(sourceInfo) {
  let needEvent = is_mplayer_peer()
  destroy_session(sourceInfo)
  if (needEvent)
    
    handlersManager.doDelayed(@() broadcastEvent("SessionDestroyed"))
}

return destroySessionScripted