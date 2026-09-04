from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent

let { LEADER_GAME_MODE_APPLIED, SQUAD_SET_READY_REQUESTED } = require("%scripts/crossModuleEvents.nut")
let { isSquadMember, isMeReady } = require("%scripts/squads/squadState.nut")
let { getEvent } = require("%scripts/events/eventsState.nut")
let { checkRequiredUnits, getCountryRepairInfo } = require("%scripts/events/eventUnitsAvail.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")








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
