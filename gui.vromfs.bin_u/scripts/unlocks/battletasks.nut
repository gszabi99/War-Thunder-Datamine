//-file:plus-string
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")


let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock = require("DataBlock")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let time = require("%scripts/time.nut")
let stdMath = require("%sqstd/math.nut")
let statsd = require("statsd")
let { activeUnlocks, getUnlockReward } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { DECORATION, UNIT, BATTLE_TASK, BATTLE_PASS_CHALLENGE, UNLOCK
} = require("%scripts/utils/genericTooltipTypes.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { getMainConditionListPrefix, isNestedUnlockMode, getHeaderCondition,
  isBitModeType } = require("%scripts/unlocks/unlocksConditions.nut")
let { getFullUnlockDesc, getUnlockMainCondDescByCfg, getLocForBitValues,
  getUnlockNameText, getUnlockRewardsText } = require("%scripts/unlocks/unlocksViewModule.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { getDecoratorById } = require("%scripts/customization/decorCache.nut")
let { updateTimeParamsFromBlk, getDifficultyTypeByName, getDifficultyTypeByTask,
  canPlayerInteractWithDifficulty, withdrawTasksArrayByDifficulty,
  EASY_TASK, MEDIUM_TASK, HARD_TASK, UNKNOWN_TASK
} = require("%scripts/unlocks/battleTaskDifficulty.nut")

let difficultyTypes = [
  EASY_TASK,
  MEDIUM_TASK,
  HARD_TASK
]

::g_battle_tasks <- null

::BattleTasks <- class {
  PLAYER_CONFIG_PATH = "seen/battletasks"
  specialTasksId = "specialTasksPersonalUnlocks"
  dailyTasksId = "dailyPersonalUnlocks"

  currentTasksArray = null
  activeTasksArray = null
  proposedTasksArray = null

  seenTasks = null
  newIconWidgetByTaskId = null

  TASKS_OUT_OF_DATE_DAYS = 15
  lastGenerationId = null
  specTasksLastGenerationId = null

  rerollCost = null

  seenTasksInited = false
  showAllTasksValue = false

  currentPlayback = null

  isCompleteMediumTask = null
  isCompleteEasyTask = null
  hasInCompleteHardTask = null

  constructor() {
    this.currentTasksArray = []
    this.activeTasksArray = []
    this.proposedTasksArray = []

    this.isCompleteMediumTask = Watched(false)
    this.isCompleteEasyTask = Watched(false)
    this.hasInCompleteHardTask = Watched(false)

    this.seenTasks = {}
    this.newIconWidgetByTaskId = {}

    this.lastGenerationId = 0
    this.specTasksLastGenerationId = 0

    subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function reset() {
    this.currentTasksArray.clear()
    this.activeTasksArray.clear()
    this.proposedTasksArray.clear()

    this.seenTasks = {}
    this.newIconWidgetByTaskId = {}
    this.seenTasksInited = false

    this.lastGenerationId = 0
    this.specTasksLastGenerationId = 0
  }

  isAvailableForUser = @() hasFeature("BattleTasks")
    && !u.isEmpty(this.getTasksArray())
    && isMultiplayerPrivilegeAvailable.value

  function updateTasksData() {
    this.currentTasksArray.clear()
    if (!::g_login.isLoggedIn())
      return

    this.updatedProposedTasks()
    this.updatedActiveTasks()

    this.currentTasksArray.sort(function(a, b) {
      if (a?._sort_order == null || b?._sort_order == null)
        return 0

      if (a._sort_order == b._sort_order)
        return 0

      return a._sort_order > b._sort_order ? 1 : -1
    })

    if (::isInMenu())
      this.checkNewSpecialTasks()
    this.updateCompleteTaskWatched()
    broadcastEvent("BattleTasksFinishedUpdate")
  }

  function onEventBattleTasksShowAll(params) {
    this.showAllTasksValue = getTblValue("showAllTasksValue", params, false)
    this.updateTasksData()
  }

  function onEventBattleTasksIncomeUpdate(_params) { this.updateTasksData() }
  function onEventBattleEnded(_params)             { this.updateTasksData() }

  function updatedProposedTasks() {
    let tasksDataBlock = ::get_proposed_personal_unlocks_blk()
    updateTimeParamsFromBlk(tasksDataBlock)
    this.lastGenerationId = tasksDataBlock?[this.dailyTasksId + "_lastGenerationId"] ?? 0
    this.specTasksLastGenerationId = tasksDataBlock?[this.specialTasksId + "_lastGenerationId"] ?? 0

    this.updateRerollCost(tasksDataBlock)

    this.proposedTasksArray = []
    this.newIconWidgetByTaskId = {}

    for (local i = 0; i < tasksDataBlock.blockCount(); i++) {
      let task = DataBlock()
      task.setFrom(tasksDataBlock.getBlock(i))
      task.isActive = false
      this.proposedTasksArray.append(task)
      if (!this.isTaskActual(task) || !this.canInteract(task))
        continue

      this.currentTasksArray.append(task)
      this.newIconWidgetByTaskId[this.getUniqueId(task)] <- null
    }
  }

  function updatedActiveTasks() {
    let currentActiveTasks = ::get_personal_unlocks_blk()
    this.activeTasksArray.clear()
    for (local i = 0; i < currentActiveTasks.blockCount(); i++) {
      let task = DataBlock()
      task.setFrom(currentActiveTasks.getBlock(i))

      if (!this.isBattleTask(task))
        continue

      task.isActive = true
      this.activeTasksArray.append(task)

      if (!this.isTaskActual(task) || !this.canInteract(task))
        continue

      this.currentTasksArray.append(task)
      let isNew = !this.isTaskDone(task) && this.canGetReward(task)
      this.markTaskSeen(this.getUniqueId(task), false, isNew)
      this.newIconWidgetByTaskId[this.getUniqueId(task)] <- null
    }
  }

  function updateRerollCost(tasksDataBlock) {
    this.rerollCost = Cost(getTblValue("_rerollCost", tasksDataBlock, 0),
                        getTblValue("_rerollGoldCost", tasksDataBlock, 0))
  }

  function isTaskActive(task) {
    return getTblValue("isActive", task, true)
  }

  function isTaskTimeExpired(task) {
    return getDifficultyTypeByTask(task).isTimeExpired(task)
  }

  function isTaskDone(config) {
    if (u.isEmpty(config))
      return false

    if (this.isBattleTask(config)) {
      if (!this.getTaskById(config.id))
        return true //Task with old difficulty type, not using anymore
      return ::is_unlocked_scripted(-1, config.id)
    }
    return ::is_unlocked_scripted(-1, config.id)
  }

  function canGetReward(task) {
    return this.isBattleTask(task)
           && this.isTaskActual(task)
           && !this.isTaskDone(task)
           && getTblValue("_readyToReward", task, false)
  }

  function canGetAnyReward() {
    foreach (task in this.getActiveTasksArray())
      if (this.canGetReward(task))
        return true
    return false
  }

  function getTasksArray() { return this.currentTasksArray }
  function getActiveTasksArray() { return this.activeTasksArray }
  function getWidgetsTable() { return this.newIconWidgetByTaskId }

  function debugClearSeenData() {
    this.seenTasks = {}
    this.saveSeenTasksData()
    //!!fix me: need to recount seen data from active tasks
  }

  function loadSeenTasksData(forceLoad = false) {
    if (this.seenTasksInited && !forceLoad)
      return true

    this.seenTasks.clear()
    let blk = ::loadLocalByAccount(this.PLAYER_CONFIG_PATH)
    if (type(blk) == "instance" && (blk instanceof DataBlock))
      for (local i = 0; i < blk.paramCount(); i++) {
        let id = blk.getParamName(i)
        this.seenTasks[id] <- max(blk.getParamValue(i), getTblValue(id, this.seenTasks, 0))
      }

    this.seenTasksInited = true
    return true
  }

  function saveSeenTasksData() {
    let minDay = time.getUtcDays() - this.TASKS_OUT_OF_DATE_DAYS
    let blk = DataBlock()
    foreach (generation_id, day in this.seenTasks) {
      if (day < minDay && !this.isBattleTaskNew(generation_id))
        continue

      blk[generation_id] = day
    }

    ::saveLocalByAccount(this.PLAYER_CONFIG_PATH, blk)
  }

  function isBattleTaskNew(generation_id) {
    this.loadSeenTasksData()
    return !(generation_id in this.seenTasks)
  }

  function markTaskSeen(generation_id, sendEvent = true, isNew = false) {
    let wasNew = this.isBattleTaskNew(generation_id)
    if (wasNew == isNew)
      return false

    if (!isNew)
      this.seenTasks[generation_id] <- time.getUtcDays()
    else if (generation_id in this.seenTasks)
      delete this.seenTasks[generation_id]

    if (sendEvent)
      broadcastEvent("NewBattleTasksChanged")
    return true
  }

  function markAllTasksSeen() {
    local changeNew = false
    foreach (task in this.currentTasksArray) {
      let generation_id = this.getUniqueId(task)
      let result = this.markTaskSeen(generation_id, false)
      changeNew = changeNew || result
    }

    if (changeNew)
      broadcastEvent("NewBattleTasksChanged")
  }

  function getUnseenTasksCount() {
    this.loadSeenTasksData()

    local num = 0
    foreach (_idx, task in this.currentTasksArray) {
      if (!this.isBattleTaskNew(this.getUniqueId(task)))
        continue

      num++
    }
    return num
  }

  function getLocalizedTaskNameById(param) {
    local task = null
    local id = null
    if (u.isDataBlock(param)) {
      task = param
      id = getTblValue("id", param)
    }
    else if (u.isString(param)) {
      task = this.getTaskById(param)
      id = param
    }
    else
      return ""

    return loc(getTblValue("locId", task, "battletask/" + id))
  }

  function getTaskById(id) {
    if (u.isTable(id) || u.isDataBlock(id))
      id = getTblValue("id", id)

    if (!id)
      return null

    foreach (task in this.activeTasksArray)
      if (task.id == id)
        return task

    foreach (task in this.proposedTasksArray)
      if (task.id == id)
        return task

    return null
  }

  function generateUnlockConfigByTask(task) {
    local config = ::build_conditions_config(task)
    ::build_unlock_desc(config)
    config.originTask <- task
    return config
  }

  function getUniqueId(task) {
    return task.id
  }

  function isController(config) {
    return getTblValue("_controller", config, false)
  }

  function isBattleTask(task) {
    if (u.isString(task))
      task = this.getTaskById(task)

    let diff = getDifficultyTypeByTask(task)
    return diff != UNKNOWN_TASK
  }

  function isUserlogForBattleTasksGroup(body) {
    let unlockId = getTblValue("unlockId", body)
    if (unlockId == null)
      return true

    return this.getTaskById(unlockId) != null
  }

  //currently it is using in userlog
  function generateUpdateDescription(logObj) {
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
        if (!isInArray(diffTypeName, whiteList)
            && !canPlayerInteractWithDifficulty(diff,
              this.proposedTasksArray, this.showAllTasksValue)) {
          blackList.append(diffTypeName)
          continue
        }

        whiteList.append(diffTypeName)
        header = diff.userlogHeaderName
      }
      if (!(header in res))
        res[header] <- []

      res[header].append(this.generateStringForUserlog(table, taskId))
    }

    local data = ""
    local lastUserLogHeader = ""
    foreach (userlogHeader, arr in res) {
      if (arr.len() == 0)
        continue

      data += data == "" ? "" : "\n"
      if (lastUserLogHeader != userlogHeader) {
        data += loc("userlog/battletask/type/" + userlogHeader) + loc("ui/colon")
        lastUserLogHeader = userlogHeader
      }
      data +=  "\n".join(arr, true)
    }

    return data
  }

  function getDifficultyByProposals(proposals) {
    if (proposals.findindex(function(_v, id) {
      let battleTask = ::g_battle_tasks.getTaskById(id)
      return HARD_TASK == getDifficultyTypeByTask(battleTask)
    }))
      return HARD_TASK

    return EASY_TASK
  }

  function generateStringForUserlog(table, taskId) {
    local text = this.getBattleTaskLocIdFromUserlog(table, taskId)
    let cost = Cost(getTblValue("cost", table, 0), getTblValue("costGold", table, 0))
    if (!u.isEmpty(cost))
      text += loc("ui/parentheses/space", { text = cost.tostring() })

    return text
  }

  function getBattleTaskLocIdFromUserlog(logObj, taskId) {
    return "locId" in logObj ? loc(logObj.locId) : this.getLocalizedTaskNameById(taskId)
  }

  function getImage(imageName = null) {
    if (imageName)
      return "ui/images/battle_tasks/" + imageName + "?P1"
    return null
  }

  function getTaskStatus(task) {
    if (this.canGetReward(task))
      return "complete"
    if (this.isTaskDone(task))
      return "done"
    if (this.isTaskTimeExpired(task))
      return "failed"
    return null
  }

  function getGenerationIdInt(task) {
    let taskGenId = task?._generation_id
    if (!taskGenId)
      return 0

    return u.isString(taskGenId) ? taskGenId.tointeger() : taskGenId
  }

  function isTaskActual(task) {
    if (!task?._generation_id)
      return true

    let taskGenId = this.getGenerationIdInt(task)
    return taskGenId == this.lastGenerationId
      || taskGenId == this.specTasksLastGenerationId
  }

  function isTaskUnderControl(checkTask, taskController, typesToCheck = null) {
    if (taskController.id == checkTask.id || taskController?._generation_id != checkTask?._generation_id)
      return false
    if (!typesToCheck)
      return true

    return isInArray(getDifficultyTypeByTask(checkTask).name, typesToCheck)
  }

  function getTasksListByControllerTask(taskController, conditions) {
    let tasksArray = []
    if (!this.isController(taskController))
      return tasksArray

    let unlocksCond = u.search(conditions, function(cond) { return cond.type == "char_personal_unlock" })
    let personalUnlocksTypes = unlocksCond && unlocksCond.values

    foreach (task in this.currentTasksArray)
      if (this.isTaskUnderControl(task, taskController, personalUnlocksTypes))
        tasksArray.append(task)

    return tasksArray
  }

  function getTaskWithAvailableAward(tasksArray) {
    return u.search(tasksArray, function(task) {
        return this.canGetReward(task)
      }.bindenv(this))
  }

  function getTaskDescription(config = null, paramsCfg = {}) {
    if (!config)
      return null

    let task = this.getTaskById(config)

    let taskDescription = []
    local taskUnlocksListPrefix = ""
    local taskUnlocksList = []
    local taskStreaksList = []
    let taskConditionsList = []
    let isPromo = paramsCfg?.isPromo ?? false

    if (this.showAllTasksValue)
      taskDescription.append("*Debug info: id - " + config.id)

    if (isPromo) {
      if (getTblValue("locDescId", config, "") != "")
        taskDescription.append(loc(config.locDescId))
      taskDescription.append(getUnlockMainCondDescByCfg(config))
    }
    else {
      taskDescription.append(getFullUnlockDesc(config))

      if (!this.canGetReward(task)) {
        taskUnlocksListPrefix = getMainConditionListPrefix(config.conditions)

        if (this.isUnlocksList(config))
          taskUnlocksList = this.getUnlocksListView(config.__merge({
            isOnlyInfo = !!paramsCfg?.isOnlyInfo
            isInteractive = paramsCfg?.isInteractive
          }))
        else
          taskStreaksList = this.getStreaksListView(config)
      }

      let controlledTasks = this.getTasksListByControllerTask(task, config.conditions)
      foreach (contrTask in controlledTasks) {
        taskConditionsList.append({
          unlocked = this.isTaskDone(contrTask)
          text = colorize(this.isActive(contrTask) ? "userlogColoredText" : "", this.getLocalizedTaskNameById(contrTask))
        })
      }
    }

    let progressData = config?.getProgressBarData ? config.getProgressBarData() : null
    let progressBarValue = config?.curVal != null && config.curVal >= 0
      ? (config.curVal.tofloat() / (config?.maxVal ?? 1) * 1000)
      : 0

    let view = {
      id = config.id
      taskDescription =  "\n".join(taskDescription, true)
      taskSpecialDescription = this.getRefreshTimeTextForTask(task)
      taskUnlocksListPrefix = taskUnlocksListPrefix
      taskUnlocks = taskUnlocksList
      taskStreaks = taskStreaksList
      taskUnlocksList = taskUnlocksList.len() + taskStreaksList.len()
      taskConditionsList = taskConditionsList.len() ? taskConditionsList : null
      needShowProgressBar = isPromo && progressData?.show
      progressBarValue = progressBarValue.tointeger()
      isPromo = isPromo
      isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
    }

    return handyman.renderCached("%gui/unlocks/battleTasksDescription.tpl", view)
  }

  function getUnlockConditionBlock(text, _id, config, isUnlocked, isFinal, compareOR = false, isBitMode = true) {
    local unlockDesc = compareOR ? loc("hints/shortcut_separator") + "\n" : ""
    unlockDesc += text
    unlockDesc += compareOR ? "" : loc(isFinal ? "ui/dot" : "ui/comma")

    return {
      tooltipMarkup = this.getTooltipMarkupByModeType(config)
      overlayTextColor = (isBitMode && isUnlocked) ? "userlog" : "active"
      text = unlockDesc
    }
  }

  function isUnlocksList(config) {
    if (isNestedUnlockMode(config.type))
      foreach (id in config.names) {
        let unlockBlk = getUnlockById(id)
        if (!(unlockBlk?.isMultiUnlock ?? false) && ::get_unlock_type(unlockBlk.type) != UNLOCKABLE_STREAK)
          return true
      }
    return false
  }

  function getUnlockAdditionalView(unlockId) {
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
      progressBarValue=unlockConfig.getProgressBarData().value
      toFavoritesCheckboxVal = isUnlockFav(unlockId) ? "yes" : "no"
    }
  }

  function getUnlocksListView(config) {
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
          }.__update(this.getUnlockAdditionalView(decorator.unlockId)))
      }
      else {
        let unlockBlk = getUnlockById(unlockId)
        if (!unlockBlk || !isUnlockVisible(unlockBlk))
          continue

        let unlockConfig = ::build_conditions_config(unlockBlk)
        let isUnlocked = isBitMode ? stdMath.is_bit_set(config.curVal, idx) : ::is_unlocked_scripted(-1, unlockId)
        let unlockName = namesLoc[idx]
        res.append({
          isEven
          isUnlocked
          text = unlockName
          tooltipMarkup = this.getTooltipMarkupByModeType(unlockConfig)
          isAddToFavVisible
        }.__update(this.getUnlockAdditionalView(unlockId)))
      }
    }

    return res
  }

  function getStreaksListView(config) {
    let isBitMode = isBitModeType(config.type)
    let namesLoc = getLocForBitValues(config.type, config.names, config.hasCustomUnlockableList)
    let compareOR = config?.compareOR ?? false

    let res = []
    for (local i = 0; i < namesLoc.len(); i++) {
      let unlockId = config.names[i]
      let unlockBlk = getUnlockById(unlockId)
      if (!unlockBlk || !isUnlockVisible(unlockBlk))
        continue

      let unlockConfig = ::build_conditions_config(unlockBlk)
      let isUnlocked = !isBitMode || stdMath.is_bit_set(config.curVal, i)
      res.append(this.getUnlockConditionBlock(
        namesLoc[i],
        unlockId,
        unlockConfig,
        isUnlocked,
        i == namesLoc.len() - 1,
        i > 0 && compareOR,
        isBitMode
      ))
    }

    return res
  }

  function getTooltipMarkupByModeType(config) {
    if (config.type == "char_unit_exist")
      return UNIT.getMarkup(config.id, { showProgress = true })

    if (this.isBattleTask(config.id))
      return BATTLE_TASK.getMarkup(config.id, { showProgress = true })

    if (activeUnlocks.value?[config.id] != null)
      return BATTLE_PASS_CHALLENGE.getMarkup(config.id, { showProgress = true })

    return UNLOCK.getMarkup(config.id, { showProgress = true })
  }

  function getRefreshTimeTextForTask(task) {
    let diff = getDifficultyTypeByTask(task)
    let timeLeft = diff.getTimeLeft(task)
    if (timeLeft < 0)
      return ""

    local labelText = "".concat(loc("unlocks/_acceptTime"), loc("ui/colon"))
    if (timeLeft < 30 * time.TIME_MINUTE_IN_SECONDS)
      labelText = colorize("warningTextColor", labelText)
    return "".concat(labelText,  colorize("unlockActiveColor", diff.getTimeLeftText(task)))
  }

  function setUpdateTimer(task, taskBlockObj, addParams = {}) {
    if (!checkObj(taskBlockObj))
      return

    let diff = getDifficultyTypeByTask(task)
    if (!diff.hasTimer)
      return

    local holderObj = taskBlockObj.findObject("task_timer_text")
    if (checkObj(holderObj) && task)
      SecondsUpdater(holderObj, function(obj, params) {
        local timeText = ::g_battle_tasks.getRefreshTimeTextForTask(task)
        let isTimeEnded = timeText == ""
        let addText = params?.addText ?? ""
        if (isTimeEnded)
          timeText = colorize("badTextColor", loc("mainmenu/battleTasks/timeWasted"))
        obj.setValue($"{addText} {timeText}")

        return isTimeEnded
      }, true, addParams)

    holderObj = taskBlockObj.findObject("tasks_refresh_timer")
    if (checkObj(holderObj))
      SecondsUpdater(holderObj, function(obj, _params) {
        let timeText = EASY_TASK.getTimeLeftText(task)
        obj.setValue(loc("ui/parentheses/space", { text = timeText + loc("icon/timer") }))

        return timeText == ""
      })

    let timeLeft = diff.getTimeLeft(task)
    if (timeLeft > 0)
      ::Timer(taskBlockObj, timeLeft + 1, @() diff.notifyTimeExpired(task), this, false, true)
  }

  function getPlaybackPath(playbackName, shouldUseDefaultLang = false) {
    if (u.isEmpty(playbackName))
      return ""

    let guiBlk = GUI.get()
    let unlockPlaybackPath = guiBlk?.unlockPlaybackPath
    if (!unlockPlaybackPath)
      return ""

    let path = unlockPlaybackPath.mainPath
    let abbrev = shouldUseDefaultLang ? "en" : ::g_language.getShortName()
    return path + abbrev + "/" + playbackName + unlockPlaybackPath.fileExtension
  }

  function getRewardMarkUpConfig(task, config) {
    let rewardMarkUp = {}
    let itemId = getTblValue("userLogId", task)
    if (itemId) {
      let item = ::ItemsManager.findItemById(::to_integer_safe(itemId, itemId, false))
      if (item)
        rewardMarkUp.itemMarkUp <- item.getNameMarkup(getTblValue("amount_trophies", task))
    }

    local reward = getUnlockRewardsText(config)
    let difficulty = getDifficultyTypeByTask(task)
    if (hasFeature("BattlePass")) {
      let unlockReward = getUnlockReward(activeUnlocks.value?[difficulty.userstatUnlockId])

      reward = reward != "" ? $"{reward}\n{unlockReward.rewardText}" : unlockReward.rewardText
      rewardMarkUp.itemMarkUp <- $"{rewardMarkUp?.itemMarkUp ?? ""}{unlockReward.itemMarkUp}"
    }

    if (difficulty == MEDIUM_TASK) {
      let specialTaskAward = ::g_warbonds.getCurrentWarbond()?.getAwardByType(::g_wb_award_type[EWBAT_BATTLE_TASK])
      if (specialTaskAward?.awardType.hasIncreasingLimit()) {
        let rewardText = loc("warbonds/canBuySpecialTasks/awardTitle", { count = 1 })
        reward = reward != "" ? $"{reward}\n{rewardText}" : rewardText
      }
    }

    if (reward == "" && !rewardMarkUp.len())
      return rewardMarkUp

    let rewardLoc = this.isTaskDone(task) ? loc("rewardReceived") : loc("reward")
    rewardMarkUp.rewardText <- rewardLoc + loc("ui/colon") + reward
    return rewardMarkUp
  }

  function generateItemView(config, paramsCfg = {}) {
    let isPromo = paramsCfg?.isPromo ?? false
    let isShortDescription = paramsCfg?.isShortDescription ?? false
    let isInteractive = paramsCfg?.isInteractive ?? true
    let task = this.getTaskById(config) || getTblValue("originTask", config)
    let isTaskBattleTask = this.isBattleTask(task)
    let isCanGetReward = this.canGetReward(task)

    let isUnlock = "unlockType" in config

    let title = isTaskBattleTask ? this.getLocalizedTaskNameById(task.id)
                : (isUnlock ? getUnlockNameText(config.unlockType, config.id) : getTblValue("text", config, ""))
    let headerCond = isUnlock ? getHeaderCondition(config.conditions) : null

    let id = isTaskBattleTask ? task.id : config.id
    let progressData = config?.getProgressBarData ? config.getProgressBarData() : null
    let progressBarValue = config?.curVal != null && config.curVal >= 0
      ? (config.curVal.tofloat() / (config?.maxVal ?? 1) * 1000)
      : 0
    let taskStatus = this.getTaskStatus(task)

    return {
      id
      title
      taskStatus
      taskImage = (paramsCfg?.showUnlockImage ?? true) && (getTblValue("image", task) || getTblValue("image", config))
      taskPlayback = getTblValue("playback", task) || getTblValue("playback", config)
      isPlaybackDownloading = !::g_sound.canPlay(id)
      taskDifficultyImage = this.getDifficultyImage(task)
      taskHeaderCondition = headerCond ? loc("ui/parentheses/space", { text = headerCond }) : null
      description = isTaskBattleTask || isUnlock ? this.getTaskDescription(config, paramsCfg) : null
      reward = isPromo ? null : this.getRewardMarkUpConfig(task, config)
      newIconWidget = (isInteractive && isTaskBattleTask)
        ? (this.isTaskActive(task) ? null : ::NewIconWidget.createLayout())
        : null
      canGetReward = isInteractive && isTaskBattleTask && isCanGetReward
      canReroll = isInteractive && isTaskBattleTask && !isCanGetReward
      otherTasksNum = task && isPromo ? this.getTotalActiveTasksNum() : null
      isLowWidthScreen = isPromo ? ::is_low_width_screen() : null
      isPromo
      isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
      needShowProgressValue = taskStatus == null && config?.curVal != null && config.curVal >= 0 && config?.maxVal != null && config.maxVal >= 0
      progressValue = config?.curVal
      progressMaxValue = config?.maxVal
      needShowProgressBar = progressData?.show
      progressBarValue = progressBarValue.tointeger()
      getTooltipId = (isPromo || isShortDescription) && isTaskBattleTask ? @() BATTLE_TASK.getTooltipId(id) : null
      isShortDescription
      shouldRefreshTimer = config?.shouldRefreshTimer ?? false
    }
  }

  function getTotalActiveTasksNum() {
    local num = 0
    foreach (task in this.getActiveTasksArray())
      if (this.isTaskActual(task) && !this.isTaskDone(task))
        num++
    return num
  }

  function getDifficultyImage(task) {
    let difficulty = getDifficultyTypeByTask(task)
    if (difficulty.showSeasonIcon) {
      let curWarbond = ::g_warbonds.getCurrentWarbond()
      if (curWarbond)
        return curWarbond.getMedalIcon()
    }

    return difficulty.image
  }

  function getTasksArrayByIncreasingDifficulty() {
    let result = []
    foreach (t in difficultyTypes) {
      let arr = withdrawTasksArrayByDifficulty(t, this.currentTasksArray)
      if (arr.len() == 0)
        continue

      if (canPlayerInteractWithDifficulty(t, this.currentTasksArray))
        result.extend(arr)
    }
    return result
  }

  // Returns only tasks that can be completed in the game mode specified,
  // including tasks with unclaimed rewards or those that have been completed.
  function getCurBattleTasksByGm(gameModeId) {
    let hasTaskForGm = this.activeTasksArray.findindex(
      @(t) ::g_battle_tasks.isTaskForGM(t, gameModeId)) != null
    if (!hasTaskForGm)
      return []

    let tasks = this.activeTasksArray.filter(@(t) ::g_battle_tasks.isTaskActual(t))
    let res = []
    foreach (diff in difficultyTypes) {
      let taskCanInteract = canPlayerInteractWithDifficulty(diff, tasks)
      if (!taskCanInteract)
        continue

      let tasksByDiff = withdrawTasksArrayByDifficulty(diff, tasks)
      if (tasksByDiff.len() == 0)
        continue

      let taskWithReward = this.getTaskWithAvailableAward(tasksByDiff)
      if (taskWithReward != null)
        res.append(taskWithReward)
      else
        res.extend(tasksByDiff.filter(@(t) ::g_battle_tasks.isTaskDone(t)
          || ::g_battle_tasks.isTaskForGM(t, gameModeId)))
    }
    return res
  }

  function isTaskForGM(task, gameModeId) {
    if (!this.isBattleTask(task))
      return false

    let cfg = ::build_conditions_config(task)
    foreach (condition in cfg.conditions) {
      let values = getTblValue("values", condition)
      if (u.isEmpty(values))
        continue
      if (isInArray(gameModeId, values))
        return true
    }
    return false
  }

  function filterTasksByGameModeId(tasksArray, gameModeId) {
    if (u.isEmpty(gameModeId))
      return tasksArray

    let res = []
    foreach (task in tasksArray)
      if (this.isTaskForGM(task, gameModeId))
        res.append(task)
    return res
  }

  function getTasksArrayByDifficulty(searchArray, difficulty = null) {
    if (u.isEmpty(searchArray))
      searchArray = this.currentTasksArray

    if (u.isEmpty(difficulty))
      return searchArray

    return searchArray.filter(@(task) ::g_battle_tasks.isTaskSameDifficulty(task, difficulty))
  }

  function isTaskSameDifficulty(task, difficulty) {
    if (!this.isBattleTask(task))
      return true

    return isInArray(task?._choiceType ?? "", difficulty.choiceType)
  }

  function isTaskSuitableForUnitTypeMask(task, unitTypeMask) {
    if (!this.isBattleTask(task))
      return false

    let blk = ::build_conditions_config(task)
    foreach (condition in blk.conditions) {
      let values = getTblValue("values", condition)
      if (u.isEmpty(values))
        continue

      foreach (value in values) {
        let gameMode = ::game_mode_manager.getGameModeById(value)
        if (!gameMode)
          continue

        foreach (unitType in gameMode.unitTypes)
          if (stdMath.is_bit_set(unitTypeMask, unitType))
            return true

        break
      }
    }

    return false
  }

  function requestRewardForTask(battleTaskId) {
    if (u.isEmpty(battleTaskId))
      return

    let battleTask = this.getTaskById(battleTaskId)
    if (!::g_warbonds.checkOverLimit(battleTask?.amounts_warbond ?? 0,
         ::g_battle_tasks.sendReceiveRewardRequest, battleTask))
      return

    this.sendReceiveRewardRequest(battleTask)
  }

  function sendReceiveRewardRequest(battleTask) {
    let blk = DataBlock()
    blk.unlockName = battleTask.id

    let taskId = ::char_send_blk("cln_reward_specific_battle_task", blk)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, function() {
      ::update_gamercards()
      broadcastEvent("BattleTasksIncomeUpdate")
      broadcastEvent("BattleTasksRewardReceived")
    })
  }

  function rerollTask(task) {
    if (u.isEmpty(task))
      return

    let blk = DataBlock()
    blk.unlockName = task.id

    let taskId = ::char_send_blk("cln_reroll_battle_task", blk)
    ::g_tasker.addTask(taskId, { showProgressBox = true },
      function() {
        statsd.send_counter("sq.battle_tasks.reroll_v2", 1, { task_id = (task?._base_id ?? "null") })
        broadcastEvent("BattleTasksIncomeUpdate")
      }
    )
  }

  function rerollSpecialTask(task) {
    if (u.isEmpty(task))
      return

    let blk = DataBlock()
    blk.unlockName = task.id
    blk.metaTypeName = this.specialTasksId

    let taskId = ::char_send_blk("cln_reroll_all_battle_tasks_for_meta", blk)
    ::g_tasker.addTask(taskId, { showProgressBox = true },
      function() {
        statsd.send_counter("sq.battle_tasks.special_reroll", 1, { task_id = (task?._base_id ?? "null") })
        broadcastEvent("BattleTasksIncomeUpdate")
      })
  }

  function canActivateHardTasks() {
    return ::isInMenu()
      && u.search(this.proposedTasksArray, Callback(this.isSpecialBattleTask, this)) != null
      && u.search(this.activeTasksArray, Callback(this.isSpecialBattleTask, this)) == null
  }

  function isSpecialBattleTask(task) {
    return this.getGenerationIdInt(task) == this.specTasksLastGenerationId
  }

  function onEventSignOut(_p) {
    this.reset()
  }

  function onEventLoginComplete(_p) {
    this.reset()
    this.updateTasksData()
  }

  function checkNewSpecialTasks() {
    if (!this.canActivateHardTasks())
      return

    let arr = u.filter(this.proposedTasksArray, Callback(this.isSpecialBattleTask, this))
    ::gui_start_battle_tasks_select_new_task_wnd(arr)
  }

  function getDifficultyTypeGroup() {
    let result = []
    foreach (t in difficultyTypes) {
      let difficultyGroup = t.getDifficultyGroup()
      if (difficultyGroup == "")
        continue

      result.append(t)
    }
    return result
  }

  function canInteract(task) {
    let diff = getDifficultyTypeByTask(task)
    return canPlayerInteractWithDifficulty(diff, this.currentTasksArray, this.showAllTasksValue)
  }

  function updateCompleteTaskWatched() {
    local isCompleteMedium = false
    local isCompleteEasy = false
    local hasInCompleteHard = false
    foreach (task in this.currentTasksArray) {
      if (isCompleteMedium && isCompleteEasy && hasInCompleteHard)
        break

      if (!this.isTaskActive(task))
        continue

      if (!this.isTaskDone(task)) {
        if (HARD_TASK == getDifficultyTypeByTask(task))
          hasInCompleteHard = true
        continue
      }

      if (EASY_TASK == getDifficultyTypeByTask(task)) {
        isCompleteEasy = true
        continue
      }

      if (MEDIUM_TASK == getDifficultyTypeByTask(task)) {
        isCompleteMedium = true
        continue
      }
    }

    this.isCompleteMediumTask(isCompleteMedium)
    this.isCompleteEasyTask(isCompleteEasy)
    this.hasInCompleteHardTask(hasInCompleteHard)
  }

  function checkCurSpecialTask() {
    if (!this.hasInCompleteHardTask.value)
      return

    let tasksDataBlock = ::get_proposed_personal_unlocks_blk()
    let genId = tasksDataBlock?[$"{this.specialTasksId}_lastGenerationId"] ?? 0
    if (genId == 0 || this.specTasksLastGenerationId == genId)
      return

    this.updateTasksData()
  }

  onEventProfileUpdated = @(_p) this.checkCurSpecialTask()
}


::g_battle_tasks = ::BattleTasks()
::g_battle_tasks.updateTasksData()
