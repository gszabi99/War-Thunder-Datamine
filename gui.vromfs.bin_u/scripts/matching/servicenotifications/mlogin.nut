from "%scripts/matching/api.nut" import matchingRpcSubscribe
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/onlineInfo/onlineInfo.nut" import totalRooms, totalPlayers, syncMatchingServerTime
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "dagor.time" import get_time_msec
from "%scripts/dagui_library.nut" import *

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
