import "%scripts/wndLib/airRaidWnd.nut" as airRaidWndScene
from "%scripts/bqQueue/bqQueue.nut" import sendBqEvent
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/user/profileStates.nut" import userIdStr
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "hangarEventCommand" import is_seen_nuclear_event, is_seen_main_nuclear_event, need_show_after_streak
from "gameplayBinding" import isInFlight
from "%scripts/dagui_library.nut" import *
from "app" import get_base_game_version
from "%scripts/webRPC.nut" import webRpcRegister

let { Version } = require("%sqstd/version.nut")

let newClientVersionEvent = mkHardPersist("matching.serviceNotifications.nuclearEventHandler")("newClientVersionEvent", {
  hasMessage = false
})

function isNewClientFunc() {
  let cur = get_base_game_version()
  return cur == 0 || cur >= Version("2.0.0.0").toint()
}

function onNewClientVersion(params) {
  newClientVersionEvent.hasMessage = true
  if (!isInFlight())
    broadcastEvent("NewClientVersion", params)

  return { result = "ok" }
}

function checkNuclearEvent(params = {}) {
  let needShowNuclearEventAfterStreak = need_show_after_streak()
  if (needShowNuclearEventAfterStreak) {
    airRaidWndScene({ hasVisibleNuclearTimer = false })
    return
  }

  let isSeenMainNuclearEvent = is_seen_main_nuclear_event()
  if (isSeenMainNuclearEvent)
    return

  let isSeenNuclearEvent = is_seen_nuclear_event()
  let isNewClient = isNewClientFunc()
  let isForceNewClientVersionEvent = isSeenNuclearEvent && isNewClient
  if (!isForceNewClientVersionEvent && !newClientVersionEvent.hasMessage)
    return

  newClientVersionEvent.hasMessage = false
  if (isSeenNuclearEvent && !isNewClient)
    return

  airRaidWndScene({ hasVisibleNuclearTimer = params?.showTimer ?? !isNewClient })
}

function bigQuerryForNuclearEvent() {
  if (!isProfileReceived.get())
    return

  let needSendStatistic = loadLocalAccountSettings("sendNuclearStatistic", true)
  if (!needSendStatistic)
    return

  sendBqEvent("CLIENT_GAMEPLAY_1", "nuclear_event", {
    user = userIdStr.get(),
    seenInOldClient = is_seen_nuclear_event(),
    seenInNewClient = is_seen_main_nuclear_event()
  })
  saveLocalAccountSettings("sendNuclearStatistic", false)
}

addListenersWithoutEnv({
  ProfileReceived = @(_p) bigQuerryForNuclearEvent()
})

webRpcRegister("new_client_version", onNewClientVersion)

return freeze({
  checkNuclearEvent
})
