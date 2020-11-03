local {obstacleIsNear, distanceToObstacle} = require("shipState.nut")
local {alert} = require("style/colors.nut").hud.damageModule
local {abs} = require("std/math.nut")

local showCollideWarning = Computed(@() distanceToObstacle.value < 0)

local textToShow = Computed(@() ::str(showCollideWarning.value ? ::loc("hud_ship_collide_warning") :
       ::loc("hud_ship_depth_on_course_warning"), ::loc("ui/colon"))
)
return @(){
  watch = obstacleIsNear
  isHidden = !obstacleIsNear.value
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  children = [
    @() {
      rendObj = ROBJ_DTEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      watch = textToShow
      text = textToShow.value
      color = alert
    }
    @() {
      watch = distanceToObstacle
      rendObj = ROBJ_DTEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = abs(distanceToObstacle.value)
      color = alert
    }
    {
      rendObj = ROBJ_DTEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = ::cross_call.measureTypes.DEPTH.getMeasureUnitsName()
      color = alert
    }
  ]
}
