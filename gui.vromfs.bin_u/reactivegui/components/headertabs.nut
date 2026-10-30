



from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst
from "%rGui/components/text.nut" import mkText
from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%rGui/components/gamepadImgByKey.nut" import mkImageCompByDargKey
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let soundWt = require_optional("sound_wt")

let font = fontsState.get("normal")
let dpPx = cssConst("dp")
let padX = cssConst("listboxHPadding")
let height = cssConst("frameHeaderHeight")
let lineH = 2 * dpPx
let textOvr = freeze({ vplace = ALIGN_CENTER, margin = [0, padX] })
let mkHint = @(key) mkImageCompByDargKey(key, null, { height = cssConst("cIco"), vplace = ALIGN_CENTER })

function tab(t, idx, state, inactiveTabs, onSelect) {
  let sf = Watched(0)
  let text = t?.tabName ?? ""
  return function() {
    let isSelected = state.get() == idx
    let isHover = (sf.get() & S_HOVER) != 0
    let isInactive = (t?.visualDisable ?? false) || (inactiveTabs?.get()[t?.id] ?? false)
    return {
      watch = [state, sf, inactiveTabs]
      key = t?.id
      size = [SIZE_TO_CONTENT, height]
      behavior = Behaviors.Button
      onElemState = @(s) sf.set(s)
      function onClick() {
        if (isSelected)
          return
        soundWt?.playSound("click")
        onSelect?(idx)
      }
      children = [
        mkText(text, font,
          isSelected ? cssColors.activeTextColor
            : isHover ? cssColors.headerOptionSelectedTextColor
            : isInactive ? cssColors.shopFilterFontColorDisabled
            : cssColors.headerOptionTextColor,
          textOvr)
        !isSelected && !isHover ? null : {
          size = [flex(), lineH]
          vplace = ALIGN_BOTTOM
          rendObj = ROBJ_SOLID
          color = isSelected ? cssColors.headerOptionSelectedColor : cssColors.headerOptionHoverColor
        }
      ]
    }
  }
}

function headerTabs(p, state, onSelect = null, inactiveTabs = null) {
  let tabs = p?.tabs ?? []
  let tabComps = tabs.map(@(t, idx) tab(t, idx, state, inactiveTabs, onSelect))
  function selectNear(dir) {
    let idx = clamp(state.get() + dir, 0, tabs.len() - 1)
    if (idx != state.get())
      onSelect?(idx)
  }
  let hotkeys = [["^J:LB", @() selectNear(-1)], ["^J:RB", @() selectNear(1)]]
  let withHints = [mkHint("J:LB")].extend(tabComps).append(mkHint("J:RB"))
  return @() {
    watch = showConsoleButtons
    size = [SIZE_TO_CONTENT, height]
    flow = FLOW_HORIZONTAL
    hotkeys
    children = showConsoleButtons.get() ? withHints : tabComps
  }
}

return headerTabs
