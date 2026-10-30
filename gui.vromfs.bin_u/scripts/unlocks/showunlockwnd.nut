from "%scripts/debriefing/checkRankUpWindow.nut" import checkRankUpWindow
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/sqDagui/framework/baseGuiHandlerManager.nut" import isHandlerInScene
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/userLog/userlogUtils.nut" import disableSeenUserlogs
from "%globalScripts/unlockConsts.nut" import *
from "%scripts/dagui_library.nut" import *

let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

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

return freeze({
  guiStartUnlockWnd
  checkDelayedUnlockWnd
  showUnlockWnd
})