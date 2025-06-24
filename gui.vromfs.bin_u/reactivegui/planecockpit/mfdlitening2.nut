from "%rGui/globals/ui_library.nut" import *

let litening2 = @(width, height, font_scale, line_width_scale) function() {
  let fontScale = font_scale
  let lineWidthScale = line_width_scale
  return {
      rendObj = ROBJ_DAS_CANVAS
      size = [width, height]
      fontId = Fonts.hud
      script = load_das("%rGui/planeCockpit/mfdLitening2.das")
      drawFunc = "render"
      setupFunc = "setup"
      fontScale
      lineWidthScale
  }
}

return litening2