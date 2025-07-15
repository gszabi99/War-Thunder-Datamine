from "%scripts/dagui_natives.nut" import is_default_aircraft
from "%scripts/dagui_library.nut" import *

let { get_game_mode } = require("mission")
let { isInFlight } = require("gameplayBinding")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isCrewAvailableInSession } = require("%scripts/respawn/respawnState.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { loadLocalByAccount } = require("%scripts/clientState/localProfileDeprecated.nut")
let { isUnitAvailableForGM } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { getCrewUnit } = require("%scripts/crew/crew.nut")
let { canChangeCrewUnits, getSessionLobbyMaxRespawns } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { updateShopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getMyCrewUnitsState, getBrokenUnits } = require("%scripts/slotbar/crewsListInfo.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")
let { getAvailableCrewId, saveSelectedCrews, selectedCrews, getReserveAircraftName, isCountrySlotbarHasUnits, ignoreTransactions } = require("%scripts/slotbar/slotbarStateData.nut")
let { getCrewsList, invalidateCrewsList, isCrewListOverrided } = require("%scripts/slotbar/crewsList.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { batchTrainCrew } = require("%scripts/crew/crewTrain.nut")
let { isCrewLockedByPrevBattle } = require("%scripts/crew/crewInfo.nut")
let { disableNetwork } = require("%globalScripts/clientState/initialState.nut")

local isInFlightCrewsList = isInFlight()
local isSlotbarUpdateSuspended = false
local isSlotbarUpdateRequired = false
local isReinitSlotbarsInProgress = false

function selectAvailableCrew(countryId) {
  local isAnyUnitInSlotbar = false
  if ((countryId in getCrewsList()) && (countryId in selectedCrews)) {
    local id = getAvailableCrewId(countryId)
    isAnyUnitInSlotbar = id >= 0
    selectedCrews[countryId] = max(0, id)
  }
  return isAnyUnitInSlotbar
}

function initSelectedCrews(forceReload = false) {
  if (!isProfileReceived.get())
    return

  let crewList = getCrewsList()
  let crewListLen = crewList.len()
  if (!forceReload && (!crewListLen || selectedCrews.len() == crewListLen))
    return

  let selCrewsBlk = loadLocalByAccount("selected_crews", null)
  local needSave = false

  selectedCrews.resize(crewListLen, 0)
  foreach (cIdx, country in crewList) {
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
  broadcastEvent("CrewChanged", { isInitSelectedCrews = true })
}

function reinitSlotbars() {
  if (isSlotbarUpdateSuspended) {
    isSlotbarUpdateRequired = true
    log("ignore reinitSlotbars: updates suspended")
    return
  }

  isSlotbarUpdateRequired = false
  if (isReinitSlotbarsInProgress) {
    script_net_assert_once("reinitAllSlotbars recursion", "reinitAllSlotbars: recursive call found")
    return
  }

  isReinitSlotbarsInProgress = true
  initSelectedCrews(true)
  broadcastEvent("CrewsListChanged")
  isReinitSlotbarsInProgress = false
}

let reinitAllSlotbars = @() reinitSlotbars()

function getSelSlotsData() {
  initSelectedCrews()
  let data = { slots = {}, units = {} }
  foreach (cIdx, country in getCrewsList()) {
    local unit = getCrewUnit(country.crews?[selectedCrews[cIdx]])
    if (unit == null && isCountrySlotbarHasUnits(country.country)) {
      selectAvailableCrew(cIdx)
      unit = getCrewUnit(country.crews?[selectedCrews[cIdx]])
    }
    data.slots[country.country] <- selectedCrews[cIdx]
    data.units[country.country] <- unit?.name ?? ""
  }
  return data
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
}

function getSelAircraftByCountry(country) {
  initSelectedCrews()
  foreach (cIdx, c in getCrewsList())
    if (c.country == country)
      return getCrewUnit(c.crews?[selectedCrews[cIdx]])
  return null
}

let getCurSlotbarUnit = @() getSelAircraftByCountry(profileCountrySq.value)

function isUnitUnlockedInSlotbar(unit, crew, country, missionRules, needDbg = false) {
  local unlocked = !isCrewLockedByPrevBattle(crew)
  if (unit) {
    unlocked = unlocked && (!country || isCrewAvailableInSession(crew, unit, needDbg))
    unlocked = unlocked && (isUnitAvailableForGM(unit, get_game_mode()) || isInFlight())
      && (!unit.disableFlyout || !isInFlight())
      && (missionRules?.isUnitEnabledBySessionRank(unit) ?? true)
    if (unlocked && !canChangeCrewUnits() && !isInFlight()
        && getSessionLobbyMaxRespawns() == 1)
      unlocked = getCurSlotbarUnit() == unit
  }
  return unlocked
}

function flushSlotbarUpdate() {
  isSlotbarUpdateSuspended = false
  if (isSlotbarUpdateRequired)
    reinitSlotbars()
}

function suspendSlotbarUpdates() {
  isSlotbarUpdateSuspended = true
}

addListenersWithoutEnv({
  function ProfileUpdated(p) {
    if (p.transactionType == EATT_UPDATE_ENTITLEMENTS)
      updateShopCountriesList()

    let brokenUnitsCached = getMyCrewUnitsState().brokenAirs
    let brokenUnitsUpdated = getBrokenUnits()

    local hasRepairedUnits = false
    foreach (unit in brokenUnitsCached) {
      if (unit not in brokenUnitsUpdated) {
        hasRepairedUnits = true
        break
      }
    }

    if (isProfileReceived.get() && !isInArray(p.transactionType, ignoreTransactions)
        && invalidateCrewsList(hasRepairedUnits) && !disableNetwork)
      reinitSlotbars()
  }

  function UnlockedCountriesUpdate(_p) {
    updateShopCountriesList()
    if (isProfileReceived.get() && invalidateCrewsList())
      reinitSlotbars()
  }

  function LobbyIsInRoomChanged(_p) {
    if (isCrewListOverrided.get())
      invalidateCrewsList()
  }

  
  SessionDestroyed = @(_p) invalidateCrewsList()
  function OverrideSlotbarChanged(_p) {
    if (invalidateCrewsList(true))
      reinitSlotbars()
  }
  SignOut = @(_p) isSlotbarUpdateSuspended = false

  function LoadingStateChange(_p) {
    isSlotbarUpdateSuspended = false
    if (isInFlightCrewsList == isInFlight())
      return
    isInFlightCrewsList = isInFlight()
    if (invalidateCrewsList())
      reinitSlotbars()
  }
}, DEFAULT_HANDLER)

return {
  getSelSlotsData
  isUnitUnlockedInSlotbar
  initSelectedCrews
  getSelAircraftByCountry
  getCurSlotbarUnit
  selectCrew
  reinitAllSlotbars
  flushSlotbarUpdate
  suspendSlotbarUpdates
}
