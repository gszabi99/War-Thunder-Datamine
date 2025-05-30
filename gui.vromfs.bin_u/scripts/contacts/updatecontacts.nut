from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
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
