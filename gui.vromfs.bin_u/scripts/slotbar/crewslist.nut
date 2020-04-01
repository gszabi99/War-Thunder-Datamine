::g_crews_list <- {
  crewsList = !::g_login.isLoggedIn() ? [] : ::get_crew_info()
  isSlotbarOverrided = false
  version = 0

  isNeedToSkipNextProfileUpdate = false
  ignoreTransactions = [
    ::EATT_SAVING
    ::EATT_CLANSYNCPROFILE
    ::EATT_CLAN_TRANSACTION
    ::EATT_SET_EXTERNAL_ID
    ::EATT_BUYING_UNLOCK
    ::EATT_COMPLAINT
    ::EATT_ENABLE_MODIFICATIONS
  ]
  isSlotbarUpdateSuspended = false
  isSlotbarUpdateRequired = false
}

g_crews_list.get <- function get()
{
  if (!crewsList.len() && ::g_login.isProfileReceived())
    refresh()
  return crewsList
}

g_crews_list.invalidate <- function invalidate(needForceInvalidate = false)
{
  if (needForceInvalidate || !::SessionLobby.isSlotbarOverrided())
  {
    crewsList = [] //do not broke previously received crewsList if someone use link on it
    return true
  }
  return false
}

g_crews_list.refresh <- function refresh()
{
  version++
  if (::SessionLobby.isSlotbarOverrided() && !::is_in_flight())
  {
    crewsList = SessionLobby.getSlotbarOverrideData()
    isSlotbarOverrided = true
    return
  }
  //we don't know about slotbar refresh in flight,
  //but we know than out of flight it refresh only with profile,
  //so can optimize it updates, and remove some direct refresh calls from outside
  crewsList = ::get_crew_info()
  isSlotbarOverrided = false
}

g_crews_list._isReinitSlotbarsInProgress <- false
g_crews_list.reinitSlotbars <- function reinitSlotbars()
{
  if (isSlotbarUpdateSuspended)
  {
    isSlotbarUpdateRequired = true
    dagor.debug("ignore reinitSlotbars: updates suspended")
    return
  }

  isSlotbarUpdateRequired = false
  if (_isReinitSlotbarsInProgress)
  {
    ::script_net_assert_once("reinitAllSlotbars recursion", "reinitAllSlotbars: recursive call found")
    return
  }

  _isReinitSlotbarsInProgress = true
  ::init_selected_crews(true)
  ::broadcastEvent("CrewsListChanged")
  _isReinitSlotbarsInProgress = false
}

g_crews_list.suspendSlotbarUpdates <- function suspendSlotbarUpdates()
{
  isSlotbarUpdateSuspended = true
}

g_crews_list.flushSlotbarUpdate <- function flushSlotbarUpdate()
{
  isSlotbarUpdateSuspended = false
  if (isSlotbarUpdateRequired)
    reinitSlotbars()
}

g_crews_list.onEventProfileUpdated <- function onEventProfileUpdated(p)
{
  if (p.transactionType == ::EATT_UPDATE_ENTITLEMENTS)
    ::update_shop_countries_list()

  if (::g_login.isProfileReceived() && !::isInArray(p.transactionType, ignoreTransactions)
      && invalidate() && !::disable_network())
    reinitSlotbars()
}

g_crews_list.onEventUnlockedCountriesUpdate <- function onEventUnlockedCountriesUpdate(p)
{
  ::update_shop_countries_list()
  if (::g_login.isProfileReceived() && invalidate())
    reinitSlotbars()
}

g_crews_list.onEventOverrideSlotbarChanged <- function onEventOverrideSlotbarChanged(p)
{
  invalidate(true)
}

g_crews_list.onEventLobbyIsInRoomChanged <- function onEventLobbyIsInRoomChanged(p)
{
  if (isSlotbarOverrided)
    invalidate()
}

g_crews_list.onEventSessionDestroyed <- function onEventSessionDestroyed(p)
{
  invalidate() //in session can be overrided slotbar. Also slots can be locked after the battle.
}

g_crews_list.onEventSignOut <- function onEventSignOut(p)
{
  isSlotbarUpdateSuspended = false
}

g_crews_list.onEventLoadingStateChange <- function onEventLoadingStateChange(p)
{
  isSlotbarUpdateSuspended = false
}

g_crews_list.makeCrewsCountryData <- function makeCrewsCountryData(country)
{
  return {
    country = country
    crews = []
  }
}

g_crews_list.addCrewToCountryData <- function addCrewToCountryData(countryData, crewId, countryId, crewUnitName)
{
  countryData.crews.append({
    id = crewId
    idCountry = countryId
    idInCountry = countryData.crews.len()
    country = countryData.country

    aircraft = crewUnitName
    isEmpty = ::u.isEmpty(crewUnitName) ? 1 : 0

    trainedSpec = {}
    trained = []
    skillPoints = 0
    lockedTillSec = 0
    isLocked = 0
  })
}

g_crews_list.getMissionEditSlotbarBlk <- function getMissionEditSlotbarBlk(missionName)
{
  local misBlk = ::get_mission_meta_info(missionName)
  local editSlotbar = ::getTblValue("editSlotbar", misBlk)
  //override slotbar does not support keepOwnUnits atm.
  if (!::u.isDataBlock(editSlotbar) || editSlotbar.keepOwnUnits)
    return null
  return editSlotbar
}

g_crews_list.calcSlotbarOverrideByMissionName <- function calcSlotbarOverrideByMissionName(missionName)
{
  local res = null
  local editSlotbar = getMissionEditSlotbarBlk(missionName)
  if (!editSlotbar)
    return res

  res = []
  local crewId = -1 //negative crews are invalid, so we prevent any actions with such crews.
  foreach(country in ::shopCountriesList)
  {
    local countryBlk = editSlotbar?[country]
    if (!::u.isDataBlock(countryBlk) || !countryBlk.blockCount()
      || !::is_country_available(country))
      continue

    local countryData = ::g_crews_list.makeCrewsCountryData(country)
    res.append(countryData)
    for(local i = 0; i < countryBlk.blockCount(); i++)
    {
      local crewBlk = countryBlk.getBlock(i)
      ::g_crews_list.addCrewToCountryData(countryData, crewId--, res.len() - 1, crewBlk.getBlockName())
    }
  }
  if (!res.len())
    res = null
  return res
}

g_crews_list.getSlotbarOverrideCountriesByMissionName <- function getSlotbarOverrideCountriesByMissionName(missionName)
{
  local res = []
  local editSlotbar = getMissionEditSlotbarBlk(missionName)
  if (!editSlotbar)
    return res

  foreach(country in ::shopCountriesList)
  {
    local countryBlk = editSlotbar?[country]
    if (::u.isDataBlock(countryBlk) && countryBlk.blockCount()
      && ::is_country_available(country))
      res.append(country)
  }
  return res
}

::reinitAllSlotbars <- function reinitAllSlotbars()
{
  ::g_crews_list.reinitSlotbars()
}

::subscribe_handler(::g_crews_list, ::g_listener_priority.DEFAULT_HANDLER)
::g_script_reloader.registerPersistentData("g_crews_list", ::g_crews_list, [ "isSlotbarOverrided" ])
