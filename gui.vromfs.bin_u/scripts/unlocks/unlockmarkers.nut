local { getMarkerUnlocks } = require("scripts/unlocks/personalUnlocks.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { isEqualSimple } = require("%sqstd/underscore.nut")

local cacheByEdiff = {}
local curUnlockIds = null // array of strings

local function getUnitsByUnlock(unlockBlk, ediff) {
  local modeBlk = unlockBlk?.mode
  if (!modeBlk)
    return []

  local conditions = (modeBlk % "condition").extend(modeBlk % "visualCondition")
  local unitCond = conditions.findvalue(@(c) ["playerUnit", "offenderUnit"].contains(c.type))
  if (unitCond)
    return (unitCond % "class").map(@(n) ::getAircraftByName(n)).filter(@(u) u != null)

  local units = null

  local countryCond = conditions.findvalue(@(c) c.type == "playerCountry")
  if (countryCond) {
    local countries = countryCond % "country"
    units = ::all_units.filter(@(u) countries.contains(u.shopCountry))
  }

  local typeCond = conditions.findvalue(@(c) ["playerType", "offenderType"].contains(c.type))
  if (typeCond) {
    local types = typeCond % "unitType"
    units = (units ?? ::all_units).filter(@(u) types.contains(u.unitType.tag))
  }

  local tagConds = conditions.filter(@(c) ["playerTag", "offenderTag"].contains(c.type))
  foreach (tagCond in tagConds) {
    local tags = tagCond % "tag"
    units = (units ?? ::all_units).filter(@(u) u.tags.findindex(@(tag) tags.contains(tag)) != null)
  }

  local rankCond = conditions.findvalue(@(c) ["playerUnitRank", "offenderUnitRank"].contains(c.type))
  if (rankCond) {
    local minRank = rankCond?.minRank ?? 0
    local maxRank = rankCond?.maxRank ?? 0
    units = (units ?? ::all_units).filter(@(u) u.rank >= minRank && (maxRank == 0 || u.rank <= maxRank))
  }

  local mRankCond = conditions.findvalue(@(c) ["playerUnitMRank", "offenderUnitMRank"].contains(c.type))
  if (mRankCond) {
    local minMRank = mRankCond?.minMRank ?? 0
    local maxMRank = mRankCond?.maxMRank ?? 0
    units = (units ?? ::all_units).filter(function(unit) {
      local mRank = unit.getEconomicRank(ediff)
      return mRank >= minMRank && (maxMRank == 0 || mRank <= maxMRank)
    })
  }

  return units ?? []
}

local function invalidateCache() {
  cacheByEdiff.clear()
  curUnlockIds = null
  ::broadcastEvent("UnlockMarkersCacheInvalidate")
}

local function getDoableUnlocks() {
  return getMarkerUnlocks().filter(@(u) ::g_unlocks.canDo(u))
}

local function checkUnlockMarkers() {
  if (!curUnlockIds)
    return

  local unlockIds = getDoableUnlocks().map(@(u) u.id)
  if (isEqualSimple(unlockIds, curUnlockIds))
    return

  invalidateCache()
}

local function cache(ediff) {
  if (ediff == null)
    return null

  if (ediff in cacheByEdiff || !::g_login.isLoggedIn())
    return cacheByEdiff?[ediff]

  local curCache = {
    unitNameToUnlockId = {}
    countries = {}
  }

  local doableUnlocks = getDoableUnlocks()
  foreach (unlockBlk in doableUnlocks)
    foreach (unit in getUnitsByUnlock(unlockBlk, ediff)) {
      curCache.unitNameToUnlockId[unit.name] <- unlockBlk.id

      if (unit.shopCountry not in curCache.countries)
        curCache.countries[unit.shopCountry] <- {}

      curCache.countries[unit.shopCountry][unit.unitType.armyId] <- true
    }

  curUnlockIds = doableUnlocks.map(@(u) u.id)
  cacheByEdiff[ediff] <- curCache
  return curCache
}

local function hasMarker(ediff) {
  return (cache(ediff)?.unitNameToUnlockId.len() ?? 0) > 0
}

local function hasMarkerByCountry(country, ediff) {
  return country in cache(ediff)?.countries
}

local function hasMarkerByArmyId(country, armyId, ediff) {
  return armyId in cache(ediff)?.countries[country]
}

local function hasMarkerByUnitName(unitName, ediff) {
  return unitName in cache(ediff)?.unitNameToUnlockId
}

local function getUnlockIdByUnitName(unitName, ediff) {
  return cache(ediff)?.unitNameToUnlockId[unitName]
}

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(p) invalidateCache()
  SignOut = @(p) invalidateCache()
  LoginComplete = @(p) invalidateCache()
  InitConfigs = @(p) invalidateCache()
})

return {
  hasMarker
  hasMarkerByCountry
  hasMarkerByArmyId
  hasMarkerByUnitName
  getUnlockIdByUnitName
  checkUnlockMarkers
}