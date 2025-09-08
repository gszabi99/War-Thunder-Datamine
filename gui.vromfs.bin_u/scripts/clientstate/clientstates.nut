from "%scripts/dagui_natives.nut" import is_online_available
from "%scripts/dagui_library.nut" import *

let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getBlkValueByPath } = require("%sqstd/datablock.nut")
let { get_settings_blk } = require("blkGetters")
let { isInFlight } = require("gameplayBinding")

let isInBattleState = Watched(isInFlight())
let isInLoadingScreen = Watched(is_in_loading_screen())
let isInMenu = Computed(@() !isInBattleState.get() && !isInLoadingScreen.get())
let isMatchingOnline = Watched(is_online_available())

function updateState() {
  isInBattleState.set(isInFlight())
  isInLoadingScreen.set(is_in_loading_screen())
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
  isMatchingOnline
  getFromSettingsBlk
}