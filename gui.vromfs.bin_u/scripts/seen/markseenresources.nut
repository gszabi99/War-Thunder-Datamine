//-file:plus-string
from "%scripts/dagui_library.nut" import *

let disableMarkSeenAllResourcesForNewUser = function() {
  ::save_local_account_settings("seen/need_hide_decorators_unseen", false)
  ::save_local_account_settings("seen/need_hide_decals_unseen", false)
}

let needMarkSeenResource = @(currentSeenListId) ::load_local_account_settings($"seen/need_hide_{currentSeenListId}_unseen", true)

let disableMarkSeenResource = @(currentSeenListId) ::save_local_account_settings($"seen/need_hide_{currentSeenListId}_unseen", false)

return {
  disableMarkSeenAllResourcesForNewUser
  needMarkSeenResource
  disableMarkSeenResource
}