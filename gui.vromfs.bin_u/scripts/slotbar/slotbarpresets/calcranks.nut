from "math" import ceil
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *

local MINIMUM_MRANK = 0

let unitClassToString = {
  [ES_UNIT_TYPE_HUMAN] = "human",
  [ES_UNIT_TYPE_HELICOPTER] = "helicopter",
  [ES_UNIT_TYPE_TANK] = "tank",
  [ES_UNIT_TYPE_AIRCRAFT] = "aircraft",
  [ES_UNIT_TYPE_SHIP] = "ship",
  [ES_UNIT_TYPE_BOAT] = "ship"
}

let isOutOfRange = @(value, range) value < range.min || value > range.max

function filterMatch(filter, unit) {
  foreach (filterType, filterValue in filter) {
    if (filterType == "name" && filterValue != unit.name)
      return false
    if (filterType == "rank" && isOutOfRange(unit.rank, filterValue))
      return false
    if (filterType == "mrank" && isOutOfRange(unit.mrank, filterValue))
      return false
    if (filterType == "class" && filterValue != unit.craftClass)
      return false
    if (filterType == "type" && filterValue != unit.craftType)
      return false
  }
  return true
}

function filterCrafts(crafts, country, team_info) {
  let filtered = []
  let { requiredCraftsAll = [], requiredCraftsAny = [], allowedCrafts = [], forbiddenCrafts = [] } = team_info

  foreach (req_filter in requiredCraftsAll) {
    local hasRequired = false
    foreach (craft in crafts) {
      if (craft.country == country && filterMatch(req_filter, craft)) {
        hasRequired = true
        break
      }
    }
    if (!hasRequired)
      return filtered
  }

  if (requiredCraftsAny.len() > 0) {
    local hasRequired = false
    foreach (req_filter in requiredCraftsAny) {
      foreach (craft in crafts) {
        if (craft.country == country && filterMatch(req_filter, craft)) {
          hasRequired = true
          break
        }
      }
      if (hasRequired)
        break
    }
    if (!hasRequired)
      return filtered
  }

  foreach (craft in crafts) {
    if (craft.country != country)
      continue

    local pass = allowedCrafts.len() == 0
    if (!pass) {
      foreach (allowed in allowedCrafts) {
        if (filterMatch(allowed, craft)) {
          pass = true
          break
        }
      }
    }
    if (!pass)
      continue

    foreach (forbidden in forbiddenCrafts) {
      if (filterMatch(forbidden, craft)) {
        pass = false
        break
      }
    }

    if (pass)
      filtered.append(craft)
  }

  return filtered
}

function specialShipsFilter(crafts) {
  local maxShipMrank = MINIMUM_MRANK
  foreach (craft in crafts)
    if (craft.craftClass == "ship" && craft.mrank > maxShipMrank)
      maxShipMrank = craft.mrank
  let airLimit = maxShipMrank + 1

  local i = crafts.len() - 1
  while (i >= 0) {
    if (crafts[i].craftClass == "aircraft" && crafts[i].mrank > airLimit)
      crafts.remove(i)
    i--
  }
}

function calcCraftsRanks(crafts, rankCalcMode) {
  crafts.sort(@(a, b) b.mrank <=> a.mrank)
  let mrank0 = crafts[0].mrank

  if (rankCalcMode == "average") {
    local mrank1 = mrank0
    local mrank2 = mrank0
    local mrankf = mrank0.tofloat()

    if (crafts.len() > 1) {
      mrank1 = max(crafts[1].mrank, mrank0 - 2, MINIMUM_MRANK)
      mrankf = ceil(mrank0 * 0.5 + mrank1 * 0.5)
    }

    if (crafts.len() > 2) {
      mrank2 = max(crafts[2].mrank, mrank0 - 2, MINIMUM_MRANK)
      mrankf = ceil(mrank0 * 0.5 + mrank1 * 0.25 + mrank2 * 0.25)
    }

    return mrankf.tointeger()
  }

  return mrank0
}

function calculateBR(userData, gameMode) {
  let crafts = []
  foreach (craft in userData.crafts)
    crafts.append({
      country    = userData.country
      craftType  = craft.craftType
      mrank      = craft.mrank
      rank       = craft.rank
      name       = craft.name
      craftClass = unitClassToString[craft.unitTypeCode]
    })

  let filtered = filterCrafts(crafts, userData.country, gameMode.teamA)

  if (filtered.len() == 0)
    return -1

  if (gameMode?.name.contains("ship"))
    specialShipsFilter(filtered)

  if (filtered.len() == 0)
    return -1

  return calcCraftsRanks(filtered, gameMode.rankCalcMode)
}

return {
  calculateBR
}
