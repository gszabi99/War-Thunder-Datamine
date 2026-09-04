from "%rGui/wwMap/wwConfigurableValues.nut" import initConfigurableValues
from "%appGlobals/worldWar/wwSettings.nut" import clearSettingsCache
from "%rGui/wwMap/wwOperationConfiguration.nut" import loadOperationData, isOperationDataLoaded
from "%rGui/wwMap/wwAirfieldsStates.nut" import updateAirfieldsData
from "%rGui/globals/ui_library.nut" import *

let configurationLoaded = Watched(false)

function initConfiguration() {
  loadOperationData()
  initConfigurableValues()
  updateAirfieldsData()
  configurationLoaded.set(true)
}

function invalidateConfiguration() {
  configurationLoaded.set(false)
  isOperationDataLoaded.set(false)
  clearSettingsCache()
}

return {
  configurationLoaded
  initConfiguration
  invalidateConfiguration
}
