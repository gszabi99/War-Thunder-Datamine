from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

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

  function sendValue(id, value)
  {
    if (this.lastSendedData?[id] == value)
      return

    this.lastSendedData[id] <- value
    ::xbox_set_user_stat(id, value)
  }

  function updateStatistics()
  {
    if (!is_platform_xbox)
      return

    let myStats = ::my_stats.getStats()

    foreach (name, func in this.xboxUserInfoStats)
    {
      let value = func(myStats)
      this.sendValue(name, value)
    }
  }

  function updatePresence(presence)
  {
    if (!is_platform_xbox || !presence)
      return

    if (presence == ::g_contact_presence.UNKNOWN
      || (this.lastSendedData?.presence ?? ::g_contact_presence.UNKNOWN) == presence)
      return

    this.lastSendedData.presence <- presence
    ::xbox_set_presence(presence.presenceName)
  }

  function onEventMyStatsUpdated(_p)
  {
    this.updateStatistics()
  }

  function onEventLoginComplete(_p)
  {
    this.updatePresence(::g_contact_presence.ONLINE)
  }

  function onEventSignOut(_p)
  {
    this.updatePresence(::g_contact_presence.OFFLINE)
  }

  function onEventMyPresenceChanged(presence)
  {
    if (presence?.status?.in_game)
      return this.updatePresence(::g_contact_presence.IN_GAME)

    if (presence?.status?.in_queue)
      return this.updatePresence(::g_contact_presence.IN_QUEUE)

    return this.updatePresence(::g_contact_presence.ONLINE)
  }
}

::g_script_reloader.registerPersistentData("PlayerInfoUpdater", playerInfoUpdater, playerInfoUpdater[PERSISTENT_DATA_PARAMS])
::subscribe_handler(playerInfoUpdater, ::g_listener_priority.DEFAULT_HANDLER)

return playerInfoUpdater
