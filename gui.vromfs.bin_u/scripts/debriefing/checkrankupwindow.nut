let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isHandlerInScene } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")
let { updatePlayerRankByCountry } = require("%scripts/user/userInfoStats.nut")

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
