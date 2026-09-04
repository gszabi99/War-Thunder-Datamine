from "%rGui/style/screenState.nut" import isInVr
from "%rGui/globals/ui_library.nut" import *

let colors = require("%rGui/style/colors.nut")

let blurPanel = {
  rendObj = !isInVr ? ROBJ_WORLD_BLUR_PANEL : null
  size = FLEX
  children = {
    rendObj = ROBJ_SOLID
    size = FLEX
    color = !isInVr ? colors.menu.blurBgrColor : colors.transparent
  }
}

let fullScreenBlurPanel = {
  rendObj = !isInVr ? ROBJ_WORLD_BLUR_PANEL : null
  size = FLEX
  children = {
    rendObj = ROBJ_SOLID
    size = FLEX
    color = 0xBF090F16
  }
}

let hudBlurPanel = {
  rendObj = !isInVr ? ROBJ_WORLD_BLUR_PANEL : ROBJ_SOLID
  size = FLEX
  color = !isInVr ? 0xBF9696A1 : 0x6E1A1E23
}

let ticketHudBlurPanel = {
  rendObj = !isInVr ? ROBJ_WORLD_BLUR_PANEL : ROBJ_SOLID
  size = FLEX
  color = 0x78000000
}

return {
  blurPanel
  fullScreenBlurPanel
  hudBlurPanel
  ticketHudBlurPanel
}
