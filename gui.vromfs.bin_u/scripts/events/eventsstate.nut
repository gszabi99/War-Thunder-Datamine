from "guiMission" import get_meta_mission_info_by_name
from "types" import String
from "%scripts/dagui_library.nut" import *
from "%scripts/events/eventsConsts.nut" import EVENT_TYPE

let { g_difficulty } = require("%scripts/difficulty.nut")
let { isEventMatchesType, isEventRandomBattles, getEventEconomicName } = require("%scripts/events/eventInfo.nut")
let { loadLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")








let gameEvents = {}
local eventsLoaded = false

let isEventsLoaded = @() eventsLoaded
function setEventsLoaded(v) { eventsLoaded = v }

let getEvent = @(eventId) gameEvents?[eventId]

function getEventByEconomicName(economicName) {
  foreach (event in gameEvents)
    if (getEventEconomicName(event) == economicName)
      return event
  return null
}

function getEventsList(typeMask = EVENT_TYPE.ANY_BASE_EVENTS, testFunc = function (_event) { return true }) {
  let result = []
  foreach (event in gameEvents)
    if (isEventMatchesType(event, typeMask) && testFunc(event))
      result.append(event.name)
  return result
}

function getLastPlayedEvent() {
  let eventData = loadLocalByAccount("lastPlayedEvent", null)
  if (eventData == null)
    return null
  let event = getEvent(eventData?.eventName)
  if (event != null)
    return event
  return getEventByEconomicName(eventData?.economicName)
}

function getEventMission(eventId, shouldReturnFirst = false) {
  local eventMissionName = ""
  let event = getEvent(eventId)
  if (event == null)
    return eventMissionName

  let list = event.mission_decl.missions_list
  
  
  
  if (list.len() == 1 || shouldReturnFirst)
    eventMissionName = list?.keys()[0] ?? list?[0] ?? ""

  
  if (!(eventMissionName instanceof String)) {
    logerr($"Wrong format of eventMissionName parameter for event with eventId {eventId}: {eventMissionName}")
    eventMissionName = ""
  }

  return eventMissionName
}

let isGameTypeOfEvent = @(event, gameTypeName)
  !!event && !!get_meta_mission_info_by_name(getEventMission(event.name))?[gameTypeName]

let isCustomGameMode = @(mGameMode) mGameMode?.forCustomLobby ?? false
let isEventMultiSlotEnabled = @(event) event?.multiSlot ?? false
let isMultiCluster = @(event) event?.multiCluster ?? false
let needRankInfoInQueue = @(event) event?.balancerMode == "mrank"

function isEventRandomBattlesById(eventId) {
  let event = getEvent(eventId)
  return event != null && isEventRandomBattles(event)
}

let getEventDifficulty = @(event) g_difficulty.getDifficultyByMatchingName(event?.difficulty ?? "arcade")
let getEventDiffCode = @(event) getEventDifficulty(event).diffCode

return {
  gameEvents
  isEventsLoaded
  setEventsLoaded

  getEvent
  getEventByEconomicName
  getEventsList
  getLastPlayedEvent
  getEventMission
  isGameTypeOfEvent
  isCustomGameMode
  isEventMultiSlotEnabled
  isMultiCluster
  needRankInfoInQueue
  isEventRandomBattlesById
  getEventDifficulty
  getEventDiffCode
}
