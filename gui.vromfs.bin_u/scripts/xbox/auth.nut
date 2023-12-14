from "%scripts/dagui_natives.nut" import xbox_on_login, is_online_available
from "%scripts/dagui_library.nut" import *
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_LOGIN] ")
let {is_any_user_active} = require("%xboxLib/impl/user.nut")
let loginState = require("%xboxLib/loginState.nut")
let {startLogout} = require("%scripts/login/logout.nut")
let { isInHangar } = require("gameplayBinding")

let { addTask } = require("%scripts/tasker.nut")

local callbackReturnFunc = null

function xbox_on_purchases_updated() {
  if (!is_online_available())
    return

  addTask(::update_entitlements_limited(),
                     {
                       showProgressBox = true
                       progressBoxText = loc("charServer/checking")
                     },
                     Callback(function() {
                       if (callbackReturnFunc) {
                         callbackReturnFunc()
                         callbackReturnFunc = null
                       }
                     }, this)
                    )
}

let set_xbox_on_purchase_cb = @(cb) callbackReturnFunc = cb

let function login(callback) {
  logX("Login")
  xbox_on_login(true, function(result) {
    let success = result == 0 // YU2_OK
    logX($"Login succeeded: {success}")
    loginState.login()
    callback?(result)
  })
}


let function logout(callback) {
  if (loginState.isLoggedIn.value) {
    logX("Logout")
    loginState.logout()
  } else {
    logX("Already logged-out. Skipping")
  }
  callback?()
}


let function update_purchases() {
  logX("Update purchases")
  if (!(is_any_user_active() && isInHangar())) {
    logX("Not in hangar or no user active => skip update")
    return
  }
  xbox_on_login(false, function(result) {
    let success = result == 0 // YU2_OK
    logX($"Login succeeded: {success}")
    if (success) {
      xbox_on_purchases_updated()
    }
  })
}


let function on_logout_callback(updated) {
  logX($"on_logout_callback({updated})")
  if (updated && ::g_login.isLoggedIn()) {
    get_cur_gui_scene().performDelayed(getroottable(), function() {
      logX("on_logout_callback -> startLogout()")
      startLogout()
    })
  }
}


loginState.subscribe_to_logout(on_logout_callback)


return {
  login
  logout
  update_purchases
  set_xbox_on_purchase_cb
}