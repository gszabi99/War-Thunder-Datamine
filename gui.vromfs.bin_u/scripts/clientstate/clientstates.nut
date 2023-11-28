//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { get_settings_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")

let isInBattleState = Watched(isInFlight())
let isInLoadingScreen = Watched(is_in_loading_screen())
let isInMenu = Computed(@() !isInBattleState.value && !isInLoadingScreen.value)

let function updateState() {
  isInBattleState(isInFlight())
  isInLoadingScreen(is_in_loading_screen())
}

let function getFromSettingsBlk(path, defVal = null) {
  // Important: On production, settings blk does NOT contain all variables from config.blk, use getSystemConfigOption() instead.
  let blk = get_settings_blk()
  let val = get_blk_value_by_path(blk, path)
  return (val != null) ? val : defVal
}

addListenersWithoutEnv({
  LoadingStateChange = @(_) updateState()
})

return {
  isInBattleState
  isInLoadingScreen
  isInMenu
  getFromSettingsBlk
}