from "%scripts/dagui_natives.nut" import set_bind_mode
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getLocalizedControlName } = require("%scripts/controls/controlsVisual.nut")

::assignButtonWindow <- function assignButtonWindow(owner, onButtonEnteredFunc) {
  loadHandler(gui_handlers.assignModalButtonWindow, { owner = owner, onButtonEnteredFunc = onButtonEnteredFunc })
}

gui_handlers.assignModalButtonWindow <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/controlsInput.blk"

  owner = null
  onButtonEnteredFunc = null
  isListenButton = false
  dev = []
  btn = []

  function initScreen() {
    set_bind_mode(true);
    this.guiScene.sleepKeyRepeat(true);
    this.isListenButton = true;
    this.scene.select();
  }

  function onButtonEntered(obj) {
    if (!this.isListenButton)
      return;

    this.dev = [];
    this.btn = [];
    for (local i = 0; i < 4; i++) {
      let devicestr = $"device{i}"
      let buttonstr = $"button{i}"
      if (obj[devicestr] != "" && obj[buttonstr] != "") {
        let devId = obj[devicestr].tointeger();
        let btnId = obj[buttonstr].tointeger();

        // Ignore zero scancode from XBox keyboard driver
        if (devId == STD_KEYBOARD_DEVICE_ID && btnId == 0)
          continue

        log("onButtonEntered", i, devId, btnId);
        this.dev.append(devId);
        this.btn.append(btnId);
      }
    }
    this.goBack();
  }

  function onCancelButtonInput(_obj) {
    this.goBack();
  }

  function onButtonAdded(obj) {
    local curBtnText = ""
    local numButtons = 0
    let curPreset = ::g_controls_manager.getCurPreset()
    for (local i = 0; i < 4; i++) {
      local devId = obj[$"device{i}"]
      local btnId = obj[$"button{i}"]
      if (devId != "" && btnId != "") {
        devId = devId.tointeger()
        btnId = btnId.tointeger()

        // Ignore zero scancode from XBox keyboard driver
        if (devId == STD_KEYBOARD_DEVICE_ID && btnId == 0)
          continue

        if (numButtons != 0)
          curBtnText = $"{curBtnText} + "

        curBtnText = "".concat(curBtnText, getLocalizedControlName(curPreset, devId, btnId))
        numButtons++
      }
    }
    curBtnText = ::hackTextAssignmentForR2buttonOnPS4(curBtnText)
    this.scene.findObject("txt_current_button").setValue("".concat(curBtnText, ((numButtons < 3) ? " + ?" : "")))
  }

  function afterModalDestroy() {
    if (this.dev.len() > 0 && this.dev.len() == this.btn.len())
      if (handlersManager.isHandlerValid(this.owner) && this.onButtonEnteredFunc)
        this.onButtonEnteredFunc.call(this.owner, this.dev, this.btn);
  }

  function onEventAfterJoinEventRoom(_event) {
    this.goBack()
  }

  function goBack() {
    this.guiScene.sleepKeyRepeat(false);
    set_bind_mode(false);
    this.isListenButton = false;
    base.goBack();
  }
}
