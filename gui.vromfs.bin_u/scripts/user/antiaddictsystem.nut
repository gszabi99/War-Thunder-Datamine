from "%scripts/dagui_library.nut" import *
let { eventbus_subscribe } = require("eventbus")
let { resetTimeout, clearTimer } = require("dagor.workcycle")
let { get_charserver_time_sec } = require("chard")
let { getExpireText } = require("%scripts/time.nut")
let { buidPartialTimeStr } = require("%appGlobals/timeLoc.nut")
let { isInMenu, isInBattleState } = require("%scripts/clientState/clientStates.nut")

let antiAddictSystemVariable = mkWatched(persist, "antiAddictSystemVariable", {
  curMin = 0         // current activity level in minutes
  warnMin = 120      // level from which a warning is sent before the fight
  limitMin = 300     // the level at which the game will be forbidden
  nextCanPlayTs = 0  // unix timestamp when it is possible to play, comes only if the possibility to play is forbidden
})

let isShowAasWarningMessage = mkWatched(persist, "isShowAasWarningMessage", false)
let needCheckShowAasLimitMessage = mkWatched(persist, "needCheckShowAasLimitMessage", false)
let hasBattleForAasMessage = mkWatched(persist, "hasBattleForAasMessage", false)

let hasMultiplayerLimitByAas = keepref(Computed(function() {
  let { curMin, limitMin, nextCanPlayTs } = antiAddictSystemVariable.get()
  return curMin >= limitMin && nextCanPlayTs > get_charserver_time_sec()
}))

let needShowAasMessageLimit = keepref(Computed(@() isInMenu.get()
  && hasMultiplayerLimitByAas.get() && needCheckShowAasLimitMessage.get()))
let needShowAasMessageWarning = keepref(Computed(function() {
  if (!isInMenu.get() || hasMultiplayerLimitByAas.get() || isShowAasWarningMessage.get() || !hasBattleForAasMessage.get())
    return false
  let { curMin, warnMin } = antiAddictSystemVariable.get()
  return curMin >= warnMin
}))

function clearCache() {
  antiAddictSystemVariable.mutate(@(v) v.__update({ curMin = 0, nextCanPlayTs = 0 }))
  isShowAasWarningMessage.set(false)
  needCheckShowAasLimitMessage.set(false)
  hasBattleForAasMessage.set(false)
}

function showMultiplayerAvailableMsg() {
  showInfoMsgBox(loc("antiAddictSystem/multiplayerAvailable"), "anti_addict_system_multiplayer_available")
  clearCache()
}

function showMultiplayerLimitByAasMsg() {
  needCheckShowAasLimitMessage.set(false)
  let { curMin, nextCanPlayTs } = antiAddictSystemVariable.get()
  let limitSec = nextCanPlayTs - get_charserver_time_sec()
  if (isShowAasWarningMessage.get())
    showInfoMsgBox(loc("antiAddictSystem/limitExceededMsg",
        { playTime = getExpireText(curMin), limitTime = buidPartialTimeStr(limitSec) }),
      "anti_addict_system_limit")
  else
    showInfoMsgBox(loc("antiAddictSystem/multiplayerForbiddenMsg",
        { playTime = getExpireText(curMin), limitTime = buidPartialTimeStr(limitSec) }),
      "anti_addict_system_limit")

  resetTimeout(limitSec, showMultiplayerAvailableMsg)
}

function markToShowMultiplayerLimitByAasMsg() {
  needCheckShowAasLimitMessage.set(true)
}

function showAasWarningMsg() {
  isShowAasWarningMessage.set(true)
  let { curMin, limitMin } = antiAddictSystemVariable.get()
  showInfoMsgBox(loc("antiAddictSystem/warningMsg",
      { playTime = getExpireText(curMin), limitAfterTime = getExpireText(limitMin - curMin) }),
    "anti_addict_system_warning")
}

eventbus_subscribe("aasNotification", @(params) antiAddictSystemVariable.mutate(@(v) v.__update(params)))
eventbus_subscribe("on_sign_out", function(_) {
  clearCache()
  clearTimer(showMultiplayerAvailableMsg)
})

needShowAasMessageLimit.subscribe(@(v) v ? showMultiplayerLimitByAasMsg() : null)
needShowAasMessageWarning.subscribe(@(v) v ? showAasWarningMsg() : null)

isInBattleState.subscribe(function(v) {
  if (v)
    hasBattleForAasMessage.set(true)
})

return {
  showMultiplayerLimitByAasMsg
  markToShowMultiplayerLimitByAasMsg
  hasMultiplayerLimitByAas
}
