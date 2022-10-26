from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")

/**[DEPRECATED] this notification callbacks call by mathing forced**/
let function on_online_info_updated(params)
{
  if ("utc_time" in params)
  {
    ::online_info_server_time_param = params.utc_time.tointeger()
    ::online_info_server_time_recieved = get_time_msec()/1000
  }

  if ("online_stats" in params)
    ::online_stats = params.online_stats

  local update_avail = false
  if("update_avail" in params && params.update_avail)
  {
    if(get_time_msec() - ::last_show_update_popup_time > 120000)
    {
      ::g_popups.add(loc("mainmenu/update_avail_popup_title"), loc("mainmenu/update_avail_popup_text"))
      ::last_show_update_popup_time = get_time_msec()
    }
    update_avail = true
  }

  ::broadcastEvent("CheckClientUpdate", {update_avail = update_avail})
  ::broadcastEvent("OnlineInfoUpdate")

  if (::current_base_gui_handler && ("onOnlineInfo" in ::current_base_gui_handler))
    ::current_base_gui_handler.onOnlineInfo.call(::current_base_gui_handler)
}

foreach (notificationName, callback in
          {
            ["mlogin.update_online_info"] = on_online_info_updated
          }
        )
  ::matching_rpc_subscribe(notificationName, callback)
