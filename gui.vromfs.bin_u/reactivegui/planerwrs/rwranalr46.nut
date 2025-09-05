from "%rGui/globals/ui_library.nut" import *

let rwrTargetsComponent = require("%rGui/planeRwrs/rwrAnAlr46Components.nut")

let color = Color(10, 202, 10, 250)
let backgroundColor = Color(0, 0, 0, 255)
let baseLineWidth = LINE_WIDTH * 0.5
let iconRadiusBaseRel = 0.15
let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 3.0
}

function calcRwrTargetRadius(target) {
  return 0.2 + target.rangeRel * 0.8
}

function scope(scale, style) {
  let styleArgs = {
    calcRwrTargetRadius,
    iconRadiusBaseRel,
    color,
    backgroundColor,
    baseLineWidth,
    styleText
  }
  return {
    size = [pw(scale * style.grid.scale), ph(scale * style.grid.scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      rwrTargetsComponent(style.object, styleArgs)
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, style) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, style)
  }
}

return tws