


from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst
import "%rGui/components/button.nut" as button
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let fontNormal = fontsState.get("normal")
let dpPx = cssConst("dp")
let btnH = cssConst("buttonHeight")
let iconSize = cssConst("cIco")
let imageButtonSize = freeze([btnH, btnH])

function mkNavButtons(itemW, onButton, hiddenIds = []) {
  function navButton(id, p) {
    let item = itemW(id)
    let shownW = Computed(@() item.get()?.shown ?? !hiddenIds.contains(id))
    let btn = button({ id, margin = 0, isEnabled = Computed(@() item.get()?.enabled ?? true),
      tooltip = @() item.get()?.tooltip }.__update(p), @() onButton(id))
    return @() { watch = shownW, children = shownW.get() ? btn : null }
  }

  function textButton(id, text, hotkey = null, ovr = {}) {
    let item = itemW(id)
    return navButton(id, { text = Computed(@() item.get()?.value ?? text), hotkey }.__update(ovr))
  }

  function imageButton(id, image, hotkey = null, tooltip = null) {
    let pic = Picture($"ui/gameuiskin#{image}:{iconSize}:{iconSize}:K")
    let content = @(_sf, _isEnabled, textColor) { size = iconSize, vplace = ALIGN_CENTER, rendObj = ROBJ_IMAGE,
      image = pic, color = textColor }
    return navButton(id, { size = imageButtonSize, minWidth = btnH, content, hotkey, tooltip = @() tooltip })
  }

  function linkButton(id, text, ovr = {}) {
    let content = @(sf, _isEnabled, _textColor) function() {
      let color = (sf & S_HOVER) != 0 ? cssColors.linkTextHoverColor : cssColors.linkTextColor
      return {
        size = [SIZE_TO_CONTENT, flex()]
        valign = ALIGN_CENTER
        children = {
          flow = FLOW_VERTICAL
          children = [
            { rendObj = ROBJ_TEXT, font = fontNormal, color, text }
            { size = [flex(), dpPx], rendObj = ROBJ_SOLID, color }
          ]
        }
      }
    }
    return navButton(id, { content }.__update(ovr))
  }

  return { textButton, imageButton, linkButton }
}

return mkNavButtons
