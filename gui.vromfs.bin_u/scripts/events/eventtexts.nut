from "%scripts/crossModuleEvents.nut" import GAME_LOCALIZATION_CHANGED
from "%scripts/events/eventInfo.nut" import getEventEconomicName, isEventForClan
from "%scripts/langUtils/language.nut" import getLocTextFromConfig
from "%scripts/events/eventsState.nut" import getEventByEconomicName
from "%scripts/events/eventTeamsInfo.nut" import getMaxBrText
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, CONFIG_VALIDATION
from "blkGetters" import get_gui_regional_blk
from "%scripts/dagui_library.nut" import *
from "%scripts/langUtils/localization.nut" import getLocIdsArray




let eventNameText = {}
let reportedCompositeLocNames = {}

function getTextsBlock(economicName) {
  return get_gui_regional_blk()?.eventsTexts?[economicName]
}

function getAbbrLocKey(event, economicName) {
  let locName = event?.loc_name
  if (locName != null && getLocIdsArray(locName).len() == 1)
    return $"{locName}/abbr"
  if (locName != null && !(economicName in reportedCompositeLocNames)) {
    reportedCompositeLocNames[economicName] <- true
    logerr(" ".concat($"[EVENTS] Composite loc_name is not planned for event game mode abbreviations.",
      $"eventName = {event.name},",
      $"economicName = {economicName},",
      $"loc_name = {toString(event.loc_name)}"))
  }
  return $"events/{economicName}/name/abbr"
}

function getEventNameOldStyle(event, economicName) {
  let locName = event?.loc_name ?? $"events/{economicName}/name"
  let ids = getLocIdsArray(locName)
  if (ids.len() == 1)
    return loc(locName, economicName)
  return "".join(ids.map(@(id) id.len() == 1 ? id : loc(id)))
}

function getEventNameText(event) {
  let economicName = getEventEconomicName(event)
  if (economicName in eventNameText)
    return eventNameText[economicName]
  let addText = isEventForClan(event) ? loc("ui/parentheses/space", { text = getMaxBrText(event) }) : ""
  let res = getLocTextFromConfig(getTextsBlock(economicName), "name", "")
  if (res.len()) {
    eventNameText[economicName] <- $"{res}{addText}"
    return eventNameText[economicName]
  }
  if (event?.chapter == "competitive") {
    eventNameText[economicName] <- loc($"tournament/{economicName}")
    return eventNameText[economicName]
  }
  eventNameText[economicName] <- $"{getEventNameOldStyle(event, economicName)}{addText}"
  return eventNameText[economicName]
}
function getNameByEconomicName(economicName) {
  return getEventNameText(getEventByEconomicName(economicName))
}
addListenersWithoutEnv({
  [GAME_LOCALIZATION_CHANGED] = @(_) eventNameText.clear()
}, CONFIG_VALIDATION)

return freeze({
  getTextsBlock
  getEventNameText
  getNameByEconomicName
  getAbbrLocKey
})
