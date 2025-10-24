from "%scripts/dagui_library.nut" import *

let { activeUnlocks, getStageByIndex } = require("%scripts/unlocks/userstatUnlocksState.nut")
let { userstatStats, refreshUserstatDescList } = require("%scripts/userstat/userstat.nut")
let { basicUnlock, premiumUnlock, hasBattlePass } = require("%scripts/battlePass/unlocksRewardsState.nut")
let { getRangeTextByPoint2 } = require("%scripts/unlocks/unlocksConditions.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { isItemdefId } = require("%scripts/items/itemsChecks.nut")
let { floor } = require("math")

let expStatId = "battlepass_exp"

const LOGIN_UNLOCK_ID = "battlepass_login_streak_1"

let season = Computed(@() userstatStats.get()?.stats.seasons["$index"] ?? 0)
let seasonEndsTime = Computed(@() userstatStats.get()?.stats.seasons["$endsAt"] ?? 0)

local lastSeasonIndex = 0
season.subscribe(function(seasonIndex) {
  if (seasonIndex == 0 || lastSeasonIndex == seasonIndex)
    return

  if (lastSeasonIndex > 0) 
    refreshUserstatDescList()

  lastSeasonIndex = seasonIndex
})

let totalProgressExp = Computed(@() basicUnlock.get()?.current ?? 0)

let basicUnlockStages = Computed(@() basicUnlock.get()?.stages ?? [])

let getLevelFromStagesByExp = @(stages, exp) stages.findindex(@(s) exp < s.progress) ?? 0
let getLevelByExp = @(exp) getLevelFromStagesByExp(basicUnlockStages.get(), exp)

let levelExp = Computed(function() {
  let res = {
    level = 1
    curLevelExp = 0
    expForLevel = 1
  }
  let curProgress = totalProgressExp.get()
  let stages = basicUnlock.get()?.stages ?? []
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

  if (!(basicUnlock.get()?.periodic ?? false))
    return res

  let lastStageIdx = stages.len() - 1
  let loopStageIdx = (basicUnlock.get()?.startStageLoop ?? 1) - 1
  let loopStage = stages?[loopStageIdx] ?? stages[lastStageIdx]
  let prevLoopStage = stages?[loopStageIdx - 1]
  let expForLevel = prevLoopStage == null ? loopStage.progress
    : loopStage.progress - prevLoopStage.progress
  let freeExp = curProgress - loopStage.progress
  return {
    level = lastStageIdx + 1
      + floor(freeExp.tofloat() / expForLevel).tointeger()
    curLevelExp = freeExp % expForLevel
    expForLevel
  }
})

let seasonLevel = Computed(@() levelExp.get().level)

let maxSeasonLvl = Computed(@() max(basicUnlock.get()?.meta.mainPrizeStage ?? 1,
  premiumUnlock.get()?.meta.mainPrizeStage ?? 1))

let loginUnlock = Computed(@() activeUnlocks.get()?[LOGIN_UNLOCK_ID])
let loginStreak = Computed(@() loginUnlock.get()?.stage ?? 0)

let getExpRewardStage = @(stageState) stageState?.updStats
  .findvalue(@(stat) stat?.name == expStatId).value.tointeger() ?? 0

let todayLoginExp = Computed(@() getExpRewardStage(
  getStageByIndex(loginUnlock.get(), (loginUnlock.get()?.stage ?? 0) - 1)))
let tomorowLoginExp = Computed(@() getExpRewardStage(
  getStageByIndex(loginUnlock.get(), (loginUnlock.get()?.stage ?? 0))))

function getExpRangeTextOfLoginStreak() {
  let stages = loginUnlock.get()?.stages
  if (stages == null)
    return ""

  let curExp = todayLoginExp.get()
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

let warbondsShopLevelByStages = Computed(@() basicUnlock.get()?.meta.wbShopLevel ?? {})

let seasonMainPrizesData = Computed(@() [].extend(premiumUnlock.get()?.meta.promo ?? [],
  basicUnlock.get()?.meta.promo ?? []))

let battlePassShopConfig = Computed(@() basicUnlock.get()?.meta.purchaseWndItems)

battlePassShopConfig.subscribe(function(itemsConfigForRequest) {
  let itemsToRequest = []
  foreach (config in (itemsConfigForRequest ?? [])) {
    foreach (_key, value in config) {
      let itemId = to_integer_safe(value, value, false) 
      if (isItemdefId(itemId))
        itemsToRequest.append(itemId)
    }
  }
  if (itemsToRequest.len() > 0)   
    inventoryClient.requestItemdefsByIds(itemsToRequest)
})

let hasBattlePassReward = Computed(@() basicUnlock.get()?.hasReward
  || (hasBattlePass.get() && premiumUnlock.get()?.hasReward))

return {
  seasonLevel
  maxSeasonLvl
  todayLoginExp
  loginStreak
  tomorowLoginExp
  season
  seasonMainPrizesData
  hasBattlePass
  battlePassShopConfig
  getExpRangeTextOfLoginStreak
  levelExp
  warbondsShopLevelByStages
  getLevelByExp
  hasBattlePassReward
  seasonEndsTime
  basicUnlockStages
  getLevelFromStagesByExp
}
