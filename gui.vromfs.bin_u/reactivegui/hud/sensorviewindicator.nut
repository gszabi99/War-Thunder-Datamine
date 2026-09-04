from "%rGui/utils/cacheDasScriptForView.nut" import getDasScriptByPath
from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/gameRendObjs.nut" import *

let sensorViewIndicatorsDas = {
  size = FLEX
  rendObj = ROBJ_DAS_CANVAS
  script = getDasScriptByPath("%rGui/hud/sensorViewIndicator.das")
  drawFunc = "draw"
  setupFunc = "setup_data"
  textColor = Color(255, 255, 255, 255)
  backColor = Color(0, 0, 0, 255)
  fontSize = 14
}







return sensorViewIndicatorsDas