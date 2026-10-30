import "%scripts/seen/seenList.nut" as seenList
import "%scripts/g_listener_priority.nut" as LISTENER_PRIORITY
from "%scripts/unlocks/unlocksCache.nut" import getUnlocksWhereInBlkOrder, getUnlockById
from "%scripts/unlocks/unlocksState.nut" import buildConditionsConfig, getUnlockMainCondDescByCfg, getUnlockCondsDescByCfg
from "%scripts/unlocks/unlocksConditions.nut" import getProgressBarData
from "%scripts/unlocks/unlocksModule.nut" import isUnlockOpened, canOpenUnlockManually
from "%scripts/gameModes/gameModeManagerState.nut" import getCurrentGameMode, getRequiredUnitTypes
from "%scripts/seen/bhvUnseen.nut" import makeConfigStr
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%scripts/dagui_library.nut" import *
from "%globalScripts/unitTypeConsts.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

const CMH_CHAPTER = "commanders_handbook"

let UNIT_TYPE_TO_GROUP = freeze({
  [ES_UNIT_TYPE_TANK]       = "ground",
  [ES_UNIT_TYPE_AIRCRAFT]   = "air",
  [ES_UNIT_TYPE_HELICOPTER] = "air",
  [ES_UNIT_TYPE_SHIP]       = "bluewater",
  [ES_UNIT_TYPE_BOAT]       = "coastal"
})

local cmhUnlocksCache = null
local cmhGroupUnlocksCache = null
local cmhGroupsCache = null

function getAllCmhUnlocks() {
  if (cmhUnlocksCache == null)
    cmhUnlocksCache = getUnlocksWhereInBlkOrder("chapter == $chapter", { chapter = CMH_CHAPTER })
  return cmhUnlocksCache
}

function invalidateCmhCache() {
  cmhUnlocksCache = null
  cmhGroupUnlocksCache = null
  cmhGroupsCache = null
}

function getCurrentCmhGroup() {
  let gameMode = getCurrentGameMode()
  if (gameMode == null)
    return null
  foreach (esUnitType in getRequiredUnitTypes(gameMode)) {
    let group = UNIT_TYPE_TO_GROUP?[esUnitType]
    if (group != null)
      return group
  }
  return null
}

function getCmhGroupUnlocks(group) {
  if (group == null)
    return []

  if (cmhGroupUnlocksCache != null)
    return cmhGroupUnlocksCache?[group] ?? []

  let groupUnlocks = {}
  foreach (blk in getAllCmhUnlocks()) {
    let blkGroup = blk?.group ?? ""
    if (blkGroup == "")
      continue
    if (blkGroup not in groupUnlocks)
      groupUnlocks[blkGroup] <- []
    groupUnlocks[blkGroup].append(blk)
  }

  cmhGroupUnlocksCache = groupUnlocks
  return cmhGroupUnlocksCache?[group] ?? []
}

function getAllCmhGroups() {
  if (cmhGroupsCache != null)
    return cmhGroupsCache

  let res = []
  foreach (blk in getAllCmhUnlocks()) {
    let group = blk?.group ?? ""
    if (group != "" && !res.contains(group))
      res.append(group)
  }
  cmhGroupsCache = res
  return cmhGroupsCache
}

function getActiveCmhUnlock(group) {
  let unlocks = getCmhGroupUnlocks(group)
  if (unlocks.len() == 0)
    return null
  return unlocks.findvalue(@(blk) !isUnlockOpened(blk.id)) ?? unlocks.top()
}

function getCmhGroupCompletedTotal(group) {
  let unlocks = getCmhGroupUnlocks(group)
  local completed = 0
  foreach (blk in unlocks)
    if (isUnlockOpened(blk.id))
      completed++
  return { completed, total = unlocks.len() }
}

function getCmhChapterCompletedTotal() {
  let unlocks = getAllCmhUnlocks()
  local completed = 0
  foreach (blk in unlocks)
    if (isUnlockOpened(blk.id))
      completed++
  return { completed, total = unlocks.len() }
}

let hasUnclaimedReward = @(blk) canOpenUnlockManually(blk)

function getClaimableCmhUnlockIds() {
  let res = []
  foreach (blk in getAllCmhUnlocks())
    if (hasUnclaimedReward(blk))
      res.append(blk.id)
  return res
}

let mkCmhUnseenCfg = @(entity) makeConfigStr(SEEN.COMMANDERS_HANDBOOK, entity)
let hasCmhUnclaimedReward = @() getClaimableCmhUnlockIds().len() > 0

function getCmhUnlockProgressData(wrapperBlk) {
  local progressBlk = null
  foreach (mode in wrapperBlk % "mode")
    if (mode?.unlock != null) {
      progressBlk = getUnlockById(mode.unlock)
      break
    }

  let cfg = buildConditionsConfig(progressBlk ?? wrapperBlk)
  return {
    curVal = cfg.curVal
    maxVal = cfg.maxVal
    hasProgress = getProgressBarData(cfg.type, cfg.curVal, cfg.maxVal).show
    mainCond = getUnlockMainCondDescByCfg(cfg)
    condsDesc = getUnlockCondsDescByCfg(cfg, ["targetIsPlayer"])
  }
}

let cmhSeen = seenList.get(SEEN.COMMANDERS_HANDBOOK)
cmhSeen.setListGetter(getClaimableCmhUnlockIds)
cmhSeen.setCanBeNewFunc(@(id) hasUnclaimedReward(getUnlockById(id)))

addListenersWithoutEnv({
  function UnlocksCacheInvalidate(_) {
    invalidateCmhCache()
    cmhSeen.onListChanged()
  }
}, LISTENER_PRIORITY.CONFIG_VALIDATION)

return freeze({
  CMH_CHAPTER
  getCurrentCmhGroup
  getAllCmhGroups
  getCmhGroupUnlocks
  getActiveCmhUnlock
  getCmhGroupCompletedTotal
  getCmhChapterCompletedTotal
  getCmhUnlockProgressData
  mkCmhUnseenCfg
  hasCmhUnclaimedReward
})
