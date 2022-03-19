const PREVIEW_WW_OPERATION_REQUEST_TIME_OUT = 10000 //ms

local WwOperationPreloader = class
{
  lastRequestTimeMsec = -PREVIEW_WW_OPERATION_REQUEST_TIME_OUT
  isRequestInProgress = false
  curTask = null

  function loadPreview(operationId, accessCb, hasProgressBox = false)
  {
    curTask = {
      operationId = operationId.tointeger()
      accessCb = accessCb
      hasProgressBox = hasProgressBox
    }

    requestPreview()
  }

  function requestPreview()
  {
    if (isRequestInProgress && !isRequestTimedOut())
      return

    if (!curTask)
      return

    isRequestInProgress = true
    lastRequestTimeMsec = ::dagor.getCurTime()

    ::ww_stop_preview()

    local operationId = curTask.operationId
    local taskId = ::ww_preview_operation(operationId)
    local accessCb = ::Callback(
      function() {
        isRequestInProgress = false
        if (operationId != curTask?.operationId)
        {
          requestPreview()
          return
        }

        ::ww_event("OperationPreviewLoaded")
        if (curTask?.accessCb)
          curTask.accessCb()
        curTask = null
      },
      this)

    local errorCb = ::Callback(
      function(res) {
        isRequestInProgress = false
        if (operationId != curTask?.operationId)
          requestPreview()
        else
          curTask = null
      },
      this)

    local param = {
      showProgressBox = curTask.hasProgressBox
    }

    ::g_tasker.addTask(taskId, param, accessCb, errorCb)
  }

  function isRequestTimedOut()
  {
    return ::dagor.getCurTime() - lastRequestTimeMsec >= PREVIEW_WW_OPERATION_REQUEST_TIME_OUT
  }
}

return WwOperationPreloader()
