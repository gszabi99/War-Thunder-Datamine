from "%globalScripts/unlockConsts.nut" import *
from "%scripts/dagui_library.nut" import *
let { checkRankUpWindow } = require("%scripts/debriefing/checkRankUpWindow.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isHandlerInScene } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")
let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { disableSeenUserlogs } = require("%scripts/userLog/userlogUtils.nut")

let delayedUnlockWnd = []
function guiStartUnlockWnd(config) {
  let unlockType = (config?.type ?? -1)
  if (unlockType == UNLOCKABLE_COUNTRY) {
    if (isInArray(config.id, shopCountriesList))
      return checkRankUpWindow(config.id, -1, 1, config)
    return false
  }
  else if (unlockType == "TournamentReward")
    return get_gui_handler("TournamentRewardReceivedWnd")?.open(config)

  loadHandler(get_gui_handler("ShowUnlockHandler"), { config = config })
  return true
}

function showUnlockWnd(config) {
  if (isHandlerInScene(get_gui_handler("ShowUnlockHandler")) ||
      isHandlerInScene(get_gui_handler("RankUpModal")) ||
      isHandlerInScene(get_gui_handler("TournamentRewardReceivedWnd")))
    return delayedUnlockWnd.append(config)

  guiStartUnlockWnd(config)
}

function checkDelayedUnlockWnd(prevUnlockData = null) {
  disableSeenUserlogs([prevUnlockData?.disableLogId])

  if (!delayedUnlockWnd.len())
    return

  let unlockData = delayedUnlockWnd.remove(0)
  if (!guiStartUnlockWnd(unlockData))
    checkDelayedUnlockWnd(unlockData)
}

return {
  guiStartUnlockWnd
  checkDelayedUnlockWnd
  showUnlockWnd
}