from "%rGui/globals/ui_library.nut" import *
let { isInVr } = require("%rGui/style/screenState.nut")
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

function hmd(width, height, is_metric_units) {
  return {
    size = [width, height]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath("%rGui/planeHmds/hmdJas39.das")
    drawFunc = "draw_hmd"
    setupFunc = "setup_hmd_data"
    font = Fonts.mirage_ils
    fontSize = 20
    fontSizeAltitudeHigher = 30
    fontSizeAltitudeLower = 20
    color = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)
    isMetricUnits = is_metric_units
  }
}

return hmd