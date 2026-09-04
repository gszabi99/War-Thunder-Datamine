from "%rGui/hudSpectatorState.nut" import isSpectatorMode
from "%rGui/missionState.nut" import localTeam
from "%appGlobals/login/loginState.nut" import isLoggedIn
from "%sqstd/string.nut" import hexStringToInt
from "%sqstd/underscore.nut" import isEqual
from "eventbus" import eventbus_subscribe
from "%rGui/globals/ui_library.nut" import *

local cc = require("colorCorrector")
let colors = require("%rGui/style/colors.nut")

let defaultTeamColorsData = {
  teamScoreBlueColor    = null
  teamBlueColor         = null
  teamBlueLightColor    = null
  teamBlueInactiveColor = null
  teamBlueDarkColor     = null
  chatTextTeamColor     = null
  teamScoreRedColor     = null
  teamRedColor          = null
  teamRedLightColor     = null
  teamRedInactiveColor  = null
  teamRedDarkColor      = null
  squadColor            = null
  chatTextSquadColor    = null

  hudColorRed           = null
  hudColorBlue          = null
  hudColorSquad         = null
  hudColorDarkRed       = null
  hudColorDarkBlue      = null
  hudColorDeathAlly     = null
  hudColorDeathEnemy    = null
  
  hudColorHero          = colors.hud.mainPlayerColor
  chatTextPrivateColor  = colors.hud.chatTextPrivateColor
  userlogColoredText    = colors.menu.userlogColoredText
  unlockActiveColor     = colors.menu.unlockActiveColor
  streakTextColor       = colors.menu.streakTextColor
  silver                = colors.menu.silver
  chatInfoColor         = 0xFFF2E003
  white                 = colors.white
}

let forcedTeamColors = mkWatched(persist, "forcedTeamColors", {})

let teamColors = Computed(function(prev) {
  local newTeamColors = clone defaultTeamColorsData
  let forcedColors = forcedTeamColors.get()
  local standardColors = !isLoggedIn.get() || !isSpectatorMode.get()
  local allyTeam, allyTeamColor, enemyTeamColor
  local isForcedColor = forcedColors.len() > 0
  if (isForcedColor) {
    allyTeam = localTeam.get()
    allyTeamColor = hexStringToInt(str("FF", (allyTeam == 2 ? forcedColors?.colorTeamB : forcedColors?.colorTeamA)))
    enemyTeamColor = hexStringToInt(str("FF", (allyTeam == 2 ? forcedColors?.colorTeamA : forcedColors?.colorTeamB)))
  }
  local squadTheme = @() standardColors ? cc.TARGET_HUE_SQUAD : cc.TARGET_HUE_SPECTATOR_ALLY
  local allyTheme =  @() standardColors ? cc.TARGET_HUE_ALLY  : cc.TARGET_HUE_SPECTATOR_ALLY
  local enemyTheme = @() standardColors ? cc.TARGET_HUE_ENEMY : cc.TARGET_HUE_SPECTATOR_ENEMY

  foreach (cfg in [
    { theme = allyTheme,  baseColor = Color(30, 30, 255),   name = "teamScoreBlueColor" }
    { theme = allyTheme,  baseColor = Color(82, 122, 255),  name = "teamBlueColor" }
    { theme = allyTheme,  baseColor = Color(153, 177, 255), name = "teamBlueLightColor" }
    { theme = allyTheme,  baseColor = Color(92,  99, 122),  name = "teamBlueInactiveColor" }
    { theme = allyTheme,  baseColor = Color(16,  24,  52),  name = "teamBlueDarkColor" }
    { theme = allyTheme,  baseColor = Color(130, 194, 255), name = "chatTextTeamColor" }
    { theme = enemyTheme, baseColor = Color(255, 30, 30),   name = "teamScoreRedColor" }
    { theme = enemyTheme, baseColor = Color(255,  90,  82), name = "teamRedColor" }
    { theme = enemyTheme, baseColor = Color(255, 162, 157), name = "teamRedLightColor" }
    { theme = enemyTheme, baseColor = Color(124,  95,  93), name = "teamRedInactiveColor" }
    { theme = enemyTheme, baseColor = Color(52,  17,  16),  name = "teamRedDarkColor" }
    { theme = squadTheme, baseColor = Color(62, 158,  47),  name = "squadColor" }
    { theme = squadTheme, baseColor = Color(198, 255, 189), name = "chatTextSquadColor" }
  ]) {
    newTeamColors[cfg.name] = isForcedColor
      ? (cfg.theme == enemyTheme ? enemyTeamColor : allyTeamColor) 
      : cc.correctHueTarget(cfg.baseColor, cfg.theme())
  }
  newTeamColors.teamBlueLightColor  = cc.correctColorLightness(newTeamColors.teamBlueColor, 0.808)
  newTeamColors.teamRedLightColor   = cc.correctColorLightness(newTeamColors.teamRedColor, 0.808)

  newTeamColors.hudColorRed         = newTeamColors.teamRedColor
  newTeamColors.hudColorBlue        = newTeamColors.teamBlueColor
  newTeamColors.hudColorSquad       = newTeamColors.squadColor
  newTeamColors.hudColorDarkRed     = newTeamColors.teamRedInactiveColor
  newTeamColors.hudColorDarkBlue    = newTeamColors.teamBlueInactiveColor
  newTeamColors.hudColorDeathAlly   = newTeamColors.teamRedLightColor
  newTeamColors.hudColorDeathEnemy  = newTeamColors.teamBlueLightColor

  return prev == FRP_INITIAL || !isEqual(prev, newTeamColors) ? newTeamColors
    : prev
})

eventbus_subscribe("recalculateTeamColors", @(v) forcedTeamColors.set(v.forcedColors))

return teamColors
