from "%rGui/globals/ui_library.nut" import *
let { hudFontHgt } = require("style/airHudStyle.nut")
let dasScript = load_das("%rGui/radar.das")

let function radarHud(width, height, x, y, color_watched) {
  return @(){
    watch = color_watched
    size = [width, height]
    pos = [x, y]
    rendObj = ROBJ_DAS_CANVAS
    script = dasScript
    drawFunc = "draw_radar_hud"
    setupFunc = "setup_radar_data"
    color = color_watched.value
    font = Fonts.hud
    fontSize = hudFontHgt
  }
}

return radarHud
