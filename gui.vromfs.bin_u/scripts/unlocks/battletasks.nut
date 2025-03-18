from "%scripts/dagui_natives.nut" import char_send_blk
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let { isInMenu, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { isDataBlock, isString, isEmpty, isTable, search } = require("%sqStdLibs/helpers/u.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")
let DataBlock = require("DataBlock")
let { getUtcDays } = require("%scripts/time.nut")
let statsd = require("statsd")
let { isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { loadConditionsFromBlk } = require("%scripts/unlocks/unlocksConditions.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { updateTimeParamsFromBlk, getDifficultyTypeByName,
  EASY_TASK, MEDIUM_TASK, HARD_TASK, UNKNOWN_TASK
} = require("%scripts/unlocks/battleTaskDifficulty.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { get_personal_unlocks_blk, get_proposed_personal_unlocks_blk } = require("blkGetters")
let { addTask } = require("%scripts/tasker.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

const TASKS_OUT_OF_DATE_DAYS = 15
const SEEN_SAVE_ID = "seen/battletasks"
const SPECIAL_TASKS_ID = "specialTasksPersonalUnlocks"
const DAILY_TASKS_ID = "dailyPersonalUnlocks"

let difficultyTypes = [
  EASY_TASK,
  MEDIUM_TASK,
  HARD_TASK
]

let currentTasksArray = []
let activeTasksArray = []
let proposedTasksArray = []

let getProposedTasks = @() proposedTasksArray

let isMediumTaskComplete = Watched(false)
let isEasyTaskComplete = Watched(false)
let isHardTaskIncomplete = Watched(false)

let seenTasks = {}
let newIconWidgetByTaskId = {}
local lastGenerationId = 0
local specTasksLastGenerationId = 0
local seenTasksInited = false

local rerollCost = null
let getBattleTaskRerollCost = @() rerollCost

local showAllTasks = false
let getShowAllTasks = @() showAllTasks

let getCurrentBattleTasks = @() currentTasksArray
let getActiveBattleTasks = @() activeTasksArray
let getWidgetsTable = @() newIconWidgetByTaskId
let getUniqueId = @(task) task.id

let isBattleTaskActive = @(task) task?.isActive ?? true

let isBattleTasksAvailable = @() hasFeature("BattleTasks")
  && currentTasksArray.len() > 0
  && isMultiplayerPrivilegeAvailable.value

function getGenerationIdInt(task) {
  let taskGenId = task?._generation_id
  if (!taskGenId)
    return 0

  return isString(taskGenId) ? taskGenId.tointeger() : taskGenId
}

function isBattleTaskActual(task) {
  if (!task?._generation_id)
    return true

  let taskGenId = getGenerationIdInt(task)
  return taskGenId == lastGenerationId
    || taskGenId == specTasksLastGenerationId
}

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

function isBattleTaskDone(config) {
  if (isEmpty(config))
    return false

  if (isBattleTask(config)) {
    if (!getBattleTaskById(config.id))
      return true 
    return isUnlockOpened(config.id)
  }
  return isUnlockOpened(config.id)
}

function getTotalActiveTasksNum() {
  local num = 0
  foreach (task in activeTasksArray)
    if (isBattleTaskActual(task) && !isBattleTaskDone(task))
      ++num
  return num
}

let canGetBattleTaskReward = @(task) isBattleTask(task)
  && isBattleTaskActual(task)
  && !isBattleTaskDone(task)
  && (task?._readyToReward ?? false)

let getBattleTaskWithAvailableAward = @(tasksArray) search(tasksArray, canGetBattleTaskReward)

function canGetAnyBattleTaskReward() {
  foreach (task in activeTasksArray)
    if (canGetBattleTaskReward(task))
      return true
  return false
}

let isBattleTaskExpired = @(task) getDifficultyTypeByTask(task).isTimeExpired(getGenerationIdInt(task))

let getTaskStatus = @(task) canGetBattleTaskReward(task) ? "complete"
  : isBattleTaskDone(task) ? "done"
  : isBattleTaskExpired(task) ? "failed"
  : null

let isSpecialBattleTask = @(task) getGenerationIdInt(task) == specTasksLastGenerationId

function getRequiredDifficultyTypeDone(diff) {
  local res = null
  if (diff.executeOrder > 0)
    res = search(difficultyTypes, @(t) t.executeOrder == (diff.executeOrder - 1))

  return res ?? UNKNOWN_TASK
}

function canPlayerInteractWithDifficulty(diff, tasksArray) {
  let reqDiffDone = getRequiredDifficultyTypeDone(diff)
  if (reqDiffDone == UNKNOWN_TASK)
    return true

  foreach (task in tasksArray) {
    let taskDifficulty = getDifficultyTypeByTask(task)
    if (taskDifficulty != reqDiffDone)
      continue
    if (!isBattleTask(task) || !isBattleTaskActual(task))
      continue
    if (isBattleTaskDone(task))
      continue
    if (diff.executeOrder <= taskDifficulty.executeOrder)
      continue

    return false
  }
  return true
}

function canInteractWithDifficulty(task) {
  let diff = getDifficultyTypeByTask(task)
  return showAllTasks || canPlayerInteractWithDifficulty(diff, currentTasksArray)
}

let canActivateSpecialTask = @() isInMenu()
  && search(proposedTasksArray, isSpecialBattleTask) != null
  && search(activeTasksArray, isSpecialBattleTask) == null

function compareBattleTasks(a, b) {
  if (a?._sort_order == null || b?._sort_order == null)
    return 0

  return b._sort_order <=> a._sort_order
}

function isTaskForGM(task, gameModeId) {
  if (!isBattleTask(task))
    return false

  let modes = task % "mode"
  let conditions = loadConditionsFromBlk(modes.top(), task)

  foreach (condition in conditions) {
    let values = getTblValue("values", condition)
    if (isEmpty(values))
      continue
    if (isInArray(gameModeId, values))
      return true
  }
  return false
}

function filterBattleTasksByGameModeId(tasksArray, gameModeId) {
  if (isEmpty(gameModeId))
    return tasksArray

  let res = []
  foreach (task in tasksArray)
    if (isTaskForGM(task, gameModeId))
      res.append(task)
  return res
}

function isBattleTaskSameDiff(task, difficulty) {
  if (!isBattleTask(task))
    return true

  return isInArray(task?._choiceType ?? "", difficulty.choiceType)
}

function getBattleTasksByDiff(searchArray, difficulty = null) {
  if (isEmpty(searchArray))
    searchArray = currentTasksArray
  if (isEmpty(difficulty))
    return searchArray

  return searchArray.filter(@(task) isBattleTaskSameDiff(task, difficulty))
}

let withdrawTasksArrayByDifficulty = @(diff, tasks)
  tasks.filter(@(task) diff == getDifficultyTypeByTask(task))



function getCurBattleTasksByGm(gameModeId) {
  let hasTaskForGm = activeTasksArray.findindex(
    @(t) isTaskForGM(t, gameModeId)) != null
  if (!hasTaskForGm)
    return []

  let tasks = activeTasksArray.filter(@(t) isBattleTaskActual(t))
  let res = []
  foreach (diff in difficultyTypes) {
    let taskCanInteract = canPlayerInteractWithDifficulty(diff, tasks)
    if (!taskCanInteract)
      continue

    let tasksByDiff = withdrawTasksArrayByDifficulty(diff, tasks)
    if (tasksByDiff.len() == 0)
      continue

    let taskWithReward = getBattleTaskWithAvailableAward(tasksByDiff)
    if (taskWithReward != null)
      res.append(taskWithReward)
    else
      res.extend(tasksByDiff.filter(@(t) isBattleTaskDone(t)
        || isTaskForGM(t, gameModeId)))
  }
  return res
}

function getBattleTasksOrderedByDiff() {
  let result = []
  foreach (t in difficultyTypes) {
    let arr = withdrawTasksArrayByDifficulty(t, currentTasksArray)
    if (arr.len() == 0)
      continue

    if (canPlayerInteractWithDifficulty(t, currentTasksArray))
      result.extend(arr)
  }
  return result
}

function isUserlogForBattleTasksGroup(body) {
  let unlockId = getTblValue("unlockId", body)
  if (unlockId == null)
    return true

  return getBattleTaskById(unlockId) != null
}

function getDifficultyByProposals(proposals) {
  let hasHardTask = !!proposals.findvalue(
    @(_, id) getDifficultyTypeByTask(getBattleTaskById(id)) == HARD_TASK)
  return hasHardTask ? HARD_TASK : EASY_TASK
}

function resetBattleTasks() {
  currentTasksArray.clear()
  activeTasksArray.clear()
  proposedTasksArray.clear()

  seenTasks.clear()
  newIconWidgetByTaskId.clear()
  seenTasksInited = false

  lastGenerationId = 0
  specTasksLastGenerationId = 0
}

eventbus_subscribe("on_sign_out", @(...) resetBattleTasks())


function loadSeenTasksData(forceLoad = false) {
  if (seenTasksInited && !forceLoad)
    return true

  seenTasks.clear()
  let blk = loadLocalByAccount(SEEN_SAVE_ID)
  if (isDataBlock(blk))
    for (local i = 0; i < blk.paramCount(); ++i) {
      let id = blk.getParamName(i)
      let value = blk.getParamValue(i)
      if (type(value) == "integer")
        seenTasks[id] <- max(value, seenTasks?[id] ?? 0)
    }

  seenTasksInited = true
  return true
}

function isBattleTaskNew(generationId) {
  loadSeenTasksData()
  return generationId not in seenTasks
}

function markBattleTaskSeen(generationId, sendEvent = true, isNew = false) {
  let wasNew = isBattleTaskNew(generationId)
  if (wasNew == isNew)
    return false

  if (!isNew)
    seenTasks[generationId] <- getUtcDays()
  else if (generationId in seenTasks)
    seenTasks.$rawdelete(generationId)

  if (sendEvent)
    broadcastEvent("NewBattleTasksChanged")
  return true
}

function markAllBattleTasksSeen() {
  local changeNew = false
  foreach (task in currentTasksArray) {
    let generationId = getUniqueId(task)
    let result = markBattleTaskSeen(generationId, false)
    changeNew = changeNew || result
  }

  if (changeNew)
    broadcastEvent("NewBattleTasksChanged")
}

function saveSeenBattleTasksData() {
  let minDay = getUtcDays() - TASKS_OUT_OF_DATE_DAYS
  let blk = DataBlock()
  foreach (generationId, day in seenTasks) {
    if (day < minDay && !isBattleTaskNew(generationId))
      continue

    blk[generationId] = day
  }

  saveLocalByAccount(SEEN_SAVE_ID, blk)
}

function updatedProposedTasks() {
  let tasksDataBlock = get_proposed_personal_unlocks_blk()
  updateTimeParamsFromBlk(tasksDataBlock)
  lastGenerationId = tasksDataBlock?[$"{DAILY_TASKS_ID}_lastGenerationId"] ?? 0
  specTasksLastGenerationId = tasksDataBlock?[$"{SPECIAL_TASKS_ID}_lastGenerationId"] ?? 0
  rerollCost = Cost(tasksDataBlock?._rerollCost ?? 0, tasksDataBlock?._rerollGoldCost ?? 0)

  proposedTasksArray.clear()
  newIconWidgetByTaskId.clear()

  for (local i = 0; i < tasksDataBlock.blockCount(); ++i) {
    let task = DataBlock()
    task.setFrom(tasksDataBlock.getBlock(i))
    task.isActive = false
    proposedTasksArray.append(task)
    if (!isBattleTaskActual(task) || !canInteractWithDifficulty(task))
      continue

    currentTasksArray.append(task)
    newIconWidgetByTaskId[getUniqueId(task)] <- null
  }
}

function updatedActiveTasks() {
  activeTasksArray.clear()

  let currentActiveTasks = get_personal_unlocks_blk()
  for (local i = 0; i < currentActiveTasks.blockCount(); ++i) {
    let task = DataBlock()
    task.setFrom(currentActiveTasks.getBlock(i))
    if (!isBattleTask(task))
      continue

    task.isActive = true
    activeTasksArray.append(task)
    if (!isBattleTaskActual(task) || !canInteractWithDifficulty(task))
      continue

    currentTasksArray.append(task)
    let isNew = !isBattleTaskDone(task) && canGetBattleTaskReward(task)
    markBattleTaskSeen(getUniqueId(task), false, isNew)
    newIconWidgetByTaskId[getUniqueId(task)] <- null
  }
}

function checkNewSpecialTasks() {
  if (!canActivateSpecialTask() || !isBattleTasksAvailable())
    return

  let battleTasksArray = proposedTasksArray.filter(@(t) isSpecialBattleTask(t))
  if (battleTasksArray.len() == 0)
    return
  loadHandler(gui_handlers.BattleTasksSelectNewTaskWnd, { battleTasksArray })
}

function updateCompleteTaskWatched() {
  local isEasyComplete = false
  local isMediumComplete = false
  local isHardIncomplete = false
  foreach (task in currentTasksArray) {
    if (isMediumComplete && isEasyComplete && isHardIncomplete)
      break
    if (!isBattleTaskActive(task))
      continue

    let diff = getDifficultyTypeByTask(task)
    let isDone = isBattleTaskDone(task)
    if (isDone && diff == EASY_TASK)
      isEasyComplete = true
    else if (isDone && diff == MEDIUM_TASK)
      isMediumComplete = true
    else if (!isDone && diff == HARD_TASK)
      isHardIncomplete = true
  }

  isEasyTaskComplete(isEasyComplete)
  isMediumTaskComplete(isMediumComplete)
  isHardTaskIncomplete(isHardIncomplete)
}

function updateTasksData() {
  currentTasksArray.clear()
  if (!isLoggedIn.get())
    return

  updatedProposedTasks()
  updatedActiveTasks()

  currentTasksArray.sort(compareBattleTasks)
  activeTasksArray.sort(compareBattleTasks)

  if (isInMenu())
    checkNewSpecialTasks()

  updateCompleteTaskWatched()
  broadcastEvent("BattleTasksFinishedUpdate")
}

function getBattleTaskDiffGroups() {
  let result = []
  foreach (t in difficultyTypes) {
    let difficultyGroup = t.getDifficultyGroup()
    if (difficultyGroup == "")
      continue

    result.append(t)
  }
  return result
}

function checkCurSpecialTask() {
  if (!isHardTaskIncomplete.value)
    return

  let tasksDataBlock = get_proposed_personal_unlocks_blk()
  let genId = tasksDataBlock?[$"{SPECIAL_TASKS_ID}_lastGenerationId"] ?? 0
  if (genId == 0 || specTasksLastGenerationId == genId)
    return

  updateTasksData()
}

function sendReceiveRewardRequest(battleTask) {
  let blk = DataBlock()
  blk.unlockName = battleTask.id

  let taskId = char_send_blk("cln_reward_specific_battle_task", blk)
  addTask(taskId, { showProgressBox = true }, function() {
    ::update_gamercards()
    broadcastEvent("BattleTasksIncomeUpdate")
    broadcastEvent("BattleTasksRewardReceived")
  })
}

function requestBattleTaskReward(battleTaskId) {
  if (isEmpty(battleTaskId))
    return

  let battleTask = getBattleTaskById(battleTaskId)
  if (!::g_warbonds.checkWarbondsOverLimit(battleTask?.amounts_warbond ?? 0,
      sendReceiveRewardRequest, battleTask))
    return

  sendReceiveRewardRequest(battleTask)
}

function rerollBattleTask(task) {
  if (isEmpty(task))
    return

  let blk = DataBlock()
  blk.unlockName = task.id

  let taskId = char_send_blk("cln_reroll_battle_task", blk)
  addTask(taskId, { showProgressBox = true },
    function() {
      statsd.send_counter("sq.battle_tasks.reroll_v2", 1, { task_id = (task?._base_id ?? "null") })
      broadcastEvent("BattleTasksIncomeUpdate")
    }
  )
}

function rerollSpecialTask(task) {
  if (isEmpty(task))
    return

  let blk = DataBlock()
  blk.unlockName = task.id
  blk.metaTypeName = SPECIAL_TASKS_ID

  let taskId = char_send_blk("cln_reroll_all_battle_tasks_for_meta", blk)
  addTask(taskId, { showProgressBox = true },
    function() {
      statsd.send_counter("sq.battle_tasks.special_reroll", 1, { task_id = (task?._base_id ?? "null") })
      broadcastEvent("BattleTasksIncomeUpdate")
    })
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

addListenersWithoutEnv({
  function LoginComplete(_) {
    resetBattleTasks()
    updateTasksData()
  }

  ProfileUpdated = @(_) checkCurSpecialTask()
  BattleTasksIncomeUpdate = @(_) updateTasksData()
  BattleEnded = @(_) updateTasksData()
  ScriptsReloaded = @(_) updateTasksData() 

  
  function BattleTasksShowAll(params) {
    showAllTasks = getTblValue("showAllTasksValue", params, false)
    updateTasksData()
  }
}, DEFAULT_HANDLER)

updateTasksData()

return {
  isMediumTaskComplete
  isEasyTaskComplete
  isHardTaskIncomplete
  isBattleTasksAvailable
  resetBattleTasks
  checkNewSpecialTasks
  isBattleTask
  isBattleTaskActual
  isSpecialBattleTask
  isBattleTaskActive
  isBattleTaskDone
  isBattleTaskExpired
  isBattleTaskSameDiff
  isBattleTaskNew
  isUserlogForBattleTasksGroup
  getDifficultyByProposals
  canActivateSpecialTask
  canGetBattleTaskReward
  canGetAnyBattleTaskReward
  requestBattleTaskReward
  filterBattleTasksByGameModeId
  rerollBattleTask
  rerollSpecialTask
  getBattleTaskRerollCost
  getCurBattleTasksByGm
  getBattleTasksByDiff
  getBattleTasksOrderedByDiff
  getBattleTaskWithAvailableAward
  getBattleTaskById
  getCurrentBattleTasks
  getActiveBattleTasks
  getWidgetsTable
  getBattleTaskDiffGroups
  getDifficultyTypeByTask
  canPlayerInteractWithDifficulty
  withdrawTasksArrayByDifficulty
  markBattleTaskSeen
  markAllBattleTasksSeen
  saveSeenBattleTasksData
  getBattleTaskNameById
  getShowAllTasks 
  getProposedTasks
  getTaskStatus
  getTotalActiveTasksNum
  getGenerationIdInt
}
