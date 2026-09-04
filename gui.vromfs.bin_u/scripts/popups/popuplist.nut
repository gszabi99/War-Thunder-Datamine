from "%scripts/dagui_library.nut" import *
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setPopupMenuPosAndAlign } = require("%scripts/sqDagui/daguiUtil.nut")

let popupList = class (BaseGuiHandlerWT) {
  wndType              = handlerType.MODAL
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupList.tpl"
  btnWidth             = null
  align                = ALIGN.BOTTOM
  clickPropagation     = false 

  
  parentObj            = null
  buttonsList          = null
  onClickCb            = null
  visualStyle          = null

  function getSceneTplView() {
    return {
      buttons = this.buttonsList
      underPopupClick    = "hidePopupList"
      underPopupDblClick = "hidePopupList"
      btnWidth = this.btnWidth
      visualStyle = this.visualStyle
      clickPropagation = this.clickPropagation
    }
  }

  function initScreen() {
    this.align = setPopupMenuPosAndAlign(
      this.parentObj, this.align, this.scene.findObject("popup_list"))
  }

  function onItemClick(obj) {
    this.onClickCb?(obj)
    this.goBack()
  }

  function hidePopupList(_obj) {
    this.goBack()
    if (!this.clickPropagation)
      return

    let [mouseX, mouseY] = get_dagui_mouse_cursor_pos()
    this.guiScene.simulateMouseClick(mouseX, mouseY, 1)
  }
}

register_gui_handler("popupList", popupList)

return {
  popupList
  openPopupList = @(params = {}) handlersManager.loadHandler(popupList, params)
}
