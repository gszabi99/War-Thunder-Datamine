from "app" import exitGame
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import is_multiplayer

let { signOut } = require("auth_wt")
let { is_gdk } = require("%sqstd/platform.nut")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { set_disable_autorelogin_once } = require("loginState.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager, get_current_base_gui_handler
} = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { isInFlight } = require("gameplayBinding")
let { quit_to_debriefing, interrupt_multiplayer } = require("guiMission")
let { quitMission } = require("%scripts/hud/startHud.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { resetLogin } = require("%scripts/login/loginManager.nut")
let destroySessionScripted = require("%scripts/matchingRooms/destroySessionScripted.nut")
let { shouldDisableMenu, disableNetwork } = require("%globalScripts/clientState/initialState.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { add_msg_box, remove_scene_box } = require("%sqDagui/framework/msgBox.nut")

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
  signOut()
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

return {
  canLogout
  startLogout
  needLogoutAfterSession
  checkLogoutScheduled
}