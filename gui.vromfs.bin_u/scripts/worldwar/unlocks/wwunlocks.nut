import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
import "%scripts/worldWar/wwEvent.nut" as wwEvent
from "%scripts/unlocks/unlocksModule.nut" import isUnlockVisible
from "%scripts/unlocks/unlocksCache.nut" import getAllUnlocksWithBlkOrder
from "%scripts/unlocks/battleTasksState.nut" import isBattleTask
from "%scripts/dagui_library.nut" import *

const CHAPTER_NAME = "worldwar"

local cacheArray = {}
local isCacheValid = false

function invalidateUnlocksCache() {
  isCacheValid = false
  wwEvent("UnlocksCacheInvalidate")
}

subscriptions.addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) invalidateUnlocksCache()
})

function getWwUnlocksForCash() {
  local chapter = ""
  local res = []
  foreach (unlock in getAllUnlocksWithBlkOrder()) {
    local newChapter = unlock?.chapter ?? ""
    if (newChapter != "")
      chapter = newChapter

    if (chapter != CHAPTER_NAME || !isUnlockVisible(unlock))
      continue

    if (!unlock?.needShowInWorldWarMenu)
      continue

    if (isBattleTask(unlock))
      continue

    res.append(unlock)
  }

  return res
}

function validateCache() {
  if (isCacheValid)
    return

  isCacheValid = true
  cacheArray = getWwUnlocksForCash()
}

function getAllUnlocks() {
  validateCache()
  return cacheArray
}

return freeze({
  getAllUnlocks = getAllUnlocks
  unlocksChapterName = CHAPTER_NAME
  invalidateUnlocksCache = invalidateUnlocksCache
})