

from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import mkText
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let soundWt = require_optional("sound_wt")

let font = fontsState.get("normal")
let padX = cssConst("listboxHPadding")
let height = cssConst("buttonHeight")
let lineH = px("2@listboxItemsInterval")
let textOvr = freeze({ vplace = ALIGN_CENTER, margin = [0, padX] })

let selectedBox = freeze({
  size = flex()
  rendObj = ROBJ_BOX
  fillColor = cssColors.buttonColor
  borderColor = cssColors.headerOptionSelectedColor
  borderWidth = [0, 0, lineH, 0]
})

let mkItemText = @(text, color) mkText(text, font, color, textOvr)

function item(it, idx, state, onSelect) {
  let sf = Watched(0)
  let key = it?.id
  let text = it?.text ?? ""
  let tooltip = it?.tooltip
  let onElemState = withHint(sf, key, @() tooltip)
  let onDetach = tooltipDetach(sf, key)
  return function() {
    let isSelected = state.get() == idx
    let isHover = (sf.get() & S_HOVER) != 0
    return {
      watch = [state, sf]
      key
      size = [SIZE_TO_CONTENT, height]
      rendObj = ROBJ_SOLID
      color = isSelected || isHover ? 0 : cssColors.listboxBgColor
      behavior = Behaviors.Button
      onElemState
      onDetach
      function onClick() {
        if (isSelected)
          return
        soundWt?.playSound("click")
        onSelect?(idx)
      }
      children = [
        isSelected ? selectedBox : null
        mkItemText(text, isSelected || isHover ? cssColors.activeTextColor : cssColors.commonTextColor)
      ]
    }
  }
}

let filterTabs = @(p, state, onSelect = null) {
  size = [p?.width ?? SIZE_TO_CONTENT, height]
  children = {
    hplace = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    children = (p?.items ?? []).map(@(it, idx) item(it, idx, state, onSelect))
  }
}

return filterTabs
