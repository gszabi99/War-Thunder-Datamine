from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%sqstd/datablock.nut" import getBlkValueByPath
from "blkGetters" import get_settings_blk
from "gameplayBinding" import isInFlight
from "%scripts/dagui_natives.nut" import is_online_available
from "%scripts/dagui_library.nut" import *

let { is_in_loading_screen } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")

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