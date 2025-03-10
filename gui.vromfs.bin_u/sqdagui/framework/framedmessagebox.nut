from "%sqDagui/daguiNativeApi.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { check_obj, setPopupMenuPosAndAlign } = require("%sqDagui/daguiUtil.nut")
let { handlerType } = require("handlerType.nut")
let { handlersManager } = require("baseGuiHandlerManager.nut")
let { gui_handlers, register_gui_handler } = require("gui_handlers.nut")
let { BaseGuiHandler } = require("baseGuiHandler.nut")















let FramedMessageBox = class (BaseGuiHandler) {
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/framedMessageBox.tpl"

  buttons = null
  title = ""
  message = ""
  pos = null
  align = "top"
  onOpenSound = null

  closeButtonDefault = [{
    id = "btn_ok"
    text = "#mainmenu/btnOk"
    shortcut = "A"
    button = true
  }]

  function open(config = {}) {
    handlersManager.loadHandler(gui_handlers.FramedMessageBox, config)
  }

  function getSceneTplView() {
    if (u.isEmpty(this.buttons))
      this.buttons = this.closeButtonDefault

    foreach (idx, button in this.buttons) {
      button.funcName <- "onButtonClick"
      button.id <- button?.id ?? ($"button_{idx}" )
    }

    return this
  }

  function initScreen() {
    let obj = this.scene.findObject("framed_message_box")
    if (!obj?.isValid())
      return

    this.align = setPopupMenuPosAndAlign(this.pos || this.getDefaultPos(), this.align, obj, {
      screenBorders = [ "1@bw", "1@bottomBarHeight" ]
    })
    obj.animation = "show"

    let buttonsObj = this.scene.findObject("framed_message_box_buttons_place")
    if (check_obj(buttonsObj))
      buttonsObj.select()

    if (!u.isEmpty(this.onOpenSound))
      this.guiScene.playSound(this.onOpenSound)
  }

  function getDefaultPos() {
    let buttonsObj = this.scene.findObject("framed_message_box_buttons_place")
    if (!check_obj(buttonsObj))
      return array(2, 0)

    return get_dagui_mouse_cursor_pos_RC()
  }

  function onButtonClick(obj) {
    foreach (button in this.buttons)
      if (button.id == obj?.id) {
        this.performAction(button?.cb)
        break
      }

    this.goBack()
  }

  function performAction(func = null) {
    if (!func)
      return

    func()
  }
}

register_gui_handler("FramedMessageBox", FramedMessageBox)