//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { charRequestJwtFromServer } = require("chard")
let { format } = require("string")
let { subscribe } = require("eventbus")
let DataBlock = require("DataBlock")
let subscriptions = require_optional("%sqStdLibs/helpers/subscriptions.nut")

if ("g_script_reloader" in getroottable())
  ::g_script_reloader.loadIfExist("%scripts/framework/msgBox.nut")

global enum TASK_CB_TYPE {
  BASIC,
  REQUEST_DATA
}

let PROGRESS_BOX_BUTTONS_DELAY = 30
let taskDataByTaskId = {}
local currentProgressBox = null

let function addTaskData(taskId, taskCbType, onSuccess, onError, showProgressBox, showErrorMessageBox) {
  let taskData = {
    taskId
    taskCbType
    showProgressBox
    showErrorMessageBox
    onSuccess
    onError
  }
  taskDataByTaskId[taskId] <- taskData
  return taskData
}

let function isMsgBoxesAvailable() {
  return "scene_msg_box" in getroottable()
}

let function showTaskProgressBox(text = null, cancelFunc = null, delayedButtons = -1) {
  if (!isMsgBoxesAvailable() || checkObj(currentProgressBox))
    return

  let guiScene = ::get_cur_gui_scene()
  if (guiScene == null)
    return

  if (text == null)
      text = loc("charServer/purchase0")
  if (cancelFunc == null)
      cancelFunc = function() {}
  if (delayedButtons < 0)
    delayedButtons = PROGRESS_BOX_BUTTONS_DELAY
  let progressBoxOptions = {
    waitAnim = true
    delayedButtons = delayedButtons
  }
  currentProgressBox = ::scene_msg_box(
    "tasker_progress_box", guiScene,
    text, [["cancel", cancelFunc]],
    "cancel", progressBoxOptions)
}

let function hideTaskProgressBox() {
  if (!isMsgBoxesAvailable() || !checkObj(currentProgressBox))
    return

  let guiScene = currentProgressBox.getScene()
  guiScene.destroyElement(currentProgressBox)
  if ("broadcastEvent" in getroottable())
    ::broadcastEvent("ModalWndDestroy")
  currentProgressBox = null
}

let function addTask(taskId, taskOptions = null, onSuccess = null, onError = null, taskCbType = TASK_CB_TYPE.BASIC) {
  if (taskId < 0)
    return false

  if (taskId in taskDataByTaskId) {
    assert(false, "Attempt to add tasks with same id.")
    return false
  }

  let showProgressBox = getTblValue("showProgressBox", taskOptions, false)

  // Same as progress box by default.
  let showErrorMessageBox = getTblValue("showErrorMessageBox", taskOptions, showProgressBox)

  addTaskData(taskId, taskCbType, onSuccess, onError, showProgressBox, showErrorMessageBox)

  if (showProgressBox) {
    showTaskProgressBox(
      getTblValue("progressBoxText", taskOptions, null),
      getTblValue("progressBoxCancelFunc", taskOptions, null),
      getTblValue("progressBoxDelayedButtons", taskOptions, -1))
  }

  return true
}

let function charSimpleAction(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null) {
  let taskId = ::char_send_simple_action(requestName, requestBlk)
  addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.BASIC)
  return taskId
}

let function charRequestJson(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null) {
  let taskId = ::char_request_json_from_server(requestName, requestBlk)
  addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.REQUEST_DATA)
  return taskId
}

let function charRequestBlk(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null) {
  let taskId = ::char_request_blk_from_server(requestName, requestBlk)
  addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.REQUEST_DATA)
  return taskId
}

let function charRequestJwt(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null) {
  requestBlk = requestBlk ?? DataBlock()
  let taskId = charRequestJwtFromServer(requestName, requestBlk)
  addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.REQUEST_DATA)
  return taskId
}

let function restoreCharCallback() {
  ::set_char_cb(::g_tasker, ::g_tasker.charCallback)
}

let function getNumBlockingTasks() {
  local result = 0
  foreach (taskData in taskDataByTaskId)
    if (taskData.showProgressBox)
      ++result
  return result
}

let function executeTaskCb(taskId, taskResult, taskCbType = TASK_CB_TYPE.BASIC, data = null) {
  let taskData = getTblValue(taskId, taskDataByTaskId, null)
  if (taskData == null)
    return

  if (taskData.taskCbType != taskCbType) //for taskCbType REQUEST_DATA there is 2 char cb
    return

  taskDataByTaskId.rawdelete(taskId)
  if (getNumBlockingTasks() == 0)
    hideTaskProgressBox()

  if (taskResult == YU2_OK) {
    if (taskData.onSuccess != null)
      if (taskCbType == TASK_CB_TYPE.REQUEST_DATA)
        taskData.onSuccess(data)
      else
        taskData.onSuccess()
    return
  }

  if (taskData.onError != null) {
    let info = taskData.onError.getfuncinfos()
    if (info.native || info.parameters.len() > 1)
      taskData.onError(taskResult)
    else
      taskData.onError()
  }

  if (taskData.showErrorMessageBox && isMsgBoxesAvailable())
    ::showInfoMsgBox(::getErrorText(taskResult), "char_connecting_error")
}

let function charCallback(taskId, _taskType, taskResult, _taskCbType = TASK_CB_TYPE.BASIC, _data = null) {
  executeTaskCb(taskId, taskResult)
}

let function onCharRequestJsonFromServerComplete(taskId, _requestName, data, result) {
  executeTaskCb(taskId, result, TASK_CB_TYPE.REQUEST_DATA, data)
}

let function onCharRequestBlkFromServerComplete(taskId, _requestName, blk, result) {
  executeTaskCb(taskId, result, TASK_CB_TYPE.REQUEST_DATA, blk)
}

let function onCharRequestJwtFromServerComplete(data) {
  let { taskId, result, jwt = null } = data
  executeTaskCb(taskId, result, TASK_CB_TYPE.REQUEST_DATA, jwt)
}


::g_tasker <- {
  addTask
  charSimpleAction
  charRequestJson
  charRequestBlk
  restoreCharCallback
  charCallback
  onEventScriptsReloaded = @(_) restoreCharCallback()
  onEventLoginStateChanged = @(_) restoreCharCallback()
}

//called from native code
::onCharRequestJsonFromServerComplete <- onCharRequestJsonFromServerComplete //-ident-hides-ident

//called from native code
::onCharRequestBlkFromServerComplete <- onCharRequestBlkFromServerComplete //-ident-hides-ident

subscribe("onCharRequestJwtFromServerComplete", onCharRequestJwtFromServerComplete)

// Why this function is in this module???
::getErrorText <- function getErrorText(result) {
  local text = loc("charServer/updateError/" + result.tostring())
  if (("EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS" in getroottable())
      && ("get_char_extended_error" in getroottable())
      && result == EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS) {
    let notAllowedChars = ::get_char_extended_error()
    text = format(text, notAllowedChars)
  }
  return text
}

restoreCharCallback()

if (subscriptions)
  subscriptions.subscribeHandler(::g_tasker, subscriptions.DEFAULT_HANDLER)

return {
  charRequestJwt
}
