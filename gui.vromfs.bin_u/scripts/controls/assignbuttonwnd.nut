from "%scripts/dagui_library.nut" import *
from "controls" import ActivationCondition
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getLocalizedControlName, hackTextAssignmentForR2buttonOnPS4, getLocalizedShortcutName
} = require("%scripts/controls/controlsVisual.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")
let { setBindMode } = require("controls")
let { clearControlsInputBhvBindings } = require("%sqDagui/guiBhv/bhvControlsInput.nut")
let { Button } = require("%scripts/controls/input/button.nut")
let { Combination } = require("%scripts/controls/input/combination.nut")

let buttonAssignStepsList = [
  {
    objId = "controls_input_step"
    updateFunction = "switchToControlsInputStep"
  }
  {
    objId = "select_activation_type_step"
    updateFunction = "switchToSelectActivationTypeStep"
  }
]

let activationTypeChooseConfig = [
  {
    activationType = ActivationCondition.DEFAULT
    locId = "controls/activationType/onPressed"
  }
  {
    activationType = ActivationCondition.LONG_PRESS
    locId = "controls/activationType/onLongPress"
  }
  {
    activationType = ActivationCondition.TAPPED_TWICE
    locId = "controls/activationType/onDoubleTap"
  }
]

function assignButtonWindow(owner, onButtonEnteredFunc, shortcutId) {
  loadHandler(gui_handlers.assignModalButtonWindow, { owner, onButtonEnteredFunc, shortcutId })
}

gui_handlers.assignModalButtonWindow <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/controlsInput.blk"

  owner = null
  onButtonEnteredFunc = null
  isListenButton = false
  shortcutId = ""
  dev = []
  btn = []
  curActivationType = ActivationCondition.DEFAULT
  curStepIdx = 0

  function initScreen() {
    if (this.shortcutId != "")
      this.scene.findObject("shortcut_name").setValue(getLocalizedShortcutName(this.shortcutId))
    this.updateWindowForCurStep()
  }

  function updateWindowForCurStep() {
    let { updateFunction } = buttonAssignStepsList[this.curStepIdx]
    this[updateFunction].call(this)
    foreach (idx, step in buttonAssignStepsList)
      showObjById(step.objId, this.curStepIdx == idx, this.scene)
    this.updateButtons()
  }

  function resetInputButtons() {
    this.dev.clear()
    this.btn.clear()
    let controlsInputObj = showObjById("controls_input_step", true, this.scene)
    clearControlsInputBhvBindings(controlsInputObj)
    this.scene.findObject("txt_current_button").setValue("")
    controlsInputObj.select()
  }

  function switchToControlsInputStep() {
    this.resetInputButtons()
    this.switchBindMode(true)
  }

  function switchToSelectActivationTypeStep() {
    this.switchBindMode(false)
    this.updateCombinationMarkup()
    let chooseActivationTypeObj = this.scene.findObject("choose_activation_type")
    if (chooseActivationTypeObj.childrenCount() > 0)
      return

    let curType = this.curActivationType
    let data = handyman.renderCached("%gui/commonParts/radiobutton.tpl", { radiobutton =
      activationTypeChooseConfig.map(@(v) { text = loc(v.locId), selected = v.activationType == curType })})
    this.guiScene.replaceContentFromText(chooseActivationTypeObj, data, data.len(), this)
  }

  function updateButtons() {
    showObjById("btn_back", this.curStepIdx > 0, this.scene)
    showObjById("btn_apply", this.curStepIdx == (buttonAssignStepsList.len() - 1), this.scene)
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
    this.switchToStep(this.curStepIdx + 1)
  }

  onCancelButtonInput = @() this.goBack()

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

  function onApply() {
    this.goBack()
    if (this.dev.len() > 0 && this.dev.len() == this.btn.len())
      if (handlersManager.isHandlerValid(this.owner) && this.onButtonEnteredFunc)
        this.onButtonEnteredFunc.call(this.owner, this.dev, this.btn, this.curActivationType)
  }

  function onEventAfterJoinEventRoom(_event) {
    this.goBack()
  }

  function goBack() {
    this.switchBindMode(false)
    base.goBack()
  }

  function switchBindMode(value) {
    this.guiScene.sleepKeyRepeat(value)
    setBindMode(value)
    this.isListenButton = value
  }

  function switchToStep(newStepIdx) {
    if (newStepIdx < 0) {
      this.goBack()
      return
    }
    if (newStepIdx not in buttonAssignStepsList) {
      this.onApply()
      return
    }

    this.curStepIdx = newStepIdx
    this.updateWindowForCurStep()
  }

  onBackToPrevStep = @() this.switchToStep(this.curStepIdx - 1)

  function onChangeActivationType(obj) {
    let prevType = this.curActivationType
    this.curActivationType =
      activationTypeChooseConfig?[obj.getValue()].activationType ?? ActivationCondition.DEFAULT
    if (prevType != this.curActivationType)
      this.updateCombinationMarkup()
  }

  function updateCombinationMarkup() {
    let elemets = []
    foreach (idx, button in this.btn)
      elemets.append(Button(this.dev[idx], button, this.curActivationType))

    let markup = elemets.len() == 0 ? ""
      : elemets.len() == 1 ? elemets[0].getMarkup()
      : Combination(elemets).getMarkup()
    let obj = this.scene.findObject("combination_markup")
    this.guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }
}

return {
  assignButtonWindow
}