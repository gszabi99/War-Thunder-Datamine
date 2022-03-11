let colors = require("reactiveGui/style/colors.nut")
let scrollbar = require("scrollbar.nut")
let { cursorVisible } = require("reactiveGui/ctrlsState.nut")

let logContainer = @() {
  size = [flex(), SIZE_TO_CONTENT]
  gap = ::fpx(3)
  padding = [::scrn_tgt(0.005) , ::scrn_tgt(0.005)]
  flow = FLOW_VERTICAL
}

let hudLog = function (params) {
  let messageComponent = params.messageComponent
  let logComponent = params.logComponent
  let content = scrollbar.makeSideScroll(
    logComponent.data(@() logContainer, messageComponent),
    {
      scrollHandler = logComponent.scrollHandler
      barStyle = @(has_scroll) scrollbar.styling.Bar(has_scroll && cursorVisible.value)
      scrollAlign = ALIGN_LEFT
    }
  )

  return @() {
    watch = cursorVisible
    rendObj = ROBJ_SOLID
    size = [flex(), ::scrn_tgt(0.135)]
    clipChildren = true
    valign = ALIGN_BOTTOM
    color = colors.hud.hudLogBgColor
    children = content
    onAttach = @(_) logComponent.scrollHandler.scrollToY(1e10)
  }
}

return hudLog
