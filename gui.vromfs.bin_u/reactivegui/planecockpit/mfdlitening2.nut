from "%rGui/globals/ui_library.nut" import *
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

let borderless = Watched(false)

function mfdCamLitening2SettingsUpd(blk) {
  borderless.set(blk.getBool("mfdCamLitening2borderless", false))
}

let litening2 = @(width, height, font_scale, line_width_scale) function() {
  let fontScale = font_scale
  let lineWidthScale = line_width_scale
  return {
      rendObj = ROBJ_DAS_CANVAS
      size = [width, height]
      fontId = Fonts.hud
      watch = borderless
      script = getDasScriptByPath("%rGui/planeCockpit/mfdLitening2.das")
      drawFunc = "render"
      setupFunc = "setup"
      fontScale
      lineWidthScale
      borderless = borderless.get()
  }
}

return { litening2, mfdCamLitening2SettingsUpd }