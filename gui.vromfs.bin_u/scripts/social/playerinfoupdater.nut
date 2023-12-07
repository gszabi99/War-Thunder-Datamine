//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerPersistentData, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { write_number } = require("%xboxLib/impl/stats.nut")
let { set_presence } = require("%xboxLib/impl/presence.nut")
let { isLoggedIn } = require("%xboxLib/loginState.nut")

let playerInfoUpdater = {
  [PERSISTENT_DATA_PARAMS] = ["lastSendedData"]

  lastSendedData = {}

  xboxUserInfoStats = {
    Vehicles = function(myStats) {
      local total = 0
      foreach (_country, data in myStats?.countryStats ?? {})
        total += data?.unitsCount ?? 0
      return total
    },
    Medals = function(myStats) {
      local total = 0
      foreach (_country, data in myStats?.countryStats ?? {})
        total += data?.medalsCount ?? 0
      return total
    },
    Level = @(myStats) myStats?.rank ?? 0
  }

  function sendValue(id, value) {
    if (this.lastSendedData?[id] == value)
      return

    this.lastSendedData[id] <- value
    write_number(id, value, null)
  }

  function updateStatistics() {
    if (!is_platform_xbox)
      return

    let myStats = ::my_stats.getStats()

    foreach (name, func in this.xboxUserInfoStats) {
      let value = func(myStats)
      this.sendValue(name, value)
    }
  }

  function updatePresence(presence) {
    if (!is_platform_xbox || !presence)
      return

    if (!isLoggedIn.value)
      return

    if (presence == ::g_contact_presence.UNKNOWN
      || (this.lastSendedData?.presence ?? ::g_contact_presence.UNKNOWN) == presence)
      return

    this.lastSendedData.presence <- presence
    set_presence(presence.presenceName, null)
  }

  function onEventMyStatsUpdated(_p) {
    this.updateStatistics()
  }

  function onEventLoginComplete(_p) {
    this.updatePresence(::g_contact_presence.ONLINE)
  }

  function onEventSignOut(_p) {
    this.updatePresence(::g_contact_presence.OFFLINE)
  }

  function onEventMyPresenceChanged(presence) {
    if (presence?.status?.in_game)
      return this.updatePresence(::g_contact_presence.IN_GAME)

    if (presence?.status?.in_queue)
      return this.updatePresence(::g_contact_presence.IN_QUEUE)

    return this.updatePresence(::g_contact_presence.ONLINE)
  }
}

registerPersistentData("PlayerInfoUpdater", playerInfoUpdater, playerInfoUpdater[PERSISTENT_DATA_PARAMS])
subscribe_handler(playerInfoUpdater, ::g_listener_priority.DEFAULT_HANDLER)

return playerInfoUpdater
