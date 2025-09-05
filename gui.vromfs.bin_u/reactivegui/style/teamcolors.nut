from "%rGui/globals/ui_library.nut" import *

let cross_call = require("%rGui/globals/cross_call.nut")
local cc = require("colorCorrector")
let { hexStringToInt } = require("%sqstd/string.nut")
let { localTeam } = require("%rGui/missionState.nut")
let { isEqual } = require("%sqstd/underscore.nut")
let colors = require("%rGui/style/colors.nut")
let { eventbus_subscribe } = require("eventbus")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

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
  
  hudColorHero          = colors.hud.mainPlayerColor
  chatTextPrivateColor  = colors.hud.chatTextPrivateColor
  userlogColoredText    = colors.menu.userlogColoredText
  unlockActiveColor     = colors.menu.unlockActiveColor
  streakTextColor       = colors.menu.streakTextColor
  silver                = colors.menu.silver
  chatInfoColor         = 0xFFF2E003

  forcedTeamColors      = {}
})


function recalculateTeamColors(forcedColors = {}) {
  local newTeamColors = clone teamColors.get()
  newTeamColors.forcedTeamColors = forcedColors
  local standardColors = !isLoggedIn.get() || !cross_call.isPlayerDedicatedSpectator()
  local allyTeam, allyTeamColor, enemyTeamColor
  local isForcedColor = forcedColors && forcedColors.len() > 0
  if (isForcedColor) {

    allyTeam = localTeam.get()
    allyTeamColor = hexStringToInt(str("FF", (allyTeam == 2 ? forcedColors?.colorTeamB : forcedColors?.colorTeamA)))
    enemyTeamColor = hexStringToInt(str("FF", (allyTeam == 2 ? forcedColors?.colorTeamA : forcedColors?.colorTeamB)))
  }
  local squadTheme = @() standardColors ? cc.TARGET_HUE_SQUAD : cc.TARGET_HUE_SPECTATOR_ALLY
  local allyTheme =  @() standardColors ? cc.TARGET_HUE_ALLY  : cc.TARGET_HUE_SPECTATOR_ALLY
  local enemyTheme = @() standardColors ? cc.TARGET_HUE_ENEMY : cc.TARGET_HUE_SPECTATOR_ENEMY

  foreach (cfg in [
    { theme = allyTheme,  baseColor = Color(82, 122, 255), name = "teamBlueColor" }
    { theme = allyTheme,  baseColor = Color(153, 177, 255), name = "teamBlueLightColor" }
    { theme = allyTheme,  baseColor = Color(92,  99, 122), name = "teamBlueInactiveColor" }
    { theme = allyTheme,  baseColor = Color(16,  24,  52), name = "teamBlueDarkColor" }
    { theme = allyTheme,  baseColor = Color(130, 194, 255), name = "chatTextTeamColor" }
    { theme = enemyTheme, baseColor = Color(255,  90,  82), name = "teamRedColor" }
    { theme = enemyTheme, baseColor = Color(255, 162, 157), name = "teamRedLightColor" }
    { theme = enemyTheme, baseColor = Color(124,  95,  93), name = "teamRedInactiveColor" }
    { theme = enemyTheme, baseColor = Color(52,  17,  16), name = "teamRedDarkColor" }
    { theme = squadTheme, baseColor = Color(62, 158,  47), name = "squadColor" }
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

  if (!isEqual(teamColors.get(), newTeamColors))
    teamColors.set(newTeamColors)
}

recalculateTeamColors()

localTeam.subscribe(function (_new_val) {
  recalculateTeamColors(teamColors.get().forcedTeamColors)
})

isLoggedIn.subscribe(@(_) recalculateTeamColors(teamColors.get().forcedTeamColors))

eventbus_subscribe("recalculateTeamColors", @(v) recalculateTeamColors(v.forcedColors))

return teamColors
