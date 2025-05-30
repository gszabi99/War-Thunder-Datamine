from "%scripts/dagui_library.nut" import *

let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")
let { getReserveAircraftName } = require("%scripts/slotbar/slotbarStateData.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")

function getBestUnitForPreview(isAllowedByUnitTypesFn, isAvailableFn, forcedUnitId = null) {
  local unit = null
  if (forcedUnitId) {
    unit = getAircraftByName(forcedUnitId)
    return isAvailableFn(unit, false) ? unit : null
  }

  let countryId = profileCountrySq.value
  if (!isSlotbarOverrided()) {
    unit = getPlayerCurUnit()
    if (isAvailableFn(unit, false) && isAllowedByUnitTypesFn(unit.unitType.tag))
      return unit

    let crews = getCrewsListByCountry(countryId)
    foreach (crew in crews)
      if ((crew?.aircraft ?? "") != "") {
        unit = getAircraftByName(crew.aircraft)
        if (isAvailableFn(unit, false) && isAllowedByUnitTypesFn(unit.unitType.tag))
          return unit
      }

    foreach (crew in crews)
      for (local i = crew.trained.len() - 1; i >= 0; i--) {
        unit = getAircraftByName(crew.trained[i])
        if (isAvailableFn(unit, false) && isAllowedByUnitTypesFn(unit.unitType.tag))
          return unit
      }
  }
  local allowedUnitType = ES_UNIT_TYPE_TANK
  foreach (unitType in unitTypes.types) {
    if (isAllowedByUnitTypesFn(unitType.tag)) {
      allowedUnitType = unitType.esUnitType
      break
    }
  }

  unit = getAircraftByName(getReserveAircraftName({
    country = countryId
    unitType = allowedUnitType
    ignoreSlotbarCheck = true
  }))
  if (isAvailableFn(unit, false))
    return unit

  unit = getAircraftByName(getReserveAircraftName({
    country = "country_usa"
    unitType = allowedUnitType
    ignoreSlotbarCheck = true
  }))
  if (isAvailableFn(unit, false))
    return unit

  return null
}

return {
  getBestUnitForPreview
}