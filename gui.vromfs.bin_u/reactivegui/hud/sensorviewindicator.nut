from "%rGui/globals/ui_library.nut" import *
let dasSensorIndicators = load_das("%rGui/hud/sensorViewIndicator.das")

let sensorViewIndicators = {
  size = flex()
  rendObj = ROBJ_DAS_CANVAS
  script = dasSensorIndicators
  drawFunc = "draw"
  setupFunc = "setup_data"
  allyColor = Color(0, 255, 0, 255)
  enemyColor = Color(255, 0, 0, 255)
  textColor = Color(255, 255, 255, 255)
  deadColor = Color(128, 128, 128, 255)
  fontSize = 14
}

return sensorViewIndicators