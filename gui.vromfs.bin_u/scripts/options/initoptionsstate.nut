let optionsMeasureUnits = require("%scripts/options/optionsMeasureUnits.nut")
let { isAuthorized } = require("%appGlobals/login/loginState.nut")
let { disableNetwork } = require("%globalScripts/clientState/initialState.nut")

let hasOptionsInitialized = @() optionsMeasureUnits.isInitialized() && (isAuthorized.get() || disableNetwork)

return {
  hasOptionsInitialized
}
