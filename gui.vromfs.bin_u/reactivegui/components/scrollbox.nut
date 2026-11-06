





from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%sqstd/platform.nut" import is_windows
import "%appGlobals/style/cssColors.nut" as cssColors

let barW = cssConst("scrollBarVisibleSize")
let barPlaceW = cssConst("scrollBarSize")

let wheelStep = px("12*@scrn_tgt/100.0") / (is_windows ? 120.0 : 100.0)

function scrollBox(p, content) {
  let [w, h] = p.size
  let { contentHeight, isBarLeft = false } = p
  let offset = p?.scrollOffsY ?? Watched(0)
  let maxOffset = @() max(0, contentHeight.get() - h)
  let shownOffset = @() clamp(offset.get(), 0, maxOffset())
  let scrollBy = @(delta) offset.set(clamp(shownOffset() + delta, 0, maxOffset()))
  let onWheelScroll = @(delta) scrollBy(-delta)
  
  local isHovered = false
  let onElemState = @(sf) isHovered = (sf & S_HOVER) != 0
  let onJoystickScroll = @(evt) isHovered ? scrollBy(evt.delta.y) : null
  
  let onOffset = @(_) gui_scene.requestHoverUpdate()
  let onAttach = @() offset.subscribe(onOffset)
  let onDetach = @() offset.unsubscribe(onOffset)
  
  let viewKey = {}
  let barSf = Watched(0)
  let knob = {
    key = "knob"
    size = [flex(1), flex(h)]
    rendObj = ROBJ_SOLID
  }
  let bar = function() {
    let knobColor = (barSf.get() & S_ACTIVE) != 0 ? cssColors.activeTextColor
      : (barSf.get() & S_HOVER) != 0 ? cssColors.scrollbarSliderColorHover
      : cssColors.scrollbarSliderColor
    let coloredKnob = knob.__merge({ color = knobColor })
    return {
      watch = [offset, contentHeight, barSf]
      pos = [isBarLeft ? 0 : w - barW, 0]
      size = [barW, h]
      behavior = Behaviors.Slider
      skipDirPadNav = true
      orientation = O_VERTICAL
      min = 0
      max = maxOffset()
      unit = 1
      fValue = shownOffset()
      onChange = @(val) offset.set(clamp(val, 0, maxOffset()))
      onElemState = @(sf) barSf.set(sf)
      rendObj = ROBJ_SOLID
      color = cssColors.scrollbarBgColor
      flow = FLOW_VERTICAL
      knob = coloredKnob
      children = [
        { size = [flex(1), flex(shownOffset())] }
        coloredKnob
        { size = [flex(1), flex(maxOffset() - shownOffset())] }
      ]
    }
  }
  let inners = {}
  return function() {
    let hasBar = contentHeight.get() > h
    let innerW = hasBar ? w - barPlaceW : w
    if (innerW not in inners)
      inners[innerW] <- content(innerW, offset, h)
    let inner = inners[innerW]
    return {
      watch = contentHeight
      size = [w, h]
      children = [
        {
          key = viewKey
          size = [innerW, h]
          pos = [isBarLeft && hasBar ? barPlaceW : 0, 0]
          clipChildren = true
          behavior = const [Behaviors.WheelScroll, Behaviors.JoystickScroll]
          skipDirPadNav = true
          wheelStep
          onWheelScroll
          onElemState
          onJoystickScroll
          onAttach
          onDetach
          
          children = @() {
            watch = offset
            size = [innerW, h]
            pos = [0, -shownOffset()]
            children = inner
          }
        }
        hasBar ? bar : null
      ]
    }
  }
}

return scrollBox
