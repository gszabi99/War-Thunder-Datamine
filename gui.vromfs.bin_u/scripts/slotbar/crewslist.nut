from "%scripts/dagui_natives.nut" import get_profile_country, disable_network, get_crew_info
from "%scripts/dagui_library.nut" import *

let { DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getSlotbarOverrideData, isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")
let { updateShopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { isInFlight } = require("gameplayBinding")
let { initSelectedCrews } = require("%scripts/slotbar/slotbarState.nut")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { getMyCrewUnitsState, getBrokenUnits } = require("%scripts/slotbar/crewsListInfo.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")

function getCrewInfo(isInBattle) {
  let crewInfo = get_crew_info()
  if (!isInBattle)
    return crewInfo
  //In a battle after a profile update, the crew list may contain crews for multiple countries instead one.
  //In this case, a bug may occur when the slotbar points to a country that does not match in the crewList.
  //It is necessary to filter them by player's country, so that the interface does not break.
  if (crewInfo.len() <= 1)
    return crewInfo

  let curCountry = get_profile_country()
  if (curCountry == "country_0") {
    if (!::should_disable_menu())
      logerr("[CREW_LIST] Country not selected")
    return crewInfo
  }

  let res = crewInfo.filter(@(v) v.country == curCountry)
  if (res.len() == 1)
    return res.map(
      @(countryInfo) countryInfo.__merge({
        crews = countryInfo.crews.map(@(crew) crew.__merge({idCountry = 0}))
      })
    )

  debugTableData(crewInfo)
  logerr("[CREW_LIST] Not found crews for selected country")
  return crewInfo
}

local crewsList = !::g_login.isLoggedIn() ? [] : getCrewInfo(isInBattleState.value)
local version = 0
local isSlotbarUpdateSuspended = false
local isSlotbarUpdateRequired = false
local isReinitSlotbarsInProgress = false

let isCrewListOverrided = hardPersistWatched("isCrewListOverrided", false)
let ignoreTransactions = [
  EATT_SAVING
  EATT_CLANSYNCPROFILE
  EATT_CLAN_TRANSACTION
  EATT_SET_EXTERNAL_ID
  EATT_BUYING_UNLOCK
  EATT_COMPLAINT
  EATT_ENABLE_MODIFICATIONS
]

function refresh() {
  version++
  if (isSlotbarOverrided() && !isInFlight()) {
    crewsList = getSlotbarOverrideData()
    isCrewListOverrided.set(true)
    return
  }
  //we don't know about slotbar refresh in flight,
  //but we know than out of flight it refresh only with profile,
  //so can optimize it updates, and remove some direct refresh calls from outside
  crewsList = getCrewInfo(isInBattleState.value)
  isCrewListOverrided.set(false)
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

function flushSlotbarUpdate() {
  isSlotbarUpdateSuspended = false
  if (isSlotbarUpdateRequired)
    reinitSlotbars()
}

function invalidateCrewsList(needForceInvalidate = false) {
  if (!needForceInvalidate && ((isSlotbarOverrided() && !isInFlight())
      || isEqual(crewsList, getCrewInfo(isInBattleState.value))))
    return false

  crewsList = [] //do not broke previously received crewsList if someone use link on it
  broadcastEvent("CrewsListInvalidate")
  return true
}

function getCrewsList() {
  if (!crewsList.len() && ::g_login.isProfileReceived())
    refresh()
  return crewsList
}

let reinitAllSlotbars = @() reinitSlotbars()
let suspendSlotbarUpdates = @() isSlotbarUpdateSuspended = true

::g_crews_list <- { // fixme cir refs
  flushSlotbarUpdate
  suspendSlotbarUpdates
  getCrewsList
}

isInBattleState.subscribe(@(_v) invalidateCrewsList())

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

    if (::g_login.isProfileReceived() && !isInArray(p.transactionType, ignoreTransactions)
        && invalidateCrewsList(hasRepairedUnits) && !disable_network())
      reinitSlotbars()
  }

  function UnlockedCountriesUpdate(_p) {
    updateShopCountriesList()
    if (::g_login.isProfileReceived() && invalidateCrewsList())
      reinitSlotbars()
  }

  function LobbyIsInRoomChanged(_p) {
    if (isCrewListOverrided.get())
      invalidateCrewsList()
  }

  //in session can be overrided slotbar. Also slots can be locked after the battle.}
  SessionDestroyed = @(_p) invalidateCrewsList()
  OverrideSlotbarChanged = @(_p) invalidateCrewsList(true)
  SignOut = @(_p) isSlotbarUpdateSuspended = false
  LoadingStateChange = @(_p) isSlotbarUpdateSuspended = false
}, DEFAULT_HANDLER)

return {
  clearCrewsList = @() crewsList = []
  isCrewListOverrided
  getCrewsListVersion = @() version
  flushSlotbarUpdate
  suspendSlotbarUpdates
  invalidateCrewsList
  reinitAllSlotbars
  getCrewsList
}