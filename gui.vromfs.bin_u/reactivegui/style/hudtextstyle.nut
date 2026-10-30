from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst


let dpPx = cssConst("dp")


let hudHeaderShade = freeze({
  fontFx = FFT_BLUR
  fontFxColor = 0xCC000000
  fontFxFactor = min(64, 24 * dpPx)
  fontFxOffsX = dpPx
  fontFxOffsY = dpPx
})

let hudTextShade = freeze({
  fontFx = FFT_BLUR
  fontFxColor = 0x55000000
  fontFxFactor = min(64, 24 * dpPx)
})


let mkWinkAnim = @[pure, nodiscard] (sec, minOpacity) [{ prop = AnimProp.opacity, from = minOpacity, to = 1,
  duration = sec, easing = CosineFull, loop = true, play = true }]

return freeze({
  hudHeaderShade
  hudTextShade
  mkWinkAnim
})
