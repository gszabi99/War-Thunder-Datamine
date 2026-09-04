from "%sqstd/platform.nut" import is_gdk
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { updateContacts = @(...) null } = isPlatformSony ? require("%scripts/contacts/psnContactsManager.nut")
    : is_gdk ? require("%scripts/contacts/xboxContactsManager.nut")
    : null

eventbus_subscribe("playerProfileDialogClosed", function(r) {
  if (r?.result.wasCanceled)
    return
  updateContacts(true)
})

return updateContacts
