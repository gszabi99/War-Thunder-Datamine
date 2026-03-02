from "%scripts/dagui_library.nut" import *

let { userstatUnlocks, userstatDescList, userstatStats
} = require("%scripts/userstat/userstat.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")


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
  let stats = userstatStats.get()
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

let personalUnlocksData = Computed(@() userstatUnlocks.get()?.personalUnlocks ?? {})

let allUnlocks = Computed(@() (userstatDescList.get()?.unlocks ?? {})
  .map(function(u, name) {
    let upd = {}
    let progress = calcUnlockProgress((userstatUnlocks.get()?.unlocks ?? {})?[name], u)
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
  let progressList = userstatUnlocks.get()?.unlocks ?? {}
  let unlockDataList = allUnlocks.get()
  let allKeys = progressList.__merge(unlockDataList) 
  return allKeys.map(@(_, name) calcUnlockProgress(progressList?[name], unlockDataList?[name]))
})

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


return {
  activeUnlocks
  unlockProgress
  emptyProgress = clone emptyProgress
  getStageByIndex
}
