from "%sqstd/platform.nut" import is_gdk, isSony
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

let { updateContacts = @(...) null } = isSony ? require("%scripts/contacts/psnContactsManager.nut")
    : is_gdk ? require("%scripts/contacts/xboxContactsManager.nut")
    : null

eventbus_subscribe("playerProfileDialogClosed", function(r) {
  if (r?.result.wasCanceled)
    return
  updateContacts(true)
})

return updateContacts
