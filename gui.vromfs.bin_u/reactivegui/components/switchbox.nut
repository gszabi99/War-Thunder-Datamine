


from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst
from "%rGui/components/text.nut" import mkText, mulAlpha
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let soundWt = require_optional("sound_wt")

let font = fontsState.get("normal")
let boxW = cssConst("switchBoxWidth")
let boxH = cssConst("switchBoxHeight")
let border = cssConst("switchBoxBorderSize")
let lineH = cssConst("switchButtonLineHeight")
let dpPx = cssConst("dp")
let gap = cssConst("blockInterval")
let knobSize = boxH - 2 * border

function knob(isChecked, isHover, alpha) {
  let line = {
    size = [flex(), lineH]
    rendObj = ROBJ_SOLID
    color = mulAlpha(isChecked ? cssColors.switchButtonLineOnColor : cssColors.switchButtonLineColor, alpha)
  }
  return {
    size = knobSize
    rendObj = ROBJ_SOLID
    color = mulAlpha(isChecked ? cssColors.switchButtonOnColor : cssColors.switchButtonColor, alpha)
    children = [
      line
      !isHover ? null : {
        size = knobSize + 2 * dpPx
        pos = [-dpPx, -dpPx]
        rendObj = ROBJ_FRAME
        borderWidth = dpPx
        color = isChecked ? cssColors.switchHoverBorderOnColor : cssColors.switchHoverBorderColor
      }
    ]
  }
}

function switchBox(p, state = null, onChange = null) {
  let id = p?.id
  let value = state ?? Watched(p?.value ?? false)
  let sf = Watched(0)
  let textChecked = p?.textChecked ?? loc("options/yes")
  let textUnchecked = p?.textUnchecked ?? loc("options/no")
  let { alpha = null, isEnabled = null } = p
  function toggle() {
    if (!(isEnabled?.get() ?? true))
      return
    let v = !value.get()
    if (state == null)
      value.set(v)
    soundWt?.playSound("check")
    onChange?(id, v)
  }
  let watch = [value, sf, alpha, isEnabled]
  return function() {
    let isChecked = value.get()
    let isHover = (sf.get() & S_HOVER) != 0
    
    let disabledFactor = (isEnabled?.get() ?? true) ? 255 : 127
    let a = alpha?.get() ?? disabledFactor
    return {
      watch
      key = id
      size = [SIZE_TO_CONTENT, boxH]
      flow = FLOW_HORIZONTAL
      behavior = Behaviors.Button
      skipDirPadNav = p?.skipDirPadNav
      onElemState = @(s) sf.set(s)
      onClick = toggle
      children = [
        {
          size = [boxW, boxH]
          padding = border
          flow = FLOW_HORIZONTAL
          rendObj = ROBJ_SOLID
          color = mulAlpha(cssColors.switchBoxBgColor, a)
          children = [
            !isChecked ? null : { size = flex(), rendObj = ROBJ_SOLID,
              color = mulAlpha(cssColors.switchBoxOnBgColor, disabledFactor) }
            knob(isChecked, isHover, a)
          ]
        }
        mkText(isChecked ? textChecked : textUnchecked, font,
          mulAlpha(isChecked ? cssColors.commonTextColor : cssColors.uncheckedTextColor, a),
          { vplace = ALIGN_CENTER, margin = [0, gap] })
      ]
    }
  }
}

return switchBox
