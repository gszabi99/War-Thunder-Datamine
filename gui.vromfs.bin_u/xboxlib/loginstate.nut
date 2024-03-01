let {hardPersistWatched} = require("%sqstd/globalState.nut")
let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_LOGIN] ")
let {eventbus_subscribe, eventbus_send} = require("eventbus")

let isLoggedIn = hardPersistWatched("xbox.isLoggedIn", false)
let loginEventName = "XBOX_LOGIN_EVENT"
let logoutEventName = "XBOX_LOGOUT_EVENT"


function login() {
  logX("Start login")
  let updated = !isLoggedIn.value
  isLoggedIn.update(true)
  eventbus_send(loginEventName, { updated = updated })
}


function logout() {
  logX("Start logout")
  let updated = isLoggedIn.value
  isLoggedIn.update(false)
  eventbus_send(logoutEventName, { updated = updated })
}


function subscribe_to_login(callback) {
  eventbus_subscribe(loginEventName, function(res) {
    callback?(res?.updated)
  })
}


function subscribe_to_logout(callback) {
  eventbus_subscribe(logoutEventName, function(res) {
    callback?(res?.updated)
  })
}


return {
  login
  logout
  subscribe_to_login
  subscribe_to_logout
  isLoggedIn
}