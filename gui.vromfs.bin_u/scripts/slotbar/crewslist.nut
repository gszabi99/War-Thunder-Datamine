from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { getSlotbarOverrideData, isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")
let { updateShopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

::g_crews_list <- {
  crewsList = !::g_login.isLoggedIn() ? [] : ::get_crew_info()
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

  onEventPlayerQuitMission = @(_p) this.invalidate()
}

::g_crews_list.get <- function get()
{
  if (!this.crewsList.len() && ::g_login.isProfileReceived())
    this.refresh()
  return this.crewsList
}

::g_crews_list.invalidate <- function invalidate(needForceInvalidate = false)
{
  if (needForceInvalidate || !isSlotbarOverrided())
  {
    this.crewsList = [] //do not broke previously received crewsList if someone use link on it
    ::broadcastEvent("CrewsListInvalidate")
    return true
  }
  return false
}

::g_crews_list.refresh <- function refresh()
{
  this.version++
  if (isSlotbarOverrided() && !::is_in_flight())
  {
    this.crewsList = getSlotbarOverrideData()
    this.isCrewListOverrided = true
    return
  }
  //we don't know about slotbar refresh in flight,
  //but we know than out of flight it refresh only with profile,
  //so can optimize it updates, and remove some direct refresh calls from outside
  this.crewsList = ::get_crew_info()
  this.isCrewListOverrided = false
}

::g_crews_list._isReinitSlotbarsInProgress <- false
::g_crews_list.reinitSlotbars <- function reinitSlotbars()
{
  if (this.isSlotbarUpdateSuspended)
  {
    this.isSlotbarUpdateRequired = true
    log("ignore reinitSlotbars: updates suspended")
    return
  }

  this.isSlotbarUpdateRequired = false
  if (this._isReinitSlotbarsInProgress)
  {
    ::script_net_assert_once("reinitAllSlotbars recursion", "reinitAllSlotbars: recursive call found")
    return
  }

  this._isReinitSlotbarsInProgress = true
  ::init_selected_crews(true)
  ::broadcastEvent("CrewsListChanged")
  this._isReinitSlotbarsInProgress = false
}

::g_crews_list.suspendSlotbarUpdates <- function suspendSlotbarUpdates()
{
  this.isSlotbarUpdateSuspended = true
}

::g_crews_list.flushSlotbarUpdate <- function flushSlotbarUpdate()
{
  this.isSlotbarUpdateSuspended = false
  if (this.isSlotbarUpdateRequired)
    reinitSlotbars()
}

::g_crews_list.onEventProfileUpdated <- function onEventProfileUpdated(p)
{
  if (p.transactionType == EATT_UPDATE_ENTITLEMENTS)
    updateShopCountriesList()

  if (::g_login.isProfileReceived() && !isInArray(p.transactionType, this.ignoreTransactions)
      && invalidate() && !::disable_network())
    reinitSlotbars()
}

::g_crews_list.onEventUnlockedCountriesUpdate <- function onEventUnlockedCountriesUpdate(_p)
{
  updateShopCountriesList()
  if (::g_login.isProfileReceived() && invalidate())
    reinitSlotbars()
}

::g_crews_list.onEventOverrideSlotbarChanged <- function onEventOverrideSlotbarChanged(_p)
{
  invalidate(true)
}

::g_crews_list.onEventLobbyIsInRoomChanged <- function onEventLobbyIsInRoomChanged(_p)
{
  if (this.isCrewListOverrided)
    invalidate()
}

::g_crews_list.onEventSessionDestroyed <- function onEventSessionDestroyed(_p)
{
  invalidate() //in session can be overrided slotbar. Also slots can be locked after the battle.
}

::g_crews_list.onEventSignOut <- function onEventSignOut(_p)
{
  this.isSlotbarUpdateSuspended = false
}

::g_crews_list.onEventLoadingStateChange <- function onEventLoadingStateChange(_p)
{
  this.isSlotbarUpdateSuspended = false
}

::reinitAllSlotbars <- function reinitAllSlotbars()
{
  ::g_crews_list.reinitSlotbars()
}

::subscribe_handler(::g_crews_list, ::g_listener_priority.DEFAULT_HANDLER)
::g_script_reloader.registerPersistentData("g_crews_list", ::g_crews_list, [ "isCrewListOverrided" ])
