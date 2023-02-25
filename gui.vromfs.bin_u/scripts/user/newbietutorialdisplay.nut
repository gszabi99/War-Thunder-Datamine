//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { skipTutorialBitmaskId } = require("%scripts/tutorials/tutorialsData.nut")

let TUTORIAL_VERSION_COUNTER = 1

let saveVersion = function(ver = null) {
  if (::loadLocalByAccount("tutor/tutorialVersion") == null)
    ::saveLocalByAccount("tutor/tutorialVersion", ver ?? TUTORIAL_VERSION_COUNTER)
}

let getVersion =  @() ::loadLocalByAccount("tutor/tutorialVersion", 0)

let needShowTutorial = @(id, tutorVersion) !::loadLocalByAccount("tutor/" + id)
                                             && (::is_me_newbie() || getVersion() >= tutorVersion)

let saveShowedTutorial = @(id) ::saveLocalByAccount("tutor/" + id, true)

subscriptions.addListenersWithoutEnv({
  AccountReset = function(_p) {
    saveVersion()
    ::saveLocalByAccount("tutor", null)
    ::save_local_account_settings("tutor", null)
    ::saveLocalByAccount(skipTutorialBitmaskId, null)
  }
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  saveVersion = saveVersion
  getVersion = getVersion
  needShowTutorial = needShowTutorial
  saveShowedTutorial = saveShowedTutorial
}