from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let needLogoutAfterSession = persist("needLogoutAfterSession", @() Watched(false))

let function canLogout() {
  return !::disable_network() && !::is_vendor_tencent()
}

let function startLogout() {
  if (!canLogout())
    return ::exit_game()

  if (::is_multiplayer()) //we cant logout from session instantly, so need to return "to debriefing"
  {
    if (::is_in_flight())
    {
      needLogoutAfterSession(true)
      ::quit_mission()
      return
    }
    else
      ::destroy_session_scripted()
  }

  if (::should_disable_menu() || ::g_login.isProfileReceived())
    ::broadcastEvent("BeforeProfileInvalidation") // Here save any data into profile.

  log("Start Logout")
  ::disable_autorelogin_once <- true
  needLogoutAfterSession(false)
  ::g_login.reset()
  ::on_sign_out()
  ::sign_out()
  ::handlersManager.startSceneFullReload(::gui_start_startscreen)
}

return {
  canLogout = canLogout
  startLogout = startLogout
  needLogoutAfterSession = needLogoutAfterSession
}