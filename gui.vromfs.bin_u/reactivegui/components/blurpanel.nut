from "%rGui/globals/ui_library.nut" import *

let { isInVr } = require("%rGui/style/screenState.nut")
let colors = require("%rGui/style/colors.nut")

let blurPanel = {
  rendObj = !isInVr ? ROBJ_WORLD_BLUR_PANEL : null
  size = flex()
  children = {
    rendObj = ROBJ_SOLID
    size = flex()
    color = !isInVr ? colors.menu.blurBgrColor : colors.transparent
  }
}

let fullScreenBlurPanel = {
  rendObj = !isInVr ? ROBJ_WORLD_BLUR_PANEL : null
  size = flex()
  children = {
    rendObj = ROBJ_SOLID
    size = flex()
    color = 0xBF090F16
  }
}

let hudBlurPanel = {
  rendObj = !isInVr ? ROBJ_WORLD_BLUR_PANEL : ROBJ_SOLID
  size = flex()
  color = !isInVr ? 0xBF9696A1 : 0x6E1A1E23
}

return {
  blurPanel
  fullScreenBlurPanel
  hudBlurPanel
}
