from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import stat_get_value_respawns

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { skipTutorialBitmaskId } = require("%scripts/tutorials/tutorialsState.nut")
let { saveLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")
let { getFirstChosenUnitType } = require("%scripts/firstChoice/firstChoice.nut")
let { disableNetwork } = require("%globalScripts/clientState/initialState.nut")
let { userIdInt64 } = require("%scripts/user/profileStates.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")


let TUTORIAL_VERSION_COUNTER = 1

let saveVersion = function(ver = null) {
  if (loadLocalByAccount("tutor/tutorialVersion") == null)
    saveLocalByAccount("tutor/tutorialVersion", ver ?? TUTORIAL_VERSION_COUNTER)
}

let getVersion =  @() loadLocalByAccount("tutor/tutorialVersion", 0)

let needShowTutorial = @(id, tutorVersion) !loadLocalByAccount($"tutor/{id}")
  && (isMeNewbie() || getVersion() >= tutorVersion)

let saveShowedTutorial = @(id) saveLocalByAccount($"tutor/{id}", true)


function getFirstCountryChoice() {
  foreach (country in shopCountriesList)
    if (isUnlockOpened($"chosen_{country}"))
      return country

  return null
}

function reqFirstCountryChoice() {
  return getFirstChosenUnitType() != ES_UNIT_TYPE_INVALID
    && getFirstCountryChoice() == null
    && !stat_get_value_respawns(0, 1)
    && !disableNetwork
}

let isTutorialBeforeCountrySelect = @() userIdInt64.get() % 2 != 0


subscriptions.addListenersWithoutEnv({
  AccountReset = function(_p) {
    saveVersion()
    saveLocalByAccount("tutor", null)
    saveLocalAccountSettings("tutor", null)
    saveLocalByAccount(skipTutorialBitmaskId, null)
  }
}, g_listener_priority.CONFIG_VALIDATION)

return {
  saveVersion
  getVersion
  needShowTutorial
  saveShowedTutorial
  reqFirstCountryChoice
  isTutorialBeforeCountrySelect
  getFirstCountryChoice
}

