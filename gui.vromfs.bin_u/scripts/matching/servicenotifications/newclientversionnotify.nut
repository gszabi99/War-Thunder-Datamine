local { is_seen_nuclear_event, is_seen_main_nuclear_event } = ::require_native("hangarEventCommand")
local airRaidWndScene = require("scripts/wndLib/airRaidWnd.nut")

local newClientVersionEvent = persist("newClientVersionEvent ", @() {
  hasMessage = false
})

local function onNewClientVersion(params) {
  newClientVersionEvent.hasMessage = true
  if (!::is_in_flight())
    ::broadcastEvent("NewClientVersion", params)

  return { result = "ok" }
}

local function checkNewClientVersionEvent(params = {}) {
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

::web_rpc.register_handler("new_client_version", onNewClientVersion)

return {
  checkNewClientVersionEvent
}
