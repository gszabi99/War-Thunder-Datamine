




from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst
from "%rGui/components/text.nut" import mkText, mulAlpha
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach
from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%rGui/components/gamepadImgByKey.nut" import mkImageCompByDargKey
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let soundWt = require_optional("sound_wt")

let font = fontsState.get("normal")
let btnHeight = cssConst("buttonHeight")
let btnWidth = cssConst("buttonWidth")
let btnMargin = cssConst("buttonMargin")
let padding = [cssConst("buttonImgPadding"), cssConst("buttonTextPadding")]
let borderWidth = cssConst("dp")
let hintSize = cssConst("cIco")
let hintGap = cssConst("buttonImgPadding")


function stateName(sf, isEnabled, visualStyle) {
  if (visualStyle == "noBgr")
    return "NoBgr"
  if (isEnabled && (sf & S_ACTIVE) != 0)
    return "Pushed"
  if (sf & S_HOVER)
    return "Hover"
  return isEnabled ? "" : "Disabled"
}

let colorsByState = freeze({
  [""] = [cssColors.buttonColor, cssColors.buttonBorderColor, cssColors.buttonFontColor],
  Hover = [cssColors.buttonColorHover, cssColors.buttonBorderColorHover, cssColors.buttonFontColorHover],
  Disabled = [cssColors.buttonColorDisabled, cssColors.buttonBorderColorDisabled, cssColors.buttonFontColorDisabled],
  Pushed = [cssColors.buttonColorPushed, cssColors.buttonBorderColorPushed, cssColors.buttonFontColorPushed],
  NoBgr = [0, 0, cssColors.buttonFontColor],
})

let contentSize = freeze([SIZE_TO_CONTENT, flex()])

function button(p, onClick = null) {
  let sf = Watched(0)
  let { id = null, visualStyle = null, content = null, alpha = null, isEnabled = null, text = "", hotkey = null,
    tooltip = null } = p
  let textW = type(text) == "string" ? null : text
  let hint = hotkey == null ? null : mkImageCompByDargKey(hotkey, null, { height = hintSize, vplace = ALIGN_CENTER })
  let btnHotkeys = hotkey == null ? null : [[$"^{hotkey}"]]
  let onElemState = tooltip == null ? @(s) sf.set(s) : withHint(sf, id, tooltip)
  let onDetach = tooltip == null ? null : tooltipDetach(sf, id)
  let watch = [sf, isEnabled, alpha, textW, hint == null ? null : showConsoleButtons]
  return function() {
    let a = alpha?.get() ?? 255
    let enabled = isEnabled?.get() ?? true
    let colors = colorsByState[stateName(sf.get(), enabled, visualStyle)]
    let textColor = mulAlpha(colors[2], a)
    let label = content != null ? content(sf.get(), enabled, textColor)
      : mkText(textW?.get() ?? text, font, textColor, const { vplace = ALIGN_CENTER })
    let isHintShown = hint != null && showConsoleButtons.get()
    return {
      watch
      key = id
      size = isHintShown ? [SIZE_TO_CONTENT, p?.size[1] ?? btnHeight] : (p?.size ?? [SIZE_TO_CONTENT, btnHeight])
      minWidth = p?.minWidth ?? btnWidth
      margin = p?.margin ?? btnMargin
      rendObj = ROBJ_SOLID
      color = mulAlpha(colors[0], a)
      behavior = Behaviors.Button
      skipDirPadNav = p?.skipDirPadNav
      hotkeys = btnHotkeys
      onElemState
      onDetach
      function onClick() {
        if (!(isEnabled?.get() ?? true))
          return
        soundWt?.playSound("click")
        onClick?()
      }
      children = [
        { size = flex(), rendObj = ROBJ_FRAME, borderWidth, color = mulAlpha(colors[1], a) }
        {
          size = contentSize
          hplace = ALIGN_CENTER
          padding
          flow = FLOW_HORIZONTAL
          gap = hintGap
          children = [isHintShown ? hint : null, label]
        }
      ]
    }
  }
}

return button
