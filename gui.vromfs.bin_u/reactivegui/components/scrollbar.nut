from "%rGui/globals/ui_library.nut" import *

let scrollbarBase = require("%rGui/components/scrollbarBase.nut")
let colors = require("%rGui/style/colors.nut")

let scrollbarWidth = fpx(8)

let styling = {
  Knob = {
    rendObj = ROBJ_SOLID
    colorCalc = @(sf) (sf & S_ACTIVE) ? colors.menu.scrollbarSliderColorHover
                    : ((sf & S_HOVER) ? colors.menu.scrollbarSliderColorHover
                                      : colors.menu.scrollbarSliderColor)
  }

  Bar = function(has_scroll) {
    if (has_scroll) {
      return freeze({
        rendObj = ROBJ_SOLID
        color = colors.menu.scrollbarBgColor
        opacity = 1
        _width = scrollbarWidth
        _height = scrollbarWidth
        skipDirPadNav = true
      })
    }
    else {
      return freeze({
        opacity = 0
        _width = scrollbarWidth
        _height = scrollbarWidth
        skipDirPadNav = true
      })
    }
  }

  ContentRoot = freeze({
    size = flex()
    skipDirPadNav = true
  })
}


let scrollbar = function(scroll_handler) {
  return scrollbarBase.scrollbar(scroll_handler, { styling = styling })
}


let makeSideScroll = function(content, options = {}) {
  if (!("styling" in options))
    options.styling <- styling
  return scrollbarBase.makeSideScroll(content, options)
}


return {
  scrollbarWidth
  scrollbar
  makeSideScroll
  styling
}
