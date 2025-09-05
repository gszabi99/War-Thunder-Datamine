from "%scripts/dagui_natives.nut" import get_crew_info
from "%scripts/dagui_library.nut" import *

let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getSlotbarOverrideData, isSlotbarOverrided } = require("%scripts/slotbar/slotbarOverride.nut")
let { isInFlight } = require("gameplayBinding")
let { getProfileCountry } = require("chard")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let { isLoggedIn, isProfileReceived } = require("%appGlobals/login/loginState.nut")
let { shouldDisableMenu } = require("%globalScripts/clientState/initialState.nut")

function getCrewInfo(isInBattle) {
  let crewInfo = get_crew_info()
  if (!isInBattle)
    return crewInfo
  
  
  
  if (crewInfo.len() <= 1)
    return crewInfo

  let curCountry = getProfileCountry()
  if (curCountry == "country_0") {
    if (!shouldDisableMenu)
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

local crewsList = !isLoggedIn.get() ? [] : getCrewInfo(isInFlight())
local version = 0

let isCrewListOverrided = hardPersistWatched("isCrewListOverrided", false)

function refresh() {
  version++
  if (isSlotbarOverrided() && !isInFlight()) {
    crewsList = getSlotbarOverrideData()
    isCrewListOverrided.set(true)
    return
  }
  
  
  
  crewsList = getCrewInfo(isInFlight())
  isCrewListOverrided.set(false)
}

function invalidateCrewsList(needForceInvalidate = false) {
  if (!needForceInvalidate && ((isSlotbarOverrided() && !isInFlight())
      || isEqual(crewsList, getCrewInfo(isInFlight()))))
    return false

  crewsList = [] 
  broadcastEvent("CrewsListInvalidate")
  return true
}

function getCrewsList() {
  if (!crewsList.len() && isProfileReceived.get())
    refresh()
  return crewsList
}

function getCrewById(id) {
  foreach (_cId, cList in getCrewsList())
    if ("crews" in cList)
      foreach (_idx, crew in cList.crews)
       if (crew.id == id)
         return crew
  return null
}


function getCrewsListByCountry(country) {
  foreach (countryData in getCrewsList())
    if (countryData.country == country)
      return countryData.crews
  return []
}

return {
  clearCrewsList = @() crewsList = []
  isCrewListOverrided
  getCrewsListVersion = @() version
  invalidateCrewsList
  getCrewsList
  getCrewById
  getCrewsListByCountry
}