import "%rGui/hud/scoreboard/infantry.ui.nut" as mkInfantry
import "%rGui/hud/scoreboard/deathmatch.ui.nut" as deathmatch
import "%rGui/hud/scoreboard/convoyHunting.nut" as convoyHunting
import "%rGui/hud/scoreboard/battleMissionHud/mkBattleMissionHud.ui.nut" as mkBattleMissionHud
import "%rGui/hud/scoreboard/nuclearEscalation.ui.nut" as mkNuclearEscalationHud
import "%rGui/dominationNotification.nut" as dominationNotification
from "%rGui/missionState.nut" import gameType, timeLeft, timeLimitWarn, customHUD
from "%rGui/compassState.nut" import HasCompass
from "%rGui/style/screenState.nut" import safeAreaSizeHud, safeAreaSizeMenu, safeAreaHud
from "%rGui/respawnWndState.nut" import isInSpectatorMode, isInRespawnWnd
from "%rGui/style/fontsState.nut" import fontSizeMultiplier
from "%rGui/hud/scoreboard/assimModes.nut" import sead, oil_refinery_strbomb, power_plant_strbomb
from "%appGlobals/hud/hudState.nut" import isAAComplexMenuActive
from "%sqstd/time.nut" import secondsToTimeSimpleString
from "%globalScripts/gameTypeConsts.nut" import *
from "%rGui/globals/ui_library.nut" import *

let football = require("%rGui/hud/scoreboard/football.ui.nut")
let po2OpMission = require("%rGui/hud/scoreboard/po2OpMission.ui.nut")
let extraction = require("%rGui/hud/scoreboard/extraction.nut")

let getNoRespTextSize = @() fpx(22)

let timerComponent = @() {
  watch = timeLeft
  rendObj = ROBJ_TEXT
  font = Fonts.medium_text_hud
  color = Color(255, 255, 255)
  pos = const [0, hdpx(40)]
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
  else if (customHUD.get() == "infantryMission")
    return mkInfantry()
  else if (customHUD.get() == "nuclearEscalation")
    return mkNuclearEscalationHud()

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
      return HasCompass.get() && !isAAComplexMenuActive.get()
        ? customHUD.get() == "infantryMission"
          ? (hdpx(34) + (safeAreaHud.get()[1] == 1.0 ? 0 : hdpx(8)))
          : hdpx(50)
        : 0
    if (isInSpectatorMode.get())
      return getNoRespTextSize() + hdpx(4)
    return 0
  })

  let margin = Computed(@() isInRespawnWnd.get() ? safeAreaSizeMenu.get().borders : safeAreaSizeHud.get().borders)

  return @() {
    watch = [gameType, margin, hasTimerComponent, customHUD, HasCompass, yPos, hudScale, isInRespawnWnd]
    size = FLEX
    pos = [0, yPos.get()]
    margin = margin.get()
    halign = ALIGN_CENTER
    flow = FLOW_VERTICAL
    gap = hdpx(10)
    children = [
      getScoreBoardChildren()
      dominationNotification
    ]

    transform = {
      scale = [hudScale.get(), hudScale.get()]
      pivot = [0.5, 0]
    }
  }
}