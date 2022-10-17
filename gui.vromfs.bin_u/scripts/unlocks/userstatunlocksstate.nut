let { userstatUnlocks, userstatDescList, userstatStats, receiveUnlockRewards
} = require("%scripts/userstat/userstat.nut")
let { showRewardWnd, canGetRewards } = require("%scripts/userstat/userstatItemsRewards.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

let rewardsInProgress = Watched({})

let emptyProgress = {
  stage = 0
  lastRewardedStage = 0
  current = 0
  required = 1
  isCompleted = false
  hasReward = false
  isFinished = false //isCompleted && !hasReward
}

let unlockTables = ::Computed(function() {
  let stats = userstatStats.value
  let res = {}
  foreach(name, value in stats?.stats ?? {})
    res[name] <- true
  foreach(name, value in stats?.inactiveTables ?? {})
    res[name] <- false
  return res
})

let function calcUnlockProgress(progressData, unlockDesc) {
  let res = clone emptyProgress
  let stage = progressData?.stage ?? 0
  res.stage = stage
  res.lastRewardedStage = progressData?.lastRewardedStage ?? 0
  res.hasReward = stage > res.lastRewardedStage

  if (progressData?.progress != null) {
    res.current = progressData.progress
    res.required = progressData.nextStage
    return res
  }

  let stageToShow = min(stage, unlockDesc?.stages.len() ?? 0)
  res.required = (unlockDesc?.stages[stageToShow].progress || 1).tointeger()
  if (stage > 0) {
    let isLastStageCompleted = (unlockDesc?.periodic != true) && (stage >= stageToShow)
    res.isCompleted = isLastStageCompleted || res.hasReward
    res.isFinished = isLastStageCompleted && !res.hasReward
    res.current = res.required
  }
  return res
}

let personalUnlocksData = ::Computed(@() userstatUnlocks.value?.personalUnlocks ?? {})

let allUnlocks = ::Computed(@() (userstatDescList.value?.unlocks ?? {})
  .map(function(u,name) {
    let upd = {}
    let progress = calcUnlockProgress((userstatUnlocks.value?.unlocks ?? {})?[name], u)
    if ((u?.personal ?? "") != "")
      upd.personalData <- personalUnlocksData.value?[u.name] ?? {}
    if ("stages" in u)
      upd.stages <- u.stages.map(@(stage) stage.__merge({ progress = (stage?.progress ?? 1).tointeger() }))
    return u.__merge(upd, progress)
  }))

let activeUnlocks = ::Computed(@() allUnlocks.value.filter(function(ud) {
  if (!(unlockTables.value?[ud?.table] ?? false))
    return false
  if ("personalData" in ud)
    return ud.personalData.len() > 0
  return true
}))

let unlockProgress = ::Computed(function() {
  let progressList = userstatUnlocks.value?.unlocks ?? {}
  let unlockDataList = allUnlocks.value
  let allKeys = progressList.__merge(unlockDataList) //use only keys from it
  return allKeys.map(@(_, name) calcUnlockProgress(progressList?[name], unlockDataList?[name]))
})

let servUnlockProgress = ::Computed(@() userstatUnlocks.value?.unlocks ?? {})

let function clampStage(unlockDesc, stage) {
  let lastStage = unlockDesc?.stages.len() ?? 0
  if (lastStage <= 0 || !(unlockDesc?.periodic ?? false) || stage < lastStage)
    return stage

  local loopStage = (unlockDesc?.startStageLoop ?? 1) - 1
  if (loopStage >= lastStage)
    loopStage = 0
  return loopStage + (stage - loopStage) % (lastStage - loopStage)
}

let getStageByIndex = @(unlockDesc, stage) unlockDesc?.stages[clampStage(unlockDesc, stage)]

let RECEIVE_REWARD_DEFAULT_OPTIONS = {
  showProgressBox = true
}

let function sendReceiveRewardRequest(params)
{
  let { stage, rewards, unlockName, taskOptions, needShowRewardWnd } = params
  let receiveRewardsCallback = function(res) {
    ::dagor.debug($"Userstat: receive reward {unlockName}, stage: {stage}, results: {res}")
    rewardsInProgress.mutate(@(val) delete val[unlockName])
  }
  rewardsInProgress.mutate(@(val) val[unlockName] <- stage)
  receiveUnlockRewards(unlockName, stage, function(res) {
    receiveRewardsCallback("success")
    if (needShowRewardWnd)
      showRewardWnd(rewards)
  }, receiveRewardsCallback, taskOptions)
}

local function receiveRewards(unlockName, taskOptions = RECEIVE_REWARD_DEFAULT_OPTIONS, needShowRewardWnd = true) {
  if (!unlockName || unlockName in rewardsInProgress.value)
    return
  taskOptions = RECEIVE_REWARD_DEFAULT_OPTIONS.__merge(taskOptions)
  let progressData = servUnlockProgress.value?[unlockName]
  let stage = progressData?.stage ?? 0
  let lastReward = progressData?.lastRewardedStage ?? 0
  let params = {
    stage = stage
    rewards = getStageByIndex(activeUnlocks.value?[unlockName], stage - 1)?.rewards
    unlockName = unlockName
    taskOptions = taskOptions
    needShowRewardWnd = needShowRewardWnd
  }
  if (lastReward < stage && canGetRewards(sendReceiveRewardRequest,
      params.__merge({ needShowRewardWnd = false })))
    sendReceiveRewardRequest(params)
}

let function getRewards(unlockDesc) {
  let res = {}
  foreach(stageData in unlockDesc?.stages ?? [])
    foreach(idStr, amount in stageData?.rewards ?? {})
      res[idStr.tointeger()] <- true
  return res
}

let unlocksByReward = keepref(::Computed(
  function() {
    let res = {}
    foreach(unlockDesc in activeUnlocks.value) {
      let rewards = getRewards(unlockDesc)
      foreach(itemdefid, _ in rewards) {
        if (!(itemdefid in res))
          res[itemdefid] <- []
        res[itemdefid].append(unlockDesc)
      }
    }
    return res
  }))

let function requestRewardItems(unlocksByRewardValue) {
  let itemsToRequest = unlocksByRewardValue.keys()
  if (itemsToRequest.len() > 0)   //request items for rewards
    inventoryClient.requestItemdefsByIds(itemsToRequest)
}

unlocksByReward.subscribe(requestRewardItems)
requestRewardItems(unlocksByReward.value)

let function getUnlockReward(userstatUnlock) {
  let rewardMarkUp = { rewardText = "", itemMarkUp = ""}
  let { lastRewardedStage = 0 } = userstatUnlock
  let stage = getStageByIndex(userstatUnlock, lastRewardedStage)
  if (stage == null)
    return rewardMarkUp

  let itemId = stage?.rewards.keys()[0]
  if (itemId != null) {
    let item = ::ItemsManager.findItemById(::to_integer_safe(itemId, itemId, false))
    rewardMarkUp.itemMarkUp = item?.getNameMarkup(stage.rewards[itemId]) ?? ""
  }

  rewardMarkUp.rewardText = "\n".join((stage?.updStats ?? [])
    .map(@(stat) ::loc($"updStats/{stat.name}", { amount = ::to_integer_safe(stat.value, 0) }, ""))
    .filter(@(rewardText) rewardText != ""))

  return rewardMarkUp
}

let function getUnlockRewardMarkUp(userstatUnlock) {
  let rewardMarkUp = getUnlockReward(userstatUnlock)
  if (rewardMarkUp.rewardText == "" && rewardMarkUp.itemMarkUp == "")
    return {}

  let rewardLoc = (userstatUnlock?.isCompleted ?? false) ? ::loc("rewardReceived") : ::loc("reward")
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