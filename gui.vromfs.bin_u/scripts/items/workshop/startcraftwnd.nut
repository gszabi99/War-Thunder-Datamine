from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/sqDagui/timer/timer.nut" import Timer
from "%scripts/dagui_library.nut" import *

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

class startCraftWnd (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptyFrame.blk"

  showImage = ""
  imageRatio = 1
  showTimeSec = -1

  function initScreen() {
    let fObj = this.scene.findObject("wnd_frame")
    let startCraftImgWidth = $"{this.imageRatio}@startCraftImgHeight"
    fObj.width = $"{startCraftImgWidth} + 2@framePadding"

    let contentObj = fObj.findObject("wnd_content")
    let data = " ".join(["img {", $"size:t='{startCraftImgWidth}, 1@startCraftImgHeight'; background-image:t='{this.showImage}'", "}"])
    this.guiScene.replaceContentFromText(contentObj, data, data.len(), this)

    if (this.showTimeSec > 0)
      Timer(this.scene, this.showTimeSec, @() this.goBack(), this)
  }
}

register_gui_handler("startCraftWnd", startCraftWnd)

return @(params) handlersManager.loadHandler(startCraftWnd, params)