from "%rGui/globals/ui_library.nut" import *

let colors = require("%rGui/style/colors.nut")
let { safeAreaSizeMenu } = require("%rGui/style/screenState.nut")
let closeBtn = require("%rGui/components/closeBtn.nut")

let frameHeaderPad = dp(2)
let frameHeaderHeight = scrn_tgt(0.045)
let borderWidth = dp(1)

let srw = Computed(@() min(scrn_tgt(1.4), safeAreaSizeMenu.get().size[0]))
let maxWindowHeight = Computed(@() safeAreaSizeMenu.get().size[1] - frameHeaderHeight
  - scrn_tgt(0.01) - fpx(59))

let frameHeader = @(headerParams) {
  size = [flex(), frameHeaderHeight]
  rendObj = ROBJ_SOLID
  color = colors.menu.frameHeaderColor
  margin = frameHeaderPad
  valign = ALIGN_CENTER
  children = [
    headerParams?.content
    closeBtn(headerParams?.closeBtn ?? {})
  ]
}.__update(headerParams)

let frameHandler = kwarg(function(content, frameParams = {}, headerParams = {}) {
  return @() {
    size = flex()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = [srw, maxWindowHeight]
    children = {
      size = [srw.get(), maxWindowHeight.get()]
      rendObj = ROBJ_BOX
      fillColor = colors.menu.frameBackgroundColor
      borderColor = colors.menu.frameBorderColor
      borderWidth = borderWidth
      flow = FLOW_VERTICAL
      children = [
        frameHeader(headerParams)
        content
      ]
    }.__update(frameParams)
  }
})


return frameHandler
