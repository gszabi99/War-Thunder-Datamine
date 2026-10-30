


from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, roundPx
from "%rGui/components/text.nut" import mulAlpha
import "%appGlobals/style/cssColors.nut" as cssColors

let incH = cssConst("sliderIncHeight")

function slider(p, state = null, onChange = null, size = null) {
  let id = p?.id
  let minVal = p?.minVal ?? 0
  let maxVal = p?.maxVal ?? 100
  let step = p?.step ?? 5
  let { alpha = null, isEnabled = null } = p
  let value = state ?? Watched(p?.value ?? minVal)
  let sf = Watched(0)
  let [w, h] = size ?? [cssConst("sliderWidth"), cssConst("sliderHeight") + 2 * incH]
  function setValue(v) {
    let q = clamp(minVal + roundPx((v - minVal) / step.tofloat()) * step, min(minVal, maxVal), max(minVal, maxVal))
    if (q == value.get())
      return
    if (state == null)
      value.set(q)
    onChange?(id, q)
  }
  let watch = [value, sf, alpha, isEnabled]
  return function() {
    let range = maxVal - minVal
    let fill = range == 0 ? 0 : roundPx(w * (value.get() - minVal).tofloat() / range)
    let enabled = isEnabled?.get() ?? true
    let isActive = enabled && (sf.get() & (S_HOVER | S_KB_FOCUS)) != 0
    let a = alpha?.get() ?? 255
    let [bgColor, fgColor] = !enabled ? [cssColors.black, cssColors.controlDisabledColor]
      : isActive ? [cssColors.sliderActiveBgColor, cssColors.sliderActiveFgColor]
      : [cssColors.sliderBgColor, cssColors.sliderFgColor]
    return {
      watch
      key = id
      size = [w, h]
      behavior = enabled ? Behaviors.Slider : null
      skipDirPadNav = p?.skipDirPadNav
      min = minVal
      max = maxVal
      unit = step
      fValue = value.get()
      orientation = O_HORIZONTAL
      onChange = setValue
      onElemState = @(s) sf.set(s)
      children = {
        size = [w, h - 2 * incH]
        pos = [0, incH]
        rendObj = ROBJ_SOLID
        color = mulAlpha(bgColor, a)
        children = { size = [fill, flex()], rendObj = ROBJ_SOLID, color = mulAlpha(fgColor, a) }
      }
    }
  }
}

return slider
