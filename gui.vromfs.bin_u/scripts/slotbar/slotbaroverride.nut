from "%scripts/dagui_natives.nut" import is_country_available
from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { isDataBlock, isEmpty, isEqual } = require("%sqStdLibs/helpers/u.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { isMissionExtrByName } = require("%scripts/missions/missionsUtils.nut")
let { getUrlOrFileMissionMetaInfo } = require("%scripts/missions/missionsUtilsModule.nut")
let { needShowOverrideSlotbar } = require("%scripts/events/eventInfo.nut")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { rnd } = require("dagor.random")

let overrideSlotbarMissionName = mkWatched(persist, "overrideSlotbarMissionName", "") 
let overrideSlotbar = persist("overrideSlotbar", @() { value = null }) 
let overrideSlotMods = persist("overrideSlotMods", @() { value = null }) 
let userSlotbarCountry = mkWatched(persist, "userSlotbarCountry", "") 
let selectedCountryByMissionName = hardPersistWatched("selectedCountryByMissionName", {})

let makeCrewsCountryData = @(country) { country = country, crews = [] }

function addCrewToCountryData(countryData, crewId, countryId, crewUnitName) {
  countryData.crews.append({
    id = crewId
    idCountry = countryId
    idInCountry = countryData.crews.len()
    country = countryData.country

    aircraft = crewUnitName
    isEmpty = isEmpty(crewUnitName) ? 1 : 0

    trainedSpec = {}
    trained = []
    skillPoints = 0
    lockedTillSec = 0
    isLocked = 0
  })
}

function getMissionEditSlotbarBlk(missionName) {
  let misBlk = getUrlOrFileMissionMetaInfo(missionName)
  let editSlotbar = misBlk?.editSlotbar
  
  if (!isDataBlock(editSlotbar) || editSlotbar.keepOwnUnits)
    return null
  return editSlotbar
}

function convertSlotbarDataBlock(blk) {
  let countries = {}
  for (local i = 0; i < blk.blockCount(); i++) {
    let countryBlk = blk.getBlock(i)
    let countryName = countryBlk.getBlockName()
    countries[countryName] <- []
    for (local n = 0; n < countryBlk.blockCount(); n++) {
      let crewBlk = countryBlk.getBlock(n)
      let crew = convertBlk(crewBlk)
      crew.crewName <- crewBlk.getBlockName()
      countries[countryName].append(crew)
    }
  }
  return countries
}

function calcSlotbarOverrideByMissionName(missionName, event = null) {
  let editSlotBarData = event?.mission_decl.editSlotbar ?? getMissionEditSlotbarBlk(missionName)
  let editSlotbar = isDataBlock(editSlotBarData) ? convertSlotbarDataBlock(editSlotBarData) : editSlotBarData

  if (!editSlotbar)
    return { ovrSlotBar = null, ovrSlotMod = null }

  let ovrSlotBar = []
  let ovrSlotMod = {}
  local crewId = -1 
  foreach (country in shopCountriesList) {
    let countryInfo = editSlotbar?[country]
    if (!countryInfo || !countryInfo.len()
      || !is_country_available(country))
      continue

    let countryData = makeCrewsCountryData(country)
    ovrSlotBar.append(countryData)
    ovrSlotMod[country] <- {}
    foreach (crName, crewData in countryInfo) {
      let { crewName = null, needToShowInEventWnd = true, addModification = [] } = crewData
      if (needToShowInEventWnd == false)
        continue

      let slotCrewName = crewName ?? crName
      addCrewToCountryData(countryData, crewId--, ovrSlotBar.len() - 1, slotCrewName)
      if (addModification.len() > 0)
        ovrSlotMod[country][slotCrewName] <- addModification
    }
  }

  if (!ovrSlotBar.len())
    return { ovrSlotBar = null, ovrSlotMod = null }

  return { ovrSlotBar, ovrSlotMod }
}

function getSlotbarOverrideCountriesByMissionName(missionName) {
  let res = []
  let editSlotbar = getMissionEditSlotbarBlk(missionName)
  if (!editSlotbar)
    return res

  foreach (country in shopCountriesList) {
    let countryBlk = editSlotbar?[country]
    if (isDataBlock(countryBlk) && countryBlk.blockCount()
      && is_country_available(country))
      res.append(country)
  }
  return res
}

function getSlotbarOverrideData(missionName = "", event = null) {
  if (missionName == "" || missionName == overrideSlotbarMissionName.get())
    return overrideSlotbar.value

  return calcSlotbarOverrideByMissionName(missionName, event).ovrSlotBar
}

function getSlotbarOverrideMods(missionName = "", event = null) {
  if (missionName == "" || missionName == overrideSlotbarMissionName.get())
    return overrideSlotMods.value

  return calcSlotbarOverrideByMissionName(missionName, event).ovrSlotMod
}

function selectCountryForCurrentOverrideSlotbar(country) {
  if (overrideSlotbarMissionName.get() == "")
    return
  selectedCountryByMissionName.mutate(@(v) v[overrideSlotbarMissionName.get()] <- country)
}

let isSlotbarOverrided = @(missionName = "", event = null)
  getSlotbarOverrideData(missionName, event) != null

function updateOverrideSlotbar(missionName, event = null) {
  if (missionName == overrideSlotbarMissionName.get())
    return
  overrideSlotbarMissionName.set(missionName)

  let { ovrSlotBar, ovrSlotMod } = calcSlotbarOverrideByMissionName(missionName, event)
  if (isEqual(overrideSlotbar.value, ovrSlotBar) && isEqual(overrideSlotMods.value, ovrSlotMod))
    return

  let profileCountry = profileCountrySq.get()
  if (!isSlotbarOverrided(missionName, event))
    userSlotbarCountry.set(profileCountry)

  overrideSlotbar.value = ovrSlotBar
  overrideSlotMods.value = ovrSlotMod
  broadcastEvent("OverrideSlotbarChanged")

  let missionCountry = selectedCountryByMissionName.get()?[missionName]
  if (missionCountry != null)
    switchProfileCountry(missionCountry)

  if (missionCountry == null && event != null) {
    let slotbarCountries = ovrSlotBar.map(@(c) c.country)
    let hasProfileCountry = slotbarCountries.contains(profileCountry)
    if (!hasProfileCountry) {
      let randomCountry = slotbarCountries[rnd() % slotbarCountries.len()]
      switchProfileCountry(randomCountry)
      selectCountryForCurrentOverrideSlotbar(randomCountry)
    }
  }
}

function resetSlotbarOverrided() {
  overrideSlotbarMissionName.set("")
  overrideSlotbar.value = null
  overrideSlotMods.value = null
  broadcastEvent("OverrideSlotbarChanged")
  if (userSlotbarCountry.get() != "")
    switchProfileCountry(userSlotbarCountry.get())
  userSlotbarCountry.set("")
}

function getEventSlotbarHint(event, country) {
  if (!needShowOverrideSlotbar(event))
    return ""

  let overrideSlotbarData = getSlotbarOverrideData(events.getEventMission(event.name), event)
  if ((overrideSlotbarData?.len() ?? 0) == 0)
    return ""

  let crews = overrideSlotbarData.findvalue(@(v) v.country == country)?.crews
  if (crews == null)
    return ""

  let hasNotUnlockedUnit = crews.findindex(function(c) {
    let unit = getAircraftByName(c.aircraft)
    return unit?.reqUnlock != null && !isUnlockOpened(unit.reqUnlock)
  }
  ) != null

  if (!hasNotUnlockedUnit)
    return ""

  return isMissionExtrByName(event.name)
    ? loc("event_extr/unlockUnits")
    : loc("event/unlockAircrafts")
}

return {
  getMissionEditSlotbarBlk
  getSlotbarOverrideCountriesByMissionName
  updateOverrideSlotbar
  getSlotbarOverrideData
  getSlotbarOverrideMods
  isSlotbarOverrided
  resetSlotbarOverrided
  getEventSlotbarHint
  selectCountryForCurrentOverrideSlotbar
}