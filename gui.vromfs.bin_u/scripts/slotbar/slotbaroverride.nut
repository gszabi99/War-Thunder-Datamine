local { isDataBlock, isEmpty, isEqual } = require("sqStdLibs/helpers/u.nut")

local overrrideSlotbarMissionName = persist("overrrideSlotbarMissionName", @() ::Watched("")) //recalc slotbar only on mission change
local overrideSlotbar = persist("overrideSlotbar", @() ::Watched(null)) //null or []
local userSlotbarCountry = persist("userSlotbarCountry", @() ::Watched("")) //for return user country after reset override slotbar

overrideSlotbar.subscribe(@(_) ::broadcastEvent("OverrideSlotbarChanged"))

local makeCrewsCountryData = @(country) { country = country, crews = [] }

local function addCrewToCountryData(countryData, crewId, countryId, crewUnitName) {
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

local function getMissionEditSlotbarBlk(missionName) {
  local misBlk = ::get_mission_meta_info(missionName)
  local editSlotbar = misBlk?.editSlotbar
  //override slotbar does not support keepOwnUnits atm.
  if (!isDataBlock(editSlotbar) || editSlotbar.keepOwnUnits)
    return null
  return editSlotbar
}

local function calcSlotbarOverrideByMissionName(missionName) {
  local res = null
  local editSlotbar = getMissionEditSlotbarBlk(missionName)
  if (!editSlotbar)
    return res

  res = []
  local crewId = -1 //negative crews are invalid, so we prevent any actions with such crews.
  foreach(country in ::shopCountriesList)
  {
    local countryBlk = editSlotbar?[country]
    if (!isDataBlock(countryBlk) || !countryBlk.blockCount()
      || !::is_country_available(country))
      continue

    local countryData = makeCrewsCountryData(country)
    res.append(countryData)
    for(local i = 0; i < countryBlk.blockCount(); i++)
    {
      local crewBlk = countryBlk.getBlock(i)
      addCrewToCountryData(countryData, crewId--, res.len() - 1, crewBlk.getBlockName())
    }
  }
  if (!res.len())
    res = null
  return res
}

local function getSlotbarOverrideCountriesByMissionName(missionName) {
  local res = []
  local editSlotbar = getMissionEditSlotbarBlk(missionName)
  if (!editSlotbar)
    return res

  foreach(country in ::shopCountriesList)
  {
    local countryBlk = editSlotbar?[country]
    if (isDataBlock(countryBlk) && countryBlk.blockCount()
      && ::is_country_available(country))
      res.append(country)
  }
  return res
}

local function getSlotbarOverrideData(missionName = "") {
  if (missionName == "" || missionName == overrrideSlotbarMissionName.value)
    return overrideSlotbar.value

  return calcSlotbarOverrideByMissionName(missionName)
}

local isSlotbarOverrided = @(missionName = "") getSlotbarOverrideData(missionName) != null

local function updateOverrideSlotbar(missionName) {
  if (missionName == overrrideSlotbarMissionName.value)
    return
  overrrideSlotbarMissionName(missionName)

  local newOverrideSlotbar = calcSlotbarOverrideByMissionName(missionName)
  if (isEqual(overrideSlotbar.value, newOverrideSlotbar))
    return

  if (!isSlotbarOverrided())
    userSlotbarCountry(::get_profile_country_sq())
  overrideSlotbar(newOverrideSlotbar)
}

local function resetSlotbarOverrided() {
  overrrideSlotbarMissionName("")
  overrideSlotbar(null)
  if (userSlotbarCountry.value != "")
    ::switch_profile_country(userSlotbarCountry.value)
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