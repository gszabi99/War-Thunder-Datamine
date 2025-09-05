from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getLocalizedControlName, hackTextAssignmentForR2buttonOnPS4
} = require("%scripts/controls/controlsVisual.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { setBindMode } = require("controls")

function assignButtonWindow(owner, onButtonEnteredFunc) {
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
    setBindMode(true);
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
    let curPreset = getCurControlsPreset()
    for (local i = 0; i < 4; i++) {
      local devId = obj[$"device{i}"]
      local btnId = obj[$"button{i}"]
      if (devId != "" && btnId != "") {
        devId = devId.tointeger()
        btnId = btnId.tointeger()

        
        if (devId == STD_KEYBOARD_DEVICE_ID && btnId == 0)
          continue

        if (numButtons != 0)
          curBtnText = $"{curBtnText} + "

        curBtnText = "".concat(curBtnText, getLocalizedControlName(curPreset, devId, btnId))
        numButtons++
      }
    }
    curBtnText = hackTextAssignmentForR2buttonOnPS4(curBtnText)
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
    setBindMode(false);
    this.isListenButton = false;
    base.goBack();
  }
}

return {
  assignButtonWindow
}