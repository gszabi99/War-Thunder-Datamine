from "%scripts/dagui_natives.nut" import char_request_blk_from_server, set_char_cb, char_request_json_from_server, char_send_simple_action
from "%scripts/dagui_library.nut" import *
from "%scripts/utils_sa.nut" import call_for_handler

let { broadcastEvent, addListenersWithoutEnv, DEFAULT_HANDLER } = require("%sqStdLibs/helpers/subscriptions.nut")
let { charRequestJwtFromServer, get_char_extended_error } = require("chard")
let { EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS } = require("chardConst")
let { format } = require("string")
let { eventbus_subscribe } = require("eventbus")
let DataBlock = require("DataBlock")

enum TASK_CB_TYPE {
  BASIC,
  REQUEST_DATA
}

let PROGRESS_BOX_BUTTONS_DELAY = 30
let taskDataByTaskId = {}
local currentProgressBox = null

function addTaskData(taskId, taskCbType, onSuccess, onError, showProgressBox, showErrorMessageBox) {
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

function showTaskProgressBox(text = null, cancelFunc = null, delayedButtons = -1) {
  if (checkObj(currentProgressBox))
    return

  let guiScene = get_cur_gui_scene()
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
  currentProgressBox = scene_msg_box(
    "tasker_progress_box", guiScene,
    text, [["cancel", cancelFunc]],
    "cancel", progressBoxOptions)
}

function hideTaskProgressBox() {
  if (!checkObj(currentProgressBox))
    return

  let guiScene = currentProgressBox.getScene()
  guiScene.destroyElement(currentProgressBox)
  broadcastEvent("ModalWndDestroy")
  currentProgressBox = null
}

function addTask(taskId, taskOptions = null, onSuccess = null, onError = null, taskCbType = TASK_CB_TYPE.BASIC) {
  if (taskId < 0)
    return false

  if (taskId in taskDataByTaskId) {
    assert(false, "Attempt to add tasks with same id.")
    return false
  }

  let showProgressBox = getTblValue("showProgressBox", taskOptions, false)

  
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

function addBgTaskCb(taskId, actionFunc, handler = null) {
  let taskCallback = Callback( function(_result = YU2_OK) {
    call_for_handler(handler, actionFunc)
  }, handler)
  addTask(taskId, null, taskCallback, taskCallback)
}

function charSimpleAction(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null) {
  let taskId = char_send_simple_action(requestName, requestBlk)
  addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.BASIC)
  return taskId
}

function charRequestJson(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null) {
  let taskId = char_request_json_from_server(requestName, requestBlk)
  addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.REQUEST_DATA)
  return taskId
}

function charRequestBlk(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null) {
  let taskId = char_request_blk_from_server(requestName, requestBlk)
  addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.REQUEST_DATA)
  return taskId
}

function charRequestJwt(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null) {
  requestBlk = requestBlk ?? DataBlock()
  let taskId = charRequestJwtFromServer(requestName, requestBlk)
  addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.REQUEST_DATA)
  return taskId
}

function getNumBlockingTasks() {
  local result = 0
  foreach (taskData in taskDataByTaskId)
    if (taskData.showProgressBox)
      ++result
  return result
}

function executeTaskCb(taskId, taskResult, taskCbType = TASK_CB_TYPE.BASIC, data = null) {
  let taskData = getTblValue(taskId, taskDataByTaskId, null)
  if (taskData == null)
    return

  if (taskData.taskCbType != taskCbType) 
    return

  taskDataByTaskId.$rawdelete(taskId)
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

  if (taskData.showErrorMessageBox)
    showInfoMsgBox(::getErrorText(taskResult), "char_connecting_error")
}

function charCallback(taskId, _taskType, taskResult, _taskCbType = TASK_CB_TYPE.BASIC, _data = null) {
  executeTaskCb(taskId, taskResult)
}

function onCharRequestJsonFromServerComplete(taskId, _requestName, data, result) {
  executeTaskCb(taskId, result, TASK_CB_TYPE.REQUEST_DATA, data)
}

function onCharRequestBlkFromServerComplete(taskId, _requestName, blk, result) {
  executeTaskCb(taskId, result, TASK_CB_TYPE.REQUEST_DATA, blk)
}

function onCharRequestJwtFromServerComplete(data) {
  let { taskId, result, jwt = null } = data
  executeTaskCb(taskId, result, TASK_CB_TYPE.REQUEST_DATA, jwt)
}

let taskerCharCb = { charCallback }

function restoreCharCallback() {
  set_char_cb(taskerCharCb, taskerCharCb.charCallback)
}


::onCharRequestJsonFromServerComplete <- onCharRequestJsonFromServerComplete 


::onCharRequestBlkFromServerComplete <- onCharRequestBlkFromServerComplete 

eventbus_subscribe("onCharRequestJwtFromServerComplete", onCharRequestJwtFromServerComplete)


::getErrorText <- function getErrorText(result) {
  local text = loc($"charServer/updateError/{result.tostring()}")
  if (result == EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS) {
    let notAllowedChars = get_char_extended_error()
    text = format(text, notAllowedChars)
  }
  return text
}

restoreCharCallback()

addListenersWithoutEnv({
  LoginStateChanged = @(_) restoreCharCallback()
}, DEFAULT_HANDLER)

return {
  charSimpleAction
  charRequestBlk
  charRequestJson
  charRequestJwt
  TASK_CB_TYPE
  addTask
  addBgTaskCb
  restoreCharCallback
  charCallback
}
