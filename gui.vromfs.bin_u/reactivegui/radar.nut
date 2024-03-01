from "%rGui/globals/ui_library.nut" import *
let { hudFontHgt } = require("style/airHudStyle.nut")
let { MfdRadarHideBkg, MfdRadarFontScale, MfdViewMode } = require("radarState.nut")
let dasRadarHud = load_das("%rGui/radar.das")
let dasRadarIndication = load_das("%rGui/radarIndication.das")

function radarHud(width, height, x, y, color_watched, has_txt_block = false) {
  return @(){
    watch = color_watched
    size = [width, height]
    pos = [x, y]
    rendObj = ROBJ_DAS_CANVAS
    script = dasRadarHud
    drawFunc = "draw_radar_hud"
    setupFunc = "setup_radar_data"
    color = color_watched.value
    font = Fonts.hud
    hasTxtBlock = has_txt_block
  }
}

let function radarMfd(pos_and_size, color_watched) {
  return @(){
    watch = [color_watched, MfdRadarHideBkg, MfdRadarFontScale, MfdViewMode, pos_and_size]
    size = [pos_and_size.value.w, pos_and_size.value.h]
    pos = [pos_and_size.value.x, pos_and_size.value.y]
    rendObj = ROBJ_DAS_CANVAS
    script = dasRadarHud
    drawFunc = "draw_radar_hud"
    setupFunc = "setup_radar_data"
    color = color_watched.value
    font = Fonts.hud
    fontSize = (MfdRadarFontScale.value > 0 ? MfdRadarFontScale.value : pos_and_size.value.h / 512.0) * 30
    hideBackground = MfdRadarHideBkg.value
    enableByMfd = true
    mode = MfdViewMode.value
  }
}

let function radarIndication(color_watched) {
  return @(){
    watch = color_watched
    size = flex()
    rendObj = ROBJ_DAS_CANVAS
    script = dasRadarIndication
    drawFunc = "draw_radar_indication"
    setupFunc = "setup_data"
    color = color_watched.value
    font = Fonts.hud
    fontSize = hudFontHgt
  }
}

return {
  radarHud
  radarIndication
  radarMfd
}
