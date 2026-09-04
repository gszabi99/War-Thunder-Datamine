from "string" import format
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/events/eventsConsts.nut" import EVENT_TYPE

let { getMatchingServerTime } = require("%scripts/onlineInfo/onlineInfo.nut")
let { getEventDisplayType, eventIdsForMainGameModeList } = require("%scripts/events/eventInfo.nut")
let { getEvent, getEventsList } = require("%scripts/events/eventsState.nut")
let { isUnitTypeAvailable } = require("%scripts/events/eventTeamsInfo.nut")





const standardChapterNames = [
  "basic_events"
  "clan_events"
  "tournaments"
]

function countEventTime(eventTime) {
  return (eventTime - getMatchingServerTime())
}
function getEventStartTime(event) {
  return ("startTime" in event) ? countEventTime(event.startTime) : 0
}
function getEventEndTime(event) {
  return ("endTime" in event) ? countEventTime(event.endTime) : 0
}
function hasEventEndTime(event) {
  return "endTime" in event
}
function isEventEnabled(event) {
  return !!event
    && !event?.disabled && !(event?.invalid ?? false)
    && (!hasEventEndTime(event) || getEventEndTime(event) > 0)
}
function isEventActive(event) {
  return isEventEnabled(event)
}
function isEventEnded(event) {
  return !isEventEnabled(event) && getEventEndTime(event) < 0
}
function isEventEnableOnDebug(event) {
  return (event?.enableOnDebug  ?? false) && !hasEventEndTime(event)
}
let canShowByEnableOnDebug = @(event) isEventEnableOnDebug(event) || hasFeature("ShowDebugEvents")
function isEventDisplayWide(event) {
  return (event?.displayWide ?? false) && !isEventEnableOnDebug(event)
}
function diffCodeCompare(d1, d2) {
  if (d1 > d2)
    return 1
  if (d1 < d2)
    return -1
  return 0
}
function getEventDiffName(eventId) {
  let event = getEvent(eventId)
  if (event == null)
    return ""
  local diffName = ""
  if ("difficulty" in event.mission_decl)
    diffName = event.mission_decl.difficulty

  return diffName
}
function wrapImageName(imageName, isWide) {
  return format("#ui/images/game_modes_tiles/%s?P1", $"{imageName}{isWide ? "_wide" : "_thin"}")
}
function getEventTileImageName(event, isWide = false) {
  if ("eventImage" in event) {
    let eventImageTemplate = event.eventImage
    return format(eventImageTemplate, isWide ? "wide" : "thin")
  }

  local res = ""
  if (isUnitTypeAvailable(event, ES_UNIT_TYPE_TANK) && isUnitTypeAvailable(event, ES_UNIT_TYPE_AIRCRAFT))
    res = "mixed"
  else if (isUnitTypeAvailable(event, ES_UNIT_TYPE_SHIP))
    res = "ship"
  else if (!isUnitTypeAvailable(event, ES_UNIT_TYPE_TANK))
    res = "air"
  else if (!isUnitTypeAvailable(event, ES_UNIT_TYPE_AIRCRAFT))
    res = "tank"
  return wrapImageName($"{getEventDiffName(event.name)}_{res}", isWide)
}
function getCustomVideioPreviewName(event) {
  return event?.customVideoPreviewName
}
function getEventPreviewVideoName(event, isWide) {
  
  
  if (isWide)
    return null

  let isEventNeedPreview = (isInArray(event.name, eventIdsForMainGameModeList) ||
    (getEventDisplayType(event).showInGamercardDrawer && isEventActive(event)))

  if (!isEventNeedPreview)
    return null

  let customVideoPreviewName = getCustomVideioPreviewName(event)
  if (customVideoPreviewName)
    return customVideoPreviewName == "" ? null : customVideoPreviewName

  let unitTypeName = isUnitTypeAvailable(event, ES_UNIT_TYPE_SHIP) ? "ship"
    : isUnitTypeAvailable(event, ES_UNIT_TYPE_TANK) ? "tank"
    : isUnitTypeAvailable(event, ES_UNIT_TYPE_AIRCRAFT) ? "air"
    : ""

  return $"video/gameModes/{unitTypeName}_{getEventDiffName(event.name)}.ivf"
}
function getEventsForGcDrawer() {
  return getEventsList(EVENT_TYPE.ANY & (~EVENT_TYPE.NEWBIE_BATTLES),
    @(event) getEventDisplayType(event).showInGamercardDrawer && isEventActive(event))
}
let getEventIsVisible = @(event) canShowByEnableOnDebug(event)
  || isEventEnabled(event)
  || (event?.visible ?? true)
let isEventVisibleInEventsWindow = @(event) event?.chapter != "competitive"
  && getEventDisplayType(event).showInEventsWindow
  && getEventIsVisible(event)
let countEventsList = @(typeMask = EVENT_TYPE.ANY_BASE_EVENTS, testFunc = @(_event) true)
  getEventsList(typeMask, testFunc).len()

function getEventsVisibleInEventsWindowCount() {
  return countEventsList(EVENT_TYPE.ANY, isEventVisibleInEventsWindow)
}
function getEventUiSortPriority(event) {
  return event?.uiSortPriority ?? 0
}
function getEventsChapter(event) {
  if (isEventEnableOnDebug(event))
    return "test_events"
  local chapterName = event?.chapter ?? "basic_events"
  if (isEventEnded(event) && isInArray(chapterName, standardChapterNames))
    chapterName = $"{chapterName}/ended"
  return chapterName
}

return {
  countEventsList
  getEventStartTime
  getEventEndTime
  hasEventEndTime
  isEventEnabled
  isEventActive
  isEventEnded
  isEventEnableOnDebug
  canShowByEnableOnDebug
  isEventDisplayWide
  diffCodeCompare
  getEventDiffName
  getEventTileImageName
  getEventPreviewVideoName
  getEventsForGcDrawer
  getEventIsVisible
  isEventVisibleInEventsWindow
  getEventsVisibleInEventsWindowCount
  getEventUiSortPriority
  getEventsChapter
}
