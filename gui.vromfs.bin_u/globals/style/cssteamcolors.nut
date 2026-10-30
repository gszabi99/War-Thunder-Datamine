import "colorCorrector" as cc

const defaultMainPlayerColor = "#dda339"

const teamColorBases = [
  { style = "squad", baseColor = "3E9E2F", names = [ "mySquadColor", "squadColor", "hudColorSquad", "chatSenderMySquadColor", "chatTextSquadVoiceColor" ] }
  { style = "squad", baseColor = "65FF4D", names = [ "chatTextSquadColor" ] }
  { style = "squad", baseColor = "A5FF97", names = [ "mySquadLightColor" ] }
  { style = "ally",  baseColor = "1E1EFF", names = [ "teamScoreBlueColor" ] }
  { style = "ally",  baseColor = "527AFF", names = [ "teamBlueColor", "hudColorBlue", "chatSenderFriendColor", "chatTextTeamVoiceColor" ],
    lightNames = [ "teamBlueLightColor", "hudColorDeathEnemy" ] }
  { style = "ally",  baseColor = "5C637A", names = [ "teamBlueInactiveColor", "hudColorDarkBlue" ] }
  { style = "ally",  baseColor = "101834", names = [ "teamBlueDarkColor" ] }
  { style = "ally",  baseColor = "82C2FF", names = [ "chatTextTeamColor" ] }
  { style = "enemy", baseColor = "FF1E1E", names = [ "teamScoreRedColor" ] }
  { style = "enemy", baseColor = "FF5A52", names = [ "teamRedColor", "hudColorRed", "chatSenderEnemyColor", "chatTextEnemyVoiceColor" ],
    lightNames = [ "teamRedLightColor", "hudColorDeathAlly" ] }
  { style = "enemy", baseColor = "7C5F5D", names = [ "teamRedInactiveColor", "hudColorDarkRed" ] }
  { style = "enemy", baseColor = "341110", names = [ "teamRedDarkColor" ] }
]

function calcTeamColors(forcedColors, allyTeam, isStandard, isCorrected = true) {
  let isForced = isCorrected && ("colorTeamA" in forcedColors) && ("colorTeamB" in forcedColors)
  let allyColor = allyTeam == 2 ? forcedColors?.colorTeamB : forcedColors?.colorTeamA
  let enemyColor = allyTeam == 2 ? forcedColors?.colorTeamA : forcedColors?.colorTeamB
  let targets = {
    squad = isStandard ? cc.TARGET_HUE_SQUAD : cc.TARGET_HUE_SPECTATOR_ALLY
    ally  = isStandard ? cc.TARGET_HUE_ALLY  : cc.TARGET_HUE_SPECTATOR_ALLY
    enemy = isStandard ? cc.TARGET_HUE_ENEMY : cc.TARGET_HUE_SPECTATOR_ENEMY
  }
  let heroColor = isForced ? $"#{allyColor}" : defaultMainPlayerColor
  let res = { mainPlayerColor = heroColor, chatSenderMeColor = heroColor, hudColorHero = heroColor }
  foreach (cfg in teamColorBases) {
    let color = isForced ? (cfg.style == "enemy" ? enemyColor : allyColor)
      : isCorrected ? cc.correctHueTarget(cfg.baseColor, targets[cfg.style])
      : cfg.baseColor
    foreach (name in cfg.names)
      res[name] <- $"#{color}"
    foreach (name in cfg?.lightNames ?? [])
      res[name] <- $"#{cc.correctColorLightness(color, 0.808)}"
  }
  return res
}

return freeze({
  calcTeamColors
})
