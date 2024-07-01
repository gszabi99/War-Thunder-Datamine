from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")

let class startCraftWnd (gui_handlers.BaseGuiHandlerWT) {
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

gui_handlers.startCraftWnd <- startCraftWnd

return @(params) handlersManager.loadHandler(startCraftWnd, params)