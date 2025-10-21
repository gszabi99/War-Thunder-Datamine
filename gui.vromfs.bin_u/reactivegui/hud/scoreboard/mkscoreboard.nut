from "%rGui/globals/ui_library.nut" import *

let { gameType, timeLeft, timeLimitWarn, customHUD } = require("%rGui/missionState.nut")
let { HasCompass } = require("%rGui/compassState.nut")
let { safeAreaSizeHud, safeAreaSizeMenu } = require("%rGui/style/screenState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")
let football = require("%rGui/hud/scoreboard/football.ui.nut")
let deathmatch = require("%rGui/hud/scoreboard/deathmatch.ui.nut")
let po2OpMission = require("%rGui/hud/scoreboard/po2OpMission.ui.nut")
let convoyHunting = require("%rGui/hud/scoreboard/convoyHunting.nut")
let mkBattleMissionHud = require("%rGui/hud/scoreboard/battleMissionHud/mkBattleMissionHud.ui.nut")
let { isInSpectatorMode, isInRespawnWnd } = require("%rGui/respawnWndState.nut")
let { fontSizeMultiplier } = require("%rGui/style/fontsState.nut")
let extraction = require("%rGui/hud/scoreboard/extraction.nut")
let { sead, oil_refinery_strbomb, power_plant_strbomb } = require("%rGui/hud/scoreboard/assimModes.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")

let getNoRespTextSize = @() fpx(22)

let timerComponent = @() {
  watch = timeLeft
  rendObj = ROBJ_TEXT
  font = Fonts.medium_text_hud
  color = Color(255, 255, 255)
  pos = [0, hdpx(40)]
  text = secondsToTimeSimpleString(timeLeft.get())
}

let hasTimerComponent = Computed(@() !isInRespawnWnd.get()
  && timeLimitWarn.get() > 0 && timeLeft.get() < timeLimitWarn.get())

let customHudNameToComp = { deathmatch, convoyHunting, po2OpMission, extraction, sead, oil_refinery_strbomb, power_plant_strbomb }

function getScoreBoardChildren() {
  if ((gameType.get() & GT_FOOTBALL) != 0)
    return football

  if (customHUD.get() == "battleMission")
    return mkBattleMissionHud()

  let customHudComp = customHudNameToComp?[customHUD.get()]
  if (customHudComp)
    return customHudComp

  if (hasTimerComponent.get())
    return timerComponent

  return null
}

return function mkScoreboard() {
  let hudScale = Computed(@() isInRespawnWnd.get()
    ? min(fontSizeMultiplier.get(), 1)
    : 1)

  let yPos = Computed(function() {
    if (!isInRespawnWnd.get())
      return HasCompass.get() && !isAAComplexMenuActive.get() ? hdpx(50) : 0
    if (isInSpectatorMode.get())
      return getNoRespTextSize() + hdpx(4)
    return 0
  })

  let margin = Computed(@() isInRespawnWnd.get() ? safeAreaSizeMenu.get().borders : safeAreaSizeHud.get().borders)

  return @() {
    watch = [gameType, margin, hasTimerComponent, customHUD, HasCompass, yPos, hudScale, isInRespawnWnd]
    size = flex()
    pos = [0, yPos.get()]
    margin = margin.get()
    halign = ALIGN_CENTER
    children = getScoreBoardChildren()

    transform = {
      scale = [hudScale.get(), hudScale.get()]
      pivot = [0.5, 0]
    }
  }
}