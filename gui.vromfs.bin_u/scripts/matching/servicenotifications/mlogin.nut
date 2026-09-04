from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "dagor.time" import get_time_msec
from "%scripts/dagui_library.nut" import *

let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { totalRooms, totalPlayers, syncMatchingServerTime } = require("%scripts/onlineInfo/onlineInfo.nut")

local lastShowUpdatePopupTime = -60000


function onOnlineInfoUpdated(params) {
  if ("utc_time" in params)
    syncMatchingServerTime(params.utc_time.tointeger())

  if ("online_stats" in params) {
    totalRooms.set(params.online_stats?.rooms_total ?? 0)
    totalPlayers.set(params.online_stats?.players_total ?? 0)
  }

  local update_avail = false
  if ("update_avail" in params && params.update_avail) {
    if (get_time_msec() - lastShowUpdatePopupTime > 120000) {
      addPopup(loc("mainmenu/update_avail_popup_title"), loc("mainmenu/update_avail_popup_text"))
      lastShowUpdatePopupTime = get_time_msec()
    }
    update_avail = true
  }

  broadcastEvent("CheckClientUpdate", { update_avail })
  broadcastEvent("OnlineInfoUpdate")
}

matchingRpcSubscribe("mlogin.update_online_info", onOnlineInfoUpdated)
