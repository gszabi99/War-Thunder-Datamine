//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this


let { g_script_reloader } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { get_time_msec } = require("dagor.time")

::online_stats <- {
  players_total = 0
  rooms_total = 0
}

::available_countries_info <-
{
  [0] = { //arcade
     country_ussr = 1,
     country_japan = 1,
     country_usa = 1,
     country_germany = 1,
     country_britain = 1
  },
  [1] = { //historical
     country_0 = 1,
     country_ussr = 1,
     country_japan = 1,
     country_usa = 1,
     country_germany = 1,
     country_britain = 1
  },
  [2] = { //realistic
     country_0 = 1,
     country_ussr  = 1,
     country_japan = 1,
     country_usa   = 1,
     country_germany = 1,
     country_britain = 1
  }
}

::last_show_update_popup_time <- -60000
::online_info_server_time_param <- 0
::online_info_server_time_recieved <- 0

g_script_reloader.registerPersistentData("onlineInfoGlobals", getroottable(),
  ["online_stats", "online_info_server_time_param", "online_info_server_time_recieved"])

::get_matching_server_time <- function get_matching_server_time() {
  return ::online_info_server_time_param + (get_time_msec() / 1000 - ::online_info_server_time_recieved)
}
