from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_STARTUP] ")
let {register_for_user_change_event, EventType, is_any_user_active} = require("%xboxLib/impl/user.nut")
let {register_constrain_callback} = require("%xboxLib/impl/app.nut")
let {update_purchases} = require("%scripts/xbox/purch.nut")
let {on_return_from_system_ui} = require("%scripts/xbox/events.nut")
let {subscribe_to_relationships_change_events, ListType} = require("%xboxLib/impl/relationships.nut")
let {xboxOverlayContactClosedCallback} = require("%scripts/contacts/xboxContactsManager.nut")
let {init_default} = require("%scripts/xbox/user.nut")
let {startLogout} = require("%scripts/login/logout.nut")


init_default(null)


let function on_constrain_callback(active) {
  logX($"Constrain callback: {active}")
  if (active && is_any_user_active()) {
    update_purchases()
    on_return_from_system_ui()
  }
}


let function on_relationships_change(list, _change_type, _xuids) {
  if (list != ListType.Friends) {
    return
  }
  if (!::g_login.isLoggedIn()) {
    return
  }
  // We don't care what changed. We will fetch all relationships anyway.
  // So just notify scripts that something changed
  xboxOverlayContactClosedCallback(1)
}


let function user_change_event_handler(event) {
  if (event == EventType.SigningOut) {
    logX("user_change_event_handler -> SigningOut")
    startLogout()
  }
}

register_for_user_change_event(user_change_event_handler)


register_constrain_callback(on_constrain_callback)
subscribe_to_relationships_change_events(on_relationships_change)
