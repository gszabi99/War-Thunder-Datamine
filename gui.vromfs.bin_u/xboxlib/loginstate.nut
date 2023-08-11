let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_LOGIN] ")
let {subscribe, send} = require("eventbus")

let cachedLoginState = persist("cachedLoginState", @() { isLoggedIn = false })
let loginEventName = "XBOX_LOGIN_EVENT"
let logoutEventName = "XBOX_LOGOUT_EVENT"


let function login() {
  logX("Start login")
  let updated = !cachedLoginState.isLoggedIn
  cachedLoginState.isLoggedIn = true
  send(loginEventName, { updated = updated })
}


let function logout() {
  logX("Start logout")
  let updated = cachedLoginState.isLoggedIn
  cachedLoginState.isLoggedIn = false
  send(logoutEventName, { updated = updated })
}


let function subscribe_to_login(callback) {
  subscribe(loginEventName, function(res) {
    callback?(res?.updated)
  })
}


let function subscribe_to_logout(callback) {
  subscribe(logoutEventName, function(res) {
    callback?(res?.updated)
  })
}


return {
  login
  logout
  subscribe_to_login
  subscribe_to_logout
  is_logged_in = @() cachedLoginState.isLoggedIn
}