import "%scripts/g_listener_priority.nut" as g_listener_priority
from "%scripts/slotbar/slotbarState.nut" import reinitAllSlotbars
from "%scripts/crew/crew.nut" import getCrewUnit
from "%scripts/slotbar/crewsList.nut" import invalidateCrewsList, getCrewsListByCountry
from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler, broadcastEvent
from "eventbus" import eventbus_subscribe
from "guiRespawn" import getAvailableRespawnBases
from "gameplayBinding" import isInFlight
from "%scripts/dagui_natives.nut" import get_local_player_country
from "%scripts/dagui_library.nut" import *

enum MIS_LOAD { 
  
  ECONOMIC_STATE      = 0x0001
  RESPAWN_BASES       = 0x0002

  
  RESPAWN_DATA_LOADED = 0x0003
}

  
function onUpdateEsFromHost(_) {
  log("on_update_es_from_host called")
  invalidateCrewsList()
  reinitAllSlotbars()
  broadcastEvent("UpdateEsFromHost")
}

eventbus_subscribe("on_update_es_from_host", onUpdateEsFromHost)

  
eventbus_subscribe("on_mission_changed", function on_mission_changed(...) {
  broadcastEvent("ChangedMissionRespawnBasesStatus")
})


let mis_loading_state = mkHardPersistWatched("respawn.misLoadingState")("mis_loading_state", 0)
let getCurState = @() mis_loading_state.get()
let setCurState = @(v) mis_loading_state.set(v)

let g_mis_loading_state = {
  getCurState
}

g_mis_loading_state.isReadyToShowRespawn <- function isReadyToShowRespawn() {
  return (getCurState() & MIS_LOAD.RESPAWN_DATA_LOADED) == MIS_LOAD.RESPAWN_DATA_LOADED
}

g_mis_loading_state.isCrewsListReceived <- function isCrewsListReceived() {
  return (getCurState() & MIS_LOAD.ECONOMIC_STATE) != 0
}

g_mis_loading_state.onEventUpdateEsFromHost <- function onEventUpdateEsFromHost(_p) {
  if (getCurState() & MIS_LOAD.ECONOMIC_STATE)
    return

  log("misLoadState: received initial  economicState")
  setCurState(getCurState() | MIS_LOAD.ECONOMIC_STATE)
  this.checkRespawnBases()
}

g_mis_loading_state.onEventLoadingStateChange <- function onEventLoadingStateChange(_p) {
  if (!isInFlight()) {
    if (getCurState() != 0)
      log("misLoadState: reset mision loading state")
    setCurState(0)
  }
}

g_mis_loading_state.checkRespawnBases <- function checkRespawnBases() {
  if ((getCurState() & MIS_LOAD.RESPAWN_BASES)
      || !(getCurState() & MIS_LOAD.ECONOMIC_STATE))
    return

  local hasRespBases = false
  foreach (crew in getCrewsListByCountry(get_local_player_country())) {
    let unit = getCrewUnit(crew)
    if (!unit)
      continue

    if (!getAvailableRespawnBases(unit.tags).len())
      continue

    hasRespBases = true
    break
  }

  log("misLoadState: check respawn bases. has available?", hasRespBases)

  if (hasRespBases)
    setCurState(getCurState() | MIS_LOAD.RESPAWN_BASES)
}

g_mis_loading_state.onEventChangedMissionRespawnBasesStatus <- function onEventChangedMissionRespawnBasesStatus(_p) {
  this.checkRespawnBases()
}

subscribe_handler(g_mis_loading_state, g_listener_priority.CONFIG_VALIDATION)
return {g_mis_loading_state}