local colors = require("reactiveGui/style/colors.nut")
local { safeAreaSizeMenu } = require("reactiveGui/style/screenState.nut")
local closeBtn = require("reactiveGui/components/closeBtn.nut")

local frameHeaderPad = ::dp(2)
local frameHeaderHeight = ::scrn_tgt(0.045)
local borderWidth = ::dp(1)

local srw = ::Computed(@() ::min(::scrn_tgt(1.4), safeAreaSizeMenu.value.size[0]))
local maxWindowHeight = ::Computed(function() {
  local srh = ::min(::scrn_tgt(1), safeAreaSizeMenu.value.size[1])
  local maxWindowHeightNoSrh = safeAreaSizeMenu.value.size[1] - ::scrn_tgt(0.045) - ::fpx(59) - ::scrn_tgt(0.01)
  return ::min(maxWindowHeightNoSrh, srh)
})

local frameHeader = @(headerParams) {
  size = [flex(), frameHeaderHeight]
  rendObj = ROBJ_SOLID
  color = colors.menu.frameHeaderColor
  margin = frameHeaderPad
  children = [
    closeBtn(headerParams?.closeBtn ?? {})
  ]
}.__update(headerParams)

local frameHandler = ::kwarg(function(content, frameParams = {}, headerParams = {}) {
  return @(){
    size = flex()
    rendObj = ROBJ_SOLID
    color = colors.menu.modalShadeColor
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    watch = [srw, maxWindowHeight]
    children = {
      size = [srw.value, maxWindowHeight.value]
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
