from "%appGlobals/login/loginState.nut" import isAuthorized
from "%globalScripts/clientState/initialState.nut" import disableNetwork

let optionsMeasureUnits = require("%scripts/options/optionsMeasureUnits.nut")

let hasOptionsInitialized = @() optionsMeasureUnits.isInitialized() && (isAuthorized.get() || disableNetwork)

return {
  hasOptionsInitialized
}
