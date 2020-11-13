local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local TUTORIAL_VERSION_COUNTER = 1

local saveVersion = function(ver = null)
{
  if (::loadLocalByAccount("tutor/tutorialVersion") == null)
    ::saveLocalByAccount("tutor/tutorialVersion", ver ?? TUTORIAL_VERSION_COUNTER)
}

local getVersion =  @() ::loadLocalByAccount("tutor/tutorialVersion", 0)

local needShowTutorial = @(id, tutorVersion) !::loadLocalByAccount("tutor/" + id)
                                             && (::is_me_newbie() || getVersion() >= tutorVersion)

local saveShowedTutorial = @(id) ::saveLocalByAccount("tutor/" + id, true)

subscriptions.addListenersWithoutEnv({
  AccountReset = function(p) {
    saveVersion()
    ::saveLocalByAccount("tutor", null)
    ::save_local_account_settings("tutor", null)
    ::saveLocalByAccount(::skip_tutorial_bitmask_id, null)
  }
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  saveVersion = saveVersion
  getVersion = getVersion
  needShowTutorial = needShowTutorial
  saveShowedTutorial = saveShowedTutorial
}