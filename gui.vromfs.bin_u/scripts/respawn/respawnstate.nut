from "%scripts/dagui_library.nut" import *

let { getWasReadySlotsMask, getSpareSlotsMask, getDisabledSlotsMask,
  getBrokenSlotsMask, getDisabledByMatchingSlotsMask
} = require("guiRespawn")
let { is_bit_set } = require("%sqstd/math.nut")
let { get_game_mode } = require("mission")
let { getUniversalSparesForUnit } = require("%scripts/items/itemsManagerModule.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { get_unit_spawn_score_weapon_mul } = require("%appGlobals/ranks_common_shared.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")

let isSpareAircraftInSlot = @(idInCountry) is_bit_set(getSpareSlotsMask(), idInCountry)

let isUnitDisabledByMatching = @(idInCountry) !is_bit_set(getBrokenSlotsMask(), idInCountry)
  && is_bit_set(getDisabledByMatchingSlotsMask(), idInCountry)

function canRespawnWithUniversalSpares(crew, unit) {
  if (!hasFeature("ActivateUniversalSpareInBattle"))
    return false

  let { idInCountry, isUnitOverrided = false } = crew
  if (isUnitOverrided)
    return false

  if (isUnitDisabledByMatching(idInCountry))
    return false

  if (get_game_mode() != GM_DOMINATION)
    return false

  let missionRules = getCurMissionRules()
  if (!missionRules.isAllowSpareInMission())
    return false

  if (isSpareAircraftInSlot(idInCountry)) 
    return false

  return getUniversalSparesForUnit(unit).len() > 0
}

function isCrewAvailableInSession(crew, unit = null, needDebug = false) {
  let { idInCountry } = crew
  let disabledSlots = getDisabledSlotsMask()
  let isAvailable = !is_bit_set(disabledSlots, idInCountry)
  let canUseUniversalSpare = unit != null && canRespawnWithUniversalSpares(crew, unit)
  if (needDebug)
    log($"isCrewAvailableInSession: disabledSlots={disabledSlots}; id={idInCountry}; isAvailable={isAvailable}, canUseUniversalSpare = {canUseUniversalSpare}")
  return isAvailable || canUseUniversalSpare
}

let isRespawnWithUniversalSpare = @(crew, unit) is_bit_set(getDisabledSlotsMask(), crew.idInCountry)
  && canRespawnWithUniversalSpares(crew, unit)

::get_unit_spawn_score_weapon_mul <- get_unit_spawn_score_weapon_mul


let needToShowBadWeatherWarning = Watched(false)


let hasAirfieldRespawn = Watched(false)


isInBattleState.subscribe(function(status) {
  if (status)
    return

  needToShowBadWeatherWarning.set(false)
  hasAirfieldRespawn.set(false)
})

return {
  isCrewAvailableInSession
  isSpareAircraftInSlot
  getWasReadySlotsMask
  getDisabledSlotsMask
  isRespawnWithUniversalSpare
  isUnitDisabledByMatching
  needToShowBadWeatherWarning
  hasAirfieldRespawn
}

