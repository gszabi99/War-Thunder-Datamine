import "%sqStdLibs/helpers/u.nut" as u
from "%appGlobals/ranks_common_shared.nut" import getWpcostUnitClass, getMaxEconomicRank, calcBattleRatingFromRank
from "string" import format
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/events/eventsConsts.nut" import UnitRelevance

let { g_team } = require("%scripts/teams.nut")
let { getUnitTypeByText } = require("%scripts/unit/unitInfo.nut")
let { maxCountryRank } = require("%scripts/ranks.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { getEvent, getEventDifficulty } = require("%scripts/events/eventsState.nut")








let fullTeamsList = [Team.A, Team.B]
let allUnitTypesMask = (ES_UNIT_TYPE_AIRCRAFT | ES_UNIT_TYPE_TANK | ES_UNIT_TYPE_SHIP | ES_UNIT_TYPE_BOAT)

function getTeamName(teamCode) {
  return g_team.getTeamByCode(teamCode).name
}

function getTeamData(eventData, team) {
  return eventData?[getTeamName(team)]
}
function isTeamDataPlayable(teamData) {
  return (teamData?.maxTeamSize ?? 1) > 0
}
function isTeamsEqual(teamAData, teamBData) {
  if (teamAData.len() != teamBData.len())
    return false

  foreach (key, value in teamAData) {
    if (key == "forcedCountry")
      continue

    if (!(key in teamBData) || !u.isEqual(value, teamBData[key]))
      return false
  }

  return true
}
function getCountries(teamData) {
  if (!teamData)
    return []
  return teamData.countries
}
function getAlowedCrafts(teamData, roomSpecialRules = null) {
  local res = teamData?.allowedCrafts ?? []
  if (roomSpecialRules) {
    res = clone res
    res.extend(roomSpecialRules)
  }
  return res
}
function getForbiddenCrafts(teamData) {
  return teamData?.forbiddenCrafts ?? []
}
function getRequiredCrafts(teamData) {
  return teamData?.requiredCrafts ?? []
}
function hasUnitRequirements(teamData) {
  return getRequiredCrafts(teamData).len() > 0
}
function getBaseUnitTypefromRule(rule, checkAllAvailable) {
  if (!("class" in rule))
    return ES_UNIT_TYPE_INVALID
  if (checkAllAvailable)
    foreach (key in ["name", "type"])
      if (key in rule)
        return ES_UNIT_TYPE_INVALID
  return getUnitTypeByText(rule["class"])
}
function getMatchingUnitType(unit) {
  return unit?.unitType.getMatchingUnitType() ?? ES_UNIT_TYPE_INVALID
}
function getMinCraftsToPlay(event) {
  return event?.minCraftsToPlay ?? 1
}
function initSidesOnce(event) {
  if (event?._isSidesInited)
    return

  local sides = []
  foreach (team in fullTeamsList)
    if (isTeamDataPlayable(getTeamData(event, team)))
      sides.append(team)

  let isFreeForAll = event?.ffa ?? false
  local isSymmetric = isFreeForAll || (event?.isSymmetric ?? false) || sides.len() <= 1
  
  if (!isSymmetric) {
    let teamDataA = getTeamData(event, sides[0])
    let teamDataB = getTeamData(event, sides[1])
    if (teamDataA == null || teamDataB == null) {
      event.visible = false
      event.disabled = true
      event.invalid <- true
      log("[eventTeamsInfo] initSidesOnce finded invalid event", event)
    }
    else
      isSymmetric = isSymmetric || isTeamsEqual(teamDataA, teamDataB)
  }
  if (isSymmetric && sides.len() > 1)
    sides = [sides[0]]

  event.sidesList <- sides
  event.isSymmetric <- isSymmetric
  event.isFreeForAll <- isFreeForAll
  event._isSidesInited <- true
}
function getSidesList(event = null) {
  if (!event)
    return fullTeamsList
  initSidesOnce(event)
  return event.sidesList
}
function isEventSymmetricTeams(event) {
  initSidesOnce(event)
  return event.isSymmetric
}
function isEventFreeForAll(event) {
  initSidesOnce(event)
  return event.isFreeForAll
}
function getCountriesByTeams(event) {
  let res = []
  foreach (team in getSidesList(event))
    res.append(getCountries(getTeamData(event, team)))
  return res
}
function isCountryAvailable(event, country) {
  let sidesList = getSidesList(event)
  foreach (team in sidesList) {
    let countries = getTeamData(event, team)?.countries
    if (countries && isInArray(country, countries))
      return true
  }
  return false
}
function getAvailableCountriesByEvent(event) {
  let result = []
  foreach (country in shopCountriesList)
    if (isCountryAvailable(event, country))
      result.append(country)

  return result.len() < shopCountriesList.len() ? result : []
}



function countAvailableUnitTypes(teamDataByTeamName) {
  local resMask = 0
  foreach (team in getSidesList()) {
    let teamData = getTeamData(teamDataByTeamName, team)
    if (!teamData || !isTeamDataPlayable(teamData))
      continue

    local teamUnitTypes = 0
    foreach (rule in getAlowedCrafts(teamData)) {
      local unitType = getBaseUnitTypefromRule(rule, false)
      if ("name" in rule) {
        let unit = getAircraftByName(rule.name)
        if (unit)
          unitType = getMatchingUnitType(unit)
      }
      if (unitType >= 0)
        teamUnitTypes = teamUnitTypes | (1 << unitType)
      if (unitType == ES_UNIT_TYPE_SHIP)
        teamUnitTypes = teamUnitTypes | (1 << ES_UNIT_TYPE_BOAT)
    }
    if (!teamUnitTypes)
      teamUnitTypes = allUnitTypesMask

    foreach (rule in getForbiddenCrafts(teamData)) {
      let unitType = getBaseUnitTypefromRule(rule, true)
      if (unitType >= 0)
        teamUnitTypes = teamUnitTypes & ~(1 << unitType)
      if (unitType == ES_UNIT_TYPE_SHIP)
        teamUnitTypes = teamUnitTypes & ~(1 << ES_UNIT_TYPE_BOAT)
    }

    resMask = resMask | teamUnitTypes
    if (resMask == allUnitTypesMask)
      break
  }
  return resMask
}
function getUnitTypesByTeamDataAndName(teamData, teamName) {
  if (teamData == null)
    return allUnitTypesMask
  return countAvailableUnitTypes({ [teamName] = teamData })
}
function countRequiredUnitTypesMaskByTeamData(teamData) {
  local res = 0
  let reqCrafts = getRequiredCrafts(teamData)
  foreach (rule in reqCrafts) {
    local unitType = getBaseUnitTypefromRule(rule, false)
    if ("name" in rule) {
      let unit = getAircraftByName(rule.name)
      if (unit)
        unitType = getMatchingUnitType(unit)
    }
    if (unitType != ES_UNIT_TYPE_INVALID)
      res = res | (1 << unitType)
    if (unitType == ES_UNIT_TYPE_SHIP)
      res = res | (1 << ES_UNIT_TYPE_BOAT)
  }
  return res
}
function countRequiredUnitTypesMask(event) {
  local res = 0
  foreach (team in getSidesList()) {
    let teamData = getTeamData(event, team)
    if (!teamData || !isTeamDataPlayable(teamData))
      continue

    res = res | countRequiredUnitTypesMaskByTeamData(teamData)
  }
  return res
}
function getEventUnitTypesMask(event) {
  if (!("unitTypesMask" in event))
    event.unitTypesMask <- countAvailableUnitTypes(event)
  return event.unitTypesMask
}
function getEventRequiredUnitTypesMask(event) {
  if (!("reqUnitTypesMask" in event))
    event.reqUnitTypesMask <- countRequiredUnitTypesMask(event)
  return event.reqUnitTypesMask
}
function isUnitTypeAvailable(event, unitType) {
  return (getEventUnitTypesMask(event) & (1 << unitType)) != 0
}
function isUnitTypeRequired(event, unitType, valueWhenNoRequiredUnits = false) {
  let reqUnitTypesMask = getEventRequiredUnitTypesMask(event)
  return reqUnitTypesMask != 0 ? ((reqUnitTypesMask & (1 << unitType)) != 0) : valueWhenNoRequiredUnits
}
function getEDiffByEvent(event) {
  if (event == null)
    return getEventDifficulty(event).getEdiff()

  if (!("ediff" in event)) {
    let difficulty = getEventDifficulty(event)
    event.ediff <- difficulty.getEdiffByUnitMask(getEventUnitTypesMask(event))
  }
  return event.ediff
}
function isUnitMatchesRule(unit, rulesList, defReturn = false, ediff = -1) {
  if (rulesList.len() <= 0)
    return defReturn

  if (u.isString(unit))
    unit = getAircraftByName(unit)
  if (!unit)
    return false

  let maxEconomicRank = getMaxEconomicRank()
  foreach (rule in rulesList) {
    if ("name" in rule) {
      if (rule.name == unit.name)
        return true
      continue
    }

    if ("mranks" in rule) {
      let unitMRank = ediff != -1 ? unit.getEconomicRank(ediff) : 0
      if (unitMRank < (rule.mranks?.min ?? 0) || (rule.mranks?.max ?? maxEconomicRank) < unitMRank)
        continue
    }

    if (("ranks" in rule)
        && (unit.rank < (rule.ranks?.min ?? 0) || (rule.ranks?.max ?? maxCountryRank.get()) < unit.rank))
      continue

    let unitType = getBaseUnitTypefromRule(rule, false)
    if (unitType != ES_UNIT_TYPE_INVALID && unitType != getMatchingUnitType(unit))
      continue
    if (("type" in rule) && (getWpcostUnitClass(unit.name) != $"exp_{rule.type}"))
      continue

    return true
  }
  return false
}
function isUnitAllowedByTeamData(teamData, airName, ediff = -1) {
  let unit = getAircraftByName(airName)
  if (!unit || unit.disableFlyout)
    return false
  if (!isInArray(unit.shopCountry, getCountries(teamData)))
    return false

  let airInAllowedList = isUnitMatchesRule(unit, getAlowedCrafts(teamData), true, ediff)
  let airInForbidenList = isUnitMatchesRule(unit, getForbiddenCrafts(teamData), false, ediff)
  return !airInForbidenList && airInAllowedList
}
function isAirRequiredAndAllowedByTeamData(teamData, airName, ediff) {
  return (isUnitMatchesRule(airName, getRequiredCrafts(teamData), true, ediff)
      && isUnitAllowedByTeamData(teamData, airName, ediff))
}
function isUnitAllowed(event, team, airName) {
  let teamData = getTeamData(event, team)
  let ediff = getEDiffByEvent(event)
  return teamData ? isUnitAllowedByTeamData(teamData, airName, ediff) : false
}
function isUnitAllowedForEvent(event, unit) {
  foreach (team in getSidesList(event))
    if (isUnitAllowed(event, team, unit.name))
      return true

  return false
}
function checkUnitRelevanceForEvent(eventId, unit) {
  let event = getEvent(eventId)
  return (!event || !unit) ? UnitRelevance.NONE
   : isUnitAllowedForEvent(event, unit) ? UnitRelevance.BEST
   : isUnitTypeAvailable(event, unit.unitType.esUnitType) ? UnitRelevance.MEDIUM
   : UnitRelevance.NONE
}
function getMaxBrText(event) {
  local maxBR = -1
  foreach (team in getSidesList(event)) {
    let teamData = getTeamData(event, team)
    if (!teamData || !isTeamDataPlayable(teamData))
      continue
    foreach (rule in getAlowedCrafts(teamData)) {
      if ("mranks" not in rule)
        continue
      maxBR = max(maxBR,  rule.mranks?.max ?? getMaxEconomicRank())
    }
    if (maxBR == -1)
      maxBR = getMaxEconomicRank()
    foreach (rule in getForbiddenCrafts(teamData)) {
      if (rule?.mranks.max == null && rule?.mranks.min == null)
        continue
      if ((rule.mranks?.max ?? getMaxEconomicRank()) == maxBR)
        maxBR = (rule.mranks?.min ?? 1) - 1
    }
  }
  return  loc("mainmenu/maxBR", { br = format("%.1f", calcBattleRatingFromRank(maxBR)) })
}
return {
  allUnitTypesMask
  getTeamData
  isTeamDataPlayable
  getTeamName
  getCountries
  getAlowedCrafts
  getForbiddenCrafts
  getRequiredCrafts
  hasUnitRequirements
  getMinCraftsToPlay
  initSidesOnce
  getSidesList
  isEventSymmetricTeams
  isEventFreeForAll
  getCountriesByTeams
  isCountryAvailable
  getAvailableCountriesByEvent
  countAvailableUnitTypes
  getUnitTypesByTeamDataAndName
  getEventUnitTypesMask
  getEventRequiredUnitTypesMask
  isUnitTypeAvailable
  isUnitTypeRequired
  getEDiffByEvent
  isUnitMatchesRule
  isUnitAllowedByTeamData
  isAirRequiredAndAllowedByTeamData
  isUnitAllowed
  isUnitAllowedForEvent
  checkUnitRelevanceForEvent
  getMaxBrText
}
