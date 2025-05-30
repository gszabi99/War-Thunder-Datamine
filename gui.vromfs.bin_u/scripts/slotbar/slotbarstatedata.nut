from "%scripts/dagui_natives.nut" import is_default_aircraft
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { getShowedUnitName } = require("%scripts/slotbar/playerCurUnit.nut")
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { isCrewLockedByPrevBattle, getCrewUnlockTime, getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { saveLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")
let { isUnitInSlotbar } = require("%scripts/unit/unitInSlotbarStatus.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { getCrewsList, getCrewsListByCountry } = require("%scripts/slotbar/crewsList.nut")
let { getSpecTypeByCrewAndUnit } = require("%scripts/crew/crewSpecType.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

let selectedCrews = persist("selectedCrews", @() [])

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

function getAvailableCrewId(countryId) {
  local id = -1
  let curUnitId = getShowedUnitName()
  foreach (idx, crew in (getCrewsList()?[countryId].crews ?? [])) {
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
  if (!isLoggedIn.get())
    return

  let blk = DataBlock()
  foreach (cIdx, country in getCrewsList())
    blk[country.country] = selectedCrews?[cIdx] ?? 0
  saveLocalByAccount("selected_crews", blk)
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
    country = profileCountrySq.value

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
  getSelectedCrews = @(crewCountryId) selectedCrews?[crewCountryId] ?? -1
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
