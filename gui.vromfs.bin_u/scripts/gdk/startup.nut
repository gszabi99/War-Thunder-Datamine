from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_STARTUP] ")
let {register_for_user_change_event, EventType, is_any_user_active} = require("%gdkLib/impl/user.nut")
let {register_constrain_callback} = require("%gdkLib/impl/app.nut")
let {update_purchases} = require("%scripts/gdk/purch.nut")
let {on_return_from_system_ui} = require("%scripts/gdk/events.nut")
let {subscribe_to_relationships_change_events, ListType} = require("%gdkLib/impl/relationships.nut")
let {fetchContactsList} = require("%scripts/contacts/xboxContactsManager.nut")
let {init_default} = require("%scripts/gdk/user.nut")
let {startLogout} = require("%scripts/login/logout.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")


function on_constrain_callback(active) {
  logX($"Constrain callback: {active}")
  if (active && is_any_user_active()) {
    update_purchases()
    on_return_from_system_ui()
  }
}


function on_relationships_change(list, _change_type, _xuids) {
  logX("Relationships changed")
  if (list != ListType.Friends) {
    logX("Invalid list, skipping update")
    return
  }
  if (!isLoggedIn.get()) {
    logX("User is not logged-in, skipping update")
    return
  }
  logX("Fetching contacts list")
  fetchContactsList()
}


function user_change_event_handler(event) {
  if (event == EventType.SigningOut) {
    logX("user_change_event_handler -> SigningOut")
    startLogout()
  }
}

register_for_user_change_event(user_change_event_handler)


register_constrain_callback(on_constrain_callback)
subscribe_to_relationships_change_events(on_relationships_change)

init_default(null)
