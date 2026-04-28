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
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")
let { getAvailableCrewId, saveSelectedCrews, selectedCrews, getReserveAircraftName, isCountrySlotbarHasUnits
 } = require("%scripts/slotbar/slotbarStateData.nut")
let { getCrewsList, invalidateCrewsList, isCrewListOverrided } = require("%scripts/slotbar/crewsList.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { batchTrainCrew } = require("%scripts/crew/crewTrain.nut")
let { isCrewLockedByPrevBattle } = require("%scripts/crew/crewInfo.nut")

local isInFlightCrewsList = isInFlight()
local isSlotbarUpdateSuspended = false
local isSlotbarUpdateRequired = false
local isReinitSlotbarsInProgress = false

function selectAvailableCrew(countryData) {
  let id = getAvailableCrewId(countryData)
  selectedCrews[countryData.country] <- max(0, id)
  return id >= 0
}

function needInitSelectedCrews(curCrewList) {
  let crewListLen = curCrewList.len()
  if (crewListLen == 0)
    return false

  if (selectedCrews.len() < crewListLen)
    return true

  foreach (countryData in curCrewList) {
    let { country } = countryData
    if (country not in selectedCrews)
      return true
  }
  return false
}

local isInitSelectedCrewsInProgress = false
function initSelectedCrews(forceReload = false) {
  if (!isProfileReceived.get())
    return

  let crewList = getCrewsList()
  if (!forceReload && !needInitSelectedCrews(crewList))
    return

  if (isInitSelectedCrewsInProgress) {
    script_net_assert_once("initSelectedCrews recursion", "initSelectedCrews: recursive call found")
    return
  }

  isInitSelectedCrewsInProgress = true
  let selCrewsBlk = loadLocalByAccount("selected_crews", null)
  local needSave = false

  foreach (countryData in crewList) {
    let { country } = countryData
    let crewIdx = selCrewsBlk?[country] ?? 0
    if ((countryData?.crews[crewIdx].aircraft ?? "") != "")
      selectedCrews[country] <- crewIdx
    else {
      if (!selectAvailableCrew(countryData)) {
        let unitId = getReserveAircraftName({ country })
        if (unitId != "")
          batchTrainCrew([{
            crewId = countryData.crews[0].id
            airName = unitId
          }])
      }
      needSave = needSave || selectedCrews?[country] != crewIdx
    }
  }
  if (needSave)
    saveSelectedCrews()
  broadcastEvent("CrewChanged", { isInitSelectedCrews = true })
  isInitSelectedCrewsInProgress = false
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
  initSelectedCrews()
  broadcastEvent("CrewsListChanged")
  isReinitSlotbarsInProgress = false
}

let reinitAllSlotbars = @() reinitSlotbars()

function getSelSlotsData() {
  initSelectedCrews()
  let data = { slots = {}, units = {} }
  foreach (countryData in getCrewsList()) {
    let { country, crews } = countryData
    local unit = getCrewUnit(crews?[selectedCrews[country]])
    if (unit == null && isCountrySlotbarHasUnits(country)) {
      selectAvailableCrew(countryData)
      unit = getCrewUnit(crews?[selectedCrews[country]])
    }
    data.slots[country] <- selectedCrews[country]
    data.units[country] <- unit?.name ?? ""
  }
  return data
}

function selectCrewSilentNoCheck(country, idInCountry) {
  if (selectedCrews[country] != idInCountry) {
    selectedCrews[country] = idInCountry
    saveSelectedCrews()
  }
}

function selectCrew(country, idInCountry, airChanged = false) {
  initSelectedCrews()
  if ((country not in selectedCrews)
      || (selectedCrews[country] == idInCountry && !airChanged))
    return

  selectCrewSilentNoCheck(country, idInCountry)
  broadcastEvent("CrewChanged")
}

function getSelAircraftByCountry(country) {
  initSelectedCrews()
  foreach (c in getCrewsList())
    if (c.country == country)
      return getCrewUnit(c.crews?[selectedCrews[country]])
  return null
}

let getCurSlotbarUnit = @() getSelAircraftByCountry(profileCountrySq.get())

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
