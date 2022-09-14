from "frp" import Watched
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_LOGIN] ")
let {subscribe, send} = require("eventbus")

let isLoggedIn = Watched(false)
let loginEventName = "XBOX_LOGIN_EVENT"
let logoutEventName = "XBOX_LOGOUT_EVENT"


let function login() {
  logX("Start login")
  if (!isLoggedIn.value)
    isLoggedIn.update(true)
}


let function logout() {
  logX("Start logout")
  if (isLoggedIn.value)
    isLoggedIn.update(false)
}


isLoggedIn.subscribe(function(v) {
  let eventName = v ? loginEventName : logoutEventName
  send(eventName, null)
})


let function subscribe_to_login(callback) {
  subscribe(loginEventName, function(_) {
    callback?()
  })
}


let function subscribe_to_logout(callback) {
  subscribe(logoutEventName, function(_) {
    callback?()
  })
}


return {
  login
  logout
  subscribe_to_login
  subscribe_to_logout
  is_logged_in = @() isLoggedIn.value
}