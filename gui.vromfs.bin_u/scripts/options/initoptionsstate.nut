import "%scripts/options/optionsMeasureUnits.nut" as optionsMeasureUnits
from "%appGlobals/login/loginState.nut" import isAuthorized
from "%globalScripts/clientState/initialState.nut" import disableNetwork

let hasOptionsInitialized = @() optionsMeasureUnits.isInitialized() && (isAuthorized.get() || disableNetwork)

return freeze({
  hasOptionsInitialized
})
