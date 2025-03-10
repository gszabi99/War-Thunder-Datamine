from "%scripts/dagui_library.nut" import *

let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getBlkValueByPath } = require("%sqstd/datablock.nut")
let { get_settings_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")

let isInBattleState = Watched(isInFlight())
let isInLoadingScreen = Watched(is_in_loading_screen())
let isInMenu = Computed(@() !isInBattleState.value && !isInLoadingScreen.value)

function updateState() {
  isInBattleState(isInFlight())
  isInLoadingScreen(is_in_loading_screen())
}

function getFromSettingsBlk(path, defVal = null) {
  
  let blk = get_settings_blk()
  let val = getBlkValueByPath(blk, path)
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