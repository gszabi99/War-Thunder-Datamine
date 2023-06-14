//checked for plus_string
from "%scripts/dagui_library.nut" import *


const PREVIEW_WW_OPERATION_REQUEST_TIME_OUT = 10000 //ms
let { get_time_msec } = require("dagor.time")

local WwOperationPreloader = class {
  lastRequestTimeMsec = -PREVIEW_WW_OPERATION_REQUEST_TIME_OUT
  isRequestInProgress = false
  curTask = null

  function loadPreview(operationId, accessCb, hasProgressBox = false) {
    this.curTask = {
      operationId = operationId.tointeger()
      accessCb = accessCb
      hasProgressBox = hasProgressBox
    }

    this.requestPreview()
  }

  function requestPreview() {
    if (this.isRequestInProgress && !this.isRequestTimedOut())
      return

    if (!this.curTask)
      return

    this.isRequestInProgress = true
    this.lastRequestTimeMsec = get_time_msec()

    ::ww_stop_preview()

    let operationId = this.curTask.operationId
    let taskId = ::ww_preview_operation(operationId)
    let accessCb = Callback(
      function() {
        this.isRequestInProgress = false
        if (operationId != this.curTask?.operationId) {
          this.requestPreview()
          return
        }

        ::ww_event("OperationPreviewLoaded")
        if (this.curTask?.accessCb)
          this.curTask.accessCb()
        this.curTask = null
      },
      this)

    let errorCb = Callback(
      function(_res) {
        this.isRequestInProgress = false
        if (operationId != this.curTask?.operationId)
          this.requestPreview()
        else
          this.curTask = null
      },
      this)

    let param = {
      showProgressBox = this.curTask.hasProgressBox
    }

    ::g_tasker.addTask(taskId, param, accessCb, errorCb)
  }

  function isRequestTimedOut() {
    return get_time_msec() - this.lastRequestTimeMsec >= PREVIEW_WW_OPERATION_REQUEST_TIME_OUT
  }
}

return WwOperationPreloader()
