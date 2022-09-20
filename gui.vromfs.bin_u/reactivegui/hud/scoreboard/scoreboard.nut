let { gameType, useDeathmatchHUD, timeLeft, timeLimitWarn, customHUD } = require("%rGui/missionState.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let { secondsToTimeSimpleString } = require("%sqstd/time.nut")
let football = require("football.ui.nut")
let deathmatch = require("deathmatch.ui.nut")
let po2OpMission = require("po2OpMission.ui.nut")

let timerComponent = @() {
  watch = timeLeft
  rendObj = ROBJ_TEXT
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

  if (customHUD.value == "po2OpMission")
    return po2OpMission

  if (timeLimitWarn.value > 0 && timeLeft.value < timeLimitWarn.value)
    return timerComponent

  return null
}

return @() {
  size = flex()
  margin = safeAreaSizeHud.value.borders
  halign = ALIGN_CENTER
  watch = [gameType, useDeathmatchHUD, safeAreaSizeHud, timeLeft, timeLimitWarn, customHUD]
  children = getScoreBoardChildren()
}
