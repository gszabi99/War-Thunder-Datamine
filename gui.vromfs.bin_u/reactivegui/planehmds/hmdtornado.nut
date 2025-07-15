from "%rGui/globals/ui_library.nut" import *
let { isInVr } = require("%rGui/style/screenState.nut")
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

function hmd(width, height) {
  return {
    size = [width, height]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath("%rGui/planeHmds/hmdTornado.das")
    drawFunc = "draw_hmd"
    setupFunc = "setup_hmd_data"
    color = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)
  }
}

return hmd