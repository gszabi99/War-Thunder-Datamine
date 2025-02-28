
from "%scripts/dagui_library.nut" import *
let { resetTimeout } = require("dagor.workcycle")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { addListenersWithoutEnv, CONFIG_VALIDATION } = require("%sqStdLibs/helpers/subscriptions.nut")
let { charRequestJwt } = require("%scripts/tasker.nut")
let { register_command } = require("console")
let { decodeJwtAndHandleErrors } = require("%scripts/profileJwt/decodeJwt.nut")
let DataBlock = require("DataBlock")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { EASTE_ERROR_DENIED_DUE_TO_AAS_LIMITS } = require("chardConst")

const SILENT_ACTUALIZE_DELAY = 60

let lastResult = mkWatched(persist, "lastResult", null)
let successResultByCountry = mkWatched(persist, "lastSuccessResult", {})
let needRefresh = mkWatched(persist, "needRefresh", false)
let isInRequestQueueData = mkWatched(persist, "isInRequestQueueData", false)
let queueProfileJwt = Computed(@() successResultByCountry.value?[profileCountrySq.value])
let isQueueDataActual = Computed(@() !needRefresh.value && queueProfileJwt.value != null && !isInRequestQueueData.value)
let needActualize = Computed(@() !isQueueDataActual.value && isProfileReceived.value && !isInBattleState.value)
let needDebugNewResult = Watched(false)
let isDeniedProfileJwtDueToAasLimits = Computed(@() lastResult.get() == EASTE_ERROR_DENIED_DUE_TO_AAS_LIMITS)

profileCountrySq.subscribe(@(_) needRefresh(true))

addListenersWithoutEnv({
  ProfileReceived            = @(_) needRefresh(true)
  CrewsListInvalidate        = @(_) needRefresh(true)
  UnitRepaired               = @(_) needRefresh(true)
  SignOut                    = @(_) successResultByCountry({})
}, CONFIG_VALIDATION)

function printQueueDataResult() {
  if (queueProfileJwt.value == null) {
    log($"[queueProfileJwt] SuccessResult for {profileCountrySq.value} is null")
    return
  }
  log($"[queueProfileJwt] SuccessResult for {profileCountrySq.value}:")
  debugTableData(decodeJwtAndHandleErrors(queueProfileJwt.value))
}

function actualizeQueueData(cb = null) {
  isInRequestQueueData(true)
  needRefresh(false)
  let curCountry = profileCountrySq.value
  function fullSuccessCb(res) {
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
  function fullErrorCb(res) {
    isInRequestQueueData(false)
    lastResult(res)
    cb?(res)
  }
  let requestBlk = DataBlock()
  requestBlk.infoTypes = "battleStartInfo;clanInfo;penaltyInfo;playerInfo"
  requestBlk.country = curCountry
  requestBlk.jwtCompressionType = "Zstd"
  requestBlk.jwtCompressionLevel = 5
  charRequestJwt("cln_get_short_user_info_jwt", requestBlk,
    { showErrorMessageBox = false }, fullSuccessCb, fullErrorCb)
}

function actualizeQueueDataIfNeed() {
  if (needActualize.value)
    actualizeQueueData()
}

function delayedActualize() {
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
  isDeniedProfileJwtDueToAasLimits
}