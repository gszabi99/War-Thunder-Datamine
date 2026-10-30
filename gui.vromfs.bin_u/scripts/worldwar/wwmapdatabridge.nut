import "%scripts/global/updateExtWatched.nut" as updateExtWatched
from "%scripts/worldWar/wwMapEventsHandler.nut" import selectBattle, selectArmy, selectAirfield, selectRearZone, hoverBattle, hoverArmy, doAction
  , moveArmy, sendAircraft, showAirfieldTooltip
from "eventbus" import eventbus_send, eventbus_subscribe
from "%scripts/dagui_library.nut" import *

let dargMapVisible = Watched(true)

let wwMapEventHandlers = {
  selectBattle
  selectArmy
  selectAirfield
  selectRearZone

  hoverBattle
  hoverArmy
  clearHovers = hoverArmy

  doAction
  moveArmy
  sendAircraft

  showAirfieldTooltip
}

let setWWMapParams = @(params) updateExtWatched({ currentMapBounds = params })

eventbus_subscribe("WWMapEvent", function(eventData) {
  if(dargMapVisible.get() == false)
    return
  let parts = eventData.eventId.split(".")
  if (parts.len() < 2 || parts[0] != "ww" || !(parts[1] in wwMapEventHandlers))
    return

  wwMapEventHandlers[parts[1]](eventData.data)
})

let hoverArmyByName = @(armyName) eventbus_send("ww.hoverArmyByName", armyName)

let showArmiesIndex = @(groupIdxs, isShow) eventbus_send("ww.showArmiesIndex", { groupIdxs, isShow })

let selectArmyByName = @(armyName) eventbus_send("ww.selectArmyByName", armyName)

return freeze({
  setWWMapParams

  hoverArmyByName
  showArmiesIndex

  selectArmyByName
  dargMapVisible
})