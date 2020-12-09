local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local statsd = require("statsd")
local { activeUnlocks, getUnlockReward } = require("scripts/unlocks/userstatUnlocksState.nut")

::g_battle_tasks <- null

::BattleTasks <- class
{
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

  constructor()
  {
    currentTasksArray = []
    activeTasksArray = []
    proposedTasksArray = []

    isCompleteMediumTask = ::Watched(false)
    isCompleteEasyTask = ::Watched(false)
    hasInCompleteHardTask = ::Watched(false)

    seenTasks = {}
    newIconWidgetByTaskId = {}

    lastGenerationId = 0
    specTasksLastGenerationId = 0

    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function reset()
  {
    currentTasksArray.clear()
    activeTasksArray.clear()
    proposedTasksArray.clear()

    seenTasks = {}
    newIconWidgetByTaskId = {}
    seenTasksInited = false

    lastGenerationId = 0
    specTasksLastGenerationId = 0
  }

  function isAvailableForUser()
  {
    return ::has_feature("BattleTasks")
           && !::u.isEmpty(getTasksArray())
  }

  function updateTasksData()
  {
    currentTasksArray.clear()
    if (!::g_login.isLoggedIn())
      return

    updatedProposedTasks()
    updatedActiveTasks()

    currentTasksArray.sort(function(a,b) {
      if (a?._sort_order == null || b?._sort_order == null)
        return 0

      if (a._sort_order == b._sort_order)
        return 0

      return a._sort_order > b._sort_order? 1 : -1
    })

    if (::isInMenu())
      checkNewSpecialTasks()
    updateCompleteTaskWatched()
    ::broadcastEvent("BattleTasksFinishedUpdate")
  }

  function onEventBattleTasksShowAll(params)
  {
    showAllTasksValue = ::getTblValue("showAllTasksValue", params, false)
    updateTasksData()
  }

  function onEventBattleTasksIncomeUpdate(params) { updateTasksData() }
  function onEventBattleEnded(params)             { updateTasksData() }

  function updatedProposedTasks()
  {
    local tasksDataBlock = ::get_proposed_personal_unlocks_blk()
    ::g_battle_task_difficulty.updateTimeParamsFromBlk(tasksDataBlock)
    lastGenerationId = tasksDataBlock?[dailyTasksId + "_lastGenerationId"] ?? 0
    specTasksLastGenerationId = tasksDataBlock?[specialTasksId + "_lastGenerationId"] ?? 0

    updateRerollCost(tasksDataBlock)

    proposedTasksArray = []
    newIconWidgetByTaskId = {}

    for (local i = 0; i < tasksDataBlock.blockCount(); i++)
    {
      local task = ::DataBlock()
      task.setFrom(tasksDataBlock.getBlock(i))
      task.isActive = false
      proposedTasksArray.append(task)
      if (!isTaskActual(task) || !canInteract(task)
        || !::g_battle_task_difficulty.checkAvailabilityByProgress(task, showAllTasksValue))
        continue

      currentTasksArray.append(task)
      newIconWidgetByTaskId[getUniqueId(task)] <- null
    }
  }

  function updatedActiveTasks()
  {
    local currentActiveTasks = ::get_personal_unlocks_blk()
    activeTasksArray.clear()
    for (local i = 0; i < currentActiveTasks.blockCount(); i++)
    {
      local task = ::DataBlock()
      task.setFrom(currentActiveTasks.getBlock(i))

      if (!isBattleTask(task))
        continue

      task.isActive = true
      activeTasksArray.append(task)

      if (!isTaskActual(task) || !canInteract(task)
        || !::g_battle_task_difficulty.checkAvailabilityByProgress(task, showAllTasksValue))
        continue

      currentTasksArray.append(task)
      local isNew = !isTaskDone(task) && canGetReward(task)
      markTaskSeen(getUniqueId(task), false, isNew)
      newIconWidgetByTaskId[getUniqueId(task)] <- null
    }
  }

  function updateRerollCost(tasksDataBlock)
  {
    rerollCost = ::Cost(::getTblValue("_rerollCost", tasksDataBlock, 0),
                        ::getTblValue("_rerollGoldCost", tasksDataBlock, 0))
  }

  function isTaskActive(task)
  {
    return ::getTblValue("isActive", task, true)
  }

  function isTaskTimeExpired(task)
  {
    return ::g_battle_task_difficulty.getDifficultyTypeByTask(task).isTimeExpired(task)
  }

  function isTaskDone(config)
  {
    if (::u.isEmpty(config))
      return false

    if (isBattleTask(config))
    {
      if (!getTaskById(config.id))
        return true //Task with old difficulty type, not using anymore
      return ::is_unlocked_scripted(-1, config.id)
    }
    return ::is_unlocked_scripted(-1, config.id)
  }

  function canGetReward(task)
  {
    return isBattleTask(task)
           && isTaskActual(task)
           && !isTaskDone(task)
           && ::getTblValue("_readyToReward", task, false)
  }

  function canGetAnyReward()
  {
    foreach (task in getActiveTasksArray())
      if (canGetReward(task))
        return true
    return false
  }

  function canActivateTask(task)
  {
    if (!isBattleTask(task))
      return false

    local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
    if (!::g_battle_task_difficulty.canPlayerInteractWithDifficulty(diff, getProposedTasksArray())
        || !::g_battle_task_difficulty.checkAvailabilityByProgress(task))
        return false

    foreach (idx, activeTask in getActiveTasksArray())
      if (!isAutoAcceptedTask(activeTask))
        return false

    return true
  }

  function getTasksArray() { return currentTasksArray }
  function getProposedTasksArray() { return proposedTasksArray }
  function getActiveTasksArray() { return activeTasksArray }
  function getWidgetsTable() { return newIconWidgetByTaskId }

  function debugClearSeenData()
  {
    seenTasks = {}
    saveSeenTasksData()
    //!!fix me: need to recount seen data from active tasks
  }

  function loadSeenTasksData(forceLoad = false)
  {
    if (seenTasksInited && !forceLoad)
      return true

    seenTasks.clear()
    local blk = ::loadLocalByAccount(PLAYER_CONFIG_PATH)
    if (typeof(blk) == "instance" && (blk instanceof ::DataBlock))
      for (local i = 0; i < blk.paramCount(); i++)
      {
        local id = blk.getParamName(i)
        seenTasks[id] <- ::max(blk.getParamValue(i), ::getTblValue(id, seenTasks, 0))
      }

    seenTasksInited = true
    return true
  }

  function saveSeenTasksData()
  {
    local minDay = time.getUtcDays() - TASKS_OUT_OF_DATE_DAYS
    local blk = ::DataBlock()
    foreach(generation_id, day in seenTasks)
    {
      if (day < minDay && !isBattleTaskNew(generation_id))
        continue

      blk[generation_id] = day
    }

    ::saveLocalByAccount(PLAYER_CONFIG_PATH, blk)
  }

  function isBattleTaskNew(generation_id)
  {
    loadSeenTasksData()
    return !(generation_id in seenTasks)
  }

  function markTaskSeen(generation_id, sendEvent = true, isNew = false)
  {
    local wasNew = isBattleTaskNew(generation_id)
    if (wasNew == isNew)
      return false

    if (!isNew)
      seenTasks[generation_id] <- time.getUtcDays()
    else if (generation_id in seenTasks)
      delete seenTasks[generation_id]

    if (sendEvent)
      ::broadcastEvent("NewBattleTasksChanged")
    return true
  }

  function markAllTasksSeen()
  {
    local changeNew = false
    foreach(task in currentTasksArray)
    {
      local generation_id = getUniqueId(task)
      local result = markTaskSeen(generation_id, false)
      changeNew = changeNew || result
    }

    if (changeNew)
      ::broadcastEvent("NewBattleTasksChanged")
  }

  function getUnseenTasksCount()
  {
    loadSeenTasksData()

    local num = 0
    foreach(idx, task in currentTasksArray)
    {
      if (!isBattleTaskNew(getUniqueId(task)))
        continue

      num++
    }
    return num
  }

  function getLocalizedTaskNameById(param)
  {
    local task = null
    local id = null
    if (::u.isDataBlock(param))
    {
      task = param
      id = ::getTblValue("id", param)
    }
    else if (::u.isString(param))
    {
      task = getTaskById(param)
      id = param
    }
    else
      return ""

    return ::loc(::getTblValue("locId", task, "battletask/" + id))
  }

  function getTaskById(id)
  {
    if (::u.isTable(id) || ::u.isDataBlock(id))
      id = ::getTblValue("id", id)

    if (!id)
      return null

    foreach(task in activeTasksArray)
      if (task.id == id)
        return task

    foreach(task in proposedTasksArray)
      if (task.id == id)
        return task

    return null
  }

  function generateUnlockConfigByTask(task)
  {
    local config = ::build_conditions_config(task)
    ::build_unlock_desc(config)
    config.originTask <- task
    return config
  }

  function getUniqueId(task)
  {
    return task.id
  }

  function isController(config)
  {
    return ::getTblValue("_controller", config, false)
  }

  function isAutoAcceptedTask(task)
  {
    return ::getTblValue("_autoAccept", task, false)
  }

  function isBattleTask(task)
  {
    if (::u.isString(task))
      task = getTaskById(task)

    local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
    return diff != ::g_battle_task_difficulty.UNKNOWN
  }

  function isUserlogForBattleTasksGroup(body)
  {
    local unlockId = ::getTblValue("unlockId", body)
    if (unlockId == null)
      return true

    return getTaskById(unlockId) != null
  }

  //currently it is using in userlog
  function generateUpdateDescription(log)
  {
    local res = {}
    local blackList = []
    local whiteList = []

    local proposedTasks = getProposedTasksArray()

    foreach(taskId, table in log)
    {
      local header = ""
      local diffTypeName = ::getTblValue("type", table)
      if (diffTypeName)
      {
        if (::isInArray(diffTypeName, blackList))
          continue

        local diff = ::g_battle_task_difficulty.getDifficultyTypeByName(diffTypeName)
        if (!::isInArray(diffTypeName, whiteList)
            && !::g_battle_task_difficulty.canPlayerInteractWithDifficulty(diff,
                                          proposedTasks, showAllTasksValue))
        {
          blackList.append(diffTypeName)
          continue
        }

        whiteList.append(diffTypeName)
        header = diff.userlogHeaderName
      }
      if (!(header in res))
        res[header] <- []

      res[header].append(generateStringForUserlog(table, taskId))
    }

    local data = ""
    local lastUserLogHeader = ""
    foreach(userlogHeader, arr in res)
    {
      if (arr.len() == 0)
        continue

      data += data == ""? "" : "\n"
      if (lastUserLogHeader != userlogHeader)
      {
        data += ::loc("userlog/battletask/type/" + userlogHeader) + ::loc("ui/colon")
        lastUserLogHeader = userlogHeader
      }
      data += ::g_string.implode(arr, "\n")
    }

    return data
  }

  function getDifficultyByProposals(proposals) {
    if (proposals.findindex(function(v, id) {
      local battleTask = ::g_battle_tasks.getTaskById(id)
      return ::g_battle_task_difficulty.HARD == ::g_battle_task_difficulty.getDifficultyTypeByTask(battleTask)
    }))
      return ::g_battle_task_difficulty.HARD

    return ::g_battle_task_difficulty.EASY
  }

  function generateStringForUserlog(table, taskId)
  {
    local text = getBattleTaskLocIdFromUserlog(table, taskId)
    local cost = ::Cost(::getTblValue("cost", table, 0), ::getTblValue("costGold", table, 0))
    if (!::u.isEmpty(cost))
      text += ::loc("ui/parentheses/space", {text = cost.tostring()})

    return text
  }

  function getBattleTaskLocIdFromUserlog(log, taskId)
  {
    return "locId" in log? ::loc(log.locId) : getLocalizedTaskNameById(taskId)
  }

  function getImage(imageName = null)
  {
    if (imageName)
      return "ui/images/battle_tasks/" + imageName + ".jpg?P1"
    return null
  }

  function getTaskStatus(task)
  {
    if (canGetReward(task))
      return "complete"
    if (isTaskDone(task))
      return "done"
    if (isTaskTimeExpired(task))
      return "failed"
    return null
  }

  function getGenerationIdInt(task)
  {
    local taskGenId = task?._generation_id
    if (!taskGenId)
      return 0

    return ::u.isString(taskGenId)? taskGenId.tointeger() : taskGenId
  }

  function isTaskActual(task)
  {
    if (!task?._generation_id)
      return true

    local taskGenId = getGenerationIdInt(task)
    return taskGenId == lastGenerationId
      || taskGenId == specTasksLastGenerationId
  }

  function isTaskUnderControl(checkTask, taskController, typesToCheck = null)
  {
    if (taskController.id == checkTask.id || taskController?._generation_id != checkTask?._generation_id)
      return false
    if (!typesToCheck)
      return true

    return ::isInArray(::g_battle_task_difficulty.getDifficultyTypeByTask(checkTask).name, typesToCheck)
  }

  function canCancelTask(task)
  {
    return !isTaskDone(task) && !::getTblValue("_preventCancel", task, false)
  }

  function getTasksListByControllerTask(taskController, conditions)
  {
    local tasksArray = []
    if (!isController(taskController))
      return tasksArray

    local unlocksCond = ::u.search(conditions, function(cond) { return cond.type == "char_personal_unlock" } )
    local personalUnlocksTypes = unlocksCond && unlocksCond.values

    foreach (task in currentTasksArray)
      if (isTaskUnderControl(task, taskController, personalUnlocksTypes))
        tasksArray.append(task)

    return tasksArray
  }

  function getTaskWithAvailableAward(tasksArray)
  {
    return ::u.search(tasksArray, function(task) {
        return canGetReward(task)
      }.bindenv(this))
  }

  function getTaskDescription(config = null, paramsCfg = {})
  {
    if (!config)
      return null

    local task = getTaskById(config)

    local taskDescription = []
    local taskUnlocksListPrefix = ""
    local taskUnlocksList = []
    local taskConditionsList = []
    local isPromo = paramsCfg?.isPromo ?? false

    if (showAllTasksValue)
      taskDescription.append("*Debug info: id - " + config.id)

    if (isPromo)
    {
      if (::getTblValue("locDescId", config, "") != "")
        taskDescription.append(::loc(config.locDescId))
      taskDescription.append(::UnlockConditions.getMainConditionText(config.conditions, config.curVal, config.maxVal))
    }
    else
    {
      if (::getTblValue("text", config, "") != "")
        taskDescription.append(config.text)

      if (!canGetReward(task))
      {
        taskUnlocksListPrefix = ::UnlockConditions.getMainConditionListPrefix(config.conditions)

        local isBitMode = ::UnlockConditions.isBitModeType(config.type)
        local namesLoc = ::UnlockConditions.getLocForBitValues(config.type, config.names, config.hasCustomUnlockableList)
        local typeOR = ::getTblValue("compareOR", config, false)
        for (local i = 0; i < namesLoc.len(); i++)
        {
          local unlockId = config.names[i]
          if (!::is_unlock_visible(::g_unlocks.getUnlockById(unlockId)))
            continue

          local isUnlocked = !isBitMode || (config.curVal & 1 << i)
          taskUnlocksList.append(getUnlockConditionBlock(namesLoc[i],
                                   unlockId,
                                   config.type,
                                   isUnlocked,
                                   i == namesLoc.len() - 1,
                                   config.hasCustomUnlockableList,
                                   i > 0 && typeOR,
                                   isBitMode))
        }
      }

      local controlledTasks = getTasksListByControllerTask(task, config.conditions)
      foreach (contrTask in controlledTasks)
      {
        taskConditionsList.append({
          unlocked = isTaskDone(contrTask)
          text = ::colorize(isActive(contrTask)? "userlogColoredText" : "", getLocalizedTaskNameById(contrTask))
        })
      }
    }

    local progressData = config?.getProgressBarData? config.getProgressBarData() : null
    local progressBarValue = config?.curVal != null && config.curVal >= 0
      ? (config.curVal.tofloat() / (config?.maxVal ?? 1) * 1000)
      : 0

    local view = {
      id = config.id
      taskDescription = ::g_string.implode(taskDescription, "\n")
      taskSpecialDescription = getRefreshTimeTextForTask(task)
      taskUnlocksListPrefix = taskUnlocksListPrefix
      taskUnlocks = taskUnlocksList
      taskUnlocksList = taskUnlocksList.len()
      taskConditionsList = taskConditionsList.len()? taskConditionsList : null
      needShowProgressBar = isPromo && progressData?.show
      progressBarValue = progressBarValue.tointeger()
      isPromo = isPromo
      isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
    }

    return ::handyman.renderCached("gui/unlocks/battleTasksDescription", view)
  }

  function getRefreshTimeTextForTask(task)
  {
    local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
    local timeLeft = diff.getTimeLeft(task)
    if (timeLeft < 0)
      return ""

    local labelText = "".concat(::loc("unlocks/_acceptTime"), ::loc("ui/colon"))
    if (timeLeft < 30 * time.TIME_MINUTE_IN_SECONDS)
      labelText = ::colorize("warningTextColor", labelText)
    return "".concat(labelText,  ::colorize("unlockActiveColor", diff.getTimeLeftText(task)))
  }

  function setUpdateTimer(task, taskBlockObj)
  {
    if (!::checkObj(taskBlockObj))
      return

    local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
    if (!diff.hasTimer) return

    local holderObj = taskBlockObj.findObject("task_timer_text")
    if (::checkObj(holderObj) && task)
      SecondsUpdater(holderObj, function(obj, params) {
        local timeText = ::g_battle_tasks.getRefreshTimeTextForTask(task)
        local isTimeEnded = timeText == ""
        if (isTimeEnded)
          timeText = ::colorize("badTextColor", ::loc("mainmenu/battleTasks/timeWasted"))
        obj.setValue(timeText)

        return isTimeEnded
      })

    holderObj = taskBlockObj.findObject("tasks_refresh_timer")
    if (::checkObj(holderObj))
      SecondsUpdater(holderObj, function(obj, params) {
        local timeText = ::g_battle_task_difficulty.EASY.getTimeLeftText(task)
        obj.setValue(::loc("ui/parentheses/space", {text = timeText + ::loc("icon/timer")}))

        return timeText == ""
      })

    local timeLeft = diff.getTimeLeft(task)
    if (timeLeft > 0)
      ::Timer(taskBlockObj, timeLeft + 1, @() diff.notifyTimeExpired(task), this, false, true)
  }

  function getUnlockConditionBlock(text, id, mType, isUnlocked, isFinal, hasCustomUnlockableList, typeOR = false, isBitMode = true)
  {
    local unlockDesc = typeOR ? ::loc("hints/shortcut_separator") + "\n" : ""
    unlockDesc += text
    unlockDesc += typeOR? "" : ::loc(isFinal? "ui/dot" : "ui/comma")

    return {
      tooltipId = ::UnlockConditions.getTooltipIdByModeType(mType, id, hasCustomUnlockableList)
      overlayTextColor = (isBitMode && isUnlocked) ? "userlog" : "active"
      text = unlockDesc
    }
  }

  function getPlaybackPath(playbackName, shouldUseDefaultLang = false)
  {
    if (::u.isEmpty(playbackName))
      return ""

    local guiBlk = ::configs.GUI.get()
    local unlockPlaybackPath = guiBlk?.unlockPlaybackPath
    if (!unlockPlaybackPath)
      return ""

    local path = unlockPlaybackPath.mainPath
    local abbrev = shouldUseDefaultLang? "en" : ::g_language.getShortName()
    return path + abbrev + "/" + playbackName + unlockPlaybackPath.fileExtension
  }

  function getRewardMarkUpConfig(task, config)
  {
    local rewardMarkUp = {}
    local itemId = ::getTblValue("userLogId", task)
    if (itemId)
    {
      local item = ::ItemsManager.findItemById(::to_integer_safe(itemId, itemId, false))
      if (item)
        rewardMarkUp.itemMarkUp <- item.getNameMarkup(::getTblValue("amount_trophies", task))
    }

    local reward = ::get_unlock_rewards_text(config)
    local difficulty = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
    if (::has_feature("BattlePass")) {
      local unlockReward = getUnlockReward(activeUnlocks.value?[difficulty.userstatUnlockId])

      reward = reward != "" ? $"{reward}\n{unlockReward.rewardText}" : unlockReward.rewardText
      rewardMarkUp.itemMarkUp <- $"{rewardMarkUp?.itemMarkUp ?? ""}{unlockReward.itemMarkUp}"
    }

    if(difficulty == ::g_battle_task_difficulty.MEDIUM) {
      local specialTaskAward = ::g_warbonds.getCurrentWarbond()?.getAwardByType(::g_wb_award_type[::EWBAT_BATTLE_TASK])
      if (specialTaskAward?.awardType.hasIncreasingLimit()) {
        local rewardText = ::loc("warbonds/canBuySpecialTasks/awardTitle", { count = 1 })
        reward = reward != "" ? $"{reward}\n{rewardText}" : rewardText
      }
    }

    if (reward == "" && !rewardMarkUp.len())
      return rewardMarkUp

    local rewardLoc = isTaskDone(task)? ::loc("rewardReceived") : ::loc("reward")
    rewardMarkUp.rewardText <- rewardLoc + ::loc("ui/colon") + reward
    return rewardMarkUp
  }

  function generateItemView(config, paramsCfg = {})
  {
    local isPromo = paramsCfg?.isPromo ?? false
    local isShortDescription = paramsCfg?.isShortDescription ?? false

    local task = getTaskById(config) || ::getTblValue("originTask", config)
    local isTaskBattleTask = isBattleTask(task)
    local isCanGetReward = canGetReward(task)

    local isUnlock = "unlockType" in config

    local title = isTaskBattleTask ? getLocalizedTaskNameById(task.id)
                : (isUnlock? ::get_unlock_name_text(config.unlockType, config.id) : ::getTblValue("text", config, ""))
    local headerCond = isUnlock ? ::UnlockConditions.getHeaderCondition(config.conditions) : null

    local id = isTaskBattleTask ? task.id : config.id
    local progressData = config?.getProgressBarData? config.getProgressBarData() : null
    local progressBarValue = config?.curVal != null && config.curVal >= 0
      ? (config.curVal.tofloat() / (config?.maxVal ?? 1) * 1000)
      : 0
    local taskStatus = getTaskStatus(task)

    return {
      id = id
      title = title
      taskStatus = taskStatus
      taskImage = (paramsCfg?.showUnlockImage ?? true) && (::getTblValue("image", task) || ::getTblValue("image", config))
      taskPlayback = ::getTblValue("playback", task) || ::getTblValue("playback", config)
      isPlaybackDownloading = !::g_sound.canPlay(id)
      taskDifficultyImage = getDifficultyImage(task)
      taskHeaderCondition = headerCond ? ::loc("ui/parentheses/space", { text = headerCond }) : null
      description = isTaskBattleTask || isUnlock ? getTaskDescription(config, paramsCfg) : null
      reward = isPromo? null : getRewardMarkUpConfig(task, config)
      newIconWidget = isTaskBattleTask ? (isTaskActive(task)? null : NewIconWidget.createLayout()) : null
      canGetReward = isTaskBattleTask && isCanGetReward
      canReroll = isTaskBattleTask && !isCanGetReward
      otherTasksNum = task && isPromo? getTotalActiveTasksNum() : null
      isLowWidthScreen = isPromo? ::is_low_width_screen() : null
      showAsUsualPromoButton = isPromo && task == null
      isPromo = isPromo
      isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
      needShowProgressValue = taskStatus == null && config?.curVal != null && config.curVal >= 0 && config?.maxVal != null && config.maxVal >= 0
      progressValue = config?.curVal
      progressMaxValue = config?.maxVal
      needShowProgressBar = progressData?.show
      progressBarValue = progressBarValue.tointeger()
      getTooltipId = (isPromo || isShortDescription) && isTaskBattleTask ? @() ::g_tooltip_type.BATTLE_TASK.getTooltipId(id) : null
      isShortDescription = isShortDescription
      shouldRefreshTimer = config?.shouldRefreshTimer ?? false
    }
  }

  function getTotalActiveTasksNum()
  {
    local num = 0
    foreach (task in getActiveTasksArray())
      if (isTaskActual(task) && !isTaskDone(task))
        num++
    return num
  }

  function getDifficultyImage(task)
  {
    local difficulty = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
    if (difficulty.showSeasonIcon)
    {
      local curWarbond = ::g_warbonds.getCurrentWarbond()
      if (curWarbond)
        return curWarbond.getMedalIcon()
    }

    return difficulty.image
  }

  function getTasksArrayByIncreasingDifficulty()
  {
    local typesArray = [
      ::g_battle_task_difficulty.EASY,
      ::g_battle_task_difficulty.MEDIUM,
      ::g_battle_task_difficulty.HARD
    ]

    local result = []
    foreach(t in typesArray)
    {
      local arr = ::g_battle_task_difficulty.withdrawTasksArrayByDifficulty(t, currentTasksArray)
      if (arr.len() == 0)
        continue

      if (::g_battle_task_difficulty.canPlayerInteractWithDifficulty(t, arr))
        result.extend(arr)
    }

    return result
  }

  function filterTasksByGameModeId(tasksArray, gameModeId)
  {
    if (::u.isEmpty(gameModeId))
      return tasksArray

    local res = []
    foreach(task in tasksArray)
    {
      if (!isBattleTask(task))
        continue

      local blk = ::build_conditions_config(task)
      foreach(condition in blk.conditions)
      {
        local values = ::getTblValue("values", condition)
        if (::u.isEmpty(values))
            continue

        if (::isInArray(gameModeId, values))
        {
          res.append(task)
          break
        }
      }
    }
    return res
  }

  function getTasksArrayByDifficulty(searchArray, difficulty = null)
  {
    if (::u.isEmpty(searchArray))
      searchArray = currentTasksArray

    if (::u.isEmpty(difficulty))
      return searchArray

    return searchArray.filter(@(task) ::g_battle_tasks.isTaskSameDifficulty(task, difficulty))
  }

  function isTaskSameDifficulty(task, difficulty)
  {
    if (!isBattleTask(task))
      return true

    return ::isInArray(task?._choiceType ?? "", difficulty.choiceType)
  }

  function isTaskSuitableForUnitTypeMask(task, unitTypeMask)
  {
    if (!isBattleTask(task))
      return false

    local blk = ::build_conditions_config(task)
    foreach(condition in blk.conditions)
    {
      local values = ::getTblValue("values", condition)
      if (::u.isEmpty(values))
        continue

      foreach (value in values)
      {
        local gameMode = ::game_mode_manager.getGameModeById(value)
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

  function requestRewardForTask(battleTaskId)
  {
    if (::u.isEmpty(battleTaskId))
      return

    local battleTask = getTaskById(battleTaskId)
    if (!::g_warbonds.checkOverLimit(battleTask))
      return

    sendReceiveRewardRequest(battleTask)
  }

  function sendReceiveRewardRequest(battleTask)
  {
    local blk = ::DataBlock()
    blk.unlockName = battleTask.id

    local taskId = ::char_send_blk("cln_reward_specific_battle_task", blk)
    ::g_tasker.addTask(taskId, {showProgressBox = true}, function() {
      ::g_warbonds_view.needShowProgressBarInPromo = true
      ::update_gamercards()
      ::broadcastEvent("BattleTasksIncomeUpdate")
      ::broadcastEvent("BattleTasksRewardReceived")
    })
  }

  function rerollTask(task)
  {
    if (::u.isEmpty(task))
      return

    local blk = ::DataBlock()
    blk.unlockName = task.id

    local taskId = ::char_send_blk("cln_reroll_battle_task", blk)
    ::g_tasker.addTask(taskId, {showProgressBox = true},
      function() {
        statsd.send_counter("sq.battle_tasks.reroll_v2", 1, {task_id = (task?._base_id ?? "null")})
        ::broadcastEvent("BattleTasksIncomeUpdate")
      }
    )
  }

  function rerollSpecialTask(task)
  {
    if (::u.isEmpty(task))
      return

    local blk = ::DataBlock()
    blk.unlockName = task.id
    blk.metaTypeName = specialTasksId

    local taskId = ::char_send_blk("cln_reroll_all_battle_tasks_for_meta", blk)
    ::g_tasker.addTask(taskId, {showProgressBox = true},
      function() {
        statsd.send_counter("sq.battle_tasks.special_reroll", 1, {task_id = (task?._base_id ?? "null")})
        ::broadcastEvent("BattleTasksIncomeUpdate")
      })
  }

  function canActivateHardTasks()
  {
    return ::isInMenu()
      && ::u.search(proposedTasksArray, ::Callback(isSpecialBattleTask, this )) != null
      && ::u.search(activeTasksArray, ::Callback(isSpecialBattleTask, this )) == null
  }

  function isSpecialBattleTask(task)
  {
    return getGenerationIdInt(task) == specTasksLastGenerationId
  }

  function onEventSignOut(p)
  {
    reset()
  }

  function onEventLoginComplete(p)
  {
    reset()
    updateTasksData()
  }

  function checkNewSpecialTasks()
  {
    if (!canActivateHardTasks())
      return

    local arr = ::u.filter(proposedTasksArray, ::Callback(isSpecialBattleTask, this) )
    ::gui_start_battle_tasks_select_new_task_wnd(arr)
  }

  function getDifficultyTypeGroup()
  {
    local result = []
    foreach(t in ::g_battle_task_difficulty.types)
    {
      local difficultyGroup = t.getDifficultyGroup()
      if (difficultyGroup =="")
        continue

      result.append(t)
    }
    return result
  }

  function canInteract(task)
  {
    local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
    return ::g_battle_task_difficulty.canPlayerInteractWithDifficulty(diff, currentTasksArray, showAllTasksValue)
  }

  function updateCompleteTaskWatched() {
    local isCompleteMedium = false
    local isCompleteEasy = false
    local hasInCompleteHard = false
    foreach (task in currentTasksArray) {
      if (isCompleteMedium && isCompleteEasy && hasInCompleteHard)
        break

      if (!isTaskActive(task))
        continue

      if (!isTaskDone(task)) {
        if (::g_battle_task_difficulty.HARD == ::g_battle_task_difficulty.getDifficultyTypeByTask(task))
          hasInCompleteHard = true
        continue
      }

      if (::g_battle_task_difficulty.EASY == ::g_battle_task_difficulty.getDifficultyTypeByTask(task)) {
        isCompleteEasy = true
        continue
      }

      if (::g_battle_task_difficulty.MEDIUM == ::g_battle_task_difficulty.getDifficultyTypeByTask(task)) {
        isCompleteMedium = true
        continue
      }
    }

    isCompleteMediumTask(isCompleteMedium)
    isCompleteEasyTask(isCompleteEasy)
    hasInCompleteHardTask(hasInCompleteHard)
  }
}


::g_battle_tasks = ::BattleTasks()
::g_battle_tasks.updateTasksData()
