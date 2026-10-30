import "%scripts/matchingRooms/destroySessionScripted.nut" as destroySessionScripted
from "%scripts/login/loginState.nut" import set_disable_autorelogin_once
from "%scripts/sqDagui/framework/baseGuiHandlerManager.nut" import get_current_base_gui_handler
from "%scripts/hud/startHud.nut" import quitMission
from "%scripts/login/loginManager.nut" import resetLogin
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/sqDagui/framework/msgBox.nut" import add_msg_box, remove_scene_box
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "%globalScripts/clientState/initialState.nut" import shouldDisableMenu, disableNetwork
from "auth_wt" import signOut
from "eventbus" import eventbus_subscribe, eventbus_send
from "gameplayBinding" import isInFlight
from "guiMission" import quit_to_debriefing, interrupt_multiplayer
from "app" import exitGame
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { handlersManager } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")

let needLogoutAfterSession = mkHardPersistWatched("login.logout")("needLogoutAfterSession", false)


function canLogout() {
  return !disableNetwork
}


function startLogout() {
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
  signOut()
  handlersManager.startSceneFullReload({ eventbusName = "gui_start_startscreen" })
}

local guiStartLogoutScheduled = false


function on_lost_psn() {
  log("on_lost_psn")
  let guiScene = get_gui_scene()
  let handler = get_current_base_gui_handler()
  if (handler == null)
    return

  remove_scene_box("connection_failed")

  if (guiScene["list_no_sessions_create"] != null) {
    remove_scene_box("list_no_sessions_create")
  }
  if (guiScene["psn_room_create_error"] != null) {
    remove_scene_box("psn_room_create_error")
  }

  if (!isInMenu.get()) {
    guiStartLogoutScheduled = true
    destroySessionScripted("on lost psn while not in menu")
    quit_to_debriefing()
    interrupt_multiplayer(true)
  }
  else {
    add_msg_box("lost_live", loc("yn1/disconnection/psn"), [["ok",
        function() {
          destroySessionScripted("after 'on lost psn' message")
          startLogout()
        }
        ]], "ok")
  }
}

function checkLogoutScheduled() {
  if (guiStartLogoutScheduled) {
    guiStartLogoutScheduled = false
    on_lost_psn()
  }
}

eventbus_subscribe("PsnLoginStateChanged", @(p) p?.isSignedIn ? null : on_lost_psn())
eventbus_subscribe("request_logout", @(...) startLogout())

return freeze({
  canLogout
  startLogout
  needLogoutAfterSession
  checkLogoutScheduled
})