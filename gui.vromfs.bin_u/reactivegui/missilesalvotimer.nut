from "%rGui/globals/ui_library.nut" import *
let { subscribe } = require("eventbus")
let { styleText } = require("style/airHudStyle.nut")
let { get_time_msec } = require("dagor.time")
let { mkCountdownTimerSec } = require("%globalScripts/timers.nut")

let salvoTimerSec = mkWatched(persist, "salvoTimerSec", -1)
let finishTimeMsec = Computed(@() get_time_msec() + (salvoTimerSec.value * 1000).tointeger())
let countdownTimer = mkCountdownTimerSec(finishTimeMsec, 0.25)
let isTimerVisible = Computed(@() countdownTimer.value > 0)

subscribe("showMissileSalvoTimer", @(res) salvoTimerSec(res.timer))

return function(colorWatch, posX, posY) {
  let salvoTimer = @() styleText.__merge({
    watch = [countdownTimer, colorWatch]
    rendObj = ROBJ_TEXT
    text = countdownTimer.value
    color = colorWatch.value
  })

  return @() {
    watch = isTimerVisible
    pos = [posX, posY]
    children = isTimerVisible.value ? salvoTimer : null
  }
}