from "%rGui/globals/ui_library.nut" import *
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

let function sonarIndication() {
  return @(){
    size = flex()
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath("%rGui/sonarIndication.das")
    drawFunc = "draw_sonar_indication"
    setupFunc = "setup_data"
    fovColor = Color(180, 180, 180, 255)
    targetColor = Color(255, 0, 0, 255)
    font = Fonts.hud
  }
}

return {
  sonarIndication
}
