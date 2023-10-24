from "%scripts/dagui_library.nut" import *
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")

let disableMarkSeenAllResourcesForNewUser = function() {
  saveLocalAccountSettings("seen/need_hide_decorators_unseen", false)
  saveLocalAccountSettings("seen/need_hide_decals_unseen", false)
}

let needMarkSeenResource = @(currentSeenListId) loadLocalAccountSettings($"seen/need_hide_{currentSeenListId}_unseen", true)

let disableMarkSeenResource = @(currentSeenListId) saveLocalAccountSettings($"seen/need_hide_{currentSeenListId}_unseen", false)

return {
  disableMarkSeenAllResourcesForNewUser
  needMarkSeenResource
  disableMarkSeenResource
}