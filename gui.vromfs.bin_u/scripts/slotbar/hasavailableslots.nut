from "%scripts/dagui_natives.nut" import get_local_player_country, is_crew_slot_was_ready_at_host
from "%scripts/dagui_library.nut" import *
from "guiRespawn" import getAvailableRespawnBases

let { get_game_mode, get_game_type, get_mp_local_team } = require("mission")
let { g_mis_loading_state } = require("%scripts/respawn/misLoadingState.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { isCrewAvailableInSession } = require("%scripts/respawn/respawnState.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")

function hasAvailableSlots() {
  if (!(get_game_type() & (GT_VERSUS | GT_COOPERATIVE)))
    return true

  if (get_game_mode() == GM_SINGLE_MISSION || get_game_mode() == GM_DYNAMIC)
    return true

  if (!g_mis_loading_state.isCrewsListReceived())
    return false

  let team = get_mp_local_team()
  let country = get_local_player_country()
  let crews = getCrewsListByCountry(country)
  if (!crews)
    return false

  log($"Looking for country {country} in team {team} slots:{crews.len()}")

  let missionRules = getCurMissionRules()
  let leftRespawns = missionRules.getLeftRespawns()
  if (leftRespawns == 0)
    return false

  let curSpawnScore = missionRules.getCurSpawnScore()
  foreach (c in crews) {
    let air = getAircraftByName(c?.aircraft ?? "")
    if (!air)
      continue

    if (!isCrewAvailableInSession(c, air)
        || !is_crew_slot_was_ready_at_host(c.idInCountry, air.name, false)
        || !getAvailableRespawnBases(air.tags).len()
        || !missionRules.getUnitLeftRespawns(air)
        || !missionRules.isUnitEnabledBySessionRank(air)
        || !missionRules.canRespawnOnUnitByRageTokens(air)
        || air.disableFlyout)
      continue

    if (missionRules.isScoreRespawnEnabled
      && curSpawnScore >= 0
      && curSpawnScore < air.getMinimumSpawnScore())
      continue

    log($"hasAvailableSlots true: unit {air.name} in slot {c.idInCountry}")
    return true
  }
  log("hasAvailableSlots false")
  return false
}

return {
  hasAvailableSlots
}