from "%scripts/time.nut" import getTimestampFromStringUtc, buildDateStr
from "%scripts/battlePass/seasonState.nut" import season, seasonLevel, getLevelFromStagesByExp, basicUnlockStages
from "%scripts/unlocks/userstatUnlocksState.nut" import activeUnlocks
from "%scripts/unlocks/userstatUnlocksView.nut" import getUnlockRewardMarkUp
from "%scripts/userstat/userstat.nut" import refreshUserstatUnlocks
from "%scripts/unlocks/unlocksConditions.nut" import getUnlockConditions, getHeaderCondition, isTimeRangeCondition
from "%scripts/unlocks/unlocksState.nut" import getUnlockNameText, buildConditionsConfig
from "%scripts/unlocks/unlocksViewModule.nut" import buildUnlockDesc
from "%scripts/unlocks/favoriteUnlocks.nut" import isUnlockFav
from "%scripts/unlocks/unlocksModule.nut" import isUnlockVisible, isUnlockOpened
from "%scripts/unlocks/unlocksCache.nut" import getUnlocksWhereInBlkOrder, getUnlockById
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/utils/genericTooltipTypes.nut" import addTooltipTypes
from "%scripts/unlocks/battleTasksView.nut" import getBattleTaskDesc
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv, broadcastEvent
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "chard" import get_charserver_time_sec
from "%scripts/dagui_library.nut" import *

let battlePassChallenges = Watched([])
let curSeasonChallenges = Computed(@() battlePassChallenges.get()
  .filter(@(unlock) unlock.battlePassSeason == season.get()))

curSeasonChallenges.subscribe(function(value) {
  foreach (challenge in value) {
    let userstatUnlock = activeUnlocks.get()?[challenge.id]
    if (!(userstatUnlock?.isCompleted ?? false) && isUnlockOpened(challenge.id)) {
      refreshUserstatUnlocks()
      return
    }
  }
})

function getLevelFromConditions(conditions, stages) {
  let battlepassLevel = conditions.findvalue(@(cond) cond?.type == "battlepassLevel")
  if (battlepassLevel)
    return battlepassLevel.level

  let battlepassProgress = conditions.findvalue(@(cond) cond?.type == "battlepassProgress")
  if (battlepassProgress)
    return getLevelFromStagesByExp(stages, battlepassProgress.progress)

  return null
}

let curSeasonChallengesByStage = Computed(function() {
  let res = {}
  foreach (challenge in curSeasonChallenges.get()) {
    let mode = challenge?.mode
    if (mode == null)
      continue

    let level = getLevelFromConditions(getUnlockConditions(mode), basicUnlockStages.get())
    if (level == null)
      continue

    res[level] <- challenge
  }
  return res
})

let mainChallengeOfSeasonId = Computed(@() $"battlepass_season_{season.get()}_challenge_all")
let mainChallengeOfSeason = Computed(@() curSeasonChallenges.get()
  .findvalue(@(challenge) challenge.id == mainChallengeOfSeasonId.get()))

function invalidateUnlocksCache() {
  battlePassChallenges.set([])
  broadcastEvent("BattlePassCacheInvalidate")
}

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(_p) invalidateUnlocksCache()
})

function updateChallenges() {
  if (hasFullLoginState.get())
    battlePassChallenges.set(getUnlocksWhereInBlkOrder("battlePassSeason != null")
      .filter(@(unlock) isUnlockVisible(unlock)))
}

function getChallengeStatus(userstatUnlock, unlockConfig) {
  if (userstatUnlock?.hasReward ?? false)
    return "complete"
  if (userstatUnlock?.isCompleted ?? false)
    return "done"
  if (unlockConfig.isExpired)
    return "expired"
  return null
}

function getConditionInTitleConfig(unlockBlk) {
  let res = {
    addTitle = ""
    titleIcon = "#ui/gameuiskin#challenge_medal.svg"
  }
  let mode = unlockBlk?.mode
  if (mode == null)
    return res

  let condition = getUnlockConditions(mode)
  let level = getLevelFromConditions(condition, basicUnlockStages.get())
  if (level != null) {
    if (level > seasonLevel.get())
      return {
        addTitle = loc("ui/parentheses/space", {
          text = loc("condition/unlockByLevel", { level = level })
        })
        titleIcon = "#ui/gameuiskin#calendar_event.svg"
      }
  }

  let timeCond = condition.findvalue(@(cond) isTimeRangeCondition(cond.type))
  if (timeCond != null) {
    let beginTime = getTimestampFromStringUtc(timeCond.beginDate)
    if (beginTime > get_charserver_time_sec())
      return {
        addTitle = loc("ui/parentheses/space", {
          text = loc("condition/unlockByTime", { date = buildDateStr(beginTime) })
        })
        titleIcon = "#ui/gameuiskin#calendar_date.svg"
      }
  }

  return res
}

function getChallengeView(config, paramsCfg = {}) {
  let id = config.id
  let userstatUnlock = activeUnlocks.get()?[id]
  let unlockConfig = buildConditionsConfig(config)
  buildUnlockDesc(unlockConfig)

  let title = getUnlockNameText(unlockConfig.unlockType, id)
  let { addTitle, titleIcon } = getConditionInTitleConfig(config)
  let headerCond = getHeaderCondition(unlockConfig.conditions)

  let progressData = unlockConfig?.getProgressBarData()
  let progressBarValue = unlockConfig?.curVal != null && unlockConfig.curVal >= 0
    ? (unlockConfig.curVal.tofloat() / (unlockConfig?.maxVal ?? 1) * 1000)
    : 0
  let challengeStatus = getChallengeStatus(userstatUnlock, unlockConfig)
  let isInteractive = paramsCfg?.isInteractive ?? true

  return {
    id = id
    title = $"{title}{addTitle}"
    taskStatus = challengeStatus
    taskDifficultyImage = titleIcon
    taskHeaderCondition = headerCond ? loc("ui/parentheses/space", { text = headerCond }) : null
    description = getBattleTaskDesc(unlockConfig, paramsCfg)
    reward = getUnlockRewardMarkUp(userstatUnlock)
    canGetReward = isInteractive && (userstatUnlock?.hasReward ?? false)
    needShowProgressValue = challengeStatus == null && config?.curVal != null
      && config.curVal >= 0 && config?.maxVal != null && config.maxVal >= 0
    progressValue = config?.curVal
    progressMaxValue = config?.maxVal
    needShowProgressBar = progressData?.show
    progressBarValue = progressBarValue.tointeger()
    isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
    isFavorite = isInteractive ? (isUnlockFav(id) ? "yes" : "no") : null
    hoverAction = paramsCfg?.hoverAction
    rewardOnTop = true
  }
}

let hasChallengesReward = Computed(@() battlePassChallenges.get()
  .findindex(@(unlock) activeUnlocks.get()?[unlock.id].hasReward ?? false) != null)

addTooltipTypes({
  BATTLE_PASS_CHALLENGE = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, id, _params) {
      if (!checkObj(obj))
        return false

      let unlockBlk = id && id != "" && getUnlockById(id)
      let view = {
        items = [getChallengeView(unlockBlk, { isOnlyInfo = true, isInteractive = false })]
        isSmallText = true
      }
      let data = handyman.renderCached("%gui/unlocks/battleTasksItem.tpl", view)

      let guiScene = obj.getScene()
      obj.width = "1@unlockBlockWidth"
      guiScene.replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
})

return freeze({
  updateChallenges
  curSeasonChallenges
  getChallengeView
  mainChallengeOfSeasonId
  mainChallengeOfSeason
  curSeasonChallengesByStage
  hasChallengesReward
})
