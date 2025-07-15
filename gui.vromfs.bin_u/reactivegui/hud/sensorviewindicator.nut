from "%rGui/globals/ui_library.nut" import *
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

let sensorViewIndicatorsDas = {
  size = flex()
  rendObj = ROBJ_DAS_CANVAS
  script = getDasScriptByPath("%rGui/hud/sensorViewIndicator.das")
  drawFunc = "draw"
  setupFunc = "setup_data"
  textColor = Color(255, 255, 255, 255)
  backColor = Color(0, 0, 0, 255)
  fontSize = 14
}







return sensorViewIndicatorsDas