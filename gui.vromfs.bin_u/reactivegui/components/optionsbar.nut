


from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import mkText
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let soundWt = require_optional("sound_wt")

let font = fontsState.get("normal")
let dpPx = cssConst("dp")
let barH = px("6@sf/@pf")

let textOvr = freeze({ vplace = ALIGN_CENTER, margin = [0, 0, barH, 0] })
let barPadding = freeze([0, dpPx, 0, 0])

function barColor(isSet, isEnabled, isLit, isHover) {
  if (!isEnabled)
    return isSet ? cssColors.controlDisabledColor : 0xFF000000
  if (isSet)
    return isLit ? 0xFFFAFAFA : 0xFFA0A0A0
  return isHover ? 0xFFB0B0B0 : isLit ? 0xFF808080 : 0xFF606060
}

function bar(idx, p, state, onChange, onHover) {
  let { id, isEnabled = null, highlight = null } = p
  let sf = Watched(0)
  let watch = [state, sf, isEnabled, highlight]
  let key = $"{id}_bar{idx}"
  let tooltip = p.items[idx]?.text
  let hintState = withHint(sf, key, @() tooltip)
  
  function onElemState(s) {
    if ((s & S_HOVER) != 0 && (sf.get() & S_HOVER) == 0)
      onHover?(idx)
    hintState(s)
  }
  let onDetach = tooltipDetach(sf, key)
  function onClick() {
    if (!(isEnabled?.get() ?? true) || idx == state.get())
      return
    soundWt?.playSound("choose")
    onChange?(id, idx)
  }
  return function() {
    let color = barColor(idx <= state.get(), isEnabled?.get() ?? true, highlight?.get() ?? false,
      (sf.get() & S_HOVER) != 0)
    return {
      watch
      key
      size = flex()
      padding = barPadding
      behavior = Behaviors.Button
      skipDirPadNav = p?.skipDirPadNav
      onElemState
      onDetach
      onClick
      children = { size = [flex(), barH], vplace = ALIGN_BOTTOM, rendObj = ROBJ_SOLID, color }
    }
  }
}

function optionsBar(p, state, onChange = null, size = null, onHover = null) {
  let { items = [], isEnabled = null } = p
  let [w, h] = size ?? [cssConst("sliderWidth"), cssConst("optContainerHeight")]
  let bars = { size = flex(), flow = FLOW_HORIZONTAL,
    children = items.map(@(_, idx) bar(idx, p, state, onChange, onHover)) }
  let watch = [state, isEnabled]
  return function() {
    let textColor = (isEnabled?.get() ?? true) ? cssColors.commonTextColor : cssColors.disabledTextColor
    return {
      watch
      size = [w, h]
      children = [mkText(items?[state.get()]?.text ?? "", font, textColor, textOvr), bars]
    }
  }
}

return optionsBar
