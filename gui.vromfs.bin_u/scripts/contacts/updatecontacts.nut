from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { updateContacts = @(...) null } = isPlatformSony ? require("%scripts/contacts/psnContactsManager.nut")
    : isPlatformXboxOne ? require("%scripts/contacts/xboxContactsManager.nut")
    : null

eventbus_subscribe("playerProfileDialogClosed", function(r) {
  if (r?.result.wasCanceled)
    return
  updateContacts(true)
})

return updateContacts
