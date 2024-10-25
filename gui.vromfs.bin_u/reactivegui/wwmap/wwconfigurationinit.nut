from "%rGui/globals/ui_library.nut" import *
let { initConfigurableValues } = require("%rGui/wwMap/wwConfigurableValues.nut")
let { initWWSettings } = require("%rGui/wwMap/wwSettings.nut")
let { loadOperationData, isOperationDataLoaded } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { updateAirfieldsData } = require("%rGui/wwMap/wwAirfieldsStates.nut")

let configurationLoaded = Watched(false)

function initConfiguration() {
  if(!initWWSettings())
    return
  loadOperationData()
  initConfigurableValues()
  updateAirfieldsData()
  configurationLoaded.set(true)
}

function invalidateConfiguration() {
  configurationLoaded.set(false)
  isOperationDataLoaded.set(false)
}

return {
  configurationLoaded
  initConfiguration
  invalidateConfiguration
}
