from "%scripts/dagui_library.nut" import *

let { get_time_msec } = require("dagor.time")

let totalRooms = mkWatched(persist, "totalRooms", 0)
let totalPlayers = mkWatched(persist, "totalPlayers", 0)
let onlineInfoServerTimeParam = mkWatched(persist, "onlineInfoServerTimeParam", 0)
let onlineInfoServerTimeReceived = mkWatched(persist, "onlineInfoServerTimeReceived", 0)

function getMatchingServerTime() {
  return onlineInfoServerTimeParam.get() + (get_time_msec() / 1000 - onlineInfoServerTimeReceived.get())
}

return {
  totalRooms
  totalPlayers
  onlineInfoServerTimeParam
  onlineInfoServerTimeReceived
  getMatchingServerTime
}