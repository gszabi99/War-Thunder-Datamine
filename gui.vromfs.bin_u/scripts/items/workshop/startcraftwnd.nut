from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let class startCraftWnd extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/emptyFrame.blk"

  showImage = ""
  imageRatio = 1
  showTimeSec = -1

  function initScreen()
  {
    let fObj = scene.findObject("wnd_frame")
    let startCraftImgWidth = $"{imageRatio}@startCraftImgHeight"
    fObj.width = $"{startCraftImgWidth} + 2@framePadding"

    let contentObj = fObj.findObject("wnd_content")
    let data = " ".join(["img {", $"size:t='{startCraftImgWidth}, 1@startCraftImgHeight'; background-image:t='{showImage}'", "}"])
    guiScene.replaceContentFromText(contentObj, data, data.len(), this)

    if (showTimeSec > 0)
      ::Timer(scene, showTimeSec, @() goBack(), this)
  }
}

::gui_handlers.startCraftWnd <- startCraftWnd

return @(params) ::handlersManager.loadHandler(startCraftWnd, params)