import "%rGui/style/colors.nut" as colors
import "%appGlobals/style/cssColorToInt.nut" as cssColorToInt
from "%rGui/hudSpectatorState.nut" import isDedicatedSpectator
from "%rGui/missionState.nut" import localTeam
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "%appGlobals/style/cssTeamColors.nut" import calcTeamColors
from "%sqstd/underscore.nut" import isEqual
from "eventbus" import eventbus_subscribe
from "%rGui/globals/ui_library.nut" import *

const teamColorNames = [
  "teamScoreBlueColor", "teamBlueColor", "teamBlueLightColor", "teamBlueInactiveColor", "teamBlueDarkColor", "chatTextTeamColor",
  "teamScoreRedColor", "teamRedColor", "teamRedLightColor", "teamRedInactiveColor", "teamRedDarkColor", "squadColor",
  "chatTextSquadColor", "hudColorRed", "hudColorBlue", "hudColorSquad", "hudColorDarkRed", "hudColorDarkBlue",
  "hudColorDeathAlly", "hudColorDeathEnemy", "hudColorHero"
]

let constTeamColors = {
  chatTextPrivateColor  = colors.hud.chatTextPrivateColor
  userlogColoredText    = colors.menu.userlogColoredText
  unlockActiveColor     = colors.menu.unlockActiveColor
  streakTextColor       = colors.menu.streakTextColor
  silver                = colors.menu.silver
  chatInfoColor         = 0xFFF2E003
  white                 = colors.white
  red                   = colors.red
  orange                = colors.orange
}

let forcedTeamColors = mkWatched(persist, "forcedTeamColors", {})

let teamColors = Computed(function(prev) {
  let cssTexts = calcTeamColors(forcedTeamColors.get(), localTeam.get(), !hasFullLoginState.get() || !isDedicatedSpectator.get())
  let newTeamColors = { ...constTeamColors }
  foreach (name in teamColorNames)
    newTeamColors[name] <- cssColorToInt(cssTexts[name])
  return prev == FRP_INITIAL || !isEqual(prev, newTeamColors) ? newTeamColors
    : prev
})

eventbus_subscribe("recalculateTeamColors", @(v) forcedTeamColors.set(v.forcedColors))

return teamColors
