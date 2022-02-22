local { getMarkerUnlocks } = require("scripts/unlocks/personalUnlocks.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { isEqualSimple } = require("%sqstd/underscore.nut")
local { getBitStatus } = require("scripts/unit/unitStatus.nut")
local seenList = require("scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)
local { getShopDiffCode } = require("scripts/shop/shopDifficulty.nut")

local cacheByEdiff = {}
local curUnlockIds = null // array of strings

local isUnitUnlocked = @(u) (bit_unit_status.locked & getBitStatus(u)) == 0

local function getUnitsByUnlock(unlockBlk, ediff) {
  local modeBlk = unlockBlk?.mode
  if (!modeBlk)
    return []

  local conditions = (modeBlk % "condition").extend(modeBlk % "visualCondition")
  local unitCond = conditions.findvalue(@(c) ["playerUnit", "offenderUnit"].contains(c.type))
  if (unitCond)
    return (unitCond % "class")
      .map(@(n) ::getAircraftByName(n))
      .filter(@(u) u != null && isUnitUnlocked(u))

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

  return units?.filter(@(u) isUnitUnlocked(u)) ?? []
}

local function invalidateCache() {
  if (!curUnlockIds)
    return

  cacheByEdiff.clear()
  curUnlockIds = null
  seenList.onListChanged()
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
    unlockIds = []
    unitNameToUnlockId = {}
    countries = {}
  }

  local doableUnlocks = getDoableUnlocks()
  foreach (unlockBlk in doableUnlocks) {
    local units = getUnitsByUnlock(unlockBlk, ediff)
    if (units.len() == 0)
      continue

    curCache.unlockIds.append(unlockBlk.id)

    foreach (unit in units) {
      curCache.unitNameToUnlockId[unit.name] <- unlockBlk.id

      if (unit.shopCountry not in curCache.countries)
        curCache.countries[unit.shopCountry] <- { unlockIds = [] }

      local country = curCache.countries[unit.shopCountry]
      if (!country.unlockIds.contains(unlockBlk.id))
        country.unlockIds.append(unlockBlk.id)

      if (unit.unitType.armyId not in country)
        country[unit.unitType.armyId] <- []

      local army = country[unit.unitType.armyId]
      if (!army.contains(unlockBlk.id))
        army.append(unlockBlk.id)
    }
  }

  curUnlockIds = doableUnlocks.map(@(u) u.id)
  cacheByEdiff[ediff] <- curCache
  return curCache
}

local function hasActiveUnlock(unlockId, ediff) {
  return cache(ediff)?.unlockIds.contains(unlockId)
}

local function getUnitListByUnlockId(unlockId) {
  local modeBlk = ::g_unlocks.getUnlockById(unlockId)?.mode
  if (!modeBlk)
    return []

  local conditions = (modeBlk % "condition").extend(modeBlk % "visualCondition")
  local unitCond = conditions.findvalue(@(c) ["playerUnit", "offenderUnit"].contains(c.type))
  if (!unitCond)
    return []

  return (unitCond % "class").map(@(n) ::getAircraftByName(n))
}

local function hasMarkerByUnitName(unitName, ediff) {
  return unitName in cache(ediff)?.unitNameToUnlockId
}

local function getUnlockIdByUnitName(unitName, ediff) {
  return cache(ediff)?.unitNameToUnlockId[unitName]
}

local function getUnlockIds(ediff) {
  return cache(ediff)?.unlockIds ?? []
}

local function getUnlockIdsByCountry(country, ediff) {
  return cache(ediff)?.countries[country].unlockIds ?? []
}

local function getUnlockIdsByArmyId(country, armyId, ediff) {
  return cache(ediff)?.countries[country][armyId] ?? []
}

seenList.setListGetter(@() getUnlockIds(getShopDiffCode()))

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(p) invalidateCache()
  SignOut = @(p) invalidateCache()
  LoginComplete = @(p) invalidateCache()
  InitConfigs = @(p) invalidateCache()
  ShopDiffCodeChanged = @(p) seenList.onListChanged()
})

return {
  hasActiveUnlock
  getUnitListByUnlockId
  hasMarkerByUnitName
  getUnlockIdByUnitName
  checkUnlockMarkers
  getUnlockIds
  getUnlockIdsByCountry
  getUnlockIdsByArmyId
}