from "%rGui/hud/actionBarState.nut" import actionBarExpandedMenu
from "%rGui/hud/torpedoMenu.nut" import torpedoMenu
from "%rGui/globals/ui_library.nut" import *

let menuGap = hdpx(3)
let menuBorderWidth = hdpx(1)

let menuByName = {
  torpedo_menu = torpedoMenu
}

function actionBarExpandedMenuComp() {
  let menu = actionBarExpandedMenu.get()
  let content = menuByName?[menu?.name ?? ""]
  if (menu == null || content == null)
    return { watch = actionBarExpandedMenu }

  let { btnPos, btnSize } = menu
  return {
    watch = actionBarExpandedMenu
    size = [btnSize[0], 0]
    pos = [btnPos[0], btnPos[1] - menuGap]
    children = {
      rendObj = ROBJ_BOX
      hplace = ALIGN_CENTER
      vplace = ALIGN_BOTTOM
      transform = true
      behavior = Behaviors.BoundToArea
      fillColor = 0xC0000000
      borderColor = 0xFFC0C0C0
      borderWidth = menuBorderWidth
      children = content
    }
  }
}

return {
  actionBarExpandedMenuComp
}
