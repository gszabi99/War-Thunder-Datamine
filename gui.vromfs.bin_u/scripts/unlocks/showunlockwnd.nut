from "%scripts/dagui_library.nut" import *
from "%scripts/social/psConsts.nut" import bit_activity

let { checkRankUpWindow } = require("%scripts/debriefing/checkRankUpWindow.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isHandlerInScene } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { disableSeenUserlogs } = require("%scripts/userLog/userlogUtils.nut")

let delayedUnlockWnd = []
function guiStartUnlockWnd(config) {
  let unlockType = getTblValue("type", config, -1)
  if (unlockType == UNLOCKABLE_COUNTRY) {
    if (isInArray(config.id, shopCountriesList))
      return checkRankUpWindow(config.id, -1, 1, config)
    return false
  }
  else if (unlockType == "TournamentReward")
    return gui_handlers.TournamentRewardReceivedWnd.open(config)

  loadHandler(gui_handlers.ShowUnlockHandler, { config = config })
  return true
}

function showUnlockWnd(config) {
  if (isHandlerInScene(gui_handlers.ShowUnlockHandler) ||
      isHandlerInScene(gui_handlers.RankUpModal) ||
      isHandlerInScene(gui_handlers.TournamentRewardReceivedWnd))
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