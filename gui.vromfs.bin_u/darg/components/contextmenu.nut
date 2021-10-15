from "daRg" import *
local style = require("contextMenu.style.nut")
local {addModalWindow, removeModalWindow} = require("modalWindows.nut")

local lastMenuIdx = 0
local function contextMenu(x, y, width, actions, menu_style = style) {
  lastMenuIdx++
  local uid = "context_menu_{0}".subst(lastMenuIdx)
  local closeMenu = @() removeModalWindow(uid)
  local menuBgColor = menu_style?.menuBgColor ?? style.menuBgColor
  local closeHotkeys = menu_style?.closeHotkeys ?? [ ["Esc", closeMenu] ]
  local function defMenuCtor(){
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

  local menuCtor = menu_style?.menuCtor ?? defMenuCtor
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
