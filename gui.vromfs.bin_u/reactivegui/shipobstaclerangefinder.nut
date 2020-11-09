local state = require("shipState.nut")
local colors = require("style/colors.nut")
local {abs} = require("std/math.nut")

return @(){
  watch = state.obstacleIsNear
  isHidden = !state.obstacleIsNear.value
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  children = [
    {
      rendObj = ROBJ_STEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = 64
      fontFx = FFT_GLOW
      text = (state.distanceToObstacle.value < 0 ? ::loc("hud_ship_collide_warning") :
       ::loc("hud_ship_depth_on_course_warning")) + ::loc("ui/colon")
      color = colors.hud.damageModule.alert
    }
    @() {
      watch = state.distanceToObstacle
      rendObj = ROBJ_DTEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = 64
      fontFx = FFT_GLOW
      text = abs(state.distanceToObstacle.value)
      color = colors.hud.damageModule.alert
    }
    {
      rendObj = ROBJ_STEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = 64
      fontFx = FFT_GLOW
      text = ::cross_call.measureTypes.DEPTH.getMeasureUnitsName()
      color = colors.hud.damageModule.alert
    }
  ]
}
