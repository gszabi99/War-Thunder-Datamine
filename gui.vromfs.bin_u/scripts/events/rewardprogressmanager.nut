from "%scripts/dagui_library.nut" import *
from "%scripts/events/eventsConsts.nut" import GAME_EVENT_TYPE

let { format } = require("string")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { getUserLogsList } = require("%scripts/userLog/userlogUtils.nut")















let __cache = {}

function fetchRowFromUserlog(event) {
  let userLogs = getUserLogsList({
    show = [
      EULT_SESSION_RESULT
    ]
  })

  foreach (logObj in userLogs) {
    let eventEconomicName = getEventEconomicName(event)
    if (getTblValue("eventId", logObj) != eventEconomicName)
      continue

    let leaderbordRow = logObj?.tournamentResult.newStat
    if (!leaderbordRow)
      return false

    __cache[eventEconomicName] <- leaderbordRow
    return true
  }
}

function requestRewardProgress(event, eventEconomicName, field, callback) {
  
  if (eventEconomicName in __cache && __cache[eventEconomicName])
    return callback(__cache[eventEconomicName]?[field])

  
  if (fetchRowFromUserlog(event))
    return callback(__cache[eventEconomicName]?[field])

  
  let request = events.getMainLbRequest(event)
  request.economicName = eventEconomicName
  if (request.forClans)
    request.tournament_mode = GAME_EVENT_TYPE.TM_ELO_GROUP_DETAIL

  let cache = __cache
  events.requestSelfRow(request, function (selfRow) {
    if (!selfRow.len())
      return callback(null)

    cache[eventEconomicName] <- selfRow[0]
    if (field in selfRow[0])
      callback(selfRow[0][field])
    else {
      let msgToSend = format("Error: no field '%s' in leaderbords for event '%s' , economic name '%s'",
                                 field, event.name, eventEconomicName)
      log(msgToSend)
    }
  })
}

addListenersWithoutEnv({
  function EventBattleEnded(params) {
    let eventId = params?.eventId ?? ""
    let event = events.getEvent(eventId) || events.getEventByEconomicName(eventId) 
    if (event)
      fetchRowFromUserlog(event)
  }
})

return {
  requestRewardProgress
}