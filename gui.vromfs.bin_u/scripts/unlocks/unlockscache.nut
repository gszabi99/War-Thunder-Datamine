import "%scripts/g_listener_priority.nut" as g_listener_priority
import "packed" as packed
from "%scripts/unlocks/regionalUnlocks.nut" import regionalUnlocks
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "blkGetters" import get_unlocks_blk, get_personal_unlocks_blk
from "chard" import get_updated_unlocks_ids
from "dagor.workcycle" import deferOnce
from "%scripts/dagui_library.nut" import *





let INDEX_FIELDS = ["chapter", "battlePassSeason", "shouldMarkUnits", "manualOpen"]

let mkQuery = @(condition) {
  positions = packed.query($"[*] ? {condition}")
  blkIdxs = packed.query($"[*] ? {condition} select blkIdx")
}
let qAll = { blkIdxs = packed.query("[*] select blkIdx") }
let qByType = mkQuery("type == $type")
let qIdsByType = packed.query("[*] ? type == $type select id")
let qBlkIdxById = packed.query("[*] ? id == $id select blkIdx")
let qLastBlkIdxById = packed.query("[*] ? id == $id order by @key desc select blkIdx")
let qIds = packed.query("[*] select id")
let queriesByCondition = {}
let idParams = { id = null }

function hasId(unlock) {
  if (unlock?.id != null)
    return true
  script_net_assert_once("missing id in unlock",
    $"Unlocks: Missing id in unlock. Cannot cache unlock. /*unlockConfigString = {toString(unlock, 2)}*/")
  return false
}

function mkRow(unlock) {
  let row = { id = unlock.id, type = unlock.type }
  foreach (field in INDEX_FIELDS) {
    let value = unlock?[field]
    if (value != null && type(value) != "instance")
      row[field] <- value
  }
  return row
}

function mkCharPart(rows, hasDupIds, hasAllUnlockables) {
  let index = packed.pack(rows)
  let len = rows.len()
  let qById = hasDupIds ? qLastBlkIdxById : qBlkIdxById
  function unlocksWhere(query, params) {
    let blk = get_unlocks_blk()
    return query.blkIdxs.all(index, params).map(@(blkIdx) blk.getBlock(blkIdx))
  }
  return {
    index
    len
    isChar = true
    hasDupIds
    unlocksWhere
    function getAll() {
      let list = hasAllUnlockables ? get_unlocks_blk() % "unlockable" : []
      if (list.len() < len)
        return unlocksWhere(qAll, null)
      list.resize(len)
      return list
    }
    function findById(id) {
      idParams.id = id
      let blkIdx = qById.first(index, idParams)
      return blkIdx == null ? null : get_unlocks_blk().getBlock(blkIdx)
    }
  }
}

function mkListPart(unlocks) {
  let byId = {}
  let list = []
  let rows = []
  foreach (unlock in unlocks)
    if (hasId(unlock)) {
      byId[unlock.id] <- unlock
      list.append(unlock)
      rows.append(mkRow(unlock))
    }
  let index = packed.pack(rows)
  return {
    index
    len = list.len()
    isChar = false
    list
    unlocksWhere = @(query, params) query.positions.keys(index, params).map(@(pos) list[pos])
    getAll = @() clone list
    findById = @(id) byId?[id]
  }
}

let emptyPart = mkListPart([])
let cacheState = persist("cacheState", @() {
  charPart = emptyPart
  charAddedRows = []
  charAddedPart = emptyPart
  personalPart = emptyPart
  regionalPart = emptyPart
  isCacheValid = false
  isClearPending = false
})
let getParts = @() [cacheState.charPart, cacheState.charAddedPart, cacheState.personalPart, cacheState.regionalPart]

function cacheCharUnlocks() {
  let blk = get_unlocks_blk()
  let rows = []
  let ids = {}
  local hasDupIds = false
  local hasAllUnlockables = !blk.paramExists("unlockable")
  for (local i = 0, n = blk.blockCount(); i < n; i++) {
    let unlock = blk.getBlock(i)
    if (unlock.getBlockName() != "unlockable")
      continue
    if (!hasId(unlock)) {
      hasAllUnlockables = false
      continue
    }
    let row = mkRow(unlock).__update({ blkIdx = i })
    if (row.id in ids)
      hasDupIds = true
    ids[row.id] <- true
    rows.append(row)
  }
  cacheState.charPart = mkCharPart(rows, hasDupIds, hasAllUnlockables)
  cacheState.charAddedRows = []
  cacheState.charAddedPart = emptyPart
}


function addUpdatedCharUnlocks(updatedIds) {
  let newIds = {}
  foreach (id in updatedIds)
    if (cacheState.charPart.findById(id) == null && cacheState.charAddedPart.findById(id) == null)
      newIds[id] <- true
  if (newIds.len() == 0)
    return

  let blk = get_unlocks_blk()
  let addedRowById = {}
  for (local i = 0, n = blk.blockCount(); i < n; i++) {
    let unlock = blk.getBlock(i)
    if (unlock.getBlockName() != "unlockable" || unlock?.id not in newIds)
      continue
    let row = mkRow(unlock).__update({ blkIdx = i })
    if (row.id in addedRowById)
      addedRowById[row.id].__update(row)
    else {
      addedRowById[row.id] <- row
      cacheState.charAddedRows.append(row)
    }
  }
  if (addedRowById.len() > 0)
    cacheState.charAddedPart = mkCharPart(cacheState.charAddedRows, false, false)
}

function updateCacheCharUnlocks() {
  if (cacheState.charPart.len == 0) {
    cacheCharUnlocks()
    return
  }

  let { updated_unlocks, overflowed } = get_updated_unlocks_ids()
  if (overflowed)
    cacheCharUnlocks()
  else
    addUpdatedCharUnlocks(updated_unlocks)
}

function applyPendingClear() {
  if (!cacheState.isClearPending)
    return
  cacheState.isClearPending = false
  cacheState.charPart = emptyPart
  cacheState.charAddedRows = []
  cacheState.charAddedPart = emptyPart
  cacheState.personalPart = emptyPart
}

local frameMemo = null

function clearFrameMemo() {
  frameMemo = null
}

function getFrameMemo() {
  if (frameMemo == null) {
    frameMemo = { byId = {}, byType = {}, all = null }
    deferOnce(clearFrameMemo)
  }
  return frameMemo
}

function cache() {
  if (cacheState.isCacheValid)
    return

  cacheState.isCacheValid = true
  frameMemo = null
  applyPendingClear()
  updateCacheCharUnlocks()
  if (!isProfileReceived.get())
    return

  cacheState.personalPart = mkListPart(get_personal_unlocks_blk() % "unlockable")
}

function invalidateCache() {
  cacheState.isCacheValid = false
  broadcastEvent("UnlocksCacheInvalidate")
}


function clearProfileCachesSilent() {
  cacheState.isClearPending = true
}

function clearProfileCaches() {
  clearProfileCachesSilent()
  invalidateCache()
}

function getUnlocksWhereInBlkOrder(condition, params = {}) {
  if (condition not in queriesByCondition)
    queriesByCondition[condition] <- mkQuery(condition)
  cache()
  let res = []
  foreach (part in getParts())
    if (part.len > 0)
      res.extend(part.unlocksWhere(queriesByCondition[condition], params))
  return res
}


function getUnlocksByTypeInBlkOrder(typeName) {
  cache()
  let { byType, byId } = getFrameMemo()
  if (typeName in byType)
    return byType[typeName]

  let params = { type = typeName }
  let res = []
  foreach (part in getParts()) {
    if (part.len == 0)
      continue
    let unlocks = part.unlocksWhere(qByType, params)
    if (part.isChar && !part.hasDupIds)
      foreach (i, id in qIdsByType.all(part.index, params))
        if (id not in byId && cacheState.regionalPart.findById(id) == null && cacheState.personalPart.findById(id) == null)
          byId[id] <- unlocks[i]
    res.extend(unlocks)
  }
  byType[typeName] <- res
  return res
}

function getAllUnlocksWithBlkOrder() {
  cache()
  let memo = getFrameMemo()
  if (memo.all == null) {
    let res = []
    foreach (part in getParts())
      if (part.len > 0) {
        let unlocks = part.getAll()
        foreach (i, id in qIds.all(part.index))
          memo.byId[id] <- unlocks[i]
        res.extend(unlocks)
      }
    memo.all = res
  }
  return memo.all
}

function getAllUnlocks() {
  let res = {}
  foreach (unlock in getAllUnlocksWithBlkOrder())
    res[unlock.id] <- unlock
  return res
}

function getUnlockById(unlockId) {
  cache()
  if (unlockId == null)
    return null
  let { byId } = getFrameMemo()
  if (unlockId not in byId)
    byId[unlockId] <- cacheState.regionalPart.findById(unlockId) ?? cacheState.personalPart.findById(unlockId)
      ?? cacheState.charAddedPart.findById(unlockId) ?? cacheState.charPart.findById(unlockId)
  return byId[unlockId]
}

regionalUnlocks.subscribe(function(_) {
  let actualUnlocks = regionalUnlocks.get()
  
  let unlocks = cacheState.regionalPart.list.filter(@(unlock) unlock.id in actualUnlocks)
  let cachedIds = {}
  unlocks.each(@(unlock) cachedIds[unlock.id] <- true)
  local isChanged = unlocks.len() != cacheState.regionalPart.len
  foreach (unlock in actualUnlocks)
    if (unlock.id not in cachedIds) {
      isChanged = true
      cachedIds[unlock.id] <- true
      unlocks.append(unlock)
    }

  if (!isChanged)
    return

  frameMemo = null
  cacheState.regionalPart = mkListPart(unlocks)
  broadcastEvent("RegionalUnlocksChanged")
})

addListenersWithoutEnv({
  SignOut = @(_) clearProfileCaches()
  ProfileReceived = @(_) clearProfileCaches()
  
  RefreshProfileOnLogin = @(_) clearProfileCachesSilent() 
  ProfileUpdated = @(_) invalidateCache()
  BlksDataStorageLoaded = @(_) clearProfileCaches()
}, g_listener_priority.CONFIG_VALIDATION)

return freeze({
  getAllUnlocks
  getAllUnlocksWithBlkOrder
  getUnlockById
  getUnlocksByTypeInBlkOrder
  getUnlocksWhereInBlkOrder
})
