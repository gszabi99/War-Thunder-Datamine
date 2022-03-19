local class startCraftWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptyFrame.blk"

  showImage = ""
  imageRatio = 1
  showTimeSec = -1

  function initScreen()
  {
    local fObj = scene.findObject("wnd_frame")
    local startCraftImgWidth = $"{imageRatio}@startCraftImgHeight"
    fObj.width = $"{startCraftImgWidth} + 2@framePadding"

    local contentObj = fObj.findObject("wnd_content")
    local data = " ".join(["img {", $"size:t='{startCraftImgWidth}, 1@startCraftImgHeight'; background-image:t='{showImage}'", "}"])
    guiScene.replaceContentFromText(contentObj, data, data.len(), this)

    if (showTimeSec > 0)
      ::Timer(scene, showTimeSec, @() goBack(), this)
  }
}

::gui_handlers.startCraftWnd <- startCraftWnd

return @(params) ::handlersManager.loadHandler(startCraftWnd, params)