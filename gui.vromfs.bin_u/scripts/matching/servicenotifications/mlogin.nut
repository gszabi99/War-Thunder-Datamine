//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { get_time_msec } = require("dagor.time")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { matchingRpcSubscribe } = require("%scripts/matching/api.nut")

/**[DEPRECATED] this notification callbacks call by mathing forced**/
let function onOnlineInfoUpdated(params) {
  if ("utc_time" in params) {
    ::online_info_server_time_param = params.utc_time.tointeger()
    ::online_info_server_time_received = get_time_msec() / 1000
  }

  if ("online_stats" in params)
    ::online_stats = params.online_stats

  local update_avail = false
  if ("update_avail" in params && params.update_avail) {
    if (get_time_msec() - ::last_show_update_popup_time > 120000) {
      ::g_popups.add(loc("mainmenu/update_avail_popup_title"), loc("mainmenu/update_avail_popup_text"))
      ::last_show_update_popup_time = get_time_msec()
    }
    update_avail = true
  }

  broadcastEvent("CheckClientUpdate", { update_avail })
  broadcastEvent("OnlineInfoUpdate")
}

matchingRpcSubscribe("mlogin.update_online_info", onOnlineInfoUpdated)
