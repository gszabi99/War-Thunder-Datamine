local { userstatUnlocks, userstatDescList, userstatStats, receiveUnlockRewards
} = require("scripts/userstat/userstat.nut")
local { showRewardWnd, canGetRewards } = require("scripts/userstat/userstatItemsRewards.nut")
local inventoryClient = require("scripts/inventory/inventoryClient.nut")

local rewardsInProgress = Watched({})

local emptyProgress = {
  stage = 0
  lastRewardedStage = 0
  current = 0
  required = 1
  isCompleted = false
  hasReward = false
  isFinished = false //isCompleted && !hasReward
}

local unlockTables = ::Computed(function() {
  local stats = userstatStats.value
  local res = {}
  foreach(name, value in stats?.stats ?? {})
    res[name] <- true
  foreach(name, value in stats?.inactiveTables ?? {})
    res[name] <- false
  return res
})

local function calcUnlockProgress(progressData, unlockDesc) {
  unlockDesc = unlockDesc ?? {}
  local res = clone emptyProgress
  local stage = progressData?.stage ?? 0
  res.stage = stage
  res.lastRewardedStage = progressData?.lastRewardedStage ?? 0
  res.hasReward = stage > res.lastRewardedStage

  if (progressData?.progress != null) {
    res.current = progressData.progress
    res.required = progressData.nextStage
    unlockDesc.__update(res)
    return res
  }

  local stageToShow = min(stage, unlockDesc?.stages.len() ?? 0)
  res.required = (unlockDesc?.stages[stageToShow].progress || 1).tointeger()
  if (stage > 0) {
    local isLastStageCompleted = (unlockDesc?.periodic != true) && (stage >= stageToShow)
    res.isCompleted = isLastStageCompleted || res.hasReward
    res.isFinished = isLastStageCompleted && !res.hasReward
    res.current = res.required
  }
  unlockDesc.__update(res)
  return res
}

local personalUnlocksData = ::Computed(@() userstatUnlocks.value?.personalUnlocks ?? {})

local allUnlocks = ::Computed(@() (userstatDescList.value?.unlocks ?? {})
  .map(function(u,name) {
    local upd = {}
    local progress = calcUnlockProgress((userstatUnlocks.value?.unlocks ?? {})?[name], u)
    if ((u?.personal ?? "") != "")
      upd.personalData <- personalUnlocksData.value?[u.name] ?? {}
    if ("stages" in u)
      upd.stages <- u.stages.map(@(stage) stage.__merge({ progress = (stage?.progress ?? 1).tointeger() }))
    return u.__merge(upd, progress)
  }))

local activeUnlocks = ::Computed(@() allUnlocks.value.filter(function(ud) {
  if (!(unlockTables.value?[ud?.table] ?? false))
    return false
  if ("personalData" in ud)
    return ud.personalData.len() > 0
  return true
}))

local unlockProgress = ::Computed(function() {
  local progressList = userstatUnlocks.value?.unlocks ?? {}
  local unlockDataList = allUnlocks.value
  local allKeys = progressList.__merge(unlockDataList) //use only keys from it
  return allKeys.map(@(_, name) calcUnlockProgress(progressList?[name], unlockDataList?[name]))
})

local servUnlockProgress = ::Computed(@() userstatUnlocks.value?.unlocks ?? {})


local RECEIVE_REWARD_DEFAULT_OPTIONS = {
  showProgressBox = true
}
local function receiveRewards(unlockName, taskOptions = RECEIVE_REWARD_DEFAULT_OPTIONS, needShowRewardWnd = true) {
  if (!unlockName || unlockName in rewardsInProgress.value)
    return
  taskOptions = RECEIVE_REWARD_DEFAULT_OPTIONS.__merge(taskOptions)
  local progressData = servUnlockProgress.value?[unlockName]
  local stage = progressData?.stage ?? 0
  local lastReward = progressData?.lastRewardedStage ?? 0
  local rewards = activeUnlocks.value?[unlockName].stages[stage - 1].rewards
  if (lastReward < stage && canGetRewards(rewards)) {
    local receiveRewardsCallback = function(res) {
      ::dagor.debug($"receiveRewards {unlockName} results: {res}")
      delete rewardsInProgress[unlockName]
    }
    rewardsInProgress[unlockName] <- stage
    receiveUnlockRewards(unlockName, stage, function(res) {
      receiveRewardsCallback("success")
      if (needShowRewardWnd)
        showRewardWnd(rewards)
    }, receiveRewardsCallback, taskOptions)
  }
}

local function getRewards(unlockDesc) {
  local res = {}
  foreach(stageData in unlockDesc?.stages ?? [])
    foreach(idStr, amount in stageData?.rewards ?? {})
      res[idStr.tointeger()] <- true
  return res
}

local unlocksByReward = keepref(::Computed(
  function() {
    local res = {}
    foreach(unlockDesc in activeUnlocks.value) {
      local rewards = getRewards(unlockDesc)
      foreach(itemdefid, _ in rewards) {
        if (!(itemdefid in res))
          res[itemdefid] <- []
        res[itemdefid].append(unlockDesc)
      }
    }
    return res
  }))

local function requestRewardItems(unlocksByRewardValue) {
  local itemsToRequest = unlocksByRewardValue.keys()
  if (itemsToRequest.len() > 0)   //request items for rewards
    inventoryClient.requestItemdefsByIds(itemsToRequest)
}

unlocksByReward.subscribe(requestRewardItems)
requestRewardItems(unlocksByReward.value)

local function clampStage(unlockDesc, stage) {
  local lastStage = unlockDesc?.stages.len() ?? 0
  if (lastStage <= 0 || !(unlockDesc?.periodic ?? false) || stage < lastStage)
    return stage

  local loopStage = (unlockDesc?.startStageLoop ?? 1) - 1
  if (loopStage >= lastStage)
    loopStage = 0
  return loopStage + (stage - loopStage) % (lastStage - loopStage)
}

local getStageByIndex = @(unlockDesc, stage) unlockDesc?.stages[clampStage(unlockDesc, stage)]

local function getUnlockReward(userstatUnlock) {
  local rewardMarkUp = { rewardText = "", itemMarkUp = ""}
  local { lastRewardedStage = 0 } = userstatUnlock
  local stage = getStageByIndex(userstatUnlock, lastRewardedStage)
  if (stage == null)
    return rewardMarkUp

  local itemId = stage?.rewards.keys()[0]
  if (itemId != null) {
    local item = ::ItemsManager.findItemById(::to_integer_safe(itemId, itemId, false))
    rewardMarkUp.itemMarkUp = item?.getNameMarkup(stage.rewards[itemId]) ?? ""
  }

  rewardMarkUp.rewardText = "\n".join((stage?.updStats ?? [])
    .map(@(stat) ::loc($"updStats/{stat.name}", { amount = stat.value }, ""))
    .filter(@(rewardText) rewardText != ""))

  return rewardMarkUp
}

local function getUnlockRewardMarkUp(userstatUnlock) {
  local rewardMarkUp = getUnlockReward(userstatUnlock)
  if (rewardMarkUp.rewardText == "" && rewardMarkUp.itemMarkUp == "")
    return {}

  local rewardLoc = (userstatUnlock?.isCompleted ?? false) ? ::loc("rewardReceived") : ::loc("reward")
  rewardMarkUp.rewardText <- $"{rewardLoc}{::loc("ui/colon")}{rewardMarkUp.rewardText}"
  return rewardMarkUp
}

return {
  activeUnlocks
  unlockProgress
  emptyProgress = clone emptyProgress
  servUnlockProgress
  receiveRewards
  getStageByIndex
  getUnlockRewardMarkUp
  getUnlockReward
}