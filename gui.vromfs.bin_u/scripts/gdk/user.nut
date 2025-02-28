let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_USER] ")
let {init_default_user, init_user_with_ui, shutdown_user} = require("%gdkLib/impl/user.nut")
let {on_gamertag_change} = require("%scripts/gdk/events.nut")

function make_user_init_callback(callback) {
  function internal(xuid) {
    logX($"Initialized user with xuid: <{xuid}>")
    on_gamertag_change()
    callback?(xuid)
  }
  return internal
}


function init_default(callback) {
  logX("init_default")
  init_default_user(make_user_init_callback(callback))
}


function init_with_ui(callback) {
  logX("init_with_ui")
  init_user_with_ui(make_user_init_callback(callback))
}


function shutdown(callback) {
  logX("shutdown")
  shutdown_user(function() {
    logX("shutdown completed")
    on_gamertag_change()
    callback?()
  })
}


return {
  shutdown
  init_default
  init_with_ui
}