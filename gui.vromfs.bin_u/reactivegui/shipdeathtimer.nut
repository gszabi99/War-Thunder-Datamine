local state = require("shipState.nut")
local colors = require("style/colors.nut")
local {secondsToTimeFormatString} = require("std/time.nut")
local timeLocTable = require("timeLocTable.nut")

return @(){
  watch = state.timeToDeath
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  children = state.timeToDeath.value <= 0 ? null : [
    {
      rendObj = ROBJ_STEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = 64
      fontFx = FFT_GLOW
      text = ::loc("hints/leaving_the_tank_in_progress") + ::loc("ui/colon")
      color = colors.hud.damageModule.alert
    }
    @() {
      watch = state.timeToDeath
      rendObj = ROBJ_DTEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = 64
      fontFx = FFT_GLOW
      text = secondsToTimeFormatString(state.timeToDeath.value).subst(timeLocTable)
      color = colors.hud.damageModule.alert
    }
  ]
}
