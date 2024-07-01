from "%scripts/dagui_library.nut" import *

let { move_mouse_on_child_by_value, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let class UnlockGroupWnd (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptyFrame.blk"
  title = ""
  unlocksList = null

  function initScreen() {
    if (!this.unlocksList || this.unlocksList.len() == 0)
      return this.goBack()

    let fObj = this.scene.findObject("wnd_frame")
    fObj["max-height"] = "1@maxWindowHeight"
    fObj["max-width"] = "1@maxWindowWidth"
    fObj["class"] = "wnd"
    fObj.width = "fw"

    let listObj = this.scene.findObject("wnd_content")
    listObj.width = $"2(@unlockBlockWidth + @framePadding) + @scrollBarSize"
    listObj["overflow-y"] = "auto"
    listObj.flow = "h-flow"
    listObj.scrollbarShortcuts = "yes"

    let titleObj = this.scene.findObject("wnd_title")
    titleObj.setValue(this.title)

    this.fillPage()
  }

  function reinitScreen(params = {}) {
    this.setParams(params)
    this.initScreen()
  }

  function fillPage() {
    let listObj = this.scene.findObject("wnd_content")

    this.guiScene.setUpdatesEnabled(false, false)
    this.guiScene.replaceContentFromText(listObj, "", 0, this)

    for (local i = 0; i < this.unlocksList.len(); ++i)
      this.addUnlock(this.unlocksList[i], listObj)

    this.guiScene.setUpdatesEnabled(true, true)
    move_mouse_on_child_by_value(listObj)
  }

  function addUnlock(unlock, listObj) {
    let obj = this.guiScene.createElementByObject(listObj, "%gui/unlocks/unlockBlock.blk", "frameBlock_dark", this)
    obj.width = "1@unlockBlockWidth"
    obj["margin-bottom"] = "1@framePadding"
    obj["margin-right"] = "1@framePadding"
    ::fill_unlock_block(obj, unlock)
  }
}

gui_handlers.UnlockGroupWnd <- UnlockGroupWnd

function showUnlocksGroupWnd(unlocksList, title) {
  loadHandler(UnlockGroupWnd, { unlocksList, title })
}

return showUnlocksGroupWnd