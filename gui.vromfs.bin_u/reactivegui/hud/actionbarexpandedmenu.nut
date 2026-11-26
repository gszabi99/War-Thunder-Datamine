from "eventbus" import eventbus_send
from "%rGui/hud/actionBarState.nut" import actionBarExpandedMenu
from "%rGui/hud/torpedoMenu.nut" import torpedoMenu
from "%rGui/globals/ui_library.nut" import *
import "%rGui/control/gui_buttons.nut" as JB

let menuGap = hdpx(3)

let menuByName = {
  torpedo_menu = torpedoMenu
}

let closeActionBarExpandMenu = @() eventbus_send("actionBarExpandClick", { actionId = -1 })

function actionBarExpandedMenuComp() {
  let menu = actionBarExpandedMenu.get()
  let content = menuByName?[menu?.name ?? ""]
  if (menu == null || content == null)
    return { watch = actionBarExpandedMenu }

  let { btnPos, btnSize } = menu
  return {
    key = "actionBarExpandMenu"
    watch = actionBarExpandedMenu
    size = [btnSize[0], 0]
    pos = [btnPos[0], btnPos[1] - menuGap]
    hotkeys = [["^Esc | {0}".subst(JB.B), closeActionBarExpandMenu]]
    children = {
      hplace = ALIGN_CENTER
      vplace = ALIGN_BOTTOM
      transform = true
      behavior = Behaviors.BoundToArea
      children = content
    }
  }
}

return {
  actionBarExpandedMenuComp
}
