local { getTimestampFromStringUtc, buildDateStr} = require("scripts/time.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { season, seasonLevel, getLevelByExp } = require("scripts/battlePass/seasonState.nut")
local { activeUnlocks, getUnlockRewardMarkUp } = require("scripts/unlocks/userstatUnlocksState.nut")
local { refreshUserstatUnlocks } = require("scripts/userstat/userstat.nut")

local battlePassChallenges = ::Watched([])
local curSeasonChallenges = ::Computed(@() battlePassChallenges.value
  .filter(@(unlock) unlock.battlePassSeason == season.value))

curSeasonChallenges.subscribe(function(value) {
  foreach (challenge in value) {
    local userstatUnlock = activeUnlocks.value?[challenge.id]
    if (!(userstatUnlock?.isCompleted ?? false) && ::is_unlocked_scripted(-1, challenge.id)) {
      refreshUserstatUnlocks()
      return
    }
  }
})

local curSeasonChallengesByStage = ::Computed(function() {
  local res = {}
  foreach (challenge in curSeasonChallenges.value) {
    local mode = challenge?.mode
    if (mode == null)
      continue

    local battlepassProgress = (mode % "condition").findvalue(@(cond) cond?.type == "battlepassProgress")
    if (battlepassProgress == null)
      continue

    local level = getLevelByExp(battlepassProgress.progress)
    res[level] <- challenge
  }
  return res
})

local mainChallengeOfSeasonId = ::Computed(@() $"battlepass_season_{season.value}_challenge_all")
local mainChallengeOfSeason = ::Computed(@() curSeasonChallenges.value
  .findvalue(@(challenge) challenge.id == mainChallengeOfSeasonId.value))

local function invalidateUnlocksCache() {
  battlePassChallenges([])
  ::broadcastEvent("BattlePassCacheInvalidate")
}

addListenersWithoutEnv({
  UnlocksCacheInvalidate = @(p) invalidateUnlocksCache()
})

local function updateChallenges(value = null) {
  if (::g_login.isLoggedIn())
    battlePassChallenges(::g_unlocks.getAllUnlocksWithBlkOrder()
      .filter(@(unlock) ::is_unlock_visible(unlock) && unlock?.battlePassSeason != null))
}

local function getChallengeStatus(userstatUnlock) {
  if (userstatUnlock?.hasReward ?? false)
    return "complete"
  if (userstatUnlock?.isCompleted ?? false)
    return "done"
  return null
}

local function getConditionInTitleConfig(unlockBlk) {
  local res = {
    addTitle = ""
    titleIcon = "#ui/gameuiskin#challenge_medal"
  }
  local mode = unlockBlk?.mode
  if (mode == null)
    return res

  local condition = (mode % "condition").extend(mode % "visualCondition")
  local battlepassProgress = condition.findvalue(@(cond) cond.type == "battlepassProgress")
  if (battlepassProgress != null) {
    local level = getLevelByExp(battlepassProgress.progress)
    if (level > seasonLevel.value)
      return {
        addTitle = ::loc("ui/parentheses/space", {
          text = ::loc("condition/unlockByLevel", { level = level })
        })
        titleIcon = "#ui/gameuiskin#calendar_event.svg"
      }
  }

  local timeCond = condition.findvalue(@(cond) ::unlock_time_range_conditions.contains(cond.type))
  if (timeCond != null) {
    local beginTime = getTimestampFromStringUtc(timeCond.beginDate)
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

local function getChallengeView(config, paramsCfg = {}) {
  local id = config.id
  local userstatUnlock = activeUnlocks.value?[id]
  local unlockConfig = ::build_conditions_config(config)
  ::build_unlock_desc(unlockConfig)

  local title = ::get_unlock_name_text(unlockConfig.unlockType, id)
  local { addTitle, titleIcon } = getConditionInTitleConfig(config)
  local headerCond = ::UnlockConditions.getHeaderCondition(unlockConfig.conditions)

  local progressData = unlockConfig?.getProgressBarData()
  local progressBarValue = unlockConfig?.curVal != null && unlockConfig.curVal >= 0
    ? (unlockConfig.curVal.tofloat() / (unlockConfig?.maxVal ?? 1) * 1000)
    : 0
  local challengeStatus = getChallengeStatus(userstatUnlock)

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

local hasChallengesReward = ::Computed(@() battlePassChallenges.value
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
