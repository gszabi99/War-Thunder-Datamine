from "%scripts/dagui_library.nut" import *

let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { selectBattle, selectArmy, selectAirfield, selectRearZone,
  hoverBattle, hoverArmy, doAction, moveArmy, sendAircraft } = require("%scripts/worldWar/wwMapEventsHandler.nut")

let dargMapVisible = mkWatched(persist, "dargMapVisible", true)

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

return {
  setWWMapParams

  hoverArmyByName
  showArmiesIndex

  selectArmyByName
  dargMapVisible
}