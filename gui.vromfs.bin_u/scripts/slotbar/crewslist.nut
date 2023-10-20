//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getSlotbarOverrideData, isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")
let { updateShopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { isInFlight } = require("gameplayBinding")

let function getCrewInfo(isInBattle) {
  let crewInfo = ::get_crew_info()
  if (!isInBattle)
    return crewInfo
  //In a battle after a profile update, the crew list may contain crews for multiple countries instead one.
  //In this case, a bug may occur when the slotbar points to a country that does not match in the crewList.
  //It is necessary to filter them by player's country, so that the interface does not break.
  if (crewInfo.len() <= 1)
    return crewInfo
  let curCountry = ::get_profile_country()
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

::g_crews_list <- {
  crewsList = !::g_login.isLoggedIn() ? [] : getCrewInfo(isInBattleState.value)
  isCrewListOverrided = false
  version = 0

  isNeedToSkipNextProfileUpdate = false
  ignoreTransactions = [
    EATT_SAVING
    EATT_CLANSYNCPROFILE
    EATT_CLAN_TRANSACTION
    EATT_SET_EXTERNAL_ID
    EATT_BUYING_UNLOCK
    EATT_COMPLAINT
    EATT_ENABLE_MODIFICATIONS
  ]
  isSlotbarUpdateSuspended = false
  isSlotbarUpdateRequired = false
}

::g_crews_list.get <- function get() {
  if (!this.crewsList.len() && ::g_login.isProfileReceived())
    this.refresh()
  return this.crewsList
}

::g_crews_list.invalidate <- function invalidate(needForceInvalidate = false) {
  if (needForceInvalidate || !isSlotbarOverrided()) {
    this.crewsList = [] //do not broke previously received crewsList if someone use link on it
    broadcastEvent("CrewsListInvalidate")
    return true
  }
  return false
}

::g_crews_list.refresh <- function refresh() {
  this.version++
  if (isSlotbarOverrided() && !isInFlight()) {
    this.crewsList = getSlotbarOverrideData()
    this.isCrewListOverrided = true
    return
  }
  //we don't know about slotbar refresh in flight,
  //but we know than out of flight it refresh only with profile,
  //so can optimize it updates, and remove some direct refresh calls from outside
  this.crewsList = getCrewInfo(isInBattleState.value)
  this.isCrewListOverrided = false
}

::g_crews_list._isReinitSlotbarsInProgress <- false
::g_crews_list.reinitSlotbars <- function reinitSlotbars() {
  if (this.isSlotbarUpdateSuspended) {
    this.isSlotbarUpdateRequired = true
    log("ignore reinitSlotbars: updates suspended")
    return
  }

  this.isSlotbarUpdateRequired = false
  if (this._isReinitSlotbarsInProgress) {
    script_net_assert_once("reinitAllSlotbars recursion", "reinitAllSlotbars: recursive call found")
    return
  }

  this._isReinitSlotbarsInProgress = true
  ::init_selected_crews(true)
  broadcastEvent("CrewsListChanged")
  this._isReinitSlotbarsInProgress = false
}

::g_crews_list.suspendSlotbarUpdates <- function suspendSlotbarUpdates() {
  this.isSlotbarUpdateSuspended = true
}

::g_crews_list.flushSlotbarUpdate <- function flushSlotbarUpdate() {
  this.isSlotbarUpdateSuspended = false
  if (this.isSlotbarUpdateRequired)
    this.reinitSlotbars()
}

::g_crews_list.onEventProfileUpdated <- function onEventProfileUpdated(p) {
  if (p.transactionType == EATT_UPDATE_ENTITLEMENTS)
    updateShopCountriesList()

  if (::g_login.isProfileReceived() && !isInArray(p.transactionType, this.ignoreTransactions)
      && this.invalidate() && !::disable_network())
    this.reinitSlotbars()
}

::g_crews_list.onEventUnlockedCountriesUpdate <- function onEventUnlockedCountriesUpdate(_p) {
  updateShopCountriesList()
  if (::g_login.isProfileReceived() && this.invalidate())
    this.reinitSlotbars()
}

::g_crews_list.onEventOverrideSlotbarChanged <- function onEventOverrideSlotbarChanged(_p) {
  this.invalidate(true)
}

::g_crews_list.onEventLobbyIsInRoomChanged <- function onEventLobbyIsInRoomChanged(_p) {
  if (this.isCrewListOverrided)
    this.invalidate()
}

::g_crews_list.onEventSessionDestroyed <- function onEventSessionDestroyed(_p) {
  this.invalidate() //in session can be overrided slotbar. Also slots can be locked after the battle.
}

::g_crews_list.onEventSignOut <- function onEventSignOut(_p) {
  this.isSlotbarUpdateSuspended = false
}

::g_crews_list.onEventLoadingStateChange <- function onEventLoadingStateChange(_p) {
  this.isSlotbarUpdateSuspended = false
}

::reinitAllSlotbars <- function reinitAllSlotbars() {
  ::g_crews_list.reinitSlotbars()
}

isInBattleState.subscribe(@(_v) ::g_crews_list.invalidate())

subscribe_handler(::g_crews_list, ::g_listener_priority.DEFAULT_HANDLER)
registerPersistentData("g_crews_list", ::g_crews_list, [ "isCrewListOverrided" ])
