//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let enums = require("%sqStdLibs/helpers/enums.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { secondsToHours, hoursToString } = require("%scripts/time.nut")

let battleTaskDifficulty = {
  types = []
  cache = {
    byName = {}
    byExecOrder = {}
    byId = {}
  }
  template = {
    name = ""
    timeParamId = ""
    userlogHeaderName = ""
    image = null
    executeOrder = -1
    lastGenExpireTime = -1
    expireTimeByGen = null
    showSeasonIcon = false
    hasTimer = true
    userstatUnlockId = ""
    isTimeExpired = @(task) this.hasTimer && this.getTimeLeft(task) < 0
    getLocName = @() loc($"battleTasks/{this.timeParamId}/name")
    getDifficultyGroup = @() this.timeParamId

    expireProcessed = null
    function notifyTimeExpired(task) {
      let generationId = ::g_battle_tasks.getGenerationIdInt(task)
      if (this.expireProcessed?[generationId] ?? false)
        return

      if (generationId != 0) {
        this.expireProcessed = this.expireProcessed ?? {}
        this.expireProcessed[generationId] <- true
      }
      broadcastEvent("BattleTasksTimeExpired")
    }

    function getTimeLeft(task) {
      let generationId = ::g_battle_tasks.getGenerationIdInt(task)
      let expireTime = this.expireTimeByGen?[generationId] ?? this.lastGenExpireTime
      return expireTime - ::get_charserver_time_sec()
    }

    function getTimeLeftText(task) {
      let timeLeft = this.getTimeLeft(task)
      if (timeLeft < 0)
        return ""

      return hoursToString(secondsToHours(timeLeft), false, true, true)
    }
  }
}

enums.addTypes(battleTaskDifficulty, {
  EASY = {
    image = "#ui/gameuiskin#battle_tasks_easy.svg"
    timeParamId = "daily"
    executeOrder = 0
    userstatUnlockId = "easy_tasks_streak"
  }

  MEDIUM = {
    image = "#ui/gameuiskin#battle_tasks_middle.svg"
    timeParamId = "daily"
    executeOrder = 1
    userstatUnlockId = "medium_tasks_streak"
  }

  HARD = {
    image = "#ui/gameuiskin#hard_task_medal3.svg"
    showSeasonIcon = true
    timeParamId = "specialTasks"
    hasTimer = false
    userstatUnlockId = "hard_tasks_streak"
  }

  UNKNOWN = {
    hasTimer = false
    getTimeLeft = @(_task) -1
  }
}, null, "name")

battleTaskDifficulty.types.sort(@(a, b) a.executeOrder <=> b.executeOrder)

let function getDifficultyTypeByName(typeName) {
  return enums.getCachedType("name", typeName, battleTaskDifficulty.cache.byName,
    battleTaskDifficulty, battleTaskDifficulty.UNKNOWN)
}

let function getDifficultyFromTask(task) {
  return getTblValue("_puType", task, "").toupper()
}

let function getDifficultyTypeByTask(task) {
  return getDifficultyTypeByName(getDifficultyFromTask(task))
}

// Only for deleted tasks in which we cannot identify difficulty
let function getDifficultyTypeById(taskId) {
  if (taskId in battleTaskDifficulty.cache.byId)
    return getDifficultyTypeByName(battleTaskDifficulty.cache.byId[taskId])

  let res = battleTaskDifficulty.types.findvalue(function(v) {
    let n = v.name.tolower()
    let m = taskId.slice(0, n.len()).tolower()
    return n == m
  })

  battleTaskDifficulty.cache.byId[taskId] <- (res != null)
    ? res.name
    : battleTaskDifficulty.UNKNOWN.name
  return res
}

let function getRequiredDifficultyTypeDone(diff) {
  local res = null
  if (diff.executeOrder > 0)
    res = u.search(battleTaskDifficulty.types, @(t) t.executeOrder == (diff.executeOrder - 1))

  return res ?? battleTaskDifficulty.UNKNOWN
}

let function canPlayerInteractWithDifficulty(diff, tasksArray, overrideStatus = false) {
  if (overrideStatus)
    return true

  let reqDiffDone = getRequiredDifficultyTypeDone(diff)
  if (reqDiffDone == battleTaskDifficulty.UNKNOWN)
    return true

  foreach (task in tasksArray) {
    let taskDifficulty = getDifficultyTypeByTask(task)
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

let function updateTimeParamsFromBlk(blk) {
  foreach (t in battleTaskDifficulty.types) {
    let lastGenerationId    = blk?[$"{t.timeParamId}PersonalUnlocks_lastGenerationId"]            ?? 0
    let lastGenTimeSuccess  = blk?[$"{t.timeParamId}PersonalUnlocks_lastGenerationTimeOnSuccess"] ?? -1
    let generationPeriodSec = blk?[$"{t.timeParamId}PersonalUnlocks_CUSTOM_generationPeriodSec"]  ?? -1

    t.lastGenExpireTime = (lastGenTimeSuccess != -1 && generationPeriodSec != -1)
      ? (lastGenTimeSuccess + generationPeriodSec)
      : -1

    if (lastGenerationId != 0 && t.lastGenExpireTime != -1) {
      t.expireTimeByGen = t.expireTimeByGen ?? {}
      t.expireTimeByGen[lastGenerationId] <- t.lastGenExpireTime

      t.expireProcessed = t.expireProcessed ?? {}
      t.expireProcessed[lastGenerationId] <- t.lastGenExpireTime < ::get_charserver_time_sec()
    }
  }
}

let function withdrawTasksArrayByDifficulty(diff, tasks) {
  return u.filter(tasks, @(task) diff == getDifficultyTypeByTask(task))
}

let function getDefaultDifficultyGroup() {
  return battleTaskDifficulty.EASY.getDifficultyGroup()
}

return {
  getDifficultyTypeByName
  getDifficultyTypeByTask
  getDifficultyTypeById
  canPlayerInteractWithDifficulty
  updateTimeParamsFromBlk
  withdrawTasksArrayByDifficulty
  getDefaultDifficultyGroup
  EASY_TASK = battleTaskDifficulty.EASY
  MEDIUM_TASK = battleTaskDifficulty.MEDIUM
  HARD_TASK = battleTaskDifficulty.HARD
  UNKNOWN_TASK = battleTaskDifficulty.UNKNOWN
}
