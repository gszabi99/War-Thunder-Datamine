local { getAvailableRespawnBases } = require_native("guiRespawn")

enum MIS_LOAD { //bit enum
  //loading parts
  ECONOMIC_STATE      = 0x0001
  RESPAWN_BASES       = 0x0002

  //parts masks
  RESPAWN_DATA_LOADED = 0x0003
}

  //calls from c++ code.
::on_update_es_from_host <- function on_update_es_from_host()
{
  dagor.debug("on_update_es_from_host called")
  ::g_crews_list.invalidate()
  ::reinitAllSlotbars()
  ::broadcastEvent("UpdateEsFromHost")
}

  //calls from c++ code. Signals that something is changed in mission
  // for now it's only state of respawn bases
::on_mission_changed <- function on_mission_changed()
{
  ::broadcastEvent("ChangedMissionRespawnBasesStatus")
}

::g_mis_loading_state <- {
  [PERSISTENT_DATA_PARAMS] = ["curState"]

  curState = 0
}

g_mis_loading_state.isReadyToShowRespawn <- function isReadyToShowRespawn()
{
  return (curState & MIS_LOAD.RESPAWN_DATA_LOADED) == MIS_LOAD.RESPAWN_DATA_LOADED
}

g_mis_loading_state.isCrewsListReceived <- function isCrewsListReceived()
{
  return (curState & MIS_LOAD.ECONOMIC_STATE) != 0
}

g_mis_loading_state.onEventUpdateEsFromHost <- function onEventUpdateEsFromHost(p)
{
  if (curState & MIS_LOAD.ECONOMIC_STATE)
    return

  dagor.debug("misLoadState: received initial  economicState")
  curState = curState | MIS_LOAD.ECONOMIC_STATE
  checkRespawnBases()
}

g_mis_loading_state.onEventLoadingStateChange <- function onEventLoadingStateChange(p)
{
  if (!::is_in_flight())
  {
    if (curState != 0)
      dagor.debug("misLoadState: reset mision loading state")
    curState = 0
  }
}

g_mis_loading_state.checkRespawnBases <- function checkRespawnBases()
{
  if ((curState & MIS_LOAD.RESPAWN_BASES)
      || !(curState & MIS_LOAD.ECONOMIC_STATE))
    return

  local hasRespBases = false
  foreach(crew in ::get_crews_list_by_country(::get_local_player_country()))
  {
    local unit = ::g_crew.getCrewUnit(crew)
    if (!unit)
      continue

    if (!getAvailableRespawnBases(unit.tags).len())
      continue

    hasRespBases = true
    break
  }

  dagor.debug("misLoadState: check respawn bases. has available? " + hasRespBases)

  if (hasRespBases)
    curState = curState | MIS_LOAD.RESPAWN_BASES
}

g_mis_loading_state.onEventChangedMissionRespawnBasesStatus <- function onEventChangedMissionRespawnBasesStatus(p)
{
  checkRespawnBases()
}

::g_script_reloader.registerPersistentDataFromRoot("g_mis_loading_state")
::subscribe_handler(::g_mis_loading_state ::g_listener_priority.CONFIG_VALIDATION)