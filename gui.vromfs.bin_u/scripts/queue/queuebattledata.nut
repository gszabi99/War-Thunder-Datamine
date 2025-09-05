
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
let queueProfileJwt = Computed(@() successResultByCountry.get()?[profileCountrySq.get()])
let isQueueDataActual = Computed(@() !needRefresh.get() && queueProfileJwt.get() != null && !isInRequestQueueData.get())
let needActualize = Computed(@() !isQueueDataActual.get() && isProfileReceived.value && !isInBattleState.get())
let needDebugNewResult = Watched(false)
let isDeniedProfileJwtDueToAasLimits = Computed(@() lastResult.get() == EASTE_ERROR_DENIED_DUE_TO_AAS_LIMITS)

profileCountrySq.subscribe(@(_) needRefresh.set(true))

addListenersWithoutEnv({
  ProfileReceived            = @(_) needRefresh.set(true)
  CrewsListInvalidate        = @(_) needRefresh.set(true)
  UnitRepaired               = @(_) needRefresh.set(true)
  SignOut                    = @(_) successResultByCountry.set({})
}, CONFIG_VALIDATION)

function printQueueDataResult() {
  if (queueProfileJwt.get() == null) {
    log($"[queueProfileJwt] SuccessResult for {profileCountrySq.get()} is null")
    return
  }
  log($"[queueProfileJwt] SuccessResult for {profileCountrySq.get()}:")
  debugTableData(decodeJwtAndHandleErrors(queueProfileJwt.get()))
}

function actualizeQueueData(cb = null) {
  isInRequestQueueData.set(true)
  needRefresh.set(false)
  let curCountry = profileCountrySq.get()
  function fullSuccessCb(res) {
    isInRequestQueueData.set(false)
    let { decodError = null } = decodeJwtAndHandleErrors(res)
    if (decodError == null) {
      lastResult.set(res)
      successResultByCountry.mutate(@(v) v[curCountry] <- res)
    }
    else
      res = successResultByCountry.get()?[curCountry]

    cb?(res)
  }
  function fullErrorCb(res) {
    isInRequestQueueData.set(false)
    lastResult.set(res)
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
  if (needActualize.get())
    actualizeQueueData()
}

function delayedActualize() {
  if (needActualize.get())
    resetTimeout(SILENT_ACTUALIZE_DELAY, actualizeQueueDataIfNeed)
}
delayedActualize()
needActualize.subscribe(function(v) {
  if (!v)
    return
  if (queueProfileJwt.get() == null)
    resetTimeout(0.1, actualizeQueueData)
  else
    delayedActualize()
})

queueProfileJwt.subscribe(function(_) {
  if (!needDebugNewResult.get())
    return
  needDebugNewResult.set(false)
  printQueueDataResult()
})

register_command(function() {
  if (needActualize.get()) {
    needDebugNewResult.set(true)
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