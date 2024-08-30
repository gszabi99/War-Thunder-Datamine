from "%rGui/globals/ui_library.nut" import *

let dasScript = load_das("%rGui/planeHmds/hmdTopOwl.das")
let { isInVr } = require("%rGui/style/screenState.nut")

function hmd(width, height) {
  return {
    size = [width, height]
    rendObj = ROBJ_DAS_CANVAS
    script = dasScript
    drawFunc = "draw_hmd"
    setupFunc = "setup_hmd_data"
    font = Fonts.hud
    fontSize = 20
    color = isInVr ? Color(10, 255, 10, 30) : Color(10, 255, 10, 10)
  }
}

return hmd