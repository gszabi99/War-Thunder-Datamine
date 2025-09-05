from "%scripts/dagui_library.nut" import *


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
  isFinished = false 
}

let unlockTables = Computed(function() {
  let stats = userstatStats.value
  let res = {}
  foreach (name, _value in stats?.stats ?? {})
    res[name] <- true
  foreach (name, _value in stats?.inactiveTables ?? {})
    res[name] <- false
  return res
})

function calcUnlockProgress(progressData, unlockDesc) {
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
  res.required = (unlockDesc?.stages[stageToShow].progress ?? 1).tointeger()
  if (stage > 0) {
    let isLastStageCompleted = (unlockDesc?.periodic != true) && (stage >= stageToShow)
    res.isCompleted = isLastStageCompleted || res.hasReward
    res.isFinished = isLastStageCompleted && !res.hasReward
    res.current = res.required
  }
  return res
}

let personalUnlocksData = Computed(@() userstatUnlocks.value?.personalUnlocks ?? {})

let allUnlocks = Computed(@() (userstatDescList.value?.unlocks ?? {})
  .map(function(u, name) {
    let upd = {}
    let progress = calcUnlockProgress((userstatUnlocks.value?.unlocks ?? {})?[name], u)
    if ((u?.personal ?? "") != "")
      upd.personalData <- personalUnlocksData.get()?[u.name] ?? {}
    if ("stages" in u)
      upd.stages <- u.stages.map(@(stage) stage.__merge({ progress = (stage?.progress ?? 1).tointeger() }))
    return u.__merge(upd, progress)
  }))

let activeUnlocks = Computed(@() allUnlocks.get().filter(function(ud) {
  if (!(unlockTables.get()?[ud?.table] ?? false))
    return false
  if ("personalData" in ud)
    return ud.personalData.len() > 0
  return true
}))

let unlockProgress = Computed(function() {
  let progressList = userstatUnlocks.value?.unlocks ?? {}
  let unlockDataList = allUnlocks.get()
  let allKeys = progressList.__merge(unlockDataList) 
  return allKeys.map(@(_, name) calcUnlockProgress(progressList?[name], unlockDataList?[name]))
})

let servUnlockProgress = Computed(@() userstatUnlocks.value?.unlocks ?? {})

function clampStage(unlockDesc, stage) {
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

function sendReceiveRewardRequest(params) {
  let { stage, unlockName, taskOptions, needShowRewardWnd } = params
  let receiveRewardsCallback = function(res) {
    log($"Userstat: receive reward {unlockName}, stage: {stage}, results: {res}")
    rewardsInProgress.mutate(@(val) val.$rawdelete(unlockName))
  }
  rewardsInProgress.mutate(@(val) val[unlockName] <- stage)
  receiveUnlockRewards(unlockName, stage, function(_res) {
    receiveRewardsCallback("success")
    if (needShowRewardWnd)
      showRewardWnd(params)
  }, receiveRewardsCallback, taskOptions)
}

function receiveRewards(unlockName, params = {}) {
  if (!unlockName || unlockName in rewardsInProgress.get())
    return
  let { needShowRewardWnd = true, rewardTitleLocId = "rewardReceived" } = params
  let taskOptions = RECEIVE_REWARD_DEFAULT_OPTIONS.__merge(params?.taskOptions ?? {})
  let progressData = servUnlockProgress.get()?[unlockName]
  let stage = progressData?.stage ?? 0
  let lastReward = progressData?.lastRewardedStage ?? 0
  params = {
    stage
    rewards = getStageByIndex(activeUnlocks.get()?[unlockName], stage - 1)?.rewards
    unlockName
    taskOptions
    needShowRewardWnd
    rewardTitleLocId
  }
  if (lastReward < stage && canGetRewards(sendReceiveRewardRequest,
      params.__merge({ needShowRewardWnd = false })))
    sendReceiveRewardRequest(params)
}

function getRewards(unlockDesc) {
  let res = {}
  foreach (stageData in unlockDesc?.stages ?? [])
    foreach (idStr, _amount in stageData?.rewards ?? {})
      res[idStr.tointeger()] <- true
  return res
}

let unlocksByReward = keepref(Computed(
  function() {
    let res = {}
    foreach (unlockDesc in activeUnlocks.get()) {
      let rewards = getRewards(unlockDesc)
      foreach (itemdefid, _ in rewards) {
        if (!(itemdefid in res))
          res[itemdefid] <- []
        res[itemdefid].append(unlockDesc)
      }
    }
    return res
  }))

function requestRewardItems(unlocksByRewardValue) {
  let itemsToRequest = unlocksByRewardValue.keys()
  if (itemsToRequest.len() > 0)   
    inventoryClient.requestItemdefsByIds(itemsToRequest)
}

unlocksByReward.subscribe(requestRewardItems)
requestRewardItems(unlocksByReward.get())

function getUnlockReward(userstatUnlock) {
  let rewardMarkUp = { rewardText = "", itemMarkUp = "" }
  let { lastRewardedStage = 0 } = userstatUnlock
  let stage = getStageByIndex(userstatUnlock, lastRewardedStage)
  if (stage == null)
    return rewardMarkUp

  let itemId = stage?.rewards.keys()[0]
  if (itemId != null) {
    let item = ::ItemsManager.findItemById(to_integer_safe(itemId, itemId, false))
    rewardMarkUp.itemMarkUp = item?.getNameMarkup(stage.rewards[itemId]) ?? ""
  }

  rewardMarkUp.rewardText = "\n".join((stage?.updStats ?? [])
    .map(@(stat) loc($"updStats/{stat.name}", { amount = to_integer_safe(stat.value, 0) }, ""))
    .filter(@(rewardText) rewardText != ""))

  return rewardMarkUp
}

function getUnlockRewardMarkUp(userstatUnlock) {
  let rewardMarkUp = getUnlockReward(userstatUnlock)
  if (rewardMarkUp.rewardText == "" && rewardMarkUp.itemMarkUp == "")
    return {}

  let rewardLoc = (userstatUnlock?.isCompleted ?? false) ? loc("rewardReceived") : loc("reward")
  rewardMarkUp.rewardText <- $"{rewardLoc}{loc("ui/colon")}{rewardMarkUp.rewardText}"
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
  rewardsInProgress
}