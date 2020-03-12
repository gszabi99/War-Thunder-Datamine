local cc = ::require_native("colorCorrector")
local string = require("std/string.nut")
local missionState = require("reactiveGui/missionState.nut")
local u = require("std/underscore.nut")
local colors = require("colors.nut")

local teamColors = Watched({
  teamBlueColor         = null
  teamBlueLightColor    = null
  teamBlueInactiveColor = null
  teamBlueDarkColor     = null
  chatTextTeamColor     = null
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
  //const colors
  hudColorHero          = colors.hud.mainPlayerColor
  chatTextPrivateColor  = colors.hud.chatTextPrivateColor
  userlogColoredText    = colors.menu.userlogColoredText
  unlockActiveColor     = colors.menu.unlockActiveColor
  streakTextColor       = colors.menu.streakTextColor
  silver                = colors.menu.silver

  forcedTeamColors      = {}
})


::interop.recalculateTeamColors <- function (forcedColors = {}) {
  local newTeamColors = clone teamColors.value
  newTeamColors.forcedTeamColors = forcedColors
  local standardColors = !::cross_call.login.isLoggedIn() || !::cross_call.isPlayerDedicatedSpectator()
  local allyTeam, allyTeamColor, enemyTeamColor
  local isForcedColor = forcedColors && forcedColors.len() > 0
  if (isForcedColor)
  {
    allyTeam = missionState.localTeam.value
    allyTeamColor = string.hexStringToInt( "FF" + (allyTeam == 2 ? forcedColors?.colorTeamB : forcedColors?.colorTeamA) )
    enemyTeamColor = string.hexStringToInt( "FF" + (allyTeam == 2 ? forcedColors?.colorTeamA : forcedColors?.colorTeamB) )
  }
  local squadTheme = @() standardColors ? cc.TARGET_HUE_SQUAD : cc.TARGET_HUE_SPECTATOR_ALLY
  local allyTheme =  @() standardColors ? cc.TARGET_HUE_ALLY  : cc.TARGET_HUE_SPECTATOR_ALLY
  local enemyTheme = @() standardColors ? cc.TARGET_HUE_ENEMY : cc.TARGET_HUE_SPECTATOR_ENEMY

  foreach (cfg in [
    { theme = allyTheme,  baseColor = Color( 82, 122, 255), name = "teamBlueColor" }
    { theme = allyTheme,  baseColor = Color(153, 177, 255), name = "teamBlueLightColor"}
    { theme = allyTheme,  baseColor = Color( 92,  99, 122), name = "teamBlueInactiveColor" }
    { theme = allyTheme,  baseColor = Color( 16,  24,  52), name = "teamBlueDarkColor" }
    { theme = allyTheme,  baseColor = Color(189, 204, 255), name = "chatTextTeamColor" }
    { theme = enemyTheme, baseColor = Color(255,  90,  82), name = "teamRedColor" }
    { theme = enemyTheme, baseColor = Color(255, 162, 157), name = "teamRedLightColor" }
    { theme = enemyTheme, baseColor = Color(124,  95,  93), name = "teamRedInactiveColor" }
    { theme = enemyTheme, baseColor = Color( 52,  17,  16), name = "teamRedDarkColor" }
    { theme = squadTheme, baseColor = Color( 62, 158,  47), name = "squadColor" }
    { theme = squadTheme, baseColor = Color(198, 255, 189), name = "chatTextSquadColor" }
  ]) {
    newTeamColors[cfg.name] = isForcedColor
      ? (cfg.theme == enemyTheme ? enemyTeamColor : allyTeamColor)
      : cc.correctHueTarget(cfg.baseColor, cfg.theme())
  }
  newTeamColors.teamBlueLightColor  = cc.correctColorLightness(newTeamColors.teamBlueColor, 50)
  newTeamColors.teamRedLightColor   = cc.correctColorLightness(newTeamColors.teamRedColor, 50)

  newTeamColors.hudColorRed         = newTeamColors.teamRedColor
  newTeamColors.hudColorBlue        = newTeamColors.teamBlueColor
  newTeamColors.hudColorSquad       = newTeamColors.squadColor
  newTeamColors.hudColorDarkRed     = newTeamColors.teamRedInactiveColor
  newTeamColors.hudColorDarkBlue    = newTeamColors.teamBlueInactiveColor
  newTeamColors.hudColorDeathAlly   = newTeamColors.teamRedLightColor
  newTeamColors.hudColorDeathEnemy  = newTeamColors.teamBlueLightColor

  if (!u.isEqual(teamColors.value, newTeamColors))
    teamColors.update(newTeamColors)
}

::interop.recalculateTeamColors()

missionState.localTeam.subscribe(function (new_val) {
  ::interop.recalculateTeamColors(teamColors.value.forcedTeamColors)
})

return teamColors
