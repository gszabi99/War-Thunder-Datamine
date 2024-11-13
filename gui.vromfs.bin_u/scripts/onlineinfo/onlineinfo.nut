from "%scripts/dagui_library.nut" import *



let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { get_time_msec } = require("dagor.time")

::online_stats <- {
  players_total = 0
  rooms_total = 0
}

::last_show_update_popup_time <- -60000
::online_info_server_time_param <- 0
::online_info_server_time_received <- 0

registerPersistentData("onlineInfoGlobals", getroottable(),
  ["online_stats", "online_info_server_time_param", "online_info_server_time_received"])

::get_matching_server_time <- function get_matching_server_time() {
  return ::online_info_server_time_param + (get_time_msec() / 1000 - ::online_info_server_time_received)
}
