import "%rGui/style/colors.nut" as colors
import "%rGui/style/cssColor.nut" as cssColor
from "%rGui/style/screenState.nut" import isInVr
from "%rGui/globals/ui_library.nut" import *

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
    color = cssColor("fullScreenBgrColor")
  }
}

let hudBlurPanel = {
  rendObj = !isInVr ? ROBJ_WORLD_BLUR_PANEL : ROBJ_SOLID
  size = FLEX
  color = !isInVr ? cssColor("hudBlur") : 0x6E1A1E23
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
