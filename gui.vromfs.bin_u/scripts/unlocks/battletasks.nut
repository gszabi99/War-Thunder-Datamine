//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { isInMenu, is_low_width_screen } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { Cost } = require("%scripts/money.nut")
let { isDataBlock, isString, isEmpty, isTable, search } = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")
let DataBlock = require("DataBlock")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { TIME_MINUTE_IN_SECONDS, getUtcDays } = require("%scripts/time.nut")
let { is_bit_set } = require("%sqstd/math.nut")
let statsd = require("statsd")
let { activeUnlocks, getUnlockReward } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { DECORATION, UNIT, BATTLE_TASK, BATTLE_PASS_CHALLENGE, UNLOCK
} = require("%scripts/utils/genericTooltipTypes.nut")
let { isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { getMainConditionListPrefix, isNestedUnlockMode, getHeaderCondition,
  isBitModeType } = require("%scripts/unlocks/unlocksConditions.nut")
let { getFullUnlockDesc, getUnlockMainCondDescByCfg, getLocForBitValues, buildUnlockDesc,
  getUnlockNameText, getUnlockRewardsText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { isUnlockVisible, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { getDecoratorById } = require("%scripts/customization/decorCache.nut")
let { updateTimeParamsFromBlk, getDifficultyTypeByName,
  EASY_TASK, MEDIUM_TASK, HARD_TASK, UNKNOWN_TASK
} = require("%scripts/unlocks/battleTaskDifficulty.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")
let { loadLocalByAccount, saveLocalByAccount } = require("%scripts/clientState/localProfile.nut")
let { get_personal_unlocks_blk, get_proposed_personal_unlocks_blk } = require("blkGetters")
let { addTask } = require("%scripts/tasker.nut")
let newIconWidget = require("%scripts/newIconWidget.nut")

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

let function getGenerationIdInt(task) {
  let taskGenId = task?._generation_id
  if (!taskGenId)
    return 0

  return isString(taskGenId) ? taskGenId.tointeger() : taskGenId
}

let function isBattleTaskActual(task) {
  if (!task?._generation_id)
    return true

  let taskGenId = getGenerationIdInt(task)
  return taskGenId == lastGenerationId
    || taskGenId == specTasksLastGenerationId
}

let function getBattleTaskById(id) {
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

let function isBattleTask(task) {
  if (isString(task))
    task = getBattleTaskById(task)

  let diff = getDifficultyTypeByTask(task)
  return diff != UNKNOWN_TASK
}

let function isBattleTaskDone(config) {
  if (isEmpty(config))
    return false

  if (isBattleTask(config)) {
    if (!getBattleTaskById(config.id))
      return true // FIXME Task with old difficulty type, not using anymore
    return isUnlockOpened(config.id)
  }
  return isUnlockOpened(config.id)
}

let function getTotalActiveTasksNum() {
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

let function canGetAnyBattleTaskReward() {
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

let function getRequiredDifficultyTypeDone(diff) {
  local res = null
  if (diff.executeOrder > 0)
    res = search(difficultyTypes, @(t) t.executeOrder == (diff.executeOrder - 1))

  return res ?? UNKNOWN_TASK
}

let function canPlayerInteractWithDifficulty(diff, tasksArray) {
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

let function canInteractWithDifficulty(task) {
  let diff = getDifficultyTypeByTask(task)
  return showAllTasks || canPlayerInteractWithDifficulty(diff, currentTasksArray)
}

let canActivateSpecialTask = @() isInMenu()
  && search(proposedTasksArray, isSpecialBattleTask) != null
  && search(activeTasksArray, isSpecialBattleTask) == null

let function compareBattleTasks(a, b) {
  if (a?._sort_order == null || b?._sort_order == null)
    return 0

  return b._sort_order <=> a._sort_order
}

let function isTaskForGM(task, gameModeId) {
  if (!isBattleTask(task))
    return false

  let cfg = ::build_conditions_config(task)
  foreach (condition in cfg.conditions) {
    let values = getTblValue("values", condition)
    if (isEmpty(values))
      continue
    if (isInArray(gameModeId, values))
      return true
  }
  return false
}

let function filterBattleTasksByGameModeId(tasksArray, gameModeId) {
  if (isEmpty(gameModeId))
    return tasksArray

  let res = []
  foreach (task in tasksArray)
    if (isTaskForGM(task, gameModeId))
      res.append(task)
  return res
}

let function isBattleTaskSameDiff(task, difficulty) {
  if (!isBattleTask(task))
    return true

  return isInArray(task?._choiceType ?? "", difficulty.choiceType)
}

let function getBattleTasksByDiff(searchArray, difficulty = null) {
  if (isEmpty(searchArray))
    searchArray = currentTasksArray
  if (isEmpty(difficulty))
    return searchArray

  return searchArray.filter(@(task) isBattleTaskSameDiff(task, difficulty))
}

let withdrawTasksArrayByDifficulty = @(diff, tasks)
  tasks.filter(@(task) diff == getDifficultyTypeByTask(task))

// Returns only tasks that can be completed in the game mode specified,
// including tasks with unclaimed rewards or those that have been completed.
let function getCurBattleTasksByGm(gameModeId) {
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

let function getBattleTasksOrderedByDiff() {
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

let function mkUnlockConfigByBattleTask(task) {
  local config = ::build_conditions_config(task)
  buildUnlockDesc(config)
  config.originTask <- task
  return config
}

let function isUserlogForBattleTasksGroup(body) {
  let unlockId = getTblValue("unlockId", body)
  if (unlockId == null)
    return true

  return getBattleTaskById(unlockId) != null
}

let function getDifficultyByProposals(proposals) {
  let hasHardTask = !!proposals.findvalue(
    @(_, id) getDifficultyTypeByTask(getBattleTaskById(id)) == HARD_TASK)
  return hasHardTask ? HARD_TASK : EASY_TASK
}

let function resetBattleTasks() {
  currentTasksArray.clear()
  activeTasksArray.clear()
  proposedTasksArray.clear()

  seenTasks.clear()
  newIconWidgetByTaskId.clear()
  seenTasksInited = false

  lastGenerationId = 0
  specTasksLastGenerationId = 0
}

let function loadSeenTasksData(forceLoad = false) {
  if (seenTasksInited && !forceLoad)
    return true

  seenTasks.clear()
  let blk = loadLocalByAccount(SEEN_SAVE_ID)
  if (isDataBlock(blk))
    for (local i = 0; i < blk.paramCount(); ++i) {
      let id = blk.getParamName(i)
      seenTasks[id] <- max(blk.getParamValue(i), getTblValue(id, seenTasks, 0))
    }

  seenTasksInited = true
  return true
}

let function isBattleTaskNew(generationId) {
  loadSeenTasksData()
  return generationId not in seenTasks
}

let function markBattleTaskSeen(generationId, sendEvent = true, isNew = false) {
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

let function markAllBattleTasksSeen() {
  local changeNew = false
  foreach (task in currentTasksArray) {
    let generationId = getUniqueId(task)
    let result = markBattleTaskSeen(generationId, false)
    changeNew = changeNew || result
  }

  if (changeNew)
    broadcastEvent("NewBattleTasksChanged")
}

let function saveSeenBattleTasksData() {
  let minDay = getUtcDays() - TASKS_OUT_OF_DATE_DAYS
  let blk = DataBlock()
  foreach (generationId, day in seenTasks) {
    if (day < minDay && !isBattleTaskNew(generationId))
      continue

    blk[generationId] = day
  }

  saveLocalByAccount(SEEN_SAVE_ID, blk)
}

let function updatedProposedTasks() {
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

let function updatedActiveTasks() {
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

let function checkNewSpecialTasks() {
  if (!canActivateSpecialTask())
    return

  let arr = proposedTasksArray.filter(@(t) isSpecialBattleTask(t))
  ::gui_start_battle_tasks_select_new_task_wnd(arr)
}

let function updateCompleteTaskWatched() {
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

let function updateTasksData() {
  currentTasksArray.clear()
  if (!::g_login.isLoggedIn())
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

let function getBattleTaskDiffGroups() {
  let result = []
  foreach (t in difficultyTypes) {
    let difficultyGroup = t.getDifficultyGroup()
    if (difficultyGroup == "")
      continue

    result.append(t)
  }
  return result
}

let function checkCurSpecialTask() {
  if (!isHardTaskIncomplete.value)
    return

  let tasksDataBlock = get_proposed_personal_unlocks_blk()
  let genId = tasksDataBlock?[$"{SPECIAL_TASKS_ID}_lastGenerationId"] ?? 0
  if (genId == 0 || specTasksLastGenerationId == genId)
    return

  updateTasksData()
}

let function sendReceiveRewardRequest(battleTask) {
  let blk = DataBlock()
  blk.unlockName = battleTask.id

  let taskId = ::char_send_blk("cln_reward_specific_battle_task", blk)
  addTask(taskId, { showProgressBox = true }, function() {
    ::update_gamercards()
    broadcastEvent("BattleTasksIncomeUpdate")
    broadcastEvent("BattleTasksRewardReceived")
  })
}

let function requestBattleTaskReward(battleTaskId) {
  if (isEmpty(battleTaskId))
    return

  let battleTask = getBattleTaskById(battleTaskId)
  if (!::g_warbonds.checkOverLimit(battleTask?.amounts_warbond ?? 0,
      sendReceiveRewardRequest, battleTask))
    return

  sendReceiveRewardRequest(battleTask)
}

let function rerollBattleTask(task) {
  if (isEmpty(task))
    return

  let blk = DataBlock()
  blk.unlockName = task.id

  let taskId = ::char_send_blk("cln_reroll_battle_task", blk)
  addTask(taskId, { showProgressBox = true },
    function() {
      statsd.send_counter("sq.battle_tasks.reroll_v2", 1, { task_id = (task?._base_id ?? "null") })
      broadcastEvent("BattleTasksIncomeUpdate")
    }
  )
}

let function rerollSpecialTask(task) {
  if (isEmpty(task))
    return

  let blk = DataBlock()
  blk.unlockName = task.id
  blk.metaTypeName = SPECIAL_TASKS_ID

  let taskId = ::char_send_blk("cln_reroll_all_battle_tasks_for_meta", blk)
  addTask(taskId, { showProgressBox = true },
    function() {
      statsd.send_counter("sq.battle_tasks.special_reroll", 1, { task_id = (task?._base_id ?? "null") })
      broadcastEvent("BattleTasksIncomeUpdate")
    })
}

// View funcs. TODO extract to separate module 'battleTasksView' after circ refs resolved

let function isUnlocksList(config) {
  if (isNestedUnlockMode(config.type))
    foreach (id in config.names) {
      let unlockBlk = getUnlockById(id)
      if (!(unlockBlk?.isMultiUnlock ?? false)
          && ::get_unlock_type(unlockBlk.type) != UNLOCKABLE_STREAK)
        return true
    }
  return false
}

let function getUnlockAdditionalView(unlockId) {
  let unlockBlk = getUnlockById(unlockId)
  if (!unlockBlk || !isUnlockVisible(unlockBlk))
    return {
      isProgressBarVisible = false
      isAddToFavVisible = false
    }

  let unlockConfig = ::build_conditions_config(unlockBlk)
  let unlockDesc = getUnlockMainCondDescByCfg(unlockConfig)

  return {
    unlockId
    unlockProgressDesc = $"({unlockDesc})"
    isProgressBarVisible = true
    progressBarValue = unlockConfig.getProgressBarData().value
    toFavoritesCheckboxVal = isUnlockFav(unlockId) ? "yes" : "no"
  }
}

let function getTooltipMarkupByModeType(config) {
  if (config.type == "char_unit_exist")
    return UNIT.getMarkup(config.id, { showProgress = true })

  if (isBattleTask(config.id))
    return BATTLE_TASK.getMarkup(config.id, { showProgress = true })

  if (activeUnlocks.value?[config.id] != null)
    return BATTLE_PASS_CHALLENGE.getMarkup(config.id, { showProgress = true })

  return UNLOCK.getMarkup(config.id, { showProgress = true })
}

let function getUnlocksListView(config) {
  let res = []

  let namesLoc = getLocForBitValues(config.type, config.names, config.hasCustomUnlockableList)
  let isBitMode = isBitModeType(config.type)
  let isInteractive = config?.isInteractive ?? true
  let isAddToFavVisible = isInteractive && !config.isOnlyInfo

  foreach (idx, unlockId in config.names) {
    let isEven = idx % 2 == 0
    if (config.type == "char_resources") {
      let decorator = getDecoratorById(unlockId)
      if (decorator && decorator.isVisible())
        res.append({
          isEven
          text = decorator.getName()
          isUnlocked = decorator.isUnlocked()
          tooltipMarkup = DECORATION.getMarkup(decorator.id, decorator.decoratorType.unlockedItemType)
          isAddToFavVisible // will be updated to false if no unlock in the decorator
        }.__update(getUnlockAdditionalView(decorator.unlockId)))
    }
    else {
      let unlockBlk = getUnlockById(unlockId)
      if (!unlockBlk || !isUnlockVisible(unlockBlk))
        continue

      let unlockConfig = ::build_conditions_config(unlockBlk)
      let isUnlocked = isBitMode ? is_bit_set(config.curVal, idx) : isUnlockOpened(unlockId)
      let unlockName = namesLoc[idx]
      res.append({
        isEven
        isUnlocked
        text = unlockName
        tooltipMarkup = getTooltipMarkupByModeType(unlockConfig)
        isAddToFavVisible
      }.__update(getUnlockAdditionalView(unlockId)))
    }
  }

  return res
}

let function getUnlockConditionBlock(text, config, isUnlocked, isFinal, compareOR, isBitMode) {
  local unlockDesc = compareOR ? loc("hints/shortcut_separator") + "\n" : ""
  unlockDesc += text
  unlockDesc += compareOR ? "" : loc(isFinal ? "ui/dot" : "ui/comma")

  return {
    tooltipMarkup = getTooltipMarkupByModeType(config)
    overlayTextColor = (isBitMode && isUnlocked) ? "userlog" : "active"
    text = unlockDesc
  }
}

let function getStreaksListView(config) {
  let isBitMode = isBitModeType(config.type)
  let namesLoc = getLocForBitValues(config.type, config.names, config.hasCustomUnlockableList)
  let compareOR = config?.compareOR ?? false

  let res = []
  for (local i = 0; i < namesLoc.len(); ++i) {
    let unlockId = config.names[i]
    let unlockBlk = getUnlockById(unlockId)
    if (!unlockBlk || !isUnlockVisible(unlockBlk))
      continue

    let unlockConfig = ::build_conditions_config(unlockBlk)
    let isUnlocked = !isBitMode || is_bit_set(config.curVal, i)
    res.append(getUnlockConditionBlock(
      namesLoc[i],
      unlockConfig,
      isUnlocked,
      i == namesLoc.len() - 1,
      i > 0 && compareOR,
      isBitMode
    ))
  }

  return res
}

let function getRefreshTimeTextForTask(task) {
  let diff = getDifficultyTypeByTask(task)
  let genId = getGenerationIdInt(task)
  let timeLeft = diff.getTimeLeft(genId)
  if (timeLeft < 0)
    return ""

  local labelText = "".concat(loc("unlocks/_acceptTime"), loc("ui/colon"))
  if (timeLeft < 30 * TIME_MINUTE_IN_SECONDS)
    labelText = colorize("warningTextColor", labelText)
  return "".concat(labelText,  colorize("unlockActiveColor", diff.getTimeLeftText(genId)))
}

let function getBattleTaskDesc(config = null, paramsCfg = {}) {
  if (!config)
    return null

  let task = getBattleTaskById(config)

  let taskDescription = []
  local taskUnlocksListPrefix = ""
  local taskUnlocksList = []
  local taskStreaksList = []
  let isPromo = paramsCfg?.isPromo ?? false

  if (getShowAllTasks())
    taskDescription.append("*Debug info: id - " + config.id)

  if (isPromo) {
    if (getTblValue("locDescId", config, "") != "")
      taskDescription.append(loc(config.locDescId))
    taskDescription.append(getUnlockMainCondDescByCfg(config))
  }
  else {
    taskDescription.append(getFullUnlockDesc(config))

    if (!canGetBattleTaskReward(task)) {
      taskUnlocksListPrefix = getMainConditionListPrefix(config.conditions)

      if (isUnlocksList(config))
        taskUnlocksList = getUnlocksListView(config.__merge({
          isOnlyInfo = !!paramsCfg?.isOnlyInfo
          isInteractive = paramsCfg?.isInteractive
        }))
      else
        taskStreaksList = getStreaksListView(config)
    }
  }

  let progressData = config?.getProgressBarData ? config.getProgressBarData() : null
  let progressBarValue = config?.curVal != null && config.curVal >= 0
    ? (config.curVal.tofloat() / (config?.maxVal ?? 1) * 1000)
    : 0

  let view = {
    id = config.id
    taskDescription =  "\n".join(taskDescription, true)
    taskSpecialDescription = getRefreshTimeTextForTask(task)
    taskUnlocksListPrefix = taskUnlocksListPrefix
    taskUnlocks = taskUnlocksList
    taskStreaks = taskStreaksList
    taskUnlocksList = taskUnlocksList.len() + taskStreaksList.len()
    needShowProgressBar = isPromo && progressData?.show
    progressBarValue = progressBarValue.tointeger()
    isPromo = isPromo
    isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
  }

  return handyman.renderCached("%gui/unlocks/battleTasksDescription.tpl", view)
}

// todo consider separating logic
let function getBattleTaskNameById(param) {
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

let function setBattleTasksUpdateTimer(task, taskBlockObj, addParams = {}) {
  if (!checkObj(taskBlockObj))
    return

  let diff = getDifficultyTypeByTask(task)
  if (!diff.hasTimer)
    return

  local holderObj = taskBlockObj.findObject("task_timer_text")
  if (checkObj(holderObj) && task)
    SecondsUpdater(holderObj, function(obj, params) {
      local timeText = getRefreshTimeTextForTask(task)
      let isTimeEnded = timeText == ""
      let addText = params?.addText ?? ""
      if (isTimeEnded)
        timeText = colorize("badTextColor", loc("mainmenu/battleTasks/timeWasted"))
      obj.setValue($"{addText} {timeText}")

      return isTimeEnded
    }, true, addParams)

  let genId = getGenerationIdInt(task)
  holderObj = taskBlockObj.findObject("tasks_refresh_timer")
  if (checkObj(holderObj))
    SecondsUpdater(holderObj, function(obj, _params) {
      let timeText = EASY_TASK.getTimeLeftText(genId)
      obj.setValue(loc("ui/parentheses/space", { text = timeText + loc("icon/timer") }))

      return timeText == ""
    })

  let timeLeft = diff.getTimeLeft(genId)
  if (timeLeft <= 0)
    return

  Timer(taskBlockObj, timeLeft + 1, @() diff.notifyTimeExpired(genId), this, false, true)
}

let function getRewardMarkUpConfig(task, config) {
  let rewardMarkUp = {}
  let itemId = getTblValue("userLogId", task)
  if (itemId) {
    let item = ::ItemsManager.findItemById(to_integer_safe(itemId, itemId, false))
    if (item)
      rewardMarkUp.itemMarkUp <- item.getNameMarkup(getTblValue("amount_trophies", task))
  }

  local reward = getUnlockRewardsText(config)
  let difficulty = getDifficultyTypeByTask(task)
  let unlockReward = getUnlockReward(activeUnlocks.value?[difficulty.userstatUnlockId])
  reward = reward != "" ? $"{reward}\n{unlockReward.rewardText}" : unlockReward.rewardText
  rewardMarkUp.itemMarkUp <- $"{rewardMarkUp?.itemMarkUp ?? ""}{unlockReward.itemMarkUp}"

  if (difficulty == MEDIUM_TASK) {
    let specialTaskAward = ::g_warbonds.getCurrentWarbond()?.getAwardByType(::g_wb_award_type[EWBAT_BATTLE_TASK])
    if (specialTaskAward?.awardType.hasIncreasingLimit) {
      let rewardText = loc("warbonds/canBuySpecialTasks/awardTitle", { count = 1 })
      reward = reward != "" ? $"{reward}\n{rewardText}" : rewardText
    }
  }

  if (reward == "" && !rewardMarkUp.len())
    return rewardMarkUp

  let rewardLoc = isBattleTaskDone(task) ? loc("rewardReceived") : loc("reward")
  rewardMarkUp.rewardText <- rewardLoc + loc("ui/colon") + reward
  return rewardMarkUp
}

let function getBattleTaskDifficultyImage(task) {
  let difficulty = getDifficultyTypeByTask(task)
  if (difficulty.showSeasonIcon) {
    let curWarbond = ::g_warbonds.getCurrentWarbond()
    if (curWarbond)
      return curWarbond.getMedalIcon()
  }

  return difficulty.image
}

let function getBattleTaskView(config, paramsCfg = {}) {
  let isPromo = paramsCfg?.isPromo ?? false
  let isShortDescription = paramsCfg?.isShortDescription ?? false
  let isInteractive = paramsCfg?.isInteractive ?? true
  let task = getBattleTaskById(config) || getTblValue("originTask", config)
  let isTaskBattleTask = isBattleTask(task)
  let isCanGetReward = canGetBattleTaskReward(task)
  let isUnlock = "unlockType" in config
  let title = isTaskBattleTask ? getBattleTaskNameById(task.id)
    : isUnlock ? getUnlockNameText(config.unlockType, config.id)
    : getTblValue("text", config, "")
  let headerCond = isUnlock ? getHeaderCondition(config.conditions) : null
  let id = isTaskBattleTask ? task.id : config.id
  let progressData = config?.getProgressBarData ? config.getProgressBarData() : null
  let progressBarValue = config?.curVal != null && config.curVal >= 0
    ? (config.curVal.tofloat() / (config?.maxVal ?? 1) * 1000)
    : 0
  let taskStatus = getTaskStatus(task)

  return {
    id
    title
    taskStatus
    taskImage = (paramsCfg?.showUnlockImage ?? true)
      && (getTblValue("image", task) || getTblValue("image", config))
    taskDifficultyImage = getBattleTaskDifficultyImage(task)
    taskHeaderCondition = headerCond ? loc("ui/parentheses/space", { text = headerCond }) : null
    description = isTaskBattleTask || isUnlock ? getBattleTaskDesc(config, paramsCfg) : null
    reward = isPromo ? null : getRewardMarkUpConfig(task, config)
    newIconWidget = (isInteractive && isTaskBattleTask && !isBattleTaskActive(task))
      ? newIconWidget.createLayout()
      : null
    canGetReward = isInteractive && isTaskBattleTask && isCanGetReward
    canReroll = isInteractive && isTaskBattleTask && !isCanGetReward
    otherTasksNum = (task && isPromo) ? getTotalActiveTasksNum() : null
    isLowWidthScreen = isPromo ? is_low_width_screen() : null
    isPromo
    isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
    needShowProgressValue = (taskStatus == null)
      && (config?.curVal != null) && (config.curVal >= 0)
      && (config?.maxVal != null) && (config.maxVal >= 0)
    progressValue = config?.curVal
    progressMaxValue = config?.maxVal
    needShowProgressBar = progressData?.show
    progressBarValue = progressBarValue.tointeger()
    getTooltipId = (isPromo || isShortDescription) && isTaskBattleTask
      ? @() BATTLE_TASK.getTooltipId(id)
      : null
    isShortDescription
    shouldRefreshTimer = config?.shouldRefreshTimer ?? false
  }
}

let getBattleTaskLocIdFromUserlog = @(logObj, taskId) ("locId" in logObj)
  ? loc(logObj.locId) : getBattleTaskNameById(taskId)

let function getBattleTaskUserLogText(table, taskId) {
  let res = [getBattleTaskLocIdFromUserlog(table, taskId)]
  let cost = Cost(table?.cost ?? 0, table?.costGold ?? 0)
  if (!isEmpty(cost))
    res.append(loc("ui/parentheses/space", { text = cost.tostring() }))

  return "".join(res)
}

let function getBattleTaskUpdateDesc(logObj) {
  let res = {}
  let blackList = []
  let whiteList = []

  foreach (taskId, table in logObj) {
    local header = ""
    let diffTypeName = getTblValue("type", table)
    if (diffTypeName) {
      if (isInArray(diffTypeName, blackList))
        continue

      let diff = getDifficultyTypeByName(diffTypeName)
      if (!isInArray(diffTypeName, whiteList) && !showAllTasks
          && !canPlayerInteractWithDifficulty(diff, proposedTasksArray)) {
        blackList.append(diffTypeName)
        continue
      }

      whiteList.append(diffTypeName)
      header = diff.userlogHeaderName
    }

    if (header not in res)
      res[header] <- []

    res[header].append(getBattleTaskUserLogText(table, taskId))
  }

  local data = ""
  local lastUserLogHeader = ""
  foreach (userlogHeader, arr in res) {
    if (arr.len() == 0)
      continue

    data += data == "" ? "" : "\n"
    if (lastUserLogHeader != userlogHeader) {
      data += loc($"userlog/battletask/type/{userlogHeader}") + loc("ui/colon")
      lastUserLogHeader = userlogHeader
    }
    data += "\n".join(arr, true)
  }

  return data
}

// FIXME circular refs with challenges,
// unlocksViewModule, genericTooltipTypes
::g_battle_tasks <- {
  isBattleTask
  mkUnlockConfigByBattleTask
  getBattleTaskById
  // view funcs
  getBattleTaskDesc
  getBattleTaskNameById
  getBattleTaskView
}

addListenersWithoutEnv({
  function LoginComplete(_) {
    resetBattleTasks()
    updateTasksData()
  }

  ProfileUpdated = @(_) checkCurSpecialTask()
  BattleTasksIncomeUpdate = @(_) updateTasksData()
  BattleEnded = @(_) updateTasksData()
  ScriptsReloaded = @(_) updateTasksData() // todo consider implement persist
  SignOut = @(_) resetBattleTasks()

  // debug
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
  mkUnlockConfigByBattleTask
  getShowAllTasks // debug
  // view
  setBattleTasksUpdateTimer
  getBattleTaskNameById
  getBattleTaskDifficultyImage
  getBattleTaskView
  getBattleTaskUserLogText
  getBattleTaskUpdateDesc
}
