//checked for plus_string

from "%scripts/dagui_library.nut" import *
let { resetTimeout } = require("dagor.workcycle")
let { isProfileReceived } = require("%scripts/login/loginStates.nut")
let { addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { charRequestJwt } = require("%scripts/tasker.nut")
let { register_command } = require("console")
let { decodeJwtAndHandleErrors } = require("%scripts/profileJwt/decodeJwt.nut")
let DataBlock = require("DataBlock")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")

const SILENT_ACTUALIZE_DELAY = 60

let lastResult = persist("lastResult", @() Watched(null))
let successResultByCountry = persist("lastSuccessResult", @() Watched({}))
let needRefresh = persist("needRefresh", @() Watched(false))
let isInRequestQueueData = persist("isInRequestQueueData", @() Watched(false))
let queueProfileJwt = Computed(@() successResultByCountry.value?[profileCountrySq.value])
let isQueueDataActual = Computed(@() !needRefresh.value && queueProfileJwt.value != null && !isInRequestQueueData.value)
let needActualize = Computed(@() !isQueueDataActual.value && isProfileReceived.value && !isInBattleState.value)
let needDebugNewResult = Watched(false)

profileCountrySq.subscribe(@(_) needRefresh(true))

addListenersWithoutEnv({
  ProfileReceived            = @(_) needRefresh(true)
  CrewsListInvalidate        = @(_) needRefresh(true)
  SignOut                    = @(_) successResultByCountry({})
}, CONFIG_VALIDATION)

let function printQueueDataResult() {
  if (queueProfileJwt.value == null) {
    log($"[queueProfileJwt] SuccessResult for {profileCountrySq.value} is null")
    return
  }
  log($"[queueProfileJwt] SuccessResult for {profileCountrySq.value}:")
  debugTableData(decodeJwtAndHandleErrors(queueProfileJwt.value))
}

let function actualizeQueueData(cb = null) {
  isInRequestQueueData(true)
  needRefresh(false)
  let curCountry = profileCountrySq.value
  let function fullSuccessCb(res) {
    isInRequestQueueData(false)
    let { decodError = null } = decodeJwtAndHandleErrors(res)
    if (decodError == null) {
      lastResult(res)
      successResultByCountry.mutate(@(v) v[curCountry] <- res)
    }
    else
      res = successResultByCountry.value?[curCountry]

    cb?(res)
  }
  let function fullErrorCb(res) {
    isInRequestQueueData(false)
    lastResult(res)
    cb?(successResultByCountry.value?[curCountry])
  }
  let requestBlk = DataBlock()
  requestBlk.infoTypes = "battleStartInfo;clanInfo;penaltyInfo;playerInfo"
  requestBlk.country = curCountry
  requestBlk.jwtCompressionType = "Zstd"
  requestBlk.jwtCompressionLevel = 5
  charRequestJwt("cln_get_short_user_info_jwt", requestBlk,
    { showErrorMessageBox = false }, fullSuccessCb, fullErrorCb)
}

let function actualizeQueueDataIfNeed() {
  if (needActualize.value)
    actualizeQueueData()
}

let function delayedActualize() {
  if (needActualize.value)
    resetTimeout(SILENT_ACTUALIZE_DELAY, actualizeQueueDataIfNeed)
}
delayedActualize()
needActualize.subscribe(function(v) {
  if (!v)
    return
  if (queueProfileJwt.value == null)
    resetTimeout(0.1, actualizeQueueData)
  else
    delayedActualize()
})

queueProfileJwt.subscribe(function(_) {
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
  }
  else
    printQueueDataResult()
}, "meta.debugJwtQueueData")

return {
  queueProfileJwt
  needActualizeQueueData = needActualize
  actualizeQueueData
}