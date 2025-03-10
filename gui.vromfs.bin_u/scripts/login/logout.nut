from "%scripts/dagui_natives.nut" import disable_network, sign_out, exit_game
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { set_disable_autorelogin_once } = require("loginState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { isInFlight } = require("gameplayBinding")
let { isXbox } = require("%sqstd/platform.nut")
let { quitMission } = require("%scripts/hud/startHud.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { resetLogin } = require("%scripts/login/loginManager.nut")

let needLogoutAfterSession = mkWatched(persist, "needLogoutAfterSession", false)


local platformLogout = null
if (isXbox) {
  platformLogout = require("%scripts/gdk/loginState.nut").logout
}


function canLogout() {
  return !disable_network()
}


function doLogout() {
  if (!canLogout())
    return exit_game()

  if (is_multiplayer()) { 
    if (isInFlight()) {
      needLogoutAfterSession(true)
      quitMission()
      return
    }
    else
      ::destroy_session_scripted("on start logout")
  }

  if (::should_disable_menu() || isProfileReceived.get())
    broadcastEvent("BeforeProfileInvalidation") 

  log("Start Logout")
  set_disable_autorelogin_once(true)
  needLogoutAfterSession(false)
  resetLogin()
  eventbus_send("on_sign_out")
  sign_out()
  handlersManager.startSceneFullReload({ eventbusName = "gui_start_startscreen" })
}


function startLogout() {
  if (platformLogout != null)
    platformLogout(function() {
      doLogout()
    })
  else
    doLogout()
}


eventbus_subscribe("request_logout", @(...) startLogout())

return {
  canLogout = canLogout
  startLogout = startLogout
  needLogoutAfterSession = needLogoutAfterSession
}