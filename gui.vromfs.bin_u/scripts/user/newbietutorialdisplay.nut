import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
from "%scripts/tutorials/tutorialsState.nut" import skipTutorialBitmaskId
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings
from "%scripts/clientState/localProfileDeprecated.nut" import loadLocalByAccount, saveLocalByAccount
from "%scripts/myStats.nut" import isMeNewbie
from "%scripts/firstChoice/firstChoice.nut" import getFirstChosenUnitType
from "%scripts/unlocks/unlocksModule.nut" import isUnlockOpened
from "%globalScripts/clientState/initialState.nut" import disableNetwork
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/dagui_natives.nut" import stat_get_value_respawns

let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")


const TUTORIAL_VERSION_COUNTER = 1

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

subscriptions.addListenersWithoutEnv({
  AccountReset = function(_p) {
    saveVersion()
    saveLocalByAccount("tutor", null)
    saveLocalAccountSettings("tutor", null)
    saveLocalByAccount(skipTutorialBitmaskId, null)
  }
}, g_listener_priority.CONFIG_VALIDATION)

return freeze({
  saveVersion
  getVersion
  needShowTutorial
  saveShowedTutorial
  reqFirstCountryChoice
  getFirstCountryChoice
})
