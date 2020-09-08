local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local { updateContacts = @() null,
        updateMuteStatus = @(...) null
} = isPlatformSony? require("scripts/contacts/psnContactsManager.nut")
  : isPlatformXboxOne ? require("scripts/contacts/xboxContactsManager.nut")
  : null

return {
  updateContacts = updateContacts
  updateMuteStatus = updateMuteStatus
}