from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_STARTUP] ")
let {is_any_user_active} = require("%xboxLib/impl/user.nut")
let {register_constrain_callback} = require("%xboxLib/impl/app.nut")
let {init_default, subscribe_to_user_init, subscribe_to_user_shutdown} = require("%xboxLib/user.nut")
let {update_purchases} = require("%scripts/xbox/auth.nut")
let {on_return_from_system_ui, on_gamertag_change, on_user_signout_finished} = require("%scripts/xbox/events.nut")
let {subscribe_to_relationships_change_events, ListType} = require("%xboxLib/impl/relationships.nut")
let {xboxOverlayContactClosedCallback} = require("%scripts/contacts/xboxContactsManager.nut")


init_default(function(xuid) {
  logX($"Initialized default user with xuid: {xuid}")
})


let function on_user_init_callback(xuid, with_ui) {
  logX($"User init: {xuid} with_ui: {with_ui}")
  on_gamertag_change()
}


let function on_user_shutdown_callback() {
  logX("User shutdown")
  on_gamertag_change()
  on_user_signout_finished()
}


let function on_constrain_callback(active) {
  if (active && is_any_user_active()) {
    update_purchases()
    on_return_from_system_ui()
  }
}


let function on_relationships_change(list, _change_type, _xuids) {
  if (list != ListType.Friends) {
    return
  }
  // We don't care what changed. We will fetch all relationships anyway.
  // So just notify scripts that something changed
  xboxOverlayContactClosedCallback(1)
}


subscribe_to_user_init(on_user_init_callback)
subscribe_to_user_shutdown(on_user_shutdown_callback)
register_constrain_callback(on_constrain_callback)
subscribe_to_relationships_change_events(on_relationships_change)
