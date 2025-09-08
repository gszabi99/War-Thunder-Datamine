from "%scripts/dagui_natives.nut" import sign_out
from "app" import exitGame
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { is_gdk } = require("%sqstd/platform.nut")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { set_disable_autorelogin_once } = require("loginState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { isInFlight } = require("gameplayBinding")
let { quitMission } = require("%scripts/hud/startHud.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { resetLogin } = require("%scripts/login/loginManager.nut")
let destroySessionScripted = require("%scripts/matchingRooms/destroySessionScripted.nut")
let { shouldDisableMenu, disableNetwork } = require("%globalScripts/clientState/initialState.nut")

let needLogoutAfterSession = mkWatched(persist, "needLogoutAfterSession", false)


local platformLogout = null
if (is_gdk) {
  platformLogout = require("%scripts/gdk/loginState.nut").logout
}


function canLogout() {
  return !disableNetwork
}


function doLogout() {
  if (!canLogout())
    return exitGame()

  if (is_multiplayer()) { 
    if (isInFlight()) {
      needLogoutAfterSession.set(true)
      quitMission()
      return
    }
    else
      destroySessionScripted("on start logout")
  }

  if (shouldDisableMenu || isProfileReceived.get())
    broadcastEvent("BeforeProfileInvalidation") 

  log("Start Logout")
  set_disable_autorelogin_once(true)
  needLogoutAfterSession.set(false)
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