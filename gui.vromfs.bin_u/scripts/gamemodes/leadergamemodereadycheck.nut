from "%scripts/crossModuleEvents.nut" import LEADER_GAME_MODE_APPLIED, SQUAD_SET_READY_REQUESTED
from "%scripts/squads/squadState.nut" import isSquadMember, isMeReady
from "%scripts/events/eventsState.nut" import getEvent
from "%scripts/events/eventUnitsAvail.nut" import checkRequiredUnits, getCountryRepairInfo
from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent








function checkLeaderGameModeReadiness(modeId) {
  if (!isSquadMember() || !isMeReady())
    return

  let event = getEvent(modeId)
  if (event == null)
    return

  if (!checkRequiredUnits(event, null, profileCountrySq.get())) {
    broadcastEvent(SQUAD_SET_READY_REQUESTED, { ready = false })
    return
  }

  if (!getCountryRepairInfo(event, null, profileCountrySq.get()).canFlyout)
    broadcastEvent(SQUAD_SET_READY_REQUESTED, { ready = false })
}

addListenersWithoutEnv({
  [LEADER_GAME_MODE_APPLIED] = @(p) checkLeaderGameModeReadiness(p.modeId)
})
