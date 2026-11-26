



from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, roundPx
from "%rGui/components/text.nut" import mulAlpha
from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%rGui/components/gamepadFocusFrame.nut" import mkFocusFrame
import "%appGlobals/style/cssColors.nut" as cssColors

let incH = cssConst("sliderIncHeight")
let dpPx = cssConst("dp")

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
  
  let laidOutW = Watched(0)
  let frame = mkFocusFrame()
  let focusFrame = @() {
    watch = laidOutW
    size = flex()
    behavior = Behaviors.RecalcHandler
    onRecalcLayout = @(_initial, elem) laidOutW.set(elem.getWidth())
    children = laidOutW.get() == 0 ? null
      : { pos = [-2 * dpPx, -dpPx], size = [laidOutW.get() + 4 * dpPx, h + 2 * dpPx], children = frame }
  }
  let watch = [value, sf, alpha, isEnabled, showConsoleButtons]
  let thumbSize = p?.hasThumb ? p?.thumbSize ?? [cssConst("sliderThumbWidth"), cssConst("sliderThumbHeight")] : null
  let [thumbPic, thumbActivePic] = thumbSize == null ? [null, null]
    : ["slider_thumb", "slider_thumb_hover"].map(@(n) Picture($"ui/gameuiskin#{n}.svg:{thumbSize[0]}:{thumbSize[1]}:P"))
  return function() {
    let range = maxVal - minVal
    let part = range == 0 ? 0 : (value.get() - minVal).tofloat() / range
    let fill = pw(100 * part)
    let enabled = isEnabled?.get() ?? true
    let isActive = enabled && (sf.get() & (S_HOVER | S_KB_FOCUS)) != 0
    let a = alpha?.get() ?? 255
    let [bgColor, fgColor] = !enabled ? [cssColors.black, cssColors.controlDisabledColor]
      : isActive ? [cssColors.sliderActiveBgColor, cssColors.sliderActiveFgColor]
      : [cssColors.sliderBgColor, cssColors.sliderFgColor]
    let isThumbActive = isActive || (enabled && (sf.get() & S_ACTIVE) != 0)
    return {
      watch
      key = id
      size = [w, h]
      behavior = enabled ? Behaviors.Slider : null
      skipDirPadNav = p?.skipDirPadNav
      ignoreWheel = p?.ignoreWheel
      min = minVal
      max = maxVal
      unit = step
      fValue = value.get()
      orientation = O_HORIZONTAL
      onChange = setValue
      onElemState = @(s) sf.set(s)
      children = [
        {
          size = [w, h - 2 * incH]
          pos = [0, incH]
          rendObj = ROBJ_SOLID
          color = mulAlpha(bgColor, a)
          children = { size = [fill, flex()], rendObj = ROBJ_SOLID, color = mulAlpha(fgColor, a) }
        }
        
        thumbSize == null ? null : {
          size = [fill, flex()]
          children = {
            size = thumbSize
            hplace = ALIGN_RIGHT
            vplace = ALIGN_CENTER
            pos = [thumbSize[0] / 2, 0]
            rendObj = ROBJ_IMAGE
            image = isThumbActive ? thumbActivePic : thumbPic
            color = mulAlpha(!enabled ? cssColors.fadedTextColor
              : isThumbActive ? cssColors.activeTextColor
              : cssColors.commonTextColor, a)
          }
        }
        showConsoleButtons.get() && (sf.get() & S_HOVER) != 0 ? focusFrame : null
      ]
    }
  }
}

return slider
