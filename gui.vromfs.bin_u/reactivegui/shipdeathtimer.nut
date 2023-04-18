from "%rGui/globals/ui_library.nut" import *

let { timeToDeath } = require("shipState.nut")
let { alert } = require("style/colors.nut").hud.damageModule
let { secondsToTimeFormatString } = require("%sqstd/time.nut")
let timeLocTable = require("timeLocTable.nut")

let showTimeToDeath = Computed(@() timeToDeath.value > 0)

return @() {
  watch = showTimeToDeath
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  children = !showTimeToDeath.value ? null : [
    {
      rendObj = ROBJ_TEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = str(loc("hints/leaving_the_tank_in_progress"), loc("ui/colon"))
      color = alert
    }
    @() {
      watch = timeToDeath
      rendObj = ROBJ_TEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = secondsToTimeFormatString(timeToDeath.value).subst(timeLocTable)
      color = alert
    }
  ]
}
