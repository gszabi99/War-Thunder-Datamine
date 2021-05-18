local { is_seen_nuclear_event,
        is_seen_main_nuclear_event,
        need_show_after_streak } = ::require_native("hangarEventCommand")
local airRaidWndScene = require("scripts/wndLib/airRaidWnd.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

local newClientVersionEvent = persist("newClientVersionEvent ", @() {
  hasMessage = false
})

local function onNewClientVersion(params) {
  newClientVersionEvent.hasMessage = true
  if (!::is_in_flight())
    ::broadcastEvent("NewClientVersion", params)

  return { result = "ok" }
}

local function checkNuclearEvent(params = {}) {
  local needShowNuclearEventAfterStreak = need_show_after_streak()
  if (needShowNuclearEventAfterStreak) {
    airRaidWndScene({hasVisibleNuclearTimer = false})
    return
  }

  local isSeenMainNuclearEvent = is_seen_main_nuclear_event()
  if (isSeenMainNuclearEvent)
    return

  local isSeenNuclearEvent = is_seen_nuclear_event()
  local isNewClient = ::is_version_equals_or_newer("2.0.0.0")
  local isForceNewClientVersionEvent = isSeenNuclearEvent && isNewClient
  if (!isForceNewClientVersionEvent && !newClientVersionEvent.hasMessage)
    return

  newClientVersionEvent.hasMessage = false
  if (isSeenNuclearEvent && !isNewClient)
    return

  airRaidWndScene({hasVisibleNuclearTimer = params?.showTimer ?? !isNewClient})
}

local function bigQuerryForNuclearEvent() {
  if (!::g_login.isProfileReceived())
    return

  local needSendStatistic = ::load_local_account_settings("sendNuclearStatistic", true)
  if (!needSendStatistic)
    return

  ::add_big_query_record("nuclear_event", ::save_to_json({
    user = ::my_user_id_str,
    seenInOldClient = is_seen_nuclear_event(),
    seenInNewClient = is_seen_main_nuclear_event()}))
  ::save_local_account_settings("sendNuclearStatistic", false)
}

addListenersWithoutEnv({
  ProfileReceived = @(p) bigQuerryForNuclearEvent()
})

::web_rpc.register_handler("new_client_version", onNewClientVersion)

return {
  checkNuclearEvent
}
