from "%scripts/dagui_natives.nut" import get_unlock_type
from "%scripts/dagui_library.nut" import *

let { is_low_width_screen } = require("%scripts/options/safeAreaMenu.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { is_bit_set } = require("%sqstd/math.nut")
let { isBitModeType, isNestedUnlockMode, getMainConditionListPrefix,
  getHeaderCondition
} = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { buildConditionsConfig, buildUnlockDesc, getTooltipMarkupByModeType,
 getUnlockRewardsText, getLocForBitValues, getFullUnlockDesc, getUnlocksListView,
 getUnlockNameText, getUnlockMainCondDescByCfg
} = require("%scripts/unlocks/unlocksViewModule.nut")
let { addTooltipTypes, getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { Cost } = require("%scripts/money.nut")
let { isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { isBattleTask, getBattleTaskNameById, getDifficultyTypeByTask, getProposedTasks,
  getGenerationIdInt, isBattleTaskDone, getShowAllTasks, canPlayerInteractWithDifficulty,
  getBattleTaskById, canGetBattleTaskReward, getTaskStatus,
  isBattleTaskActive, getTotalActiveTasksNum
} = require("%scripts/unlocks/battleTasks.nut")
let { TIME_MINUTE_IN_SECONDS } = require("%scripts/time.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { getDifficultyTypeByName, EASY_TASK, MEDIUM_TASK } = require("%scripts/unlocks/battleTaskDifficulty.nut")
let { Timer } = require("%sqDagui/timer/timer.nut")
let { activeUnlocks, getUnlockReward } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { fillWarbondAwardDesc } = require("%scripts/warbonds/warbondAwardView.nut")
let newIconWidget = require("%scripts/newIconWidget.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let warBondAwardType = require("%scripts/warbonds/warbondAwardType.nut")

function mkUnlockConfigByBattleTask(task) {
  local config = buildConditionsConfig(task)
  buildUnlockDesc(config)
  config.originTask <- task
  return config
}

function isUnlocksList(config) {
  if (isNestedUnlockMode(config.type))
    foreach (id in config.names) {
      let unlockBlk = getUnlockById(id)
      if (!(unlockBlk?.isMultiUnlock ?? false)
          && get_unlock_type(unlockBlk.type) != UNLOCKABLE_STREAK)
        return true
    }
  return false
}

function getRefreshTimeTextForTask(task) {
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

function setBattleTasksUpdateTimer(task, taskBlockObj, addParams = {}) {
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
      obj.setValue(loc("ui/parentheses/space", { text = $"{timeText}{loc("icon/timer")}" }))

      return timeText == ""
    })

  let timeLeft = diff.getTimeLeft(genId)
  if (timeLeft <= 0)
    return

  Timer(taskBlockObj, timeLeft + 1, @() diff.notifyTimeExpired(genId), this, false, true)
}

function getRewardMarkUpConfig(task, config) {
  let rewardMarkUp = {}
  let itemId = getTblValue("userLogId", task)
  if (itemId) {
    let item = findItemById(to_integer_safe(itemId, itemId, false))
    if (item)
      rewardMarkUp.itemMarkUp <- item.getNameMarkup(getTblValue("amount_trophies", task))
  }

  local reward = getUnlockRewardsText(config)
  let difficulty = getDifficultyTypeByTask(task)
  let unlockReward = getUnlockReward(activeUnlocks.get()?[difficulty.userstatUnlockId])
  reward = reward != "" ? $"{reward}\n{unlockReward.rewardText}" : unlockReward.rewardText
  rewardMarkUp.itemMarkUp <- $"{rewardMarkUp?.itemMarkUp ?? ""}{unlockReward.itemMarkUp}"

  if (difficulty == MEDIUM_TASK) {
    let specialTaskAward = ::g_warbonds.getCurrentWarbond()?.getAwardByType(warBondAwardType[EWBAT_BATTLE_TASK])
    if (specialTaskAward?.awardType.hasIncreasingLimit) {
      let rewardText = loc("warbonds/canBuySpecialTasks/awardTitle", { count = 1 })
      reward = reward != "" ? $"{reward}\n{rewardText}" : rewardText
    }
  }

  if (reward == "" && !rewardMarkUp.len())
    return rewardMarkUp

  let rewardLoc = isBattleTaskDone(task) ? loc("rewardReceived") : loc("reward")
  rewardMarkUp.rewardText <-$"{rewardLoc}{loc("ui/colon")}{reward}"
  return rewardMarkUp
}

function getBattleTaskDifficultyImage(task) {
  let difficulty = getDifficultyTypeByTask(task)
  if (difficulty.showSeasonIcon) {
    let curWarbond = ::g_warbonds.getCurrentWarbond()
    if (curWarbond)
      return curWarbond.getMedalIcon()
  }

  return difficulty.image
}

let getBattleTaskLocIdFromUserlog = @(logObj, taskId) ("locId" in logObj)
  ? loc(logObj.locId) : getBattleTaskNameById(taskId)

function getBattleTaskUserLogText(table, taskId) {
  let res = [getBattleTaskLocIdFromUserlog(table, taskId)]
  let cost = Cost(table?.cost ?? 0, table?.costGold ?? 0)
  if (!isEmpty(cost))
    res.append(loc("ui/parentheses/space", { text = cost.tostring() }))

  return "".join(res)
}

function getBattleTaskUpdateDesc(logObj) {
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
      if (!isInArray(diffTypeName, whiteList) && !getShowAllTasks()
          && !canPlayerInteractWithDifficulty(diff, getProposedTasks())) {
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

    data = $"{data}{data == "" ? "" : "\n"}"
    if (lastUserLogHeader != userlogHeader) {
      data = "".concat(data, loc($"userlog/battletask/type/{userlogHeader}"), loc("ui/colon"))
      lastUserLogHeader = userlogHeader
    }
    data = "".concat(data, "\n".join(arr, true))
  }

  return data
}

function getUnlockConditionBlock(text, config, isUnlocked, isFinal, compareOR, isBitMode) {
  let unlockDesc = compareOR ? "\n".concat(loc("hints/shortcut_separator"), text)
    : "".concat(text, loc(isFinal ? "ui/dot" : "ui/comma"))
  return {
    tooltipMarkup = getTooltipMarkupByModeType(config)
    overlayTextColor = (isBitMode && isUnlocked) ? "userlog" : "active"
    text = unlockDesc
  }
}

function getStreaksListView(config) {
  let isBitMode = isBitModeType(config.type)
  let namesLoc = getLocForBitValues(config.type, config.names, config.hasCustomUnlockableList)
  let compareOR = config?.compareOR ?? false

  let res = []
  for (local i = 0; i < namesLoc.len(); ++i) {
    let unlockId = config.names[i]
    let unlockBlk = getUnlockById(unlockId)
    if (!unlockBlk || !isUnlockVisible(unlockBlk))
      continue

    let unlockConfig = buildConditionsConfig(unlockBlk)
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

function getBattleTaskDesc(config = null, paramsCfg = {}) {
  if (!config)
    return null

  let task = getBattleTaskById(config)

  let taskDescription = []
  local taskUnlocksListPrefix = ""
  local taskUnlocksList = []
  local taskStreaksList = []
  let isPromo = paramsCfg?.isPromo ?? false

  if (getShowAllTasks())
    taskDescription.append($"*Debug info: id - {config.id}")

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

function getBattleTaskView(config, paramsCfg = {}) {
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
      ? @() getTooltipType("BATTLE_TASK").getTooltipId(id)
      : null
    isShortDescription
    shouldRefreshTimer = config?.shouldRefreshTimer ?? false
  }
}

addTooltipTypes({
  SPECIAL_TASK = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, params) {
      if (!checkObj(obj))
        return false

      let warbond = ::g_warbonds.findWarbond(
        getTblValue("wbId", params),
        getTblValue("wbListId", params)
      )
      let award = warbond ? warbond.getAwardById(id) : null
      if (!award)
        return false

      let guiScene = obj.getScene()
      guiScene.replaceContent(obj, "%gui/items/itemTooltip.blk", handler)
      if (fillWarbondAwardDesc(obj, handler, award))
        return true

      obj.findObject("item_name").setValue(award.getNameText())
      obj.findObject("item_desc").setValue(award.getDescText())

      let imageData = award.getDescriptionImage()
      guiScene.replaceContentFromText(obj.findObject("item_icon"), imageData, imageData.len(), handler)
      return true
    }
  }

  BATTLE_TASK = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, _params) {
      if (!checkObj(obj))
        return false

      let battleTask = getBattleTaskById(id)
      if (!battleTask)
        return false

      let config = mkUnlockConfigByBattleTask(battleTask)
      let view = getBattleTaskView(config, { isOnlyInfo = true })
      let data = handyman.renderCached("%gui/unlocks/battleTasksItem.tpl", { items = [view], isSmallText = true })

      let guiScene = obj.getScene()
      obj.width = "1@unlockBlockWidth"
      guiScene.replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})

return {
  setBattleTasksUpdateTimer
  getBattleTaskDifficultyImage
  getBattleTaskView
  getBattleTaskUserLogText
  getBattleTaskUpdateDesc
  mkUnlockConfigByBattleTask
  getBattleTaskDesc
}