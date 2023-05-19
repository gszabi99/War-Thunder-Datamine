//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")

let isInBattleState = Watched(::is_in_flight())
let isInLoadingScreen = Watched(::is_in_loading_screen())
let isInMenu = Computed(@() !isInBattleState.value && !isInLoadingScreen.value)

let function updateState() {
  isInBattleState(::is_in_flight())
  isInLoadingScreen(::is_in_loading_screen())
}

addListenersWithoutEnv({
  LoadingStateChange = @(_) updateState()
})

return {
  isInBattleState
  isInLoadingScreen
  isInMenu
}