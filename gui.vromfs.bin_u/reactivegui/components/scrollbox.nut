




from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%sqstd/platform.nut" import is_windows
import "%appGlobals/style/cssColors.nut" as cssColors

let barW = cssConst("scrollBarVisibleSize")
let barPlaceW = cssConst("scrollBarSize")

let wheelStep = px("12*@scrn_tgt/100.0") / (is_windows ? 120.0 : 100.0)

function scrollBox(p, content) {
  let [w, h] = p.size
  let { contentHeight } = p
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
  let bar = function() {
    let contentH = contentHeight.get()
    let thumbH = contentH > 0 ? h * h / contentH : h
    return {
      watch = [offset, contentHeight]
      pos = [w - barW, 0]
      size = [barW, h]
      rendObj = ROBJ_SOLID
      color = cssColors.scrollbarBgColor
      children = {
        pos = [0, contentH > 0 ? shownOffset() * h / contentH : 0]
        size = [barW, thumbH]
        rendObj = ROBJ_SOLID
        color = cssColors.scrollbarSliderColor
      }
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
          clipChildren = true
          behavior = const [Behaviors.WheelScroll, Behaviors.JoystickScroll]
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
