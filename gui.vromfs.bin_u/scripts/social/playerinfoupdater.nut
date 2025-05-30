from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { write_number } = require("%gdkLib/impl/stats.nut")
let { set_presence } = require("%gdkLib/impl/presence.nut")
let { is_any_user_active } = require("%gdkLib/impl/user.nut")
let { getStats } = require("%scripts/myStats.nut")
let { contactPresence } = require("%scripts/contacts/contactPresence.nut")

let lastSendedData =  persist("lastSendedData", @() {})

let playerInfoUpdater = freeze({
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
    if (lastSendedData?[id] == value)
      return

    lastSendedData[id] <- value
    write_number(id, value, null)
  }

  function updateStatistics() {
    if (!is_platform_xbox)
      return

    let myStats = getStats()

    foreach (name, func in this.xboxUserInfoStats) {
      let value = func(myStats)
      this.sendValue(name, value)
    }
  }

  function updatePresence(presence) {
    if (!is_platform_xbox || !presence)
      return

    if (!is_any_user_active())
      return

    if (presence == contactPresence.UNKNOWN
      || (lastSendedData?.presence ?? contactPresence.UNKNOWN) == presence)
      return

    lastSendedData.presence <- presence
    set_presence(presence.presenceName, null)
  }

  function onEventMyStatsUpdated(_p) {
    this.updateStatistics()
  }

  function onEventLoginComplete(_p) {
    this.updatePresence(contactPresence.ONLINE)
  }

  function onEventSignOut(_p) {
    this.updatePresence(contactPresence.OFFLINE)
  }

  function onEventMyPresenceChanged(presence) {
    if (presence?.status.in_game)
      return this.updatePresence(contactPresence.IN_GAME)

    if (presence?.status.in_queue)
      return this.updatePresence(contactPresence.IN_QUEUE)

    return this.updatePresence(contactPresence.ONLINE)
  }
})

subscribe_handler(playerInfoUpdater, g_listener_priority.DEFAULT_HANDLER)

return playerInfoUpdater
