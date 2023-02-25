//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { activeUnlocks, getStageByIndex } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { userstatStats, refreshUserstatDescList } = require("%scripts/userstat/userstat.nut")
let { basicUnlock, premiumUnlock, hasBattlePass } = require("%scripts/battlePass/unlocksRewardsState.nut")
let { getRangeTextByPoint2 } = require("%scripts/unlocks/unlocksConditions.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { floor } = require("math")

let expStatId = "battlepass_exp"

let season = Computed(@() userstatStats.value?.stats.seasons["$index"] ?? 0)

local lastSeasonIndex = 0
season.subscribe(function(seasonIndex) {
  if (seasonIndex == 0 || lastSeasonIndex == seasonIndex)
    return

  if (lastSeasonIndex > 0) // update userstat unlocks description when season changed
    refreshUserstatDescList()

  lastSeasonIndex = seasonIndex
})

let totalProgressExp = Computed(@() basicUnlock.value?.current ?? 0)

let function getLevelByExp(exp) {
  let stages = basicUnlock.value?.stages ?? []
  if (stages.len() == 0)
    return 0

  return stages.findindex(@(s) exp < s.progress) ?? 0
}

let levelExp = Computed(function() {
  let res = {
    level = 1
    curLevelExp = 0
    expForLevel = 1
  }
  let curProgress = totalProgressExp.value
  let stages = basicUnlock.value?.stages ?? []
  if (stages.len() == 0)
    return res
  let stageIdx = stages.findindex(@(s) curProgress < s.progress)
  if (stageIdx != null) {
    let expForPrevLevel = stages?[stageIdx - 1].progress ?? 0
    return {
      level = stageIdx
      curLevelExp = curProgress - expForPrevLevel
      expForLevel = (stages[stageIdx]?.progress ?? 0) - expForPrevLevel
    }
  }

  if (!(basicUnlock.value?.periodic ?? false))
    return res

  let lastStageIdx = stages.len() - 1
  let loopStageIdx = (basicUnlock.value?.startStageLoop ?? 1) - 1
  let loopStage = stages?[loopStageIdx] ?? stages[lastStageIdx]
  let prevLoopStage = stages?[loopStageIdx - 1]
  let progressForStage = prevLoopStage == null ? loopStage.progress
    : loopStage.progress - prevLoopStage.progress
  let freeExp = curProgress - loopStage.progress
  return {
    level = lastStageIdx + 1
      + floor(freeExp.tofloat() / progressForStage).tointeger()
    curLevelExp = freeExp % progressForStage
    expForLevel = loopStage.progress - prevLoopStage.progress
  }
})

let seasonLevel = Computed(@() levelExp.value.level)

let maxSeasonLvl = Computed(@() max(basicUnlock.value?.meta.mainPrizeStage ?? 1,
  premiumUnlock.value?.meta.mainPrizeStage ?? 1))

let loginUnlockId = Computed(@() $"battlepass_login_streak_1")
let loginUnlock = Computed(@() activeUnlocks.value?[loginUnlockId.value])
let loginStreak = Computed(@() loginUnlock.value?.stage ?? 0)

let getExpRewardStage = @(stageState) stageState?.updStats
  .findvalue(@(stat) stat?.name == expStatId).value.tointeger() ?? 0

let todayLoginExp = Computed(@() getExpRewardStage(
  getStageByIndex(loginUnlock.value, (loginUnlock.value?.stage ?? 0) - 1)))
let tomorowLoginExp = Computed(@() getExpRewardStage(
  getStageByIndex(loginUnlock.value, (loginUnlock.value?.stage ?? 0))))

let function getExpRangeTextOfLoginStreak() {
  let stages = loginUnlock.value?.stages
  if (stages == null)
    return ""

  let curExp = todayLoginExp.value
  local x = null
  local y = null
  foreach (idx, stage in stages) {
    let value = stage?.updStats.findvalue(@(stat) stat?.name == expStatId).value.tointeger() ?? 0
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

  let text = getRangeTextByPoint2(
    { x = x ?? 0, y = y ?? 0 }, {
      valueStr = "%d"
      maxOnlyStr = loc("conditions/unitRank/format_max")
      minOnlyStr = loc("conditions/unitRank/format_min")
    })
  return "".concat(loc("progress/amount/forValues", { amount = curExp }),
    loc("ui/colon"), text)
}

let warbondsShopLevelByStages = Computed(@() basicUnlock.value?.meta.wbShopLevel ?? {})

let seasonMainPrizesData = Computed(@() [].extend(premiumUnlock.value?.meta.promo ?? [],
  basicUnlock.value?.meta.promo ?? []))

let battlePassShopConfig = Computed(@() basicUnlock.value?.meta.purchaseWndItems)

battlePassShopConfig.subscribe(function(itemsConfigForRequest) {
  let itemsToRequest = []
  foreach (config in (itemsConfigForRequest ?? [])) {
    foreach (_key, value in config) {
      let itemId = ::to_integer_safe(value, value, false) //-param-pos
      if (::ItemsManager.isItemdefId(itemId))
        itemsToRequest.append(itemId)
    }
  }
  if (itemsToRequest.len() > 0)   //request items for rewards
    inventoryClient.requestItemdefsByIds(itemsToRequest)
})

let hasBattlePassReward = Computed(@() basicUnlock.value?.hasReward
  || (hasBattlePass.value && premiumUnlock.value?.hasReward))

return {
  seasonLevel
  maxSeasonLvl
  todayLoginExp
  loginStreak
  tomorowLoginExp
  loginUnlockId
  season
  seasonMainPrizesData
  hasBattlePass
  battlePassShopConfig
  getExpRangeTextOfLoginStreak
  levelExp
  warbondsShopLevelByStages
  getLevelByExp
  hasBattlePassReward
}
