from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

const PREVIEW_WW_OPERATION_REQUEST_TIME_OUT = 10000 //ms
let { get_time_msec } = require("dagor.time")

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
    lastRequestTimeMsec = get_time_msec()

    ::ww_stop_preview()

    let operationId = curTask.operationId
    let taskId = ::ww_preview_operation(operationId)
    let accessCb = Callback(
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

    let errorCb = Callback(
      function(_res) {
        isRequestInProgress = false
        if (operationId != curTask?.operationId)
          requestPreview()
        else
          curTask = null
      },
      this)

    let param = {
      showProgressBox = curTask.hasProgressBox
    }

    ::g_tasker.addTask(taskId, param, accessCb, errorCb)
  }

  function isRequestTimedOut()
  {
    return get_time_msec() - lastRequestTimeMsec >= PREVIEW_WW_OPERATION_REQUEST_TIME_OUT
  }
}

return WwOperationPreloader()
