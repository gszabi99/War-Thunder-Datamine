from "%scripts/dagui_library.nut" import *

let enums = require("%sqStdLibs/helpers/enums.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { secondsToHours, hoursToString } = require("%scripts/time.nut")
let { get_charserver_time_sec } = require("chard")

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
    showSeasonIcon = false
    hasTimer = true
    userstatUnlockId = ""
    getLocName = @() loc($"battleTasks/{this.timeParamId}/name")
    getDifficultyGroup = @() this.timeParamId

    expireTimeByGen = null
    expireProcessed = null
    function notifyTimeExpired(generationId) {
      if (this.expireProcessed?[generationId] ?? false)
        return

      if (generationId != 0) {
        this.expireProcessed = this.expireProcessed ?? {}
        this.expireProcessed[generationId] <- true
      }
      broadcastEvent("BattleTasksTimeExpired")
    }

    function getTimeLeft(generationId) {
      let expireTime = this.expireTimeByGen?[generationId] ?? this.lastGenExpireTime
      return expireTime - get_charserver_time_sec()
    }

    function getTimeLeftText(generationId) {
      let timeLeft = this.getTimeLeft(generationId)
      if (timeLeft < 0)
        return ""

      return hoursToString(secondsToHours(timeLeft), false, true, true)
    }

    isTimeExpired = @(genId) this.hasTimer && this.getTimeLeft(genId) < 0
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
    getTimeLeft = @(_generationId) -1
  }
}, null, "name")

battleTaskDifficulty.types.sort(@(a, b) a.executeOrder <=> b.executeOrder)

function getDifficultyTypeByName(typeName) {
  return enums.getCachedType("name", typeName, battleTaskDifficulty.cache.byName,
    battleTaskDifficulty, battleTaskDifficulty.UNKNOWN)
}

// Only for deleted tasks in which we cannot identify difficulty
function getDifficultyTypeById(taskId) {
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

function updateTimeParamsFromBlk(blk) {
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
      t.expireProcessed[lastGenerationId] <- t.lastGenExpireTime < get_charserver_time_sec()
    }
  }
}

function getDefaultDifficultyGroup() {
  return battleTaskDifficulty.EASY.getDifficultyGroup()
}

return {
  getDifficultyTypeByName
  getDifficultyTypeById
  updateTimeParamsFromBlk
  getDefaultDifficultyGroup
  EASY_TASK = battleTaskDifficulty.EASY
  MEDIUM_TASK = battleTaskDifficulty.MEDIUM
  HARD_TASK = battleTaskDifficulty.HARD
  UNKNOWN_TASK = battleTaskDifficulty.UNKNOWN
}
