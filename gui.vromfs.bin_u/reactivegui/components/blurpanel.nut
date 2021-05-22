local { isInVr } = require("reactiveGui/style/screenState.nut")
local colors = require("reactiveGui/style/colors.nut")

local blurPanel = @() {
  watch = isInVr
  rendObj = !isInVr.value ? ROBJ_WORLD_BLUR_PANEL : null
  size = flex()
  children = {
    rendObj = ROBJ_SOLID
    size = flex()
    color = !isInVr.value ? colors.menu.blurBgrColor : colors.transparent
  }
}

return blurPanel
