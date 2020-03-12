local playerInfoUpdater = {
  [PERSISTENT_DATA_PARAMS] = ["lastSendedData"]

  lastSendedData = {}

  xboxUserInfoStats = {
    Vehicles = function(myStats) {
      local total = 0
      foreach (country, data in myStats?.countryStats ?? {})
        total += data?.unitsCount ?? 0
      return total
    },
    Medals = function(myStats) {
      local total = 0
      foreach (country, data in myStats?.countryStats ?? {})
        total += data?.medalsCount ?? 0
      return total
    },
    Level = @(myStats) myStats?.rank ?? 0
  }

  function sendValue(id, value)
  {
    if (lastSendedData?[id] == value)
      return

    lastSendedData[id] <- value
    ::xbox_set_user_stat(id, value)
  }

  function updateStatistics()
  {
    if (!::is_platform_xboxone)
      return

    local myStats = ::my_stats.getStats()

    foreach (name, func in xboxUserInfoStats)
    {
      local value = func(myStats)
      sendValue(name, value)
    }
  }

  function updatePresence(presence)
  {
    if (!::is_platform_xboxone || !presence)
      return

    if (presence == ::g_contact_presence.UNKNOWN
      || (lastSendedData?.presence ?? ::g_contact_presence.UNKNOWN) == presence)
      return

    lastSendedData.presence <- presence
    ::xbox_set_presence(presence.presenceName)
  }

  function onEventMyStatsUpdated(p)
  {
    updateStatistics()
  }

  function onEventLoginComplete(p)
  {
    updatePresence(::g_contact_presence.ONLINE)
  }

  function onEventSignOut(p)
  {
    updatePresence(::g_contact_presence.OFFLINE)
  }

  function onEventMyPresenceChanged(presence)
  {
    if (presence?.status?.in_game)
      return updatePresence(::g_contact_presence.IN_GAME)

    if (presence?.status?.in_queue)
      return updatePresence(::g_contact_presence.IN_QUEUE)

    return updatePresence(::g_contact_presence.ONLINE)
  }
}

::g_script_reloader.registerPersistentData("PlayerInfoUpdater", playerInfoUpdater, playerInfoUpdater[PERSISTENT_DATA_PARAMS])
::subscribe_handler(playerInfoUpdater, ::g_listener_priority.DEFAULT_HANDLER)

return playerInfoUpdater