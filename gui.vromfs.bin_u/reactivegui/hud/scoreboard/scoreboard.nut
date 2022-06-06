let { gameType, useDeathmatchHUD, timeLeft, timeLimitWarn } = require("%rGui/missionState.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")
let football = require("football.ui.nut")
let deathmatch = require("deathmatch.ui.nut")

let timerComponent = @() {
  watch = timeLeft
  rendObj = ROBJ_DTEXT
  font = Fonts.medium_text_hud
  color = Color(255, 255, 255)
  pos = [0, hdpx(40)]
  text = secondsToTimeSimpleString(timeLeft.value)
}

let function getScoreBoardChildren() {
  if ((gameType.value & GT_FOOTBALL) != 0)
    return football

  if (useDeathmatchHUD.value)
    return deathmatch

  if (timeLimitWarn.value > 0 && timeLeft.value < timeLimitWarn.value)
    return timerComponent

  return null
}

return @() {
  size = flex()
  margin = safeAreaSizeHud.value.borders
  halign = ALIGN_CENTER
  watch = [gameType, useDeathmatchHUD, safeAreaSizeHud, timeLeft, timeLimitWarn]
  children = getScoreBoardChildren()
}
