from "%rGui/style/screenState.nut" import isInVr
from "%rGui/utils/cacheDasScriptForView.nut" import getDasScriptByPath
from "%rGui/globals/ui_library.nut" import *

function hmd(width, height, is_metric_units) {
  return {
    size = [width, height]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath("%rGui/planeHmds/hmdCobraHmd.das")
    drawFunc = "draw_hmd"
    setupFunc = "setup_hmd_data"
    font = Fonts.mirage_ils
    fontSize = 20
    fontSizeAltitudeHigher = 20
    fontSizeAltitudeLower = 20
    color = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)
    isMetricUnits = is_metric_units
  }
}

return hmd
