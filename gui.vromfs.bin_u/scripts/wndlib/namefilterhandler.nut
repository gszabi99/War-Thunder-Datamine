from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")


let NameFilterHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/wndLib/nameFilterHandler.blk"
  sceneTplName = null
  goBackCb = null
  applyFilterCb = null
  applyFilterTimer = null

  function applyFilter(obj) {
    clearTimer(this.applyFilterTimer)
    let filterText = utf8ToLower(obj.getValue())
    if (filterText == "") {
      this.applyFilterCb?(filterText)
      return
    }
    let applyCallback = Callback(@() this.applyFilterCb?(filterText), this)
    this.applyFilterTimer = setTimeout(0.5, @() applyCallback())
  }

  function onFilterCancel(obj) {
    if (obj.getValue() != "")
      obj.setValue("")
    else
      this.guiScene.performDelayed(this, this.goBack)
  }

  function goBack() {
    base.goBack()
    this.goBackCb?()
  }
}

gui_handlers.NameFilterHandler <- NameFilterHandler

return {
  loadNameFilterHandler = @(params) handlersManager.loadHandler(NameFilterHandler, params)
}
