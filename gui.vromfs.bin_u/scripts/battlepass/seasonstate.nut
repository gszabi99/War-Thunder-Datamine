from "%scripts/unlocks/userstatUnlocksState.nut" import activeUnlocks, getStageByIndex
from "%scripts/userstat/userstat.nut" import userstatStats, refreshUserstatDescList
from "%scripts/battlePass/unlocksRewardsState.nut" import basicUnlock, premiumUnlock, hasBattlePass, basicUnlockMeta, premiumUnlockMeta
from "%scripts/unlocks/unlocksConditions.nut" import getRangeTextByPoint2
from "%scripts/items/itemsChecks.nut" import isItemdefId
from "math" import floor
from "%scripts/dagui_library.nut" import *

let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

const expStatId = "battlepass_exp"

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

let maxSeasonLvl = Computed(@() max(basicUnlockMeta.get()?.mainPrizeStage ?? 1,
  premiumUnlockMeta.get()?.mainPrizeStage ?? 1))

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

let warbondsShopLevelByStages = Computed(@() basicUnlockMeta.get()?.wbShopLevel ?? {})
let getBPStageByShopLevel = @(level) warbondsShopLevelByStages.get()
  .findindex(@(l) level == l) ?? -1


let seasonMainPrizesData = Computed(@() [].extend(premiumUnlockMeta.get()?.promo ?? [],
  basicUnlockMeta.get()?.promo ?? []))

let battlePassShopConfig = Computed(@() basicUnlockMeta.get()?.purchaseWndItems)

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

return freeze({
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
  getBPStageByShopLevel
  getLevelByExp
  hasBattlePassReward
  seasonEndsTime
  basicUnlockStages
  getLevelFromStagesByExp
})
