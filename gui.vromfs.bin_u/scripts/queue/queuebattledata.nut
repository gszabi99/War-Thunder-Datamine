//checked for explicitness
#no-root-fallback
#explicit-this

from "%scripts/dagui_library.nut" import *
let { setTimeout } = require("dagor.workcycle")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")
let { addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { charRequestJwt } = require("%scripts/tasker.nut")
let { register_command } = require("console")
let { decodeJwtAndHandleErrors } = require("%scripts/profileJwt/decodeJwt.nut")
let DataBlock = require("DataBlock")

const SILENT_ACTUALIZE_DELAY = 60

let lastResult = persist("lastResult", @() Watched(null))
let successResult = persist("lastSuccessResult", @() Watched(null))
let needRefresh = persist("needRefresh", @() Watched(false))
let isInRequestQueueData = persist("isInRequestQueueData", @() Watched(false))
let isQueueDataActual = Computed(@() !needRefresh.value && successResult.value != null && !isInRequestQueueData.value)
let needActualize = Computed(@() !isQueueDataActual.value && isProfileReceived.value)
let needDebugNewResult = Watched(false)

addListenersWithoutEnv({
  ProfileReceived            = @(_) needRefresh(true)
  CrewChanged                = @(_) needRefresh(true)
  SignOut                    = @(_) successResult(null)
}, CONFIG_VALIDATION)

let function printQueueDataResult() {
  if (successResult.value == null) {
    log("[queueProfileJwt] Last successResult is null")
    return
  }
  log("[queueProfileJwt] Last successResult:")
  debugTableData(decodeJwtAndHandleErrors(successResult.value))
}

let function actualizeQueueData(cb = null) {
  isInRequestQueueData(true)
  needRefresh(false)
  let function fullSuccessCb(res) {
    isInRequestQueueData(false)
    lastResult(res)
    successResult(res)
    cb?(res)
  }
  let function fullErrorCb(res) {
    isInRequestQueueData(false)
    lastResult(res)
    cb?(successResult.value)
  }
  let requestBlk = DataBlock()
  requestBlk.infoTypes = "battleStartInfo;clanInfo;penaltyInfo;playerInfo"
  charRequestJwt("cln_get_short_user_info_jwt", requestBlk,
    { showErrorMessageBox = false }, fullSuccessCb, fullErrorCb)
}

local timerId = -1
let function delayedActualize() {
  if (needActualize.value && timerId == -1)
    timerId = setTimeout(SILENT_ACTUALIZE_DELAY,
      function() {
        if (needActualize.value)
          actualizeQueueData()
      })
}
delayedActualize()
needActualize.subscribe(function(v) {
  if (!v)
    return
  if (successResult.value == null)
    setTimeout(0.1, actualizeQueueData)
  else
    delayedActualize()
})

successResult.subscribe(function(_) {
  if (!needDebugNewResult.value)
    return
  needDebugNewResult(false)
  printQueueDataResult()
})

register_command(function() {
  if (needActualize.value) {
    needDebugNewResult(true)
    actualizeQueueData()
    console_print("Actualize queue data")
  } else
    printQueueDataResult()
}, "meta.debugJwtQueueData")

return {
  queueProfileJwt = Computed(@() successResult.value)
  isQueueDataActual
  actualizeQueueData
}