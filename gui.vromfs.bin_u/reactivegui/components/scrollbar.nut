let scrollbarBase = require("scrollbarBase.nut")
let colors = require("%rGui/style/colors.nut")


let styling = {
  Knob = class {
    rendObj = ROBJ_SOLID
    colorCalc = @(sf) (sf & S_ACTIVE) ? colors.menu.scrollbarSliderColorHover
                    : ((sf & S_HOVER) ? colors.menu.scrollbarSliderColorHover
                                      : colors.menu.scrollbarSliderColor)
  }

  Bar = function(has_scroll) {
    if (has_scroll) {
      return class {
        rendObj = ROBJ_SOLID
        color = colors.menu.scrollbarBgColor
        opacity = 1
        _width = ::fpx(8)
        _height = ::fpx(8)
        skipDirPadNav=true
      }
    } else {
      return class {
        opacity = 0
        _width = ::fpx(8)
        _height = ::fpx(8)
        skipDirPadNav=true
      }
    }
  }

  ContentRoot = class {
    size = flex()
    skipDirPadNav=true
  }
}


let scrollbar = function(scroll_handler) {
  return scrollbarBase.scroll(scroll_handler, {styling=styling})
}


let makeSideScroll = function(content, options={}) {
  if (!("styling" in options))
    options.styling <- styling
  return scrollbarBase.makeSideScroll(content, options)
}


let export = class {
  scrollbar = scrollbar
  makeSideScroll = makeSideScroll
  styling = styling
}()


return export
