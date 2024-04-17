from "%scripts/dagui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let { resetTimeout, clearTimer, deferOnce } = require("dagor.workcycle")
let { get_charserver_time_sec } = require("chard")
let { getExpireText } = require("%scripts/time.nut")
let { buidPartialTimeStr } = require("%appGlobals/timeLoc.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isDeniedProfileJwtDueToAasLimits } = require("%scripts/queue/queueBattleData.nut")

const SKIPPED_AAS_WARNING_MSG = "skipped_msg/aasWarningMessage"

let antiAddictSystemVariable = mkWatched(persist, "antiAddictSystemVariable", {
  curMin = 0         // current activity level in minutes
  warnMin = 120      // level from which a warning is sent before the fight
  limitMin = 300     // the level at which the game will be forbidden
  nextCanPlayTs = 0  // unix timestamp when it is possible to play, comes only if the possibility to play is forbidden
})

let needCheckShowAasLimitMessage = mkWatched(persist, "needCheckShowAasLimitMessage", false)

let hasMultiplayerLimitByAas = keepref(Computed(function() {
  let { curMin, limitMin, nextCanPlayTs } = antiAddictSystemVariable.get()
  return curMin >= limitMin && nextCanPlayTs > get_charserver_time_sec()
}))

let needShowAasMessageLimit = keepref(Computed(@() isInMenu.get()
  && hasMultiplayerLimitByAas.get() && needCheckShowAasLimitMessage.get()))

function clearCache() {
  antiAddictSystemVariable.mutate(@(v) v.__update({ curMin = 0, nextCanPlayTs = 0 }))
  needCheckShowAasLimitMessage.set(false)
}

function showMultiplayerAvailableMsg() {
  showInfoMsgBox(loc("antiAddictSystem/multiplayerAvailable"), "anti_addict_system_multiplayer_available")
}

function showMultiplayerLimitByAasMsg(onAcceptCb, onCancelCb) {
  needCheckShowAasLimitMessage.set(false)
  let { curMin, nextCanPlayTs } = antiAddictSystemVariable.get()
  let limitSec = nextCanPlayTs - get_charserver_time_sec()
  let messageLocId = isDeniedProfileJwtDueToAasLimits.get() ? "antiAddictSystem/limitExceededMsg"
    : "antiAddictSystem/warningMsgOnlyPlayTime"

  loadHandler(gui_handlers.SkipableMsgBox, {
    parentHandler = {}
    message = loc(messageLocId,
      { playTime = getExpireText(curMin), limitTime = buidPartialTimeStr(limitSec) })
    startBtnText = loc("msgbox/btn_continue")
    ableToStartAndSkip = onAcceptCb != null && !isDeniedProfileJwtDueToAasLimits.get()
    onStartPressed = onAcceptCb
    cancelFunc = onCancelCb
  })
  resetTimeout(limitSec, showMultiplayerAvailableMsg)
}

function markToShowMultiplayerLimitByAasMsg() {
  needCheckShowAasLimitMessage.set(true)
}

function checkShowMultiplayerAasWarningMsg(onAcceptCb, onCancelCb = null) {
  if (hasMultiplayerLimitByAas.get()) {
    showMultiplayerLimitByAasMsg(onAcceptCb, onCancelCb)
    return
  }

  let { curMin, warnMin } = antiAddictSystemVariable.get()
  if (curMin < warnMin) {
    onAcceptCb()
    return
  }

  if (loadLocalAccountSettings(SKIPPED_AAS_WARNING_MSG, false)) {
    onAcceptCb()
    return
  }

  loadHandler(gui_handlers.SkipableMsgBox, {
    parentHandler = {}
    message = loc("antiAddictSystem/warningMsgOnlyPlayTime", { playTime = getExpireText(curMin) })
    startBtnText = loc("msgbox/btn_continue")
    skipFunc = @(value) saveLocalAccountSettings(SKIPPED_AAS_WARNING_MSG, value)
    onStartPressed = onAcceptCb
    cancelFunc = onCancelCb
  })
}

eventbus_subscribe("aasNotification", @(params) antiAddictSystemVariable.mutate(@(v) v.__update(params)))

eventbus_subscribe("on_sign_out", function(_) {
  clearCache()
  clearTimer(showMultiplayerAvailableMsg)
  clearTimer(clearCache)
})

needShowAasMessageLimit.subscribe(@(v) v ? deferOnce(showMultiplayerLimitByAasMsg) : null)

function onAntiAddictSystemVariableChange() {
  let { nextCanPlayTs } = antiAddictSystemVariable.get()
  let limitSec = nextCanPlayTs - get_charserver_time_sec()
  if (limitSec > 0)
    resetTimeout(limitSec, clearCache)
  else
    clearTimer(clearCache)
}

antiAddictSystemVariable.subscribe(@(_v) deferOnce(onAntiAddictSystemVariableChange))

return {
  markToShowMultiplayerLimitByAasMsg
  checkShowMultiplayerAasWarningMsg
}
