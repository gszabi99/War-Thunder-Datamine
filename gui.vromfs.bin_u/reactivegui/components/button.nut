





from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst
from "%rGui/components/text.nut" import mkText, mulAlpha
from "%rGui/components/commonBg.nut" import commonBg
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
  Secondary = [cssColors.buttonColorSecondary, 0, cssColors.buttonFontColorSecondary],
  SecondaryHover = [cssColors.buttonColorSecondary, 0, cssColors.activeTextColor],
  SecondaryDisabled = [cssColors.buttonColorSecondary, 0, cssColors.buttonFontColorSecondary],
  SecondaryPushed = [cssColors.buttonColorSecondary, 0, cssColors.buttonFontColorSecondary],
})

let secondaryBgByState = freeze({
  [""] = { image = "#ui/gameuiskin#button_flat_", position = "2, 3, 2, 2" }
  Hover = { image = "#ui/gameuiskin#button_flat_hover", position = "2, 3, 2, 2" }
  Disabled = { image = "#ui/gameuiskin#button_flat_disabled", position = "1, 3, 1, 1" }
  Pushed = { image = "#ui/gameuiskin#button_flat_active", position = "2, 3" }
})

let winkAnimations = freeze([{ prop = AnimProp.opacity, from = 1.0, to = 170 / 255.0, duration = 3.0,
  easing = CosineFull, loop = true, play = true }])

let contentSize = freeze([SIZE_TO_CONTENT, flex()])

function button(p, onClickCb = null) {
  let sf = Watched(0)
  let { id = null, visualStyle = null, content = null, alpha = null, isEnabled = null, text = "", hotkey = null,
    tooltip = null } = p
  let textW = type(text) == "string" ? null : text
  let hint = hotkey == null ? null : mkImageCompByDargKey(hotkey, null, { height = hintSize, vplace = ALIGN_CENTER })
  let btnHotkeys = hotkey == null ? null : [[$"^{hotkey}"]]
  let onElemState = tooltip == null ? @(s) sf.set(s) : withHint(sf, id, tooltip)
  let hideTooltip = tooltip == null ? null : tooltipDetach(sf, id)
  
  function onDetach() {
    hideTooltip?()
    sf.set(0)
  }
  let watch = [sf, isEnabled, alpha, textW, hint == null ? null : showConsoleButtons]
  return function() {
    let a = alpha?.get() ?? 255
    let enabled = isEnabled?.get() ?? true
    let state = stateName(sf.get(), enabled, visualStyle)
    let isSecondary = visualStyle == "secondary"
    let colors = colorsByState[isSecondary ? $"Secondary{state}" : state]
    let textColor = mulAlpha(colors[2], a)
    let label = content != null ? content(sf.get(), enabled, textColor)
      : mkText(textW?.get() ?? text, font, textColor, const { vplace = ALIGN_CENTER })
    let isHintShown = hint != null && showConsoleButtons.get()
    let secondaryBg = isSecondary ? secondaryBgByState[state] : null
    let bg = !isSecondary
      ? [{ size = flex(), rendObj = ROBJ_FRAME, borderWidth, color = mulAlpha(colors[1], a) }]
      : commonBg({ image = secondaryBg?.image, repeat = "expand", position = secondaryBg?.position,
          bgcolor = mulAlpha(colors[0], a) })
    let wink = !isSecondary || state != "" ? null : commonBg({
      image = "#ui/gameuiskin#button_flat_glow", repeat = "expand", position = "2, 3, 2, 2",
      bgcolor = mulAlpha(cssColors.buttonWinkColorSecondary, a)
    })[0].__update({ animations = winkAnimations })
    return {
      watch
      key = id
      size = isHintShown ? [SIZE_TO_CONTENT, p?.size[1] ?? btnHeight] : (p?.size ?? [SIZE_TO_CONTENT, btnHeight])
      minWidth = p?.minWidth ?? btnWidth
      margin = p?.margin ?? btnMargin
      rendObj = ROBJ_SOLID
      color = isSecondary ? 0 : mulAlpha(colors[0], a)
      behavior = Behaviors.Button
      skipDirPadNav = p?.skipDirPadNav
      hotkeys = btnHotkeys
      onElemState
      onDetach
      function onClick() {
        if (!(isEnabled?.get() ?? true))
          return
        soundWt?.playSound("click")
        onClickCb?()
      }
      children = bg.append(wink, {
        size = contentSize
        hplace = isHintShown ? ALIGN_LEFT : ALIGN_CENTER
        padding
        flow = FLOW_HORIZONTAL
        gap = hintGap
        children = [isHintShown ? hint : null, label]
      })
    }
  }
}

return button
