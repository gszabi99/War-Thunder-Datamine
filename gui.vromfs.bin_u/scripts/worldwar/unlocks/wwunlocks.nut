//checked for plus_string
from "%scripts/dagui_library.nut" import *

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { getAllUnlocksWithBlkOrder } = require("%scripts/unlocks/unlocksCache.nut")
let { isBattleTask } = require("%scripts/unlocks/battleTasks.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")

const CHAPTER_NAME = "worldwar"

local cacheArray = {}
local isCacheValid = false

local function invalidateUnlocksCache() {
  isCacheValid = false
  wwEvent("UnlocksCacheInvalidate")
}

subscriptions.addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) invalidateUnlocksCache()
})

local function getWwUnlocksForCash() {
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

local function validateCache() {
  if (isCacheValid)
    return

  isCacheValid = true
  cacheArray = getWwUnlocksForCash()
}

local function getAllUnlocks() {
  validateCache()
  return cacheArray
}

return {
  getAllUnlocks = getAllUnlocks
  unlocksChapterName = CHAPTER_NAME
  invalidateUnlocksCache = invalidateUnlocksCache
}