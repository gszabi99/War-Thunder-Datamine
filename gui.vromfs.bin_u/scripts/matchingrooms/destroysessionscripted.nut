from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "multiplayer" import is_mplayer_peer, destroy_session
from "dagor.workcycle" import deferOnce

let notifySessionDestroy = @() broadcastEvent("SessionDestroyed")

function destroySessionScripted(sourceInfo) {
  let needEvent = is_mplayer_peer()
  destroy_session(sourceInfo)
  if (needEvent)
    
    deferOnce(notifySessionDestroy)
}

return destroySessionScripted