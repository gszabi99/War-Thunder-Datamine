from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%sqstd/string.nut" import utf8ToLower
from "dagor.workcycle" import setTimeout, clearTimer
from "%scripts/dagui_library.nut" import *

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

return freeze({
  loadNameFilterHandler = @(params) handlersManager.loadHandler(NameFilterHandler, params)
})
