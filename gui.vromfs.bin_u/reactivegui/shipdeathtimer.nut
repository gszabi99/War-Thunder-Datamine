local {timeToDeath} = require("shipState.nut")
local {alert} = require("style/colors.nut").hud.damageModule
local {secondsToTimeFormatString} = require("std/time.nut")
local timeLocTable = require("timeLocTable.nut")

local showTimeToDeath = Computed(@() timeToDeath.value > 0)

return @(){
  watch = showTimeToDeath
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  children = !showTimeToDeath.value ? null : [
    {
      rendObj = ROBJ_DTEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = ::str(::loc("hints/leaving_the_tank_in_progress"), ::loc("ui/colon"))
      color = alert
    }
    @() {
      watch = timeToDeath
      rendObj = ROBJ_DTEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = secondsToTimeFormatString(timeToDeath.value).subst(timeLocTable)
      color = alert
    }
  ]
}
