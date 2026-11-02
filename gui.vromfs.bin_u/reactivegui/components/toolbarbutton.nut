


import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors
from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst
from "%rGui/components/text.nut" import mkText
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach

let soundWt = require_optional("sound_wt")

let font = fontsState.get("normal")
let btnSize = cssConst("spectatorToolbarBtnSize")
let iconSize = cssConst("sIco")
let btnMargin = [0, (0.25 * btnSize).tointeger()]

const disabledColor = 0x30303030

function contentColor(sf, isEnabled, isHighlighted) {
  if (!isEnabled)
    return disabledColor
  if (isHighlighted)
    return cssColors.userlogColoredText
  return (sf & S_HOVER) ? cssColors.buttonFontColorHover : cssColors.gray
}

function toolbarButton(p, onClick) {
  let sf = Watched(0)
  let { id, icon = null, iconRotate = 0, text = null, isEnabled = null, isHighlighted = null, tooltip = null,
    altIcon = null, isAltIcon = null } = p
  let mkImage = @(name) name == null ? null : Picture($"ui/gameuiskin#{name}.svg:{iconSize}:{iconSize}:K")
  let image = mkImage(icon)
  let altImage = mkImage(altIcon)
  let iconTransform = iconRotate == 0 ? null : { rotate = iconRotate }
  let onElemState = tooltip == null ? @(s) sf.set(s) : withHint(sf, id, tooltip)
  let onDetach = tooltip == null ? null : tooltipDetach(sf, id)
  return function() {
    let enabled = isEnabled?.get() ?? true
    let color = contentColor(sf.get(), enabled, isHighlighted?.get() ?? false)
    return {
      watch = [sf, isEnabled, isHighlighted, isAltIcon]
      key = id
      size = [SIZE_TO_CONTENT, btnSize]
      minWidth = btnSize
      margin = btnMargin
      rendObj = ROBJ_SOLID
      color = (enabled && (sf.get() & S_HOVER) != 0) ? cssColors.switchButtonOnColor : 0
      behavior = Behaviors.Button
      onElemState
      onDetach
      function onClick() {
        if (!enabled)
          return
        soundWt?.playSound("click")
        onClick()
      }
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      children = image != null
        ? { size = iconSize, rendObj = ROBJ_IMAGE, image = (isAltIcon?.get() ?? false) ? altImage : image, color,
            transform = iconTransform }
        : mkText(text, font, color)
    }
  }
}

return toolbarButton
