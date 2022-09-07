from "daRg" import *
let style = require("contextMenu.style.nut")
let {addModalWindow, removeModalWindow} = require("modalWindows.nut")

local lastMenuIdx = 0

let function contextMenu(x, y, width, actions, menu_style = style) {
  lastMenuIdx++
  let uid = "context_menu_{0}".subst(lastMenuIdx)
  let closeMenu = @() removeModalWindow(uid)
  let menuBgColor = menu_style?.menuBgColor ?? style.menuBgColor
  let closeHotkeys = menu_style?.closeHotkeys ?? [ ["Esc", closeMenu] ]
  let function defMenuCtor(){
    return {
      rendObj = ROBJ_SOLID
      size = [width, SIZE_TO_CONTENT]
      pos = [x, y]
      flow = FLOW_VERTICAL
      color = menuBgColor
      safeAreaMargin = [sh(2), sh(2)]
      transform = {}
      behavior = Behaviors.BoundToArea

      hotkeys = closeHotkeys
      children = actions.map(@(item) menu_style.listItem(item.text,
        function () {
          item.action()
          closeMenu()
        }))
    }
  }

  let menuCtor = menu_style?.menuCtor ?? defMenuCtor
  set_kb_focus(null)
  addModalWindow({
    key = uid
    children = menuCtor()
  })
  return uid
}


return {
  contextMenu
  remove = removeModalWindow
}
