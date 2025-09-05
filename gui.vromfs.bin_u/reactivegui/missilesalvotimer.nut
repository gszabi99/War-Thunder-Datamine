from "%rGui/globals/ui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let { styleText } = require("%rGui/style/airHudStyle.nut")
let { get_time_msec } = require("dagor.time")
let { mkCountdownTimerSec } = require("%globalScripts/timers.nut")

let salvoTimerSec = mkWatched(persist, "salvoTimerSec", -1)
let finishTimeMsec = Computed(@() get_time_msec() + (salvoTimerSec.get() * 1000).tointeger())
let countdownTimer = mkCountdownTimerSec(finishTimeMsec, 0.25)
let isTimerVisible = Computed(@() countdownTimer.get() > 0)

eventbus_subscribe("showMissileSalvoTimer", @(res) salvoTimerSec.set(res.timer))

return function(colorWatch, posX, posY) {
  let salvoTimer = @() styleText.__merge({
    watch = [countdownTimer, colorWatch]
    rendObj = ROBJ_TEXT
    text = countdownTimer.get()
    color = colorWatch.value
  })

  return @() {
    watch = isTimerVisible
    pos = [posX, posY]
    children = isTimerVisible.get() ? salvoTimer : null
  }
}