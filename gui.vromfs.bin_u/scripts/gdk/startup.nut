from "%appGlobals/login/loginState.nut" import isLoggedIn
from "%gdkLib/impl/user.nut" import is_any_user_active
from "%gdkLib/impl/app.nut" import register_unconstrain_callback
from "%gdkLib/impl/relationships.nut" import subscribe_to_relationships_change_events, ListType
from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_STARTUP] ")
let { update_purchases } = require("%scripts/gdk/purch.nut")
let { on_return_from_system_ui } = require("%scripts/gdk/events.nut")
let { fetchContactsList } = require("%scripts/contacts/xboxContactsManager.nut")


function on_constrain_callback() {
  logX("Constrain callback")
  if (is_any_user_active()) {
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


register_unconstrain_callback(on_constrain_callback)
subscribe_to_relationships_change_events(on_relationships_change)
