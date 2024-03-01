from "%rGui/globals/ui_library.nut" import *

let { gameType, timeLeft, timeLimitWarn, customHUD } = require("%rGui/missionState.nut")
let { HasCompass } = require("%rGui/compassState.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")
let football = require("football.ui.nut")
let deathmatch = require("deathmatch.ui.nut")
let po2OpMission = require("po2OpMission.ui.nut")
let convoyHunting = require("convoyHunting.nut")
let mkBattleMissionHud = require("battleMissionHud/mkBattleMissionHud.ui.nut")

let timerComponent = @() {
  watch = timeLeft
  rendObj = ROBJ_TEXT
  font = Fonts.medium_text_hud
  color = Color(255, 255, 255)
  pos = [0, hdpx(40)]
  text = secondsToTimeSimpleString(timeLeft.value)
}

let hasTimerComponent = Computed(@() timeLimitWarn.value > 0 && timeLeft.value < timeLimitWarn.value)

let customHudNameToComp = { deathmatch, convoyHunting, po2OpMission }

function getScoreBoardChildren() {
  if ((gameType.value & GT_FOOTBALL) != 0)
    return football

  if (customHUD.get() == "battleMission")
    return mkBattleMissionHud()

  let customHudComp = customHudNameToComp?[customHUD.get()]
  if (customHudComp)
    return customHudComp

  if (hasTimerComponent.value)
    return timerComponent

  return null
}

return @() {
  watch = [gameType, safeAreaSizeHud, hasTimerComponent, customHUD, HasCompass]
  size = flex()
  pos = [0, (HasCompass.value ? hdpx(50) : 0)]
  margin = safeAreaSizeHud.value.borders
  halign = ALIGN_CENTER
  children = getScoreBoardChildren()
}
