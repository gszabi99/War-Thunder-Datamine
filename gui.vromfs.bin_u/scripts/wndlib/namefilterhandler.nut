from "%sqstd/string.nut" import utf8ToLower
from "dagor.workcycle" import setTimeout, clearTimer
from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")


let NameFilterHandler = class (BaseGuiHandlerWT) {
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

register_gui_handler("NameFilterHandler", NameFilterHandler)

return {
  loadNameFilterHandler = @(params) handlersManager.loadHandler(NameFilterHandler, params)
}
