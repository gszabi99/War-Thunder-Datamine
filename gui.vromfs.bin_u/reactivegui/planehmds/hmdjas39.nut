from "%rGui/globals/ui_library.nut" import *

let dasScript = load_das("%rGui/planeHmds/hmdJas39.das")
let { isInVr } = require("%rGui/style/screenState.nut")

function hmd(width, height, is_metric_units) {
  return {
    size = [width, height]
    rendObj = ROBJ_DAS_CANVAS
    script = dasScript
    drawFunc = "draw_hmd"
    setupFunc = "setup_hmd_data"
    font = Fonts.mirage_ils
    fontSize = 20
    color = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)
    isMetricUnits = is_metric_units
  }
}

return hmd