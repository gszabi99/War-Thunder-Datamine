from "%scripts/dagui_library.nut" import *

let { isDataBlock, isTable, isString } = require("%sqStdLibs/helpers/u.nut")
let { getDifficultyTypeByName, UNKNOWN_TASK
} = require("%scripts/unlocks/battleTaskDifficulty.nut")


let isMediumTaskComplete = Watched(false)
let isEasyTaskComplete = Watched(false)
let isHardTaskIncomplete = Watched(false)


let currentTasksArray = []
let activeTasksArray = []
let proposedTasksArray = []


function getBattleTaskById(id) {
  if (isTable(id) || isDataBlock(id))
    id = getTblValue("id", id)
  if (!id)
    return null

  foreach (task in activeTasksArray)
    if (task.id == id)
      return task
  foreach (task in proposedTasksArray)
    if (task.id == id)
      return task
  return null
}


function getBattleTaskNameById(param) {
  local task = null
  local id = null
  if (isDataBlock(param)) {
    task = param
    id = getTblValue("id", param)
  }
  else if (isString(param)) {
    task = getBattleTaskById(param)
    id = param
  }
  else
    return ""

  return loc(getTblValue("locId", task, $"battletask/{id}"))
}


let getDifficultyFromTask = @(task)
  getTblValue("_puType", task, "").toupper()

let getDifficultyTypeByTask = @(task)
  getDifficultyTypeByName(getDifficultyFromTask(task))

function isBattleTask(task) {
  if (isString(task))
    task = getBattleTaskById(task)

  let diff = getDifficultyTypeByTask(task)
  return diff != UNKNOWN_TASK
}


return {
  isMediumTaskComplete
  isEasyTaskComplete
  isHardTaskIncomplete
  currentTasksArray
  activeTasksArray
  proposedTasksArray
  isBattleTask
  getBattleTaskById
  getBattleTaskNameById
  getDifficultyTypeByTask
}
