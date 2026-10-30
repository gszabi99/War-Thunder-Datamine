from "dagor.time" import get_time_msec
from "math" import abs
from "%scripts/dagui_library.nut" import *

let hardPersistWatched = mkHardPersistWatched("onlineInfo.onlineInfo")
let totalRooms = hardPersistWatched("totalRooms", 0)
let totalPlayers = hardPersistWatched("totalPlayers", 0)
let onlineInfoServerTimeParam = hardPersistWatched("onlineInfoServerTimeParam", 0)
let onlineInfoServerTimeReceivedMsec = hardPersistWatched("onlineInfoServerTimeReceivedMsec", 0)

const SERVER_TIME_RESYNC_SEC = 2



function getMatchingServerTime() {
  let anchorMsec = onlineInfoServerTimeReceivedMsec.get()
  if (anchorMsec == 0) 
    return onlineInfoServerTimeParam.get()
  return onlineInfoServerTimeParam.get() + ((get_time_msec() - anchorMsec) / 1000)
}



function syncMatchingServerTime(serverTime) {
  if (onlineInfoServerTimeReceivedMsec.get() != 0
      && abs(serverTime - getMatchingServerTime()) <= SERVER_TIME_RESYNC_SEC)
    return
  onlineInfoServerTimeParam.set(serverTime)
  onlineInfoServerTimeReceivedMsec.set(get_time_msec())
}

return freeze({
  totalRooms
  totalPlayers
  getMatchingServerTime
  syncMatchingServerTime
})
