//checked for plus_string
from "%scripts/dagui_natives.nut" import is_player_unit_alive, is_default_aircraft, is_respawn_screen, get_player_unit_name
from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { getShowedUnitName } = require("%scripts/slotbar/playerCurUnit.nut")
let { get_game_mode } = require("mission")
let { isInFlight } = require("gameplayBinding")
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { batchTrainCrew } = require("%scripts/crew/crewActions.nut")
let { isCrewLockedByPrevBattle, getCrewUnlockTime } = require("%scripts/crew/crewInfo.nut")
let { isCrewAvailableInSession } = require("%scripts/respawn/respawnState.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfile.nut")
let { getEsUnitType } = require("%scripts/unit/unitInfo.nut")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")

let selectedCrews = persist("selectedCrews", @() [])

function getCrewsListByCountry(country) {
  foreach (countryData in ::g_crews_list.get())
    if (countryData.country == country)
      return countryData.crews
  return []
}

let function isCountrySlotbarHasUnits(countryId) {
  return getCrewsListByCountry(countryId).findvalue(@(crew) ::g_crew.getCrewUnit(crew) != null) != null
}

let function getAvailableCrewId(countryId) {
  local id = -1
  let curUnitId = getShowedUnitName()
  foreach (idx, crew in (::g_crews_list.get()?[countryId].crews ?? [])) {
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

let function selectAvailableCrew(countryId) {
  local isAnyUnitInSlotbar = false
  if ((countryId in ::g_crews_list.get()) && (countryId in selectedCrews)) {
    local id = getAvailableCrewId(countryId)
    isAnyUnitInSlotbar = id >= 0
    selectedCrews[countryId] = max(0, id)
  }
  return isAnyUnitInSlotbar
}

function saveSelectedCrews() {
  if (!::g_login.isLoggedIn())
    return

  let blk = DataBlock()
  foreach (cIdx, country in ::g_crews_list.get())
    blk[country.country] = selectedCrews?[cIdx] ?? 0
  saveLocalByAccount("selected_crews", blk)
}

function getCrewById(id) {
  foreach (_cId, cList in ::g_crews_list.get())
    if ("crews" in cList)
      foreach (_idx, crew in cList.crews)
       if (crew.id == id)
         return crew
  return null
}

function getCrewByAir(air) {
  foreach (country in ::g_crews_list.get())
    if (country.country == air.shopCountry)
      foreach (crew in country.crews)
        if (("aircraft" in crew) && crew.aircraft == air.name)
          return crew
  return null
}

let isUnitInSlotbar = @(unit) getCrewByAir(unit) != null

let function checkReserveUnit(unit, paramsTable) {
  let country = getTblValue("country", paramsTable, "")
  let unitType = getTblValue("unitType", paramsTable, ES_UNIT_TYPE_AIRCRAFT)
  let ignoreUnits = getTblValue("ignoreUnits", paramsTable, [])
  let ignoreSlotbarCheck = getTblValue("ignoreSlotbarCheck", paramsTable, false)

  return (unit.shopCountry == country)
    && (getEsUnitType(unit) == unitType || unitType == ES_UNIT_TYPE_INVALID)
    && !isInArray(unit.name, ignoreUnits)
    && is_default_aircraft(unit.name)
    && unit.isBought()
    && unit.isVisibleInShop()
    && (ignoreSlotbarCheck || !isUnitInSlotbar(unit))
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

  foreach (unit in getAllUnits())
    if (checkReserveUnit(unit, paramsTable))
      return unit.name

  return ""
}

function initSelectedCrews(forceReload = false) {
  if (!forceReload && (!::g_crews_list.get().len() || selectedCrews.len() == ::g_crews_list.get().len()))
    return

  let selCrewsBlk = loadLocalByAccount("selected_crews", null)
  local needSave = false

  selectedCrews.resize(::g_crews_list.get().len(), 0)
  foreach (cIdx, country in ::g_crews_list.get()) {
    let crewIdx = selCrewsBlk?[country.country] ?? 0
    if ((country?.crews[crewIdx].aircraft ?? "") != "")
      selectedCrews[cIdx] = crewIdx
    else {
      if (!selectAvailableCrew(cIdx)) {
        let unitId = getReserveAircraftName({ country = country.country })
        if (unitId != "")
          batchTrainCrew([{
            crewId = country.crews[0].id
            airName = unitId
          }])
      }
      needSave = needSave || selectedCrews[cIdx] != crewIdx
    }
  }
  if (needSave)
    saveSelectedCrews()
  broadcastEvent("CrewChanged")
}

let function getSelSlotsData() {
  initSelectedCrews()
  let data = { slots = {}, units = {} }
  foreach (cIdx, country in ::g_crews_list.get()) {
    local unit = ::g_crew.getCrewUnit(country.crews?[selectedCrews[cIdx]])
    if (unit == null && isCountrySlotbarHasUnits(country.country)) {
      selectAvailableCrew(cIdx)
      unit = ::g_crew.getCrewUnit(country.crews?[selectedCrews[cIdx]])
    }
    data.slots[country.country] <- selectedCrews[cIdx]
    data.units[country.country] <- unit?.name ?? ""
  }
  return data
}

function isUnitUnlockedInSlotbar(unit, crew, country, missionRules, needDbg = false) {
  local unlocked = !isCrewLockedByPrevBattle(crew)
  if (unit) {
    unlocked = unlocked && (!country || isCrewAvailableInSession(crew, unit, needDbg))
    unlocked = unlocked && (::isUnitAvailableForGM(unit, get_game_mode()) || isInFlight())
      && (!unit.disableFlyout || !isInFlight())
      && (missionRules?.isUnitEnabledBySessionRank(unit) ?? true)
    if (unlocked && !::SessionLobby.canChangeCrewUnits() && !isInFlight()
        && ::SessionLobby.getMaxRespawns() == 1)
      unlocked = ::SessionLobby.getMyCurUnit() == unit
  }

  return unlocked
}

function isUnitEnabledForSlotbar(unit, params) {
  if (!unit || unit.disableFlyout)
    return false

  local res = true
  let { eventId = null, room = null, availableUnits = null,
    roomCreationContext = null, mainMenuSlotbar = null, missionRules = null
  } = params

  if (eventId != null) {
    res = false
    let event = ::events.getEvent(eventId)
    if (event)
      res = ::events.isUnitAllowedForEventRoom(event, room, unit)
  }
  else if (availableUnits != null)
    res = unit.name in availableUnits
  else if (isInSessionRoom.get() && !isInFlight())
    res = ::SessionLobby.isUnitAllowed(unit)
  else if (roomCreationContext != null)
    res = roomCreationContext.isUnitAllowed(unit)

  if (!res)
    return res

  res = !mainMenuSlotbar || ::game_mode_manager.isUnitAllowedForGameMode(unit)
  if (!res || missionRules == null)
    return res

  let isAvaliableUnit = (missionRules.getUnitLeftRespawns(unit) != 0
    || missionRules.isUnitAvailableBySpawnScore(unit))
    && missionRules.isUnitEnabledByRandomGroups(unit.name)
  let isControlledUnit = !is_respawn_screen()
    && is_player_unit_alive()
    && get_player_unit_name() == unit.name

  return isAvaliableUnit || isControlledUnit
}

function isCountryAllCrewsUnlockedInHangar(countryId) {
  foreach (tbl in ::g_crews_list.get())
    if (tbl.country == countryId)
      foreach (crew in tbl.crews)
        if (isCrewLockedByPrevBattle(crew))
          return false
  return true
}

function getSlotbarUnitTypes(country) {
  let res = []
  foreach (countryData in ::g_crews_list.get())
    if (countryData.country == country)
      foreach (crew in countryData.crews)
        if (("aircraft" in crew) && crew.aircraft != "") {
          let unit = getAircraftByName(crew.aircraft)
          if (unit)
            appendOnce(getEsUnitType(unit), res)
        }
  return res
}

function selectCrewSilentNoCheck(countryId, idInCountry) {
  if (selectedCrews[countryId] != idInCountry) {
    selectedCrews[countryId] = idInCountry
    saveSelectedCrews()
  }
}

function selectCrew(countryId, idInCountry, airChanged = false) {
  initSelectedCrews()
  if ((countryId not in selectedCrews)
      || (selectedCrews[countryId] == idInCountry && !airChanged))
    return

  selectCrewSilentNoCheck(countryId, idInCountry)
  broadcastEvent("CrewChanged")
  ::g_squad_utils.updateMyCountryData(!isInFlight())
}

function getSelAircraftByCountry(country) {
  initSelectedCrews()
  foreach (cIdx, c in ::g_crews_list.get())
    if (c.country == country)
      return ::g_crew.getCrewUnit(c.crews?[selectedCrews[cIdx]])
  return null
}

let getCurSlotbarUnit = @() getSelAircraftByCountry(profileCountrySq.value)

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
    maxSpecCrewIdx = getTblValue("idInCountry", compareToCrew, maxSpecCrewIdx)
    maxSpecCode = ::g_crew_spec_type.getTypeByCrewAndUnit(compareToCrew, unit).code
  }

  foreach (idx, crew in crews) {
    let specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
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
  foreach (_idx, crewBlock in ::g_crews_list.get())
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
  getSelSlotsData
  isUnitUnlockedInSlotbar
  isUnitEnabledForSlotbar
  initSelectedCrews
  getSelectedCrews = @(crewCountryId) selectedCrews?[crewCountryId] ?? -1
  getSelAircraftByCountry
  getCurSlotbarUnit
  getCrewsListByCountry
  isCountryAllCrewsUnlockedInHangar
  getCrewById
  getCrewByAir
  isUnitInSlotbar
  getSlotbarUnitTypes
  selectCrew
  getCrewUnlockTimeByUnit
  getBestTrainedCrewIdxForUnit
  getFirstEmptyCrewSlot
  getReserveAircraftName
}
