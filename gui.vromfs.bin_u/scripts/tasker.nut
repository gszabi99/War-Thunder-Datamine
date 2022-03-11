local subscriptions = require_optional("sqStdLibs/helpers/subscriptions.nut")

if ("g_script_reloader" in ::getroottable())
  ::g_script_reloader.loadIfExist("scripts/framework/msgBox.nut")

global enum TASK_CB_TYPE
{
  BASIC,
  REQUEST_DATA
}

::g_tasker <- {
  PROGRESS_BOX_BUTTONS_DELAY = 30

  taskDataByTaskId = {}
  currentProgressBox = null

  function addTask(taskId, taskOptions = null, onSuccess = null, onError = null, taskCbType = TASK_CB_TYPE.BASIC)
  {
    if (taskId < 0)
      return false

    if (taskId in taskDataByTaskId)
    {
      ::dagor.assertf(false, "Attempt to add tasks with same id.")
      return false
    }

    local showProgressBox = ::getTblValue("showProgressBox", taskOptions, false)

    // Same as progress box by default.
    local showErrorMessageBox = ::getTblValue("showErrorMessageBox", taskOptions, showProgressBox)

    addTaskData(taskId, taskCbType, onSuccess, onError, showProgressBox, showErrorMessageBox)

    if (showProgressBox)
    {
      showTaskProgressBox(
        ::getTblValue("progressBoxText", taskOptions, null),
        ::getTblValue("progressBoxCancelFunc", taskOptions, null),
        ::getTblValue("progressBoxDelayedButtons", taskOptions, -1))
    }

    return true
  }

  function charSimpleAction(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null)
  {
    local taskId = ::char_send_simple_action(requestName, requestBlk)
    addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.BASIC)
    return taskId
  }

  function charRequestJson(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null)
  {
    local taskId = ::char_request_json_from_server(requestName, requestBlk)
    addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.REQUEST_DATA)
    return taskId
  }

  function charRequestBlk(requestName, requestBlk = null, taskOptions = null, onSuccess = null, onError = null)
  {
    local taskId = ::char_request_blk_from_server(requestName, requestBlk)
    addTask(taskId, taskOptions, onSuccess, onError, TASK_CB_TYPE.REQUEST_DATA)
    return taskId
  }

  function addTaskData(taskId, taskCbType, onSuccess, onError, showProgressBox, showErrorMessageBox)
  {
    local taskData = {
      taskId = taskId
      taskCbType = taskCbType
      showProgressBox = showProgressBox
      showErrorMessageBox = showErrorMessageBox
      onSuccess = onSuccess
      onError = onError
    }
    taskDataByTaskId[taskId] <-taskData
    return taskData
  }

  function restoreCharCallback()
  {
    ::set_char_cb(::g_tasker, ::g_tasker.charCallback)
  }

  function charCallback(taskId, taskType, taskResult, taskCbType = TASK_CB_TYPE.BASIC, data = null)
  {
    executeTaskCb(taskId, taskResult)
  }

  function onCharRequestJsonFromServerComplete(taskId, requestName, data, result)
  {
    executeTaskCb(taskId, result, TASK_CB_TYPE.REQUEST_DATA, data)
  }

  function onCharRequestBlkFromServerComplete(taskId, requestName, blk, result)
  {
    executeTaskCb(taskId, result, TASK_CB_TYPE.REQUEST_DATA, blk)
  }

  function executeTaskCb(taskId, taskResult, taskCbType = TASK_CB_TYPE.BASIC, data = null)
  {
    local taskData = ::getTblValue(taskId, taskDataByTaskId, null)
    if (taskData == null)
      return

    if (taskData.taskCbType != taskCbType) //for taskCbType REQUEST_DATA there is 2 char cb
      return

    taskDataByTaskId.rawdelete(taskId)
    if (getNumBlockingTasks() == 0)
      hideTaskProgressBox()

    if (taskResult == ::YU2_OK)
    {
      if (taskData.onSuccess != null)
        if (taskCbType == TASK_CB_TYPE.REQUEST_DATA)
          taskData.onSuccess(data)
        else
          taskData.onSuccess()
      return
    }

    if (taskData.onError != null)
    {
      local info = taskData.onError.getfuncinfos()
      if (info.native || info.parameters.len() > 1)
        taskData.onError(taskResult)
      else
        taskData.onError()
    }

    if (taskData.showErrorMessageBox && isMsgBoxesAvailable())
      ::showInfoMsgBox(getErrorText(taskResult), "char_connecting_error")
  }

  function isMsgBoxesAvailable()
  {
    return "scene_msg_box" in ::getroottable()
  }

  function showTaskProgressBox(text = null, cancelFunc = null, delayedButtons = -1)
  {
    if (!isMsgBoxesAvailable() || ::checkObj(currentProgressBox))
      return

    local guiScene = ::get_cur_gui_scene()
    if (guiScene == null)
      return

    if (text == null)
        text = ::loc("charServer/purchase0")
    if (cancelFunc == null)
        cancelFunc = function() {}
    if (delayedButtons < 0)
      delayedButtons = PROGRESS_BOX_BUTTONS_DELAY
    local progressBoxOptions = {
      waitAnim = true
      delayedButtons = delayedButtons
    }
    currentProgressBox = ::scene_msg_box(
      "tasker_progress_box", guiScene,
      text, [["cancel", cancelFunc]],
      "cancel", progressBoxOptions)
  }

  function hideTaskProgressBox()
  {
    if (!isMsgBoxesAvailable() || !::checkObj(currentProgressBox))
      return

    local guiScene = currentProgressBox.getScene()
    guiScene.destroyElement(currentProgressBox)
    if ("broadcastEvent" in ::getroottable())
      ::broadcastEvent("ModalWndDestroy")
    currentProgressBox = null
  }

  function getNumBlockingTasks()
  {
    local result = 0
    foreach (taskData in taskDataByTaskId)
      if (taskData.showProgressBox)
        ++result
    return result
  }

  function onEventScriptsReloaded(p)
  {
    restoreCharCallback()
  }

  function onEventLoginStateChanged(p)
  {
    restoreCharCallback()
  }

}

//called from code
::onCharRequestJsonFromServerComplete <- function onCharRequestJsonFromServerComplete(taskId, requestName, data, result)
{
  ::g_tasker.onCharRequestJsonFromServerComplete(taskId, requestName, data, result)
}

//called from code
::onCharRequestBlkFromServerComplete <- function onCharRequestBlkFromServerComplete(taskId, requestName, blk, result)
{
  ::g_tasker.onCharRequestBlkFromServerComplete(taskId, requestName, blk, result)
}


::getErrorText <- function getErrorText(result)
{
  local text = ::loc("charServer/updateError/" + result.tostring())
  if (("EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS" in getroottable())
      && ("get_char_extended_error" in getroottable())
      && result == ::EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS)
  {
    local notAllowedChars = ::get_char_extended_error()
    text = ::format(text, notAllowedChars)
  }
  return text
}

::g_tasker.restoreCharCallback()
if (subscriptions)
  subscriptions.subscribeHandler(::g_tasker, subscriptions.DEFAULT_HANDLER)
