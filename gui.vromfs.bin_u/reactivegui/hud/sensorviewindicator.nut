from "%rGui/globals/ui_library.nut" import *
let dasSensorIndicators = load_das("%rGui/hud/sensorViewIndicator.das")

let sensorViewIndicatorsDas = {
  size = flex()
  rendObj = ROBJ_DAS_CANVAS
  script = dasSensorIndicators
  drawFunc = "draw"
  setupFunc = "setup_data"
  textColor = Color(255, 255, 255, 255)
  backColor = Color(0, 0, 0, 255)
  fontSize = 14
}







return sensorViewIndicatorsDas