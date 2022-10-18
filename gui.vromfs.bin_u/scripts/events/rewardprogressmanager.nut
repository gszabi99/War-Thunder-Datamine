from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
/**
 * Caches data from leaderboard to provide always
 * actual values of reward progress.
 *
 * Usage:
 * Just call requestProgress function and it will provide actual value
 * requestProgress(event, field, callback, context = null)
 *   @event    - tournament event
 *   @eventEconomicName =event economic name for request season leaderboard
 *   @field    - name of leaderboard field you want to get
 *   @callback - callback function, which receives
 *               a value as an argument (null if there is no value)
 */
::g_reward_progress_manager <- {
  __cache = {}

  function requestProgress(event, eventEconomicName, field, callback)
  {
    //Try to get from cache
    if (eventEconomicName in __cache && __cache[eventEconomicName])
      return callback(__cache[eventEconomicName]?[field])

    //Try to get from userlog
    if (fetchRowFromUserlog(event))
      return callback(__cache[eventEconomicName]?[field])

    //Try to get from leaderbords
    let request = ::events.getMainLbRequest(event)
    request.economicName = eventEconomicName
    if (request.forClans)
      request.tournament_mode = GAME_EVENT_TYPE.TM_ELO_GROUP_DETAIL

    let cache = __cache
    ::events.requestSelfRow(request, function (selfRow) {
      if (!selfRow.len())
        return callback(null)

      cache[eventEconomicName] <- selfRow[0]
      if (field in selfRow[0])
        callback(selfRow[0][field])
      else
      {
        let msgToSend = format("Error: no field '%s' in leaderbords for event '%s' , economic name '%s'",
                                   field, event.name, eventEconomicName)
        log(msgToSend)
      }
    })
  }

  function onEventEventBattleEnded(params)
  {
    let eventId = params?.eventId ?? ""
    let event = ::events.getEvent(eventId) || ::events.getEventByEconomicName(eventId)// if event name difference of its shared economic name
    if (event)
      fetchRowFromUserlog(event)
  }

  function fetchRowFromUserlog(event)
  {
    let userLogs = ::getUserLogsList({
      show = [
        EULT_SESSION_RESULT
      ]
    })

    foreach (logObj in userLogs)
    {
      let eventEconomicName = ::events.getEventEconomicName(event)
      if (getTblValue("eventId", logObj) != eventEconomicName)
        continue

      let leaderbordRow = logObj?.tournamentResult?.newStat
      if (!leaderbordRow)
        return false

      __cache[eventEconomicName] <- leaderbordRow
      return true
    }
  }
}

::add_event_listener("EventBattleEnded", ::g_reward_progress_manager.onEventEventBattleEnded, ::g_reward_progress_manager)
