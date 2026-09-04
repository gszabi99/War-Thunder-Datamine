from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, CONFIG_VALIDATION
from "blkGetters" import get_gui_regional_blk
from "%scripts/dagui_library.nut" import *

let { GAME_LOCALIZATION_CHANGED } = require("%scripts/crossModuleEvents.nut")
let { getEventEconomicName, isEventForClan } = require("%scripts/events/eventInfo.nut")
let { getLocTextFromConfig } = require("%scripts/langUtils/language.nut")
let { getEventByEconomicName } = require("%scripts/events/eventsState.nut")
let { getMaxBrText } = require("%scripts/events/eventTeamsInfo.nut")




let eventNameText = {}

function getTextsBlock(economicName) {
  return get_gui_regional_blk()?.eventsTexts?[economicName]
}
function getNameLocOldStyle(event, economicName) {
  return event?.loc_name ?? $"events/{economicName}/name"
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
  eventNameText[economicName] <- $"{loc(getNameLocOldStyle(event, economicName), economicName)}{addText}"
  return eventNameText[economicName]
}
function getNameByEconomicName(economicName) {
  return getEventNameText(getEventByEconomicName(economicName))
}
addListenersWithoutEnv({
  [GAME_LOCALIZATION_CHANGED] = @(_) eventNameText.clear()
}, CONFIG_VALIDATION)

return {
  getTextsBlock
  getEventNameText
  getNameByEconomicName
  getNameLocOldStyle
}
