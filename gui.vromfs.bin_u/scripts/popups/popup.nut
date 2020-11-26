::Popup <- class
{
  static POPUP_BLK = "gui/popup/popup.blk"
  static POPUP_BUTTON_BLK = "gui/popup/popupButton.blk"

  title = ""
  message = ""

  groupName = null
  lifetime = null

  handler = null
  buttons = []
  selfObj = null
  onClickPopupAction = null

  constructor(config)
  {
    onClickPopupAction = config.onClickPopupAction
    buttons = config.buttons || []
    handler = config.handler
    groupName = config.groupName
    title = config.title
    message = config.msg
    lifetime = config.lifetime
  }

  function isValidView()
  {
    return ::check_obj(selfObj)
  }

  function show(popupNestObj)
  {
    popupNestObj.setUserData(this)

    local popupGuiScene = ::get_cur_gui_scene()
    selfObj = popupGuiScene.createElementByObject(popupNestObj, POPUP_BLK, "popup", this)

    if(!::u.isEmpty(title))
      selfObj.findObject("title").setValue(title)
    else
      selfObj.findObject("title").show(false)

    selfObj.findObject("msg").setValue(message)

    local obj = selfObj.findObject("popup_buttons_place")
    foreach (button in buttons)
    {
      local buttonObj = popupGuiScene.createElementByObject(obj, POPUP_BUTTON_BLK, "Button_text", this)
      buttonObj.id = button.id
      buttonObj.setValue(button.text)
    }

    selfObj.setUserData(this)

    if (lifetime > 0)
      selfObj.timer_interval_msec = lifetime.tostring()
  }

  function destroy(isForced = false)
  {
    if (::checkObj(selfObj))
      selfObj.fade = isForced ? "forced" : "out"
  }

  function requestDestroy(isForced = true)
  {
    destroy(isForced)
    ::g_popups.remove(this)
  }

  function performPopupAction(func)
  {
    if (!func)
      return
    if (handler != null)
      func.call(handler)
    else
      func()
  }

  function onClickPopup(obj)
  {
    if (onClickPopupAction)
      performPopupAction(onClickPopupAction)
    requestDestroy()
  }

  function onRClickPopup(obj)
  {
    requestDestroy()
  }

  function onClosePopup(obj)
  {
    requestDestroy()
  }

  function onPopupButtonClick(obj)
  {
    local id = obj?.id
    local button = buttons.findvalue(@(b) b.id == id)
    obj.getScene().performDelayed(this, function() {
      if (!isValidView())
        return
      performPopupAction(button?.func)
      requestDestroy()
    })
  }

  function onTimerUpdate(obj, dt)
  {
    requestDestroy(false)
  }
}
