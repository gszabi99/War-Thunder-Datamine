from "%rGui/globals/ui_library.nut" import *
let tankSightDas = load_das("%rGui/tankSight.das")

let mkTankSight = @(isPreviewMode = false) {
    size = flex()
    rendObj = ROBJ_DAS_CANVAS
    script = tankSightDas
    drawFunc = "draw_sight_hud"
    setupFunc = "setup_data"
    lineWidth = 2.0
    isPreviewMode
  }

return mkTankSight