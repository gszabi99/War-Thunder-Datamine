from "%rGui/globals/ui_library.nut" import *

let colors = require("%rGui/style/colors.nut")
let scrollbar = require("scrollbar.nut")
let { cursorVisible } = require("%rGui/ctrlsState.nut")

let logContainer = @() {
  size = [flex(), SIZE_TO_CONTENT]
  gap = hdpx(2)
  padding = [scrn_tgt(0.005),  scrn_tgt(0.005)]
  flow = FLOW_VERTICAL
}

let hudLog = function (params) {
  let messageComponent = params.messageComponent
  let logComponent = params.logComponent
  let content = logComponent.data(@() logContainer, messageComponent)

  return @() {
    watch = cursorVisible
    rendObj = ROBJ_SOLID
    size = [flex(), hdpx(158)]
    clipChildren = true
    valign = ALIGN_BOTTOM
    color = colors.hud.hudLogBgColor
    children = scrollbar.makeSideScroll(content, {
      scrollHandler = logComponent.scrollHandler
      barStyle = @(has_scroll) scrollbar.styling.Bar(has_scroll && cursorVisible.value)
      scrollAlign = ALIGN_LEFT
    })
    onAttach = @(_) logComponent.scrollHandler.scrollToY(1e10)
  }
}

return hudLog
