from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")

let popupList = class (gui_handlers.BaseGuiHandlerWT) {
  wndType              = handlerType.MODAL
  sceneBlkName         = null
  needVoiceChat        = false
  sceneTplName         = "%gui/popup/popupList.tpl"
  btnWidth             = null
  align                = ALIGN.BOTTOM
  clickPropagation     = false // when enabled clicking outside the popup will trigger click on the underlying element

  //init params
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

gui_handlers.popupList <- popupList

return {
  openPopupList = @(params = {}) handlersManager.loadHandler(popupList, params)
}
