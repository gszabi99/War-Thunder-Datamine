local { activeUnlocks, receiveRewards, getStageByIndex } = require("scripts/unlocks/userstatUnlocksState.nut")
local { userstatStats } = require("scripts/userstat/userstat.nut")
local { basicUnlock, basicProgress, premiumUnlock, premiumProgress
} = require("scripts/battlePass/unlocksRewardsState.nut")
local inventoryClient = require("scripts/inventory/inventoryClient.nut")

local expStatId = "battlepass_exp"
local curSeasonBattlePassUnlockId = ::Computed(@() premiumUnlock.value?.requirement)

local hasBattlePass = ::Computed(@() curSeasonBattlePassUnlockId.value != null
  && (activeUnlocks.value?[curSeasonBattlePassUnlockId.value].isCompleted ?? false))

local season = ::Computed(@() userstatStats.value?.stats.seasons["$index"] ?? 0)

local totalProgressExp = ::Computed(@() basicUnlock.value?.current ?? 0)

local levelExp = ::Computed(function() {
  local res = {
    level = 1
    curLevelExp = 0
    expForLevel = 1
  }
  local curProgress = totalProgressExp.value
  local stages = basicUnlock.value?.stages ?? []
  if (stages.len() == 0)
    return res
  local stageIdx = stages.findindex(@(s) curProgress < s.progress)
  if (stageIdx != null) {
    local expForPrevLevel = stages?[stageIdx-1].progress ?? 0
    return {
      level = stageIdx
      curLevelExp = curProgress - expForPrevLevel
      expForLevel = (stages[stageIdx]?.progress ?? 0) - expForPrevLevel
    }
  }

  if (!(basicUnlock.value?.periodic ?? false))
    return res

  local lastStageIdx = stages.len() - 1
  local loopStageIdx = (basicUnlock.value?.startStageLoop ?? 1) - 1
  local loopStage = stages?[loopStageIdx] ?? stages[lastStageIdx]
  local prevLoopStage = stages?[loopStageIdx-1]
  local progressForStage = prevLoopStage == null ? loopStage.progress
    : loopStage.progress - prevLoopStage.progress
  local freeExp = curProgress - loopStage.progress
  stageIdx = lastStageIdx
    + ::ceil(freeExp.tofloat() / progressForStage).tointeger()
  return {
    level = stageIdx
    curLevelExp = freeExp % progressForStage
    expForLevel = loopStage.progress - prevLoopStage.progress
  }
})

local seasonLevel = ::Computed(@() levelExp.value.level)
local openedSeasonLevel = ::Computed(@() ::max(basicProgress.value?.stage ?? 0, premiumProgress.value?.stage ?? 0))

local maxSeasonLvl = ::Computed(@() ::max(basicUnlock.value?.meta.mainPrizeStage ?? 1,
  premiumUnlock.value?.meta.mainPrizeStage ?? 1))

local loginUnlockId = ::Computed(@() $"battlepass_login_streak_{season.value}")
local loginUnlock = ::Computed(@() activeUnlocks.value?[loginUnlockId.value])
local loginStreak = ::Computed(@() loginUnlock.value?.stage ?? 0)

local getExpRewardStage = @(stageState) stageState?.updStats
  .findvalue(@(stat) stat?.name == expStatId).value.tointeger() ?? 0

local todayLoginExp = ::Computed(@() getExpRewardStage(
  getStageByIndex(loginUnlock.value, loginUnlock.value?.stage ?? -1)))
local tomorowLoginExp = ::Computed(@() getExpRewardStage(
  getStageByIndex(loginUnlock.value, (loginUnlock.value?.stage ?? -1) + 1)))

local function getExpRangeTextOfLoginStreak() {
  local stages = loginUnlock.value?.stages
  if (stages == null)
    return ""

  local curExp = todayLoginExp.value
  local x = null
  local y = null
  foreach (idx, stage in stages) {
    local value = stage?.updStats.findvalue(@(stat) stat?.name == expStatId).value.tointeger() ?? 0
    if (value < curExp)
      continue

    if (value == curExp) {
      if (x == null)
        x = idx + 1
      continue
    }

    y = idx
    break
  }

  local text = ::UnlockConditions.getRangeTextByPoint2(
    { x = x ?? 0, y = y ?? 0 }, {
      valueStr = "%d"
      maxOnlyStr = ::loc("conditions/unitRank/format_max")
      minOnlyStr = ::loc("conditions/unitRank/format_min")
    })
  return "".concat(::loc("progress/amount/forValues", { amount = curExp }),
    ::loc("ui/colon"), text)
}

local warbondsShopLevelByStages = ::Computed(@() basicUnlock.value?.meta.wbShopLevel ?? {})

local function receiveEmtyRewards(unlock, progressData) {
  if (!(unlock?.hasReward ?? false))
    return

  local curStageData = unlock?.stages[(progressData?.stage ?? 0) - 1]
  if (curStageData != null && (curStageData?.rewards.len() ?? 0) == 0)
    receiveRewards(unlock?.name, { showProgressBox = false }, false)
}

local getSeasonMainPrizesData = @() (premiumUnlock.value?.meta.promo ?? [])
  .extend(basicUnlock.value?.meta.promo ?? [])

basicProgress.subscribe(@(progressData) receiveEmtyRewards(basicUnlock.value, progressData))
premiumProgress.subscribe(function(progressData) {
  if (hasBattlePass.value)
    receiveEmtyRewards(premiumUnlock.value, progressData)
})

local battlePassShopConfig = ::Computed(@() basicUnlock.value?.meta.purchaseWndItems)

battlePassShopConfig.subscribe(function(itemsConfigForRequest) {
  local itemsToRequest = []
  foreach (config in (itemsConfigForRequest ?? [])) {
    foreach (key, value in config) {
      local itemId = ::to_integer_safe(value, value, false)
      if (::ItemsManager.isItemdefId(itemId))
        itemsToRequest.append(itemId)
    }
  }
  if (itemsToRequest.len() > 0)   //request items for rewards
    inventoryClient.requestItemdefsByIds(itemsToRequest)
})

return {
  seasonLevel
  openedSeasonLevel
  maxSeasonLvl
  todayLoginExp
  loginStreak
  tomorowLoginExp
  loginUnlockId
  season
  getSeasonMainPrizesData
  hasBattlePass
  battlePassShopConfig
  getExpRangeTextOfLoginStreak
  levelExp
  warbondsShopLevelByStages
}
