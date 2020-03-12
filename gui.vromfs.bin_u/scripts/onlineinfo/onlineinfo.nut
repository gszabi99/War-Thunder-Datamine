global const MAX_FETCH_RETRIES = 5

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

::g_script_reloader.registerPersistentData("onlineInfoGlobals", ::getroottable(),
  ["online_stats", "online_info_server_time_param", "online_info_server_time_recieved"])

::get_matching_server_time <- function get_matching_server_time()
{
  return ::online_info_server_time_param + (dagor.getCurTime()/1000 - ::online_info_server_time_recieved)
}
