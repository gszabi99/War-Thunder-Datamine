local enums = ::require("sqStdlibs/helpers/enums.nut")
local time = require("scripts/time.nut")

::g_battle_task_difficulty <- {
  types = []
  template = {}
  cache = {
    byName = {}
    byExecOrder = {}
  }
}

local function _getTimeLeft(task)
{
  local expireTime = expireTimeByGen?[::g_battle_tasks.getGenerationIdInt(task)] ?? lastGenExpireTime
  return expireTime - ::get_charserver_time_sec()
}

g_battle_task_difficulty._getTimeLeftText <- function _getTimeLeftText(task)
{
  local timeLeft = getTimeLeft(task)
  if (timeLeft < 0)
    return ""

  return time.hoursToString(time.secondsToHours(timeLeft), false, true, true)
}

::g_battle_task_difficulty.template <- {
  getLocName = @() ::loc("battleTasks/" + timeParamId + "/name")
  getTimeLeftText = ::g_battle_task_difficulty._getTimeLeftText
  getDifficultyGroup = @() timeParamId

  name = ""
  timeParamId = ""
  userlogHeaderName = ""
  image = null
  executeOrder = -1
  lastGenerationId = 0
  lastGenTimeSuccess = -1
  lastGenTimeFailure = -1
  generationPeriodSec = -1
  lastGenExpireTime = -1
  expireTimeByGen = null
  showAtPositiveProgress = false
  timeLimit = function() { return -1 }
  getTimeLeft = function(task) { return -1 }
  isTimeExpired = @(task) hasTimer && getTimeLeft(task) < 0
  showSeasonIcon = false
  canIncreaseShopLevel = true
  hasTimer = true

  expireProcessed = null
  notifyTimeExpired = function(task) {
    local generationId = ::g_battle_tasks.getGenerationIdInt(task)
    if (expireProcessed?[generationId] ?? false)
      return

    if (generationId != 0)
    {
      expireProcessed = expireProcessed ?? {}
      expireProcessed[generationId] <- true
    }
    ::broadcastEvent("BattleTasksTimeExpired")
  }
}

enums.addTypesByGlobalName("g_battle_task_difficulty", {
  EASY = {
    image = "#ui/gameuiskin#battle_tasks_easy"
    timeParamId = "daily"
    executeOrder = 0
    timeLimit = function() { return time.daysToSeconds(1) }
    getTimeLeft = _getTimeLeft
  }

  MEDIUM = {
    image = "#ui/gameuiskin#battle_tasks_middle"
    timeParamId = "daily"
    executeOrder = 1
    timeLimit = function() { return time.daysToSeconds(1) }
    getTimeLeft = _getTimeLeft
  }

  HARD = {
    image = "#ui/gameuiskin#hard_task_medal3"
    showSeasonIcon = true
    canIncreaseShopLevel = false
    timeParamId = "specialTasks"
    timeLimit = function() { return time.daysToSeconds(1) }
    getTimeLeft = _getTimeLeft
    hasTimer = false
  }

  UNKNOWN = {
    hasTimer = false
  }

/******** Old types **********/
  WEEKLY = {}
  DAILY = {}
  MONTHLY = {}
  COMMON = {}
/*****************************/
}, null, "name")

g_battle_task_difficulty.types.sort(function(a,b){
  if (a.executeOrder != b.executeOrder)
    return a.executeOrder > b.executeOrder ? 1 : -1
  return 0
})

g_battle_task_difficulty.getDifficultyTypeByName <- function getDifficultyTypeByName(typeName)
{
  return enums.getCachedType("name", typeName, ::g_battle_task_difficulty.cache.byName,
    ::g_battle_task_difficulty, ::g_battle_task_difficulty.UNKNOWN)
}

g_battle_task_difficulty.getDifficultyFromTask <- function getDifficultyFromTask(task)
{
  return ::getTblValue("_puType", task, "").toupper()
}

g_battle_task_difficulty.getDifficultyTypeByTask <- function getDifficultyTypeByTask(task)
{
  return getDifficultyTypeByName(getDifficultyFromTask(task))
}

g_battle_task_difficulty.getRequiredDifficultyTypeDone <- function getRequiredDifficultyTypeDone(diff)
{
  local res = null
  if (diff.executeOrder >= 0)
    res = ::u.search(types, @(t) t.executeOrder == (diff.executeOrder-1))

  return res || ::g_battle_task_difficulty.UNKNOWN
}

g_battle_task_difficulty.getRefreshTimeForAllTypes <- function getRefreshTimeForAllTypes(tasksArray, overrideStatus = false)
{
  local processedTimeParamIds = []
  if (!overrideStatus)
    foreach(task in tasksArray)
    {
      local t = getDifficultyTypeByTask(task)
      ::u.appendOnce(t.timeParamId, processedTimeParamIds)
    }

  local resultArray = []
  foreach(t in types)
  {
    if (::isInArray(t.timeParamId, processedTimeParamIds))
      continue

    processedTimeParamIds.append(t.timeParamId)

    local timeText = t.getTimeLeftText(null)
    if (timeText != "")
      resultArray.append(t.getLocName() + ::loc("ui/parentheses/space", {text = timeText}))
  }

  return resultArray
}

g_battle_task_difficulty.canPlayerInteractWithDifficulty <- function canPlayerInteractWithDifficulty(diff, tasksArray, overrideStatus = false)
{
  if (overrideStatus)
    return true

  local reqDiffDone = getRequiredDifficultyTypeDone(diff)
  if (reqDiffDone == ::g_battle_task_difficulty.UNKNOWN)
    return true

  foreach(task in tasksArray)
  {
    local taskDifficulty = getDifficultyTypeByTask(task)
    if (taskDifficulty != reqDiffDone)
      continue

    if (!::g_battle_tasks.isBattleTask(task) || !::g_battle_tasks.isTaskActual(task))
      continue

    if (::g_battle_tasks.isTaskDone(task))
      continue

    if (diff.executeOrder <= taskDifficulty.executeOrder)
      continue

    return false
  }

  return true
}

g_battle_task_difficulty.updateTimeParamsFromBlk <- function updateTimeParamsFromBlk(blk)
{
  foreach(t in types)
  {
    t.lastGenerationId    = blk?[$"{t.timeParamId}PersonalUnlocks_lastGenerationId"]            ?? 0
    t.lastGenTimeSuccess  = blk?[$"{t.timeParamId}PersonalUnlocks_lastGenerationTimeOnSuccess"] ?? -1
    t.lastGenTimeFailure  = blk?[$"{t.timeParamId}PersonalUnlocks_lastGenerationTimeOnFailure"] ?? -1
    t.generationPeriodSec = blk?[$"{t.timeParamId}PersonalUnlocks_CUSTOM_generationPeriodSec"]  ?? -1

    t.lastGenExpireTime = (t.lastGenTimeSuccess != -1 && t.generationPeriodSec != -1)
      ? (t.lastGenTimeSuccess + t.generationPeriodSec)
      : -1

    if (t.lastGenerationId != 0 && t.lastGenExpireTime != -1)
    {
      t.expireTimeByGen = t.expireTimeByGen ?? {}
      t.expireTimeByGen[t.lastGenerationId] <- t.lastGenExpireTime

      t.expireProcessed = t.expireProcessed ?? {}
      t.expireProcessed[t.lastGenerationId] <- t.lastGenExpireTime < ::get_charserver_time_sec()
    }
  }
}

g_battle_task_difficulty.checkAvailabilityByProgress <- function checkAvailabilityByProgress(task, overrideStatus = false)
{
  if (overrideStatus)
    return true

  if (!::g_battle_tasks.isTaskDone(task) ||
    !getDifficultyTypeByTask(task).showAtPositiveProgress)
    return true

  local progress = ::get_unlock_progress(task.id, -1)
  return ::getTblValue("curVal", progress, 0) > 0
}

g_battle_task_difficulty.withdrawTasksArrayByDifficulty <- function withdrawTasksArrayByDifficulty(diff, tasks)
{
  return ::u.filter(tasks, @(task) diff == ::g_battle_task_difficulty.getDifficultyTypeByTask(task) )
}

g_battle_task_difficulty.getDefaultDifficultyGroup <- function getDefaultDifficultyGroup()
{
  return EASY.getDifficultyGroup()
}
