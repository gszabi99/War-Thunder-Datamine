from "%scripts/gdk/purch.nut" import update_purchases
from "%scripts/gdk/events.nut" import on_return_from_system_ui
from "%scripts/contacts/xboxContactsManager.nut" import fetchContactsList
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "%gdkLib/impl/user.nut" import is_any_user_active
from "%gdkLib/impl/app.nut" import register_unconstrain_callback
from "%gdkLib/impl/relationships.nut" import subscribe_to_relationships_change_events, ListType
from "%gdkLib/crossnetwork.nut" import init_crossnetwork
from "%scripts/dagui_library.nut" import *

let logX = require("%sqstd/log.nut")().with_prefix("[XBOX_STARTUP] ")


function on_constrain_callback() {
  logX("Constrain callback")
  if (is_any_user_active()) {
    update_purchases()
    on_return_from_system_ui()
  }
}


function on_relationships_change(list, _change_type, _xuids) {
  logX("Relationships changed")
  if (list != ListType.Friends && list != ListType.Avoid) {
    logX($"List {list} is not synced to contacts, skipping update")
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

if (is_any_user_active()) {
  logX("Script reload with active user, reinit crossnetwork")
  init_crossnetwork()
}
