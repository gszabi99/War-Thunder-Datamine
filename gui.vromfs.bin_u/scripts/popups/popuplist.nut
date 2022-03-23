let popupList = class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType              = handlerType.MODAL
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupList"
  btnWidth             = null

  //init params
  parentPos            = null
  buttonsList          = null
  onClickCb            = null
  visualStyle          = null

  function getSceneTplView() {
    return {
      buttons = buttonsList
      underPopupClick    = "hidePopupList"
      underPopupDblClick = "hidePopupList"
      posX = parentPos[0]
      posY = parentPos[1]
      btnWidth = btnWidth
      visualStyle = visualStyle
    }
  }

  function onItemClick(obj) {
    onClickCb?(obj)
    goBack()
  }

  function hidePopupList(obj) {
    goBack()
  }
}

::gui_handlers.popupList <- popupList

return {
  openPopupList = @(params = {}) ::handlersManager.loadHandler(popupList, params)
}
