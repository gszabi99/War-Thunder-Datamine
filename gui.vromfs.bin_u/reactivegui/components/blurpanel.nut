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

return blurPanel
