//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { get_base_game_version } = require("app")
let { is_seen_nuclear_event, is_seen_main_nuclear_event, need_show_after_streak
} = require("hangarEventCommand")
let airRaidWndScene = require("%scripts/wndLib/airRaidWnd.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { Version } = require("%sqstd/version.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { web_rpc } = require("%scripts/webRPC.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isInFlight } = require("gameplayBinding")
let { userIdStr } = require("%scripts/user/profileStates.nut")

let newClientVersionEvent = persist("newClientVersionEvent ", @() {
  hasMessage = false
})

let function isNewClientFunc() {
  let cur = get_base_game_version()
  return cur == 0 || cur >= Version("2.0.0.0").toint()
}

let function onNewClientVersion(params) {
  newClientVersionEvent.hasMessage = true
  if (!isInFlight())
    broadcastEvent("NewClientVersion", params)

  return { result = "ok" }
}

let function checkNuclearEvent(params = {}) {
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

let function bigQuerryForNuclearEvent() {
  if (!::g_login.isProfileReceived())
    return

  let needSendStatistic = loadLocalAccountSettings("sendNuclearStatistic", true)
  if (!needSendStatistic)
    return

  sendBqEvent("CLIENT_GAMEPLAY_1", "nuclear_event", {
    user = userIdStr.value,
    seenInOldClient = is_seen_nuclear_event(),
    seenInNewClient = is_seen_main_nuclear_event()
  })
  saveLocalAccountSettings("sendNuclearStatistic", false)
}

addListenersWithoutEnv({
  ProfileReceived = @(_p) bigQuerryForNuclearEvent()
})

web_rpc.register_handler("new_client_version", onNewClientVersion)

return {
  checkNuclearEvent
}
