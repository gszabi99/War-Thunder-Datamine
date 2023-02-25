from "%rGui/globals/ui_library.nut" import *

let { obstacleIsNear, distanceToObstacle } = require("shipState.nut")
let { alert } = require("style/colors.nut").hud.damageModule
let { abs } = require("%sqstd/math.nut")
let { measureUnitsNames } = require("options/optionsMeasureUnits.nut")

let showCollideWarning = Computed(@() distanceToObstacle.value < 0)

let textToShow = Computed(@() str(showCollideWarning.value ? loc("hud_ship_collide_warning") :
       loc("hud_ship_depth_on_course_warning"), loc("ui/colon"))
)
return @() {
  watch = obstacleIsNear
  isHidden = !obstacleIsNear.value
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  children = [
    @() {
      rendObj = ROBJ_TEXT
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
      rendObj = ROBJ_TEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = abs(distanceToObstacle.value)
      color = alert
    }
    @() {
      watch = measureUnitsNames
      rendObj = ROBJ_TEXT
      font = Fonts.medium_text_hud
      fontFxColor = Color(0, 0, 0, 50)
      fontFxFactor = min(64, hdpx(64))
      fontFx = FFT_GLOW
      text = loc(measureUnitsNames.value?.meters_alt ?? "")
      color = alert
    }
  ]
}
