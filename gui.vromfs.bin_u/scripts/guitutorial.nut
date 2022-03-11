local tutorAction = require("scripts/tutorials/tutorialActions.nut")

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

guiTutor.createHighlight <- function createHighlight(scene, objDataArray, handler = null, params = null)
  //obj Config = [{
  //    obj          //    DaGuiObject,
                     // or string obj name in scene,
                     // or table with size and pos,
                     // or array of objects to highlight as one
  //    box          // GuiBox - can be used instead of obj
  //    id, onClick
  //  }...]
{
  local guiScene = scene.getScene()
  local sizeIncMul = ::getTblValue("sizeIncMul", params, _sizeIncMul)
  local sizeIncAdd = ::getTblValue("sizeIncAdd", params, _sizeIncAdd)
  local isFullscreen = params?.isFullscreen ?? _isFullscreen
  local rootBox = ::GuiBox().setFromDaguiObj(isFullscreen ? guiScene.getRoot() : scene)
  local rootPosCompensation = [ - rootBox.c1[0], - rootBox.c1[1] ]
  local defOnClick = ::getTblValue("onClick", params, null)
  local view = {
    id = ::getTblValue("id", params, _id)
    isFullscreen = isFullscreen
    lightBlock = ::getTblValue("lightBlock", params, _lightBlock)
    darkBlock = ::getTblValue("darkBlock", params, _darkBlock)
    lightBlocks = []
    darkBlocks = []
  }

  local rootXPad = isFullscreen ? -::to_pixels("1@bwInVr") : 0
  local rootYPad = isFullscreen ? -::to_pixels("1@bhInVr") : 0
  local darkBoxes = []
  if (view.darkBlock && view.darkBlock != "")
    darkBoxes.append(rootBox.cloneBox(rootXPad, rootYPad).incPos(rootPosCompensation))

  foreach(config in objDataArray)
  {
    local block = getBlockFromObjData(config, scene, defOnClick)
    if (!block)
      continue

    block.box.incSize(sizeIncAdd, sizeIncMul)
    block.box.incPos(rootPosCompensation)
    block.onClick <- ::getTblValue("onClick", block) || defOnClick
    view.lightBlocks.append(blockToView(block))

    for(local i = darkBoxes.len() - 1; i >= 0; i--)
    {
      local newBoxes = block.box.cutBox(darkBoxes[i])
      if (!newBoxes)
        continue

      darkBoxes.remove(i)
      darkBoxes.extend(newBoxes)
    }
  }

  foreach(box in darkBoxes)
    view.darkBlocks.append(blockToView({ box = box, onClick = defOnClick }))

  local data = ::handyman.renderCached(("gui/tutorials/tutorDarkScreen"), view)
  guiScene.replaceContentFromText(scene, data, data.len(), handler)

  return scene.findObject(view.id)
}

guiTutor.getBlockFromObjData <- function getBlockFromObjData(objData, scene = null, defOnClick = null)
{
  local res = null
  local obj = ::getTblValue("obj", objData) || objData
  if (typeof(obj) == "string")
    obj = ::checkObj(scene) ? scene.findObject(obj) : null
  else if (typeof(obj) == "function")
    obj = obj()
  if (typeof(obj) == "array")
  {
    for (local i = 0; i < obj.len(); i++)
    {
      local block = getBlockFromObjData(obj[i], scene)
      if (!block)
        continue
      if (!res)
        res = block
      else
        res.box.addBox(block.box)
    }
  } else if (typeof(obj) == "table")
  {
    if (("box" in obj) && obj.box)
      res = clone obj
  } else if (typeof(obj) == "instance")
    if (obj instanceof ::DaGuiObject)
    {
      if (::checkObj(obj) && obj.isVisible())
        res = {
          id = "_" + (obj?.id ?? "null")
          box = ::GuiBox().setFromDaguiObj(obj)
        }
    } else if (obj instanceof ::GuiBox)
      res = {
        id = ""
        box = obj
      }
  if (!res)
    return null

  local id = ::getTblValue("id", objData)
  if (id)
    res.id <- id
  res.onClick <- ::getTblValue("onClick", objData, defOnClick)
  res.isNoDelayOnClick <- objData?.isNoDelayOnClick ?? _isNoDelayOnClick
  res.hasArrow <- objData?.hasArrow ?? false
  return res
}

guiTutor.blockToView <- function blockToView(block)
{
  local box = block.box
  for(local i = 0; i < 2; i++)
  {
    block["pos" + i] <- box.c1[i]
    block["size" + i] <- box.c2[i] - box.c1[i]
  }
  return block
}

::gui_modal_tutor <- function gui_modal_tutor(stepsConfig, wndHandler, isTutorialCancelable = false)
//stepsConfig = [
//  {
//    obj     - array of objects to show in this step.
//              (some of object can be array of objects, - they will be combined in one)
//    text    - text to view
//    actionType = global enum tutorAction    - type of action for the next step (default = tutorAction.ANY_CLICK)
//    cb      - callback on finish tutor step
//  }
//]
{
  return ::gui_start_modal_wnd(::gui_handlers.Tutor, {
    ownerWeak = wndHandler,
    config = stepsConfig,
    isTutorialCancelable = isTutorialCancelable
  })
}

class ::gui_handlers.Tutor extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/tutorials/tutorWnd.blk"

  config = null
  ownerWeak = null

  stepIdx = 0

  // Used to check whether tutorial was canceled or not.
  canceled = true

  isTutorialCancelable = false
  stepTimeoutSec = TITOR_STEP_TIMEOUT_SEC

  function initScreen()
  {
    if (!ownerWeak || !config || !config.len())
      return finalizeTutorial()

    ownerWeak = ownerWeak.weakref()
    guiScene.setUpdatesEnabled(true, true)
    showSceneBtn("close_btn", isTutorialCancelable)
    if (!isTutorialCancelable)
      scene.findObject("allow_cancel_timer").setUserData(this)
    showStep()
  }

  function showStep()
  {
    if (!ownerWeak)
      return finalizeTutorial()

    local stepData = config[stepIdx]
    local actionType = ::getTblValue("actionType", stepData, tutorAction.ANY_CLICK)
    local params = {
      onClick = (actionType == tutorAction.ANY_CLICK)? "onNext" : null
    }

    local msgObj = scene.findObject("msg_text")
    local text = ::getTblValue("text", stepData, "")

    local bottomText = ::getTblValue("bottomText", stepData, "")
    if (text != "" && bottomText != "")
      text += "\n\n" + bottomText

    msgObj.setValue(text)

    local needAccessKey = (actionType == tutorAction.OBJ_CLICK ||
                           actionType == tutorAction.FIRST_OBJ_CLICK)
    local shortcut = ::getTblValue("shortcut", stepData, needAccessKey ? ::GAMEPAD_ENTER_SHORTCUT : null)
    local blocksList = []
    local objList = stepData?.obj ?? []
    if (!::u.isArray(objList))
      objList = [objList]

    foreach(obj in objList)
    {
      local block = ::guiTutor.getBlockFromObjData(obj, ownerWeak.scene)
      if (!block)
        continue

      if (actionType != tutorAction.WAIT_ONLY)
      {
        block.onClick <- (actionType != tutorAction.FIRST_OBJ_CLICK) ? "onNext" : null
        if (shortcut)
          block.accessKey <- shortcut.accessKey
      }
      blocksList.append(block)
    }

    local needArrow = (stepData?.haveArrow ?? true) && blocksList.len() > 0
    if (needArrow && !blocksList.findvalue(@(b) b?.hasArrow == true))
      blocksList[0].hasArrow = true

    updateObjectsPos(blocksList, needArrow)

    if (needArrow) {
      local mainMsgY = scene.findObject("msg_block").getPosRC()[1]
      local arrowWidth = ::to_pixels("1@tutorArrowSize")
      local arrowHeight = ::to_pixels("3@tutorArrowSize")
      local view = { arrows = [] }

      foreach (block in blocksList)
      {
        if (!block.hasArrow)
          continue

        local isTop = mainMsgY < block.box.c1[1]
        view.arrows.append({
          left     = (block.box.c1[0] + block.box.c2[0] - arrowWidth) / 2
          top      = isTop ? block.box.c1[1] - arrowHeight : block.box.c2[1]
          rotation = isTop ? 0 : 180
        })
      }

      local blk = ::handyman.renderCached("gui/tutorials/tutorArrow", view)
      guiScene.replaceContentFromText(scene.findObject("arrows_container"), blk, blk.len(), this)
    }

    if (actionType == tutorAction.FIRST_OBJ_CLICK && blocksList.len() > 0)
    {
      blocksList[0].onClick = "onNext"
      blocksList.reverse()
    }
    ::guiTutor.createHighlight(scene.findObject("dark_screen"), blocksList, this, params)

    showSceneBtn("dummy_console_next", actionType == tutorAction.ANY_CLICK)

    local nextActionShortcut = ::getTblValue("nextActionShortcut", stepData)
    if (nextActionShortcut && ::show_console_buttons)
      nextActionShortcut = "PRESS_TO_CONTINUE"

    local markup = ""
    if (nextActionShortcut)
    {
      markup += ::show_console_buttons? ::Input.Button(shortcut.dev[0], shortcut.btn[0]).getMarkup() : ""
      markup += "activeText {text:t='{text}'; caption:t='yes'; margin-left:t='1@framePadding'}".subst({ text = "#" + nextActionShortcut })
    }

    local nextShObj = scene.findObject("next_step_shortcut")
    guiScene.replaceContentFromText(nextShObj, markup, markup.len(), ownerWeak)

    local waitTime = ::getTblValue("waitTime", stepData, actionType == tutorAction.WAIT_ONLY? 1 : -1)
    if (waitTime > 0)
      ::Timer(scene, waitTime, (@(stepIdx) function() {timerNext(stepIdx)})(stepIdx), this)

    stepTimeoutSec = TITOR_STEP_TIMEOUT_SEC
  }

  function updateObjectsPos(blocks, needArrow = true)
  {
    guiScene.applyPendingChanges(false)

    local boxList = []
    foreach(b in blocks)
      boxList.append(b.box)

    if (needArrow)
    {
      local incSize = ::to_pixels("3@tutorArrowSize") // arrow height
      foreach(b in blocks)
        if (b.hasArrow)
          boxList.append(b.box.cloneBox(incSize)) // inc targetBox for correct place message
    }

    local mainMsgObj = scene.findObject("msg_block")
    local minPos = guiScene.calcString("1@bh", null)
    local maxPos = guiScene.calcString("sh -1@bh", null)
    local newPos = LinesGenerator.findGoodPos(mainMsgObj, 1, boxList, minPos, maxPos)
    if (newPos != null)
      mainMsgObj.top = newPos.tostring()
  }

  function timerNext(timerStep)
  {
    if (timerStep != stepIdx)
      return

    onNext()
  }

  function onNext()
  {
    if (stepIdx >= config.len() - 1 || !ownerWeak)
      return finalizeTutorial()

    canceled = false
    checkCb()
    canceled = true
    stepIdx++
    showStep()
  }

  function consoleNext()
  {
    onNext()
  }

  function checkCb()
  {
    if (canceled)
      return

    local stepData = ::getTblValue(stepIdx, config)
    local cb = ::getTblValue("cb", stepData)
    if (!cb)
      return

    if (::u.isCallback(cb) || ::getTblValue("keepEnv", stepData, false))
      cb()
    else
      ::call_for_handler(ownerWeak, cb)
  }

  function afterModalDestroy()
  {
    checkCb()
  }

  function finalizeTutorial()
  {
    canceled = false
    goBack()
  }

  function onAllowCancelTimer(obj, dt)
  {
    if (isTutorialCancelable)
      return
    stepTimeoutSec -= dt
    if (stepTimeoutSec > 0)
      return
    isTutorialCancelable = true
    showSceneBtn("close_btn", isTutorialCancelable)
  }
}
