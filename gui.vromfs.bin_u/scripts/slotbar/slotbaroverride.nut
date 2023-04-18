//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { isDataBlock, isEmpty, isEqual } = require("%sqStdLibs/helpers/u.nut")

let overrrideSlotbarMissionName = persist("overrrideSlotbarMissionName", @() Watched("")) //recalc slotbar only on mission change
let overrideSlotbar = persist("overrideSlotbar", @() Watched(null)) //null or []
let userSlotbarCountry = persist("userSlotbarCountry", @() Watched("")) //for return user country after reset override slotbar
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { switchProfileCountry, profileCountrySq } = require("%scripts/user/playerCountry.nut")

overrideSlotbar.subscribe(@(_) ::broadcastEvent("OverrideSlotbarChanged"))

let makeCrewsCountryData = @(country) { country = country, crews = [] }

let function addCrewToCountryData(countryData, crewId, countryId, crewUnitName) {
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

let function getMissionEditSlotbarBlk(missionName) {
  let misBlk = ::get_mission_meta_info(missionName)
  let editSlotbar = misBlk?.editSlotbar
  //override slotbar does not support keepOwnUnits atm.
  if (!isDataBlock(editSlotbar) || editSlotbar.keepOwnUnits)
    return null
  return editSlotbar
}

let function calcSlotbarOverrideByMissionName(missionName, event = null) {
  local res = null
  let gmEditSlotbar = event?.mission_decl.editSlotbar
  let editSlotbar = gmEditSlotbar ? ::build_blk_from_container(gmEditSlotbar) //!!!FIX ME Will be better to turn editSlotbar data block from missions config into table
    : getMissionEditSlotbarBlk(missionName)
  if (!editSlotbar)
    return res

  res = []
  local crewId = -1 //negative crews are invalid, so we prevent any actions with such crews.
  foreach (country in shopCountriesList) {
    let countryBlk = editSlotbar?[country]
    if (!isDataBlock(countryBlk) || !countryBlk.blockCount()
      || !::is_country_available(country))
      continue

    let countryData = makeCrewsCountryData(country)
    res.append(countryData)
    for (local i = 0; i < countryBlk.blockCount(); i++) {
      let crewBlk = countryBlk.getBlock(i)
      addCrewToCountryData(countryData, crewId--, res.len() - 1, crewBlk.getBlockName())
    }
  }
  if (!res.len())
    res = null
  return res
}

let function getSlotbarOverrideCountriesByMissionName(missionName) {
  let res = []
  let editSlotbar = getMissionEditSlotbarBlk(missionName)
  if (!editSlotbar)
    return res

  foreach (country in shopCountriesList) {
    let countryBlk = editSlotbar?[country]
    if (isDataBlock(countryBlk) && countryBlk.blockCount()
      && ::is_country_available(country))
      res.append(country)
  }
  return res
}

let function getSlotbarOverrideData(missionName = "", event = null) {
  if (missionName == "" || missionName == overrrideSlotbarMissionName.value)
    return overrideSlotbar.value

  return calcSlotbarOverrideByMissionName(missionName, event)
}

let isSlotbarOverrided = @(missionName = "", event = null) getSlotbarOverrideData(missionName, event) != null

let function updateOverrideSlotbar(missionName, event = null) {
  if (missionName == overrrideSlotbarMissionName.value)
    return
  overrrideSlotbarMissionName(missionName)

  let newOverrideSlotbar = calcSlotbarOverrideByMissionName(missionName, event)
  if (isEqual(overrideSlotbar.value, newOverrideSlotbar))
    return

  if (!isSlotbarOverrided())
    userSlotbarCountry(profileCountrySq.value)
  overrideSlotbar(newOverrideSlotbar)
}

let function resetSlotbarOverrided() {
  overrrideSlotbarMissionName("")
  overrideSlotbar(null)
  if (userSlotbarCountry.value != "")
    switchProfileCountry(userSlotbarCountry.value)
  userSlotbarCountry("")
}

return {
  getMissionEditSlotbarBlk
  getSlotbarOverrideCountriesByMissionName
  updateOverrideSlotbar
  getSlotbarOverrideData
  isSlotbarOverrided
  resetSlotbarOverrided
}