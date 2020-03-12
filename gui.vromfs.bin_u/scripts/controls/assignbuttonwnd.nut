::assignButtonWindow <- function assignButtonWindow(owner, onButtonEnteredFunc)
{
  ::gui_start_modal_wnd(::gui_handlers.assignModalButtonWindow, { owner = owner, onButtonEnteredFunc = onButtonEnteredFunc})
}

class ::gui_handlers.assignModalButtonWindow extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/controlsInput.blk"

  owner = null
  onButtonEnteredFunc = null
  isListenButton = false
  dev = []
  btn = []

  function initScreen()
  {
    ::set_bind_mode(true);
    guiScene.sleepKeyRepeat(true);
    isListenButton = true;
    scene.select();
  }

  function onButtonEntered(obj)
  {
    if (!isListenButton)
      return;

    dev = [];
    btn = [];
    for (local i = 0; i < 3; i++)
    {
      if (obj["device" + i]!="" && obj["button" + i]!="")
      {
        local devId = obj["device" + i].tointeger();
        local btnId = obj["button" + i].tointeger();

        // Ignore zero scancode from XBox keyboard driver
        if (devId == STD_KEYBOARD_DEVICE_ID && btnId == 0)
          continue

        dagor.debug("onButtonEntered "+i+" "+devId+" "+btnId);
        dev.append(devId);
        btn.append(btnId);
      }
    }
    goBack();
  }

  function onCancelButtonInput(obj)
  {
    goBack();
  }

  function onButtonAdded(obj)
  {
    local curBtnText = ""
    local numButtons = 0
    local curPreset = ::g_controls_manager.getCurPreset()
    for (local i = 0; i < 3; i++)
    {
      local devId = obj["device" + i]
      local btnId = obj["button" + i]
      if (devId != "" && btnId != "")
      {
        devId = devId.tointeger()
        btnId = btnId.tointeger()

        // Ignore zero scancode from XBox keyboard driver
        if (devId == STD_KEYBOARD_DEVICE_ID && btnId == 0)
          continue

        if (numButtons != 0)
          curBtnText += " + "

        curBtnText += ::getLocalizedControlName(curPreset, devId, btnId)
        numButtons++
      }
    }
    curBtnText = ::hackTextAssignmentForR2buttonOnPS4(curBtnText)
    scene.findObject("txt_current_button").setValue(curBtnText + ((numButtons < 3)? " + ?" : ""));
  }

  function afterModalDestroy()
  {
    if (dev.len() > 0 && dev.len() == btn.len())
      if (::handlersManager.isHandlerValid(owner) && onButtonEnteredFunc)
        onButtonEnteredFunc.call(owner, dev, btn);
  }

  function onEventAfterJoinEventRoom(event)
  {
    goBack()
  }

  function goBack()
  {
    guiScene.sleepKeyRepeat(false);
    ::set_bind_mode(false);
    isListenButton = false;
    base.goBack();
  }
}