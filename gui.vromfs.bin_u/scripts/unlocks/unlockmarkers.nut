from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { getMarkerUnlocks } = require("%scripts/unlocks/personalUnlocks.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { isEqualSimple } = require("%sqstd/underscore.nut")
let { getBitStatus } = require("%scripts/unit/unitStatus.nut")
let seenList = require("%scripts/seen/seenList.nut").get(SEEN.UNLOCK_MARKERS)
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let { getUnlockConditions } = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { canDoUnlock } = require("%scripts/unlocks/unlocksModule.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { bit_unit_status } = require("%scripts/unit/unitInfo.nut")

let cacheByEdiff = {}
local curUnlockIds = null // array of strings

let isUnitUnlocked = @(u) (bit_unit_status.locked & getBitStatus(u)) == 0

function getUnitsByUnlock(unlockBlk, ediff) {
  let modeBlk = unlockBlk?.mode
  if (!modeBlk)
    return []

  let conditions = getUnlockConditions(modeBlk)
  let unitCond = conditions.findvalue(@(c) ["playerUnit", "offenderUnit"].contains(c.type))
  if (unitCond)
    return (unitCond % "class")
      .map(@(n) getAircraftByName(n))
      .filter(@(u) u != null && isUnitUnlocked(u))

  local units = null

  let countryCond = conditions.findvalue(@(c) c.type == "playerCountry")
  if (countryCond) {
    let countries = countryCond % "country"
    units = getAllUnits().filter(@(u) countries.contains(u.shopCountry))
  }

  let typeCond = conditions.findvalue(@(c) ["playerType", "offenderType"].contains(c.type))
  if (typeCond) {
    let types = typeCond % "unitType"
    units = (units ?? getAllUnits()).filter(@(u) types.contains(u.unitType.tag))
  }

  let tagConds = conditions.filter(@(c) ["playerTag", "offenderTag"].contains(c.type))
  foreach (tagCond in tagConds) {
    let tags = tagCond % "tag"
    units = (units ?? getAllUnits()).filter(@(u) u.tags.findindex(@(tag) tags.contains(tag)) != null)
  }

  let rankCond = conditions.findvalue(@(c) ["playerUnitRank", "offenderUnitRank"].contains(c.type))
  if (rankCond) {
    let minRank = rankCond?.minRank ?? 0
    let maxRank = rankCond?.maxRank ?? 0
    units = (units ?? getAllUnits()).filter(@(u) u.rank >= minRank && (maxRank == 0 || u.rank <= maxRank))
  }

  let mRankCond = conditions.findvalue(@(c) ["playerUnitMRank", "offenderUnitMRank"].contains(c.type))
  if (mRankCond) {
    let minMRank = mRankCond?.minMRank ?? 0
    let maxMRank = mRankCond?.maxMRank ?? 0
    units = (units ?? getAllUnits()).filter(function(unit) {
      let mRank = unit.getEconomicRank(ediff)
      return mRank >= minMRank && (maxMRank == 0 || mRank <= maxMRank)
    })
  }

  return units?.filter(@(u) isUnitUnlocked(u)) ?? []
}

function invalidateCache() {
  if (!curUnlockIds)
    return

  cacheByEdiff.clear()
  curUnlockIds = null
  seenList.onListChanged()
  broadcastEvent("UnlockMarkersCacheInvalidate")
}

function getDoableUnlocks() {
  return getMarkerUnlocks().filter(@(u) canDoUnlock(u))
}

function checkUnlockMarkers() {
  if (!curUnlockIds)
    return

  let unlockIds = getDoableUnlocks().map(@(u) u.id)
  if (isEqualSimple(unlockIds, curUnlockIds))
    return

  invalidateCache()
}

function cache(ediff) {
  if (ediff == null)
    return null

  if (ediff in cacheByEdiff || !::g_login.isLoggedIn())
    return cacheByEdiff?[ediff]

  let curCache = {
    unlockIds = []
    unitNameToUnlockId = {}
    countries = {}
  }

  let doableUnlocks = getDoableUnlocks()
  foreach (unlockBlk in doableUnlocks) {
    let units = getUnitsByUnlock(unlockBlk, ediff)
    if (units.len() == 0)
      continue

    curCache.unlockIds.append(unlockBlk.id)

    foreach (unit in units) {
      curCache.unitNameToUnlockId[unit.name] <- unlockBlk.id

      if (unit.shopCountry not in curCache.countries)
        curCache.countries[unit.shopCountry] <- { unlockIds = [] }

      let country = curCache.countries[unit.shopCountry]
      if (!country.unlockIds.contains(unlockBlk.id))
        country.unlockIds.append(unlockBlk.id)

      if (unit.unitType.armyId not in country)
        country[unit.unitType.armyId] <- []

      let army = country[unit.unitType.armyId]
      if (!army.contains(unlockBlk.id))
        army.append(unlockBlk.id)
    }
  }

  curUnlockIds = doableUnlocks.map(@(u) u.id)
  cacheByEdiff[ediff] <- curCache
  return curCache
}

function hasActiveUnlock(unlockId, ediff) {
  return cache(ediff)?.unlockIds.contains(unlockId)
}

function getUnitListByUnlockId(unlockId) {
  let modeBlk = getUnlockById(unlockId)?.mode
  if (!modeBlk)
    return []

  let conditions = getUnlockConditions(modeBlk)
  let unitCond = conditions.findvalue(@(c) ["playerUnit", "offenderUnit"].contains(c.type))
  if (!unitCond)
    return []

  return (unitCond % "class").map(@(n) getAircraftByName(n))
}

function hasMarkerByUnitName(unitName, ediff) {
  return unitName in cache(ediff)?.unitNameToUnlockId
}

function getUnlockIdByUnitName(unitName, ediff) {
  return cache(ediff)?.unitNameToUnlockId[unitName] ?? ""
}

function getUnlockIds(ediff) {
  return cache(ediff)?.unlockIds ?? []
}

function getUnlockIdsByCountry(country, ediff) {
  return cache(ediff)?.countries[country].unlockIds ?? []
}

function getUnlockIdsByArmyId(country, armyId, ediff) {
  return cache(ediff)?.countries[country][armyId] ?? []
}

seenList.setListGetter(@() getUnlockIds(getShopDiffCode()))

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) invalidateCache()
  InitConfigs = @(_p) invalidateCache()
  ShopDiffCodeChanged = @(_p) seenList.onListChanged()
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