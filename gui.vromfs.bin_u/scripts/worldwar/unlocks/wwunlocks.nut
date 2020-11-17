local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")

const CHAPTER_NAME = "worldwar"

local cacheArray = {}
local isCacheValid = false

local function invalidateUnlocksCache() {
  isCacheValid = false
  ::ww_event("UnlocksCacheInvalidate")
}

subscriptions.addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(p) invalidateUnlocksCache()
})

local function getWwUnlocksForCash() {
  local chapter = ""
  local res = []
  foreach(unlock in ::g_unlocks.getAllUnlocksWithBlkOrder())
  {
    local newChapter = unlock?.chapter ?? ""
    if (newChapter != "")
      chapter = newChapter

    if (chapter != CHAPTER_NAME || !::is_unlock_visible(unlock))
      continue

    if (!unlock?.needShowInWorldWarMenu)
      continue

    if (unlock?.showAsBattleTask || ::BattleTasks.isBattleTask(unlock))
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
  getCurrenNotCompletedUnlocks = @() getAllUnlocks().filter(@(unlock) ::g_unlocks.canDo(unlock))
  unlocksChapterName = CHAPTER_NAME
  invalidateUnlocksCache = invalidateUnlocksCache
}