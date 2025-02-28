from "%scripts/dagui_library.nut" import *
from "%scripts/controls/rawShortcuts.nut" import GAMEPAD_ENTER_SHORTCUT
from "%scripts/utils_sa.nut" import call_for_handler

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { Button } = require("%scripts/controls/input/button.nut")
let { getBlockFromObjData, createHighlight } = require("%scripts/guiBox.nut")
let { findGoodPos } = require("%scripts/linesGenerator.nut")

const TUTOR_STEP_TIMEOUT_SEC  = 30

let Tutor = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/tutorials/tutorWnd.blk"

  config = null
  ownerWeak = null

  stepIdx = 0

  // Used to check whether tutorial was canceled or not.
  canceled = true

  isTutorialCancelable = false
  stepTimeoutSec = TUTOR_STEP_TIMEOUT_SEC

  function initScreen() {
    if (!this.ownerWeak || !this.config || !this.config.len())
      return this.finalizeTutorial()

    this.ownerWeak = this.ownerWeak.weakref()
    this.guiScene.setUpdatesEnabled(true, true)
    showObjById("close_btn", this.isTutorialCancelable, this.scene)
    if (!this.isTutorialCancelable)
      this.scene.findObject("allow_cancel_timer").setUserData(this)
    this.showStep()
  }

  function showStep() {
    if (!this.ownerWeak)
      return this.finalizeTutorial()

    let stepData = this.config[this.stepIdx]
    let actionType = getTblValue("actionType", stepData, tutorAction.ANY_CLICK)
    let params = {
      onClick = (actionType == tutorAction.ANY_CLICK) ? "onNext" : null
    }

    let msgObj = this.scene.findObject("msg_text")
    local text = getTblValue("text", stepData, "")

    let bottomText = getTblValue("bottomText", stepData, "")
    if (text != "" && bottomText != "")
      text = $"{text}\n\n{bottomText}"

    msgObj.setValue(text)

    let needAccessKey = (actionType == tutorAction.OBJ_CLICK ||
                           actionType == tutorAction.FIRST_OBJ_CLICK)
    let shortcut = getTblValue("shortcut", stepData, needAccessKey ? GAMEPAD_ENTER_SHORTCUT : null)
    let blocksList = []
    local objList = stepData?.obj ?? []
    if (!u.isArray(objList))
      objList = [objList]

    foreach (obj in objList) {
      let block = getBlockFromObjData(obj, this.ownerWeak.scene)
      if (!block)
        continue

      if (actionType != tutorAction.WAIT_ONLY) {
        block.onClick <- (actionType != tutorAction.FIRST_OBJ_CLICK) ? "onNext" : null
        if (shortcut)
          block.accessKey <- shortcut.accessKey
      }
      blocksList.append(block)
    }

    let needArrow = (stepData?.haveArrow ?? true) && blocksList.len() > 0
    if (needArrow && !blocksList.findvalue(@(b) b?.hasArrow == true))
      blocksList[0].hasArrow = true

    local nextActionShortcut = getTblValue("nextActionShortcut", stepData)
    if (nextActionShortcut && showConsoleButtons.value)
      nextActionShortcut = "PRESS_TO_CONTINUE"

    local markup = ""
    if (nextActionShortcut) {
      markup = "".concat(
        markup,
        showConsoleButtons.value ? Button(shortcut.dev[0], shortcut.btn[0]).getMarkup() : "",
        "activeText {text:t='{text}'; caption:t='yes'; margin-left:t='1@framePadding'}".subst({ text = $"#{nextActionShortcut}" })
      )
    }

    let nextShObj = this.scene.findObject("next_step_shortcut")
    this.guiScene.replaceContentFromText(nextShObj, markup, markup.len(), this.ownerWeak)

    this.updateObjectsPos(blocksList, needArrow)

    if (needArrow) {
      let mainMsgY = this.scene.findObject("msg_block").getPosRC()[1]
      let arrowWidth = to_pixels("1@tutorArrowSize")
      let arrowHeight = to_pixels("3@tutorArrowSize")
      let view = { arrows = [] }

      foreach (block in blocksList) {
        if (!block.hasArrow)
          continue

        let isTop = mainMsgY < block.box.c1[1]
        view.arrows.append({
          left     = (block.box.c1[0] + block.box.c2[0] - arrowWidth) / 2
          top      = isTop ? block.box.c1[1] - arrowHeight : block.box.c2[1]
          rotation = isTop ? 0 : 180
        })
      }

      let blk = handyman.renderCached("%gui/tutorials/tutorArrow.tpl", view)
      this.guiScene.replaceContentFromText(this.scene.findObject("arrows_container"), blk, blk.len(), this)
    }

    if (actionType == tutorAction.FIRST_OBJ_CLICK && blocksList.len() > 0) {
      blocksList[0].onClick = "onNext"
      blocksList.reverse()
    }
    createHighlight(this.scene.findObject("dark_screen"), blocksList, this, params)

    showObjById("dummy_console_next", actionType == tutorAction.ANY_CLICK, this.scene)

    let waitTime = getTblValue("waitTime", stepData, actionType == tutorAction.WAIT_ONLY ? 1 : -1)
    if (waitTime > 0)
      Timer(this.scene, waitTime, (@(stepIdx) function() { this.timerNext(stepIdx) })(this.stepIdx), this) //-ident-hides-ident

    this.stepTimeoutSec = TUTOR_STEP_TIMEOUT_SEC
  }

  function updateObjectsPos(blocks, needArrow = true) {
    this.guiScene.applyPendingChanges(false)

    let boxList = []
    foreach (b in blocks)
      boxList.append(b.box)

    if (needArrow) {
      let incSize = to_pixels("3@tutorArrowSize") // arrow height
      foreach (b in blocks)
        if (b.hasArrow)
          boxList.append(b.box.cloneBox(incSize)) // inc targetBox for correct place message
    }

    let mainMsgObj = this.scene.findObject("msg_block")
    let minPos = this.guiScene.calcString("1@bh", null)
    let maxPos = this.guiScene.calcString("sh -1@bh", null)
    let newPos = findGoodPos(mainMsgObj, 1, boxList, minPos, maxPos)
    if (newPos != null)
      mainMsgObj.top = newPos.tostring()
  }

  function timerNext(timerStep) {
    if (timerStep != this.stepIdx)
      return

    this.onNext()
  }

  function onNext() {
    if (this.stepIdx >= this.config.len() - 1 || !this.ownerWeak)
      return this.finalizeTutorial()

    this.canceled = false
    this.checkCb()
    this.canceled = true
    this.stepIdx++
    this.showStep()
  }

  function consoleNext() {
    this.onNext()
  }

  function checkCb() {
    if (this.canceled)
      return

    let stepData = getTblValue(this.stepIdx, this.config)
    let cb = getTblValue("cb", stepData)
    if (!cb)
      return

    if (u.isCallback(cb) || getTblValue("keepEnv", stepData, false))
      cb()
    else
      call_for_handler(this.ownerWeak, cb)
  }

  function afterModalDestroy() {
    this.checkCb()
  }

  function finalizeTutorial() {
    this.canceled = false
    this.goBack()
  }

  function onAllowCancelTimer(_obj, dt) {
    if (this.isTutorialCancelable)
      return
    this.stepTimeoutSec -= dt
    if (this.stepTimeoutSec > 0)
      return
    this.isTutorialCancelable = true
    showObjById("close_btn", this.isTutorialCancelable, this.scene)
  }
}

function gui_modal_tutor(stepsConfig, wndHandler, isTutorialCancelable = false) {
//stepsConfig = [
//  {
//    obj     - array of objects to show in this step.
//              (some of object can be array of objects, - they will be combined in one)
//    text    - text to view
//    actionType = enum tutorAction    - type of action for the next step (default = tutorAction.ANY_CLICK)
//    cb      - callback on finish tutor step
//  }
//]
  return loadHandler(Tutor, {
    ownerWeak = wndHandler,
    config = stepsConfig,
    isTutorialCancelable = isTutorialCancelable
  })
}

gui_handlers.Tutor <- Tutor

return {
  gui_modal_tutor
  Tutor
}