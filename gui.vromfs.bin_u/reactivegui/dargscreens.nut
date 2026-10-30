import "%rGui/hud/killFeed.nut" as killFeed
import "%rGui/hud/hintMessages.nut" as hintMessages
from "%rGui/hud/mpScore/mpScore.nut" import mpScoreHud, mpScoreLine
import "%rGui/login/loginScreen.nut" as loginScreen
import "%rGui/options/optionsScreen.nut" as optionsScreen
import "%rGui/controls/controlsScreen.nut" as controlsScreen


return freeze({
  ["hud.killFeed"] = killFeed,
  ["hud.hintMessages"] = hintMessages,
  ["hud.mpScore"] = mpScoreHud,
  mpScore = mpScoreLine,
  login = loginScreen,
  options = optionsScreen,
  controls = controlsScreen,
})
