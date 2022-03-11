let { getTimestampFromStringUtc, buildDateStr} = require("scripts/time.nut")
let { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
let { season, seasonLevel, getLevelByExp } = require("scripts/battlePass/seasonState.nut")
let { activeUnlocks, getUnlockRewardMarkUp } = require("scripts/unlocks/userstatUnlocksState.nut")
let { refreshUserstatUnlocks } = require("scripts/userstat/userstat.nut")

let battlePassChallenges = ::Watched([])
let curSeasonChallenges = ::Computed(@() battlePassChallenges.value
  .filter(@(unlock) unlock.battlePassSeason == season.value))

curSeasonChallenges.subscribe(function(value) {
  foreach (challenge in value) {
    let userstatUnlock = activeUnlocks.value?[challenge.id]
    if (!(userstatUnlock?.isCompleted ?? false) && ::is_unlocked_scripted(-1, challenge.id)) {
      refreshUserstatUnlocks()
      return
    }
  }
})

let curSeasonChallengesByStage = ::Computed(function() {
  let res = {}
  foreach (challenge in curSeasonChallenges.value) {
    let mode = challenge?.mode
    if (mode == null)
      continue

    let battlepassProgress = (mode % "condition").findvalue(@(cond) cond?.type == "battlepassProgress")
    if (battlepassProgress == null)
      continue

    let level = getLevelByExp(battlepassProgress.progress)
    res[level] <- challenge
  }
  return res
})

let mainChallengeOfSeasonId = ::Computed(@() $"battlepass_season_{season.value}_challenge_all")
let mainChallengeOfSeason = ::Computed(@() curSeasonChallenges.value
  .findvalue(@(challenge) challenge.id == mainChallengeOfSeasonId.value))

let function invalidateUnlocksCache() {
  battlePassChallenges([])
  ::broadcastEvent("BattlePassCacheInvalidate")
}

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(p) invalidateUnlocksCache()
})

let function updateChallenges(value = null) {
  if (::g_login.isLoggedIn())
    battlePassChallenges(::g_unlocks.getAllUnlocksWithBlkOrder()
      .filter(@(unlock) ::is_unlock_visible(unlock) && unlock?.battlePassSeason != null))
}

let function getChallengeStatus(userstatUnlock, unlockConfig) {
  if (userstatUnlock?.hasReward ?? false)
    return "complete"
  if (userstatUnlock?.isCompleted ?? false)
    return "done"
  if (unlockConfig.isExpired)
    return "expired"
  return null
}

let function getConditionInTitleConfig(unlockBlk) {
  let res = {
    addTitle = ""
    titleIcon = "#ui/gameuiskin#challenge_medal"
  }
  let mode = unlockBlk?.mode
  if (mode == null)
    return res

  let condition = (mode % "condition").extend(mode % "visualCondition")
  let battlepassProgress = condition.findvalue(@(cond) cond.type == "battlepassProgress")
  if (battlepassProgress != null) {
    let level = getLevelByExp(battlepassProgress.progress)
    if (level > seasonLevel.value)
      return {
        addTitle = ::loc("ui/parentheses/space", {
          text = ::loc("condition/unlockByLevel", { level = level })
        })
        titleIcon = "#ui/gameuiskin#calendar_event.svg"
      }
  }

  let timeCond = condition.findvalue(@(cond) ::unlock_time_range_conditions.contains(cond.type))
  if (timeCond != null) {
    let beginTime = getTimestampFromStringUtc(timeCond.beginDate)
    if (beginTime > ::get_charserver_time_sec())
      return {
        addTitle = ::loc("ui/parentheses/space", {
          text = ::loc("condition/unlockByTime", { date = buildDateStr(beginTime) })
        })
        titleIcon = "#ui/gameuiskin#calendar_date.svg"
      }
  }

  return res
}

let function getChallengeView(config, paramsCfg = {}) {
  let id = config.id
  let userstatUnlock = activeUnlocks.value?[id]
  let unlockConfig = ::build_conditions_config(config)
  ::build_unlock_desc(unlockConfig)

  let title = ::get_unlock_name_text(unlockConfig.unlockType, id)
  let { addTitle, titleIcon } = getConditionInTitleConfig(config)
  let headerCond = ::UnlockConditions.getHeaderCondition(unlockConfig.conditions)

  let progressData = unlockConfig?.getProgressBarData()
  let progressBarValue = unlockConfig?.curVal != null && unlockConfig.curVal >= 0
    ? (unlockConfig.curVal.tofloat() / (unlockConfig?.maxVal ?? 1) * 1000)
    : 0
  let challengeStatus = getChallengeStatus(userstatUnlock, unlockConfig)

  return {
    id = id
    title = $"{title}{addTitle}"
    taskStatus = challengeStatus
    taskDifficultyImage = titleIcon
    taskHeaderCondition = headerCond ? ::loc("ui/parentheses/space", { text = headerCond }) : null
    description = ::g_battle_tasks.getTaskDescription(unlockConfig, paramsCfg)
    reward = getUnlockRewardMarkUp(userstatUnlock)
    canGetReward = userstatUnlock?.hasReward ?? false
    needShowProgressValue = challengeStatus == null && config?.curVal != null
      && config.curVal >= 0 && config?.maxVal != null && config.maxVal >= 0
    progressValue = config?.curVal
    progressMaxValue = config?.maxVal
    needShowProgressBar = progressData?.show
    progressBarValue = progressBarValue.tointeger()
    isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
    isFavorite = (id in ::g_unlocks.getFavoriteUnlocks()) ? "yes" : "no"
    hoverAction = paramsCfg?.hoverAction
  }
}

let hasChallengesReward = ::Computed(@() battlePassChallenges.value
  .findindex(@(unlock) activeUnlocks.value?[unlock.id].hasReward ?? false) != null)

return {
  updateChallenges
  curSeasonChallenges
  getChallengeView
  mainChallengeOfSeasonId
  mainChallengeOfSeason
  curSeasonChallengesByStage
  hasChallengesReward
}
