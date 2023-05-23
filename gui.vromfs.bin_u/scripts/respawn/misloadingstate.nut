//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { getAvailableRespawnBases } = require("guiRespawn")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { registerPersistentDataFromRoot, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

enum MIS_LOAD { //bit enum
  //loading parts
  ECONOMIC_STATE      = 0x0001
  RESPAWN_BASES       = 0x0002

  //parts masks
  RESPAWN_DATA_LOADED = 0x0003
}

  //calls from c++ code.
::on_update_es_from_host <- function on_update_es_from_host() {
  log("on_update_es_from_host called")
  ::g_crews_list.invalidate()
  ::reinitAllSlotbars()
  broadcastEvent("UpdateEsFromHost")
}

  //calls from c++ code. Signals that something is changed in mission
  // for now it's only state of respawn bases
::on_mission_changed <- function on_mission_changed() {
  broadcastEvent("ChangedMissionRespawnBasesStatus")
}

::g_mis_loading_state <- {
  [PERSISTENT_DATA_PARAMS] = ["curState"]

  curState = 0
}

::g_mis_loading_state.isReadyToShowRespawn <- function isReadyToShowRespawn() {
  return (this.curState & MIS_LOAD.RESPAWN_DATA_LOADED) == MIS_LOAD.RESPAWN_DATA_LOADED
}

::g_mis_loading_state.isCrewsListReceived <- function isCrewsListReceived() {
  return (this.curState & MIS_LOAD.ECONOMIC_STATE) != 0
}

::g_mis_loading_state.onEventUpdateEsFromHost <- function onEventUpdateEsFromHost(_p) {
  if (this.curState & MIS_LOAD.ECONOMIC_STATE)
    return

  log("misLoadState: received initial  economicState")
  this.curState = this.curState | MIS_LOAD.ECONOMIC_STATE
  this.checkRespawnBases()
}

::g_mis_loading_state.onEventLoadingStateChange <- function onEventLoadingStateChange(_p) {
  if (!::is_in_flight()) {
    if (this.curState != 0)
      log("misLoadState: reset mision loading state")
    this.curState = 0
  }
}

::g_mis_loading_state.checkRespawnBases <- function checkRespawnBases() {
  if ((this.curState & MIS_LOAD.RESPAWN_BASES)
      || !(this.curState & MIS_LOAD.ECONOMIC_STATE))
    return

  local hasRespBases = false
  foreach (crew in ::get_crews_list_by_country(::get_local_player_country())) {
    let unit = ::g_crew.getCrewUnit(crew)
    if (!unit)
      continue

    if (!getAvailableRespawnBases(unit.tags).len())
      continue

    hasRespBases = true
    break
  }

  log("misLoadState: check respawn bases. has available? " + hasRespBases)

  if (hasRespBases)
    this.curState = this.curState | MIS_LOAD.RESPAWN_BASES
}

::g_mis_loading_state.onEventChangedMissionRespawnBasesStatus <- function onEventChangedMissionRespawnBasesStatus(_p) {
  this.checkRespawnBases()
}

registerPersistentDataFromRoot("g_mis_loading_state")
subscribe_handler(::g_mis_loading_state ::g_listener_priority.CONFIG_VALIDATION)