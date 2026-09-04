from "dagor.time" import get_time_msec
from "math" import abs
from "%scripts/dagui_library.nut" import *

let totalRooms = mkWatched(persist, "totalRooms", 0)
let totalPlayers = mkWatched(persist, "totalPlayers", 0)
let onlineInfoServerTimeParam = mkWatched(persist, "onlineInfoServerTimeParam", 0)
let onlineInfoServerTimeReceivedMsec = mkWatched(persist, "onlineInfoServerTimeReceivedMsec", 0)

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

return {
  totalRooms
  totalPlayers
  getMatchingServerTime
  syncMatchingServerTime
}
