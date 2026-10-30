from "%scripts/unit/unitsData.nut" import getAllUnits
from "%scripts/slotbar/playerCurUnit.nut" import getShowedUnitName
from "%scripts/crew/crewInfo.nut" import isCrewLockedByPrevBattle, getCrewUnlockTime, getCrewByAir
from "%scripts/user/playerCountry.nut" import profileCountrySq
from "%scripts/clientState/localProfileDeprecated.nut" import saveLocalByAccount
from "%scripts/unit/unitParams.nut" import getEsUnitType
from "%scripts/unit/unitInSlotbarStatus.nut" import isUnitInSlotbar
from "%scripts/crew/crew.nut" import getCrewUnit
from "%scripts/slotbar/crewsList.nut" import getCrewsList, getCrewsListByCountry
from "%scripts/crew/crewSpecType.nut" import getSpecTypeByCrewAndUnit
from "%sqStdLibs/helpers/u.nut" import appendOnce
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "%scripts/dagui_natives.nut" import is_default_aircraft
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/dagui_library.nut" import *
from "%globalScripts/charActionConsts.nut" import *

let selectedCrews = {}

let ignoreTransactions = [
  EATT_SAVING
  EATT_CLANSYNCPROFILE
  EATT_CLAN_TRANSACTION
  EATT_SET_EXTERNAL_ID
  EATT_BUYING_UNLOCK
  EATT_COMPLAINT
  EATT_ENABLE_MODIFICATIONS
]

function isCountrySlotbarHasUnits(countryId) {
  return getCrewsListByCountry(countryId).findvalue(@(crew) getCrewUnit(crew) != null) != null
}

function getAvailableCrewId(countryData) {
  local id = -1
  let { crews = [] } = countryData
  let curUnitId = getShowedUnitName()
  foreach (idx, crew in crews) {
    if (("aircraft" not in crew) || crew.aircraft == "")
      continue
    if (crew.aircraft == curUnitId) {
      id = idx
      break
    }
    if (id < 0)
      id = idx
  }
  return id
}

function saveSelectedCrews() {
  if (!hasFullLoginState.get())
    return

  saveLocalByAccount("selected_crews", selectedCrews)
}

function checkReserveUnit(unit, paramsTable) {
  let country = paramsTable?.country ?? ""
  let unitType = paramsTable?.unitType ?? ES_UNIT_TYPE_AIRCRAFT
  let ignoreUnits = paramsTable?.ignoreUnits ?? []
  let ignoreSlotbarCheck = paramsTable?.ignoreSlotbarCheck ?? false

  return (unit.shopCountry == country)
    && (getEsUnitType(unit) == unitType || unitType == ES_UNIT_TYPE_INVALID)
    && !isInArray(unit.name, ignoreUnits)
    && is_default_aircraft(unit.name)
    && unit.isBought()
    && unit.isVisibleInShop()
    && (ignoreSlotbarCheck || !isUnitInSlotbar(unit))
}

function getReserveAircraftName(paramsTable) {
  let preferredCrew = paramsTable?.preferredCrew

  
  let trainedSpec = preferredCrew?.trainedSpec ?? {}
  foreach (unitName, _unitSpec in trainedSpec) {
    let unit = getAircraftByName(unitName)
    if (unit != null && checkReserveUnit(unit, paramsTable))
      return unit.name
  }

  foreach (unit in getAllUnits())
    if (checkReserveUnit(unit, paramsTable))
      return unit.name

  return ""
}

function isCountryAllCrewsUnlockedInHangar(countryId) {
  foreach (tbl in getCrewsList())
    if (tbl.country == countryId)
      foreach (crew in tbl.crews)
        if (isCrewLockedByPrevBattle(crew))
          return false
  return true
}

function getSlotbarUnitTypes(country) {
  let res = []
  foreach (countryData in getCrewsList())
    if (countryData.country == country)
      foreach (crew in countryData.crews)
        if (("aircraft" in crew) && crew.aircraft != "") {
          let unit = getAircraftByName(crew.aircraft)
          if (unit)
            appendOnce(getEsUnitType(unit), res)
        }
  return res
}

let getCrewUnlockTimeByUnit = @(unit) unit == null ? 0
 : getCrewUnlockTime(getCrewByAir(unit))

let isCrewSlotEmpty = @(crew) crew?.aircraft == ""

function getBestTrainedCrewIdxForUnit(unit, mustBeEmpty, compareToCrew = null) {
  if (!unit)
    return -1

  let crews = getCrewsListByCountry(unit.shopCountry)
  if (!crews.len())
    return -1

  local maxSpecCrewIdx = -1
  local maxSpecCode = -1

  if (compareToCrew) {
    maxSpecCrewIdx = compareToCrew?.idInCountry ?? maxSpecCrewIdx
    maxSpecCode = getSpecTypeByCrewAndUnit(compareToCrew, unit).code
  }

  foreach (idx, crew in crews) {
    let specType = getSpecTypeByCrewAndUnit(crew, unit)
    if (specType.code > maxSpecCode && (!mustBeEmpty || isCrewSlotEmpty(crew))) {
      maxSpecCrewIdx = idx
      maxSpecCode = specType.code
    }
  }

  return maxSpecCrewIdx
}

function getFirstEmptyCrewSlot(country = null) {
  if (!country)
    country = profileCountrySq.get()

  local crew = null
  foreach (_idx, crewBlock in getCrewsList())
    if (crewBlock.country == country) {
      crew = crewBlock.crews
      break
    }

  if (crew == null)
    return -1

  foreach (idx, crewBlock in crew)
    if (isCrewSlotEmpty(crewBlock))
      return idx

  return -1
}

return {
  isCountrySlotbarHasUnits
  getSelectedCrews = @(country) selectedCrews?[country] ?? -1
  isCountryAllCrewsUnlockedInHangar
  getSlotbarUnitTypes
  getCrewUnlockTimeByUnit
  getBestTrainedCrewIdxForUnit
  getFirstEmptyCrewSlot
  getReserveAircraftName
  selectedCrews
  ignoreTransactions
  getAvailableCrewId
  saveSelectedCrews
}
