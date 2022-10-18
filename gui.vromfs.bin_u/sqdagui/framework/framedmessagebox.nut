#explicit-this
#no-root-fallback

let u = require("%sqStdLibs/helpers/u.nut")

/*
  FramedMessageBox is a message box, with visible frame.
  Config {
    pos - required position to show or will be used current mouse position
    align - ["left", "right", "top", "bottom"] - near the setted position
    title - upper tiny text
    message - main small text
    onOpenSound - sound ID to play on box open
    buttons - array of table params, for gui/commonParts/button.tpl
    {
      cb - callback for button, otherwise action will be 'goBack' only.
      * if not exist any button - use closeButtonDefault.
    }
  }
*/

::gui_handlers.FramedMessageBox <- class extends ::BaseGuiHandler
{
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/framedMessageBox"

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

  function open(config = {})
  {
    ::handlersManager.loadHandler(::gui_handlers.FramedMessageBox, config)
  }

  function getSceneTplView()
  {
    if (u.isEmpty(this.buttons))
      this.buttons = this.closeButtonDefault

    foreach(idx, button in this.buttons)
    {
      button.funcName <- "onButtonClick"
      button.id <- button?.id ?? ("button_" + idx)
    }

    return this
  }

  function initScreen()
  {
    let obj = this.scene.findObject("framed_message_box")
    if (!::checkObj(obj))
      return

    this.align = ::g_dagui_utils.setPopupMenuPosAndAlign(this.pos || this.getDefaultPos(), this.align, obj, {
      screenBorders = [ "1@bw", "1@bottomBarHeight" ]
    })
    obj.animation = "show"

    let buttonsObj = this.scene.findObject("framed_message_box_buttons_place")
    if (::check_obj(buttonsObj))
      buttonsObj.select()

    if (!u.isEmpty(this.onOpenSound))
      this.guiScene.playSound(this.onOpenSound)
  }

  function getDefaultPos()
  {
    let buttonsObj = this.scene.findObject("framed_message_box_buttons_place")
    if (!::check_obj(buttonsObj))
      return ::array(2, 0)

    return ::get_dagui_mouse_cursor_pos_RC()
  }

  function onButtonClick(obj)
  {
    foreach(button in this.buttons)
      if (button.id == obj?.id)
      {
        this.performAction(button?.cb)
        break
      }

    this.goBack()
  }

  function performAction(func = null)
  {
    if (!func)
      return

    func()
  }
}
