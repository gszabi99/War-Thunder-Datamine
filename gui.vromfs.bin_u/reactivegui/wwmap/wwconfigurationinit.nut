from "%rGui/globals/ui_library.nut" import *
let { initConfigurableValues } = require("%rGui/wwMap/wwConfigurableValues.nut")
let { clearSettingsCache } = require("%appGlobals/worldWar/wwSettings.nut")
let { loadOperationData, isOperationDataLoaded } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { updateAirfieldsData } = require("%rGui/wwMap/wwAirfieldsStates.nut")

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
