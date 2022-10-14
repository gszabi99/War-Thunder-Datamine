from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { tryOpenNextTutorialHandler } = require("%scripts/tutorials/nextTutorialHandler.nut")
let { checkTutorialsList } = require("%scripts/tutorials/tutorialsData.nut")
let { getShowedUnit } = require("%scripts/slotbar/playerCurUnit.nut")

::getReserveAircraftName <- function getReserveAircraftName(paramsTable)
{
  let preferredCrew = getTblValue("preferredCrew", paramsTable, null)

  // Trained level by unit name.
  let trainedSpec = getTblValue("trainedSpec", preferredCrew, {})

  foreach (unitName, unitSpec in trainedSpec)
  {
    let unit = ::getAircraftByName(unitName)
    if (unit != null && ::checkReserveUnit(unit, paramsTable))
      return unit.name
  }

  foreach (unit in ::all_units)
    if (::checkReserveUnit(unit, paramsTable))
      return unit.name

  return ""
}

::checkReserveUnit <- function checkReserveUnit(unit, paramsTable)
{
  let country = getTblValue("country", paramsTable, "")
  let unitType = getTblValue("unitType", paramsTable, ES_UNIT_TYPE_AIRCRAFT)
  let ignoreUnits = getTblValue("ignoreUnits", paramsTable, [])
  let ignoreSlotbarCheck = getTblValue("ignoreSlotbarCheck", paramsTable, false)

  return (unit.shopCountry == country &&
         (::get_es_unit_type(unit) == unitType || unitType == ES_UNIT_TYPE_INVALID) &&
         !isInArray(unit.name, ignoreUnits) &&
         ::is_default_aircraft(unit.name) &&
         unit.isBought() &&
         unit.isVisibleInShop() &&
         (ignoreSlotbarCheck || !::isUnitInSlotbar(unit)))
}

::check_tutorial_on_start <- function check_tutorial_on_start()
{
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
