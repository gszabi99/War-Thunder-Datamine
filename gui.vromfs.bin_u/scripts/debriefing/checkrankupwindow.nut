from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/sqDagui/framework/baseGuiHandlerManager.nut" import isHandlerInScene
from "%scripts/user/userInfoStats.nut" import updatePlayerRankByCountry

let delayedRankUpWnd = []

function checkRankUpWindow(country, old_rank, new_rank, unlockData = null) {
  if (country == "country_0" || country == "")
    return false
  if (new_rank <= old_rank)
    return false

  let gained_ranks = [];
  for (local i = old_rank + 1; i <= new_rank; i++)
    gained_ranks.append(i);
  let config = { country = country, ranks = gained_ranks, unlockData = unlockData }
  if (isHandlerInScene(get_gui_handler("RankUpModal")))
    delayedRankUpWnd.append(config) 
  else
    loadHandler(get_gui_handler("RankUpModal"), config)
  updatePlayerRankByCountry(country, new_rank)
  return true
}

return {
  delayedRankUpWnd
  checkRankUpWindow
}
