//-file:plus-string
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { skipTutorialBitmaskId } = require("%scripts/tutorials/tutorialsState.nut")
let { saveLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")

let TUTORIAL_VERSION_COUNTER = 1

let saveVersion = function(ver = null) {
  if (loadLocalByAccount("tutor/tutorialVersion") == null)
    saveLocalByAccount("tutor/tutorialVersion", ver ?? TUTORIAL_VERSION_COUNTER)
}

let getVersion =  @() loadLocalByAccount("tutor/tutorialVersion", 0)

let needShowTutorial = @(id, tutorVersion) !loadLocalByAccount("tutor/" + id)
  && (isMeNewbie() || getVersion() >= tutorVersion)

let saveShowedTutorial = @(id) saveLocalByAccount("tutor/" + id, true)

subscriptions.addListenersWithoutEnv({
  AccountReset = function(_p) {
    saveVersion()
    saveLocalByAccount("tutor", null)
    saveLocalAccountSettings("tutor", null)
    saveLocalByAccount(skipTutorialBitmaskId, null)
  }
}, g_listener_priority.CONFIG_VALIDATION)

return {
  saveVersion = saveVersion
  getVersion = getVersion
  needShowTutorial = needShowTutorial
  saveShowedTutorial = saveShowedTutorial
}