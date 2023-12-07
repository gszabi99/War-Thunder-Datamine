//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")

const TITOR_STEP_TIMEOUT_SEC  = 30

//req handyman
::guiTutor <- {
  _id = "tutor_screen_root"
  _isFullscreen = true
  _lightBlock = "tutorLight"
  _darkBlock = "tutorDark"
  _sizeIncMul = 0
  _sizeIncAdd = -2 //boxes size decreased for more accurate view of close objects
  _isNoDelayOnClick = false //optional no delay on_click for lightboxes
}

::guiTutor.createHighlight <- function createHighlight(scene, objDataArray, handler = null, params = null) {
  //obj Config = [{
  //    obj          //    DaGuiObject,
                     // or string obj name in scene,
                     // or table with size and pos,
                     // or array of objects to highlight as one
  //    box          // GuiBox - can be used instead of obj
  //    id, onClick
  //  }...]
  let guiScene = scene.getScene()
  let sizeIncMul = getTblValue("sizeIncMul", params, this._sizeIncMul)
  let sizeIncAdd = getTblValue("sizeIncAdd", params, this._sizeIncAdd)
  let isFullscreen = params?.isFullscreen ?? this._isFullscreen
  let rootBox = ::GuiBox().setFromDaguiObj(isFullscreen ? guiScene.getRoot() : scene)
  let rootPosCompensation = [ -rootBox.c1[0], -rootBox.c1[1] ]
  let defOnClick = getTblValue("onClick", params, null)
  let view = {
    id = getTblValue("id", params, this._id)
    isFullscreen = isFullscreen
    lightBlock = getTblValue("lightBlock", params, this._lightBlock)
    darkBlock = getTblValue("darkBlock", params, this._darkBlock)
    lightBlocks = []
    darkBlocks = []
  }

  let rootXPad = isFullscreen ? -to_pixels("1@bwInVr") : 0
  let rootYPad = isFullscreen ? -to_pixels("1@bhInVr") : 0
  let darkBoxes = []
  if (view.darkBlock && view.darkBlock != "")
    darkBoxes.append(rootBox.cloneBox(rootXPad, rootYPad).incPos(rootPosCompensation))

  foreach (config in objDataArray) {
    let block = this.getBlockFromObjData(config, scene, defOnClick)
    if (!block)
      continue

    block.box.incSize(sizeIncAdd, sizeIncMul)
    block.box.incPos(rootPosCompensation)
    block.onClick <- getTblValue("onClick", block) || defOnClick
    view.lightBlocks.append(this.blockToView(block))

    for (local i = darkBoxes.len() - 1; i >= 0; i--) {
      let newBoxes = block.box.cutBox(darkBoxes[i])
      if (!newBoxes)
        continue

      darkBoxes.remove(i)
      darkBoxes.extend(newBoxes)
    }
  }

  foreach (box in darkBoxes)
    view.darkBlocks.append(this.blockToView({ box = box, onClick = defOnClick }))

  let data = handyman.renderCached(("%gui/tutorials/tutorDarkScreen.tpl"), view)
  guiScene.replaceContentFromText(scene, data, data.len(), handler)

  return scene.findObject(view.id)
}

::guiTutor.getBlockFromObjData <- function getBlockFromObjData(objData, scene = null, defOnClick = null) {
  local res = null
  local obj = getTblValue("obj", objData) || objData
  if (type(obj) == "string")
    obj = checkObj(scene) ? scene.findObject(obj) : null
  else if (type(obj) == "function")
    obj = obj()
  if (type(obj) == "array") {
    for (local i = 0; i < obj.len(); i++) {
      let block = this.getBlockFromObjData(obj[i], scene)
      if (!block)
        continue
      if (!res)
        res = block
      else
        res.box.addBox(block.box)
    }
  }
  else if (type(obj) == "table") {
    if (("box" in obj) && obj.box)
      res = clone obj
  }
  else if (type(obj) == "instance")
    if (obj instanceof ::DaGuiObject) {
      if (checkObj(obj) && obj.isVisible())
        res = {
          id = "_" + (obj?.id ?? "null")
          box = ::GuiBox().setFromDaguiObj(obj)
        }
    }
    else if (obj instanceof ::GuiBox)
      res = {
        id = ""
        box = obj
      }
  if (!res)
    return null

  let id = getTblValue("id", objData)
  if (id)
    res.id <- id
  res.onClick <- getTblValue("onClick", objData, defOnClick)
  res.isNoDelayOnClick <- objData?.isNoDelayOnClick ?? this._isNoDelayOnClick
  res.hasArrow <- objData?.hasArrow ?? false
  return res
}

::guiTutor.blockToView <- function blockToView(block) {
  let box = block.box
  for (local i = 0; i < 2; i++) {
    block["pos" + i] <- box.c1[i]
    block["size" + i] <- box.c2[i] - box.c1[i]
  }
  return block
}

::gui_modal_tutor <- function gui_modal_tutor(stepsConfig, wndHandler, isTutorialCancelable = false) {
//stepsConfig = [
//  {
//    obj     - array of objects to show in this step.
//              (some of object can be array of objects, - they will be combined in one)
//    text    - text to view
//    actionType = enum tutorAction    - type of action for the next step (default = tutorAction.ANY_CLICK)
//    cb      - callback on finish tutor step
//  }
//]
  return loadHandler(gui_handlers.Tutor, {
    ownerWeak = wndHandler,
    config = stepsConfig,
    isTutorialCancelable = isTutorialCancelable
  })
}

gui_handlers.Tutor <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/tutorials/tutorWnd.blk"

  config = null
  ownerWeak = null

  stepIdx = 0

  // Used to check whether tutorial was canceled or not.
  canceled = true

  isTutorialCancelable = false
  stepTimeoutSec = TITOR_STEP_TIMEOUT_SEC

  function initScreen() {
    if (!this.ownerWeak || !this.config || !this.config.len())
      return this.finalizeTutorial()

    this.ownerWeak = this.ownerWeak.weakref()
    this.guiScene.setUpdatesEnabled(true, true)
    this.showSceneBtn("close_btn", this.isTutorialCancelable)
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
      text += "\n\n" + bottomText

    msgObj.setValue(text)

    let needAccessKey = (actionType == tutorAction.OBJ_CLICK ||
                           actionType == tutorAction.FIRST_OBJ_CLICK)
    let shortcut = getTblValue("shortcut", stepData, needAccessKey ? ::GAMEPAD_ENTER_SHORTCUT : null)
    let blocksList = []
    local objList = stepData?.obj ?? []
    if (!u.isArray(objList))
      objList = [objList]

    foreach (obj in objList) {
      let block = ::guiTutor.getBlockFromObjData(obj, this.ownerWeak.scene)
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
    ::guiTutor.createHighlight(this.scene.findObject("dark_screen"), blocksList, this, params)

    this.showSceneBtn("dummy_console_next", actionType == tutorAction.ANY_CLICK)

    local nextActionShortcut = getTblValue("nextActionShortcut", stepData)
    if (nextActionShortcut && showConsoleButtons.value)
      nextActionShortcut = "PRESS_TO_CONTINUE"

    local markup = ""
    if (nextActionShortcut) {
      markup += showConsoleButtons.value ? ::Input.Button(shortcut.dev[0], shortcut.btn[0]).getMarkup() : ""
      markup += "activeText {text:t='{text}'; caption:t='yes'; margin-left:t='1@framePadding'}".subst({ text = "#" + nextActionShortcut })
    }

    let nextShObj = this.scene.findObject("next_step_shortcut")
    this.guiScene.replaceContentFromText(nextShObj, markup, markup.len(), this.ownerWeak)

    let waitTime = getTblValue("waitTime", stepData, actionType == tutorAction.WAIT_ONLY ? 1 : -1)
    if (waitTime > 0)
      Timer(this.scene, waitTime, (@(stepIdx) function() { this.timerNext(stepIdx) })(this.stepIdx), this) //-ident-hides-ident

    this.stepTimeoutSec = TITOR_STEP_TIMEOUT_SEC
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
    let newPos = ::LinesGenerator.findGoodPos(mainMsgObj, 1, boxList, minPos, maxPos)
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
      ::call_for_handler(this.ownerWeak, cb)
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
    this.showSceneBtn("close_btn", this.isTutorialCancelable)
  }
}
