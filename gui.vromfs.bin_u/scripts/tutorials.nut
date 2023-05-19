//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { tryOpenNextTutorialHandler } = require("%scripts/tutorials/nextTutorialHandler.nut")
let { checkTutorialsList } = require("%scripts/tutorials/tutorialsData.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")

let function checkReserveUnit(unit, paramsTable) {
  let country = getTblValue("country", paramsTable, "")
  let unitType = getTblValue("unitType", paramsTable, ES_UNIT_TYPE_AIRCRAFT)
  let ignoreUnits = getTblValue("ignoreUnits", paramsTable, [])
  let ignoreSlotbarCheck = getTblValue("ignoreSlotbarCheck", paramsTable, false)

  return (unit.shopCountry == country)
    && (::get_es_unit_type(unit) == unitType || unitType == ES_UNIT_TYPE_INVALID)
    && !isInArray(unit.name, ignoreUnits)
    && ::is_default_aircraft(unit.name)
    && unit.isBought()
    && unit.isVisibleInShop()
    && (ignoreSlotbarCheck || !::isUnitInSlotbar(unit))
}

let function getReserveAircraftName(paramsTable) {
  let preferredCrew = getTblValue("preferredCrew", paramsTable, null)

  // Trained level by unit name.
  let trainedSpec = getTblValue("trainedSpec", preferredCrew, {})

  foreach (unitName, _unitSpec in trainedSpec) {
    let unit = getAircraftByName(unitName)
    if (unit != null && checkReserveUnit(unit, paramsTable))
      return unit.name
  }

  foreach (unit in ::all_units)
    if (checkReserveUnit(unit, paramsTable))
      return unit.name

  return ""
}

let function checkTutorialOnStart() {
  let unit = getShowedUnit()
  foreach (tutorial in checkTutorialsList) {
    if (!(tutorial?.isNeedAskInMainmenu ?? false))
      continue

    if (("requiresFeature" in tutorial) && !hasFeature(tutorial.requiresFeature))
      continue

    if (tutorial.suitableForUnit(unit) && tryOpenNextTutorialHandler(tutorial.id))
      return
  }
}

return {
  getReserveAircraftName
  checkTutorialOnStart
}