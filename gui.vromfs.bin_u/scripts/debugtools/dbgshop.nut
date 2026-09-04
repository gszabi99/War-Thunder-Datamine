import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/ranks_common_shared.nut" import isUnitSpecial
from "string" import format
from "%scripts/dagui_library.nut" import *
from "%scripts/gameModes/gameModeConsts.nut" import BATTLE_TYPES
from "%scripts/unit/unitInfoTexts.nut" import getFontIconByBattleType

let { g_difficulty } = require("%scripts/difficulty.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let { isUnitGroup } = require("%scripts/unit/unitStatus.nut")
let { getUnitSlotRankText } = require("%scripts/slotbar/slotbarView.nut")
let { Cost } = require("%scripts/money.nut")

enum ShopDevModeOption {
  SHOW_ALL_BATTLE_RATINGS = 1
  SHOW_ECONOMIC_RANKS = 2
}

let devMode = persist("shopDevMode", @() {mode = null})

function setShopDevMode(val) {
  if (val == devMode.mode)
    return
  devMode.mode = val
  broadcastEvent("ShopDevModeChange", { moode = val })
}

let getShopDevMode = @() devMode.mode

let getShopDevModeOptions = @() [
  {
    text = "Show All Battle Ratings"
    value = ShopDevModeOption.SHOW_ALL_BATTLE_RATINGS
    enabled = true
    textStyle = "textStyle:t='textarea';"
    selected = getShopDevMode() == ShopDevModeOption.SHOW_ALL_BATTLE_RATINGS
  }
  {
    text = "Show Economic Ranks"
    value = ShopDevModeOption.SHOW_ECONOMIC_RANKS
    enabled = true
    textStyle = "textStyle:t='textarea';"
    selected = getShopDevMode() == ShopDevModeOption.SHOW_ECONOMIC_RANKS
  }
]

function getUnitAllBattleRatingsText(unit) {
  if (isUnitGroup(unit))
    return ""
  return loc("ui/slash").join(g_difficulty.types
    .filter(@(v, _n) v.isAvailable())
    .map(@(v) format("%.1f", unit.getBattleRating(v.getEdiff()))))
}

function getUnitBattleRatingsByBattleTypeText(unit, diff) {
  const battleTypesOrder = [BATTLE_TYPES.AIR, BATTLE_TYPES.TANK, BATTLE_TYPES.SHIP]
  let brTexts = []
  foreach (battleType in battleTypesOrder) {
    if (battleType == BATTLE_TYPES.SHIP && diff == g_difficulty.SIMULATOR) 
      continue
    brTexts.append(" ".concat(getFontIconByBattleType(battleType),
      format("%.1f", unit.getBattleRating(diff.getEdiff(battleType)))))
  }
  return loc("ui/vertical_bar").join(brTexts)
}

function getUnitDebugBattleRatingsText(unit) {
  if (getShopDevMode() != ShopDevModeOption.SHOW_ALL_BATTLE_RATINGS || !hasFeature("DevShopMode")
      || isUnitGroup(unit) || unit?.isFakeUnit)
    return ""
  let ratingsByDiff = []
  foreach (diff in g_difficulty.types)
    if (diff.isAvailable())
      ratingsByDiff.append("".concat(loc(diff.abbreviation), loc("ui/colon"),
        getUnitBattleRatingsByBattleTypeText(unit, diff)))
  return "\n".join(ratingsByDiff)
}

function getUnitDebugCostText(unit) {
  if (getShopDevMode() != ShopDevModeOption.SHOW_ECONOMIC_RANKS || !hasFeature("DevShopMode")
      || isUnitGroup(unit) || unit.marketplaceItemdefId != null)
    return ""
  let cost = isUnitSpecial(unit) ? Cost(0, unit.costGold) : Cost(unit.cost).setRp(unit.reqExp)
  return cost.tostring()
}

function getUnitEconomikRankText(unit) {
  let brText = getUnitSlotRankText(unit, null, true, getShopDiffCode())
  if (!isUnitGroup(unit)) {
    let rank = unit.getUnitWpCostBlk().economicRank
    return $"{rank} / {brText}"
  }

  let ranks = unit.airsGroup.map(@(un) un.getUnitWpCostBlk().economicRank)
  let minRank = u.min(ranks)
  let maxRank = u.max(ranks)
  let ranksRangeText = minRank == maxRank ? minRank : $"{minRank} - {maxRank}"
  return $"{ranksRangeText} / {brText}"
}

function getUnitDebugRankText(unit) {
  if (unit?.isFakeUnit ?? false)
    return ""
  if (getShopDevMode() == ShopDevModeOption.SHOW_ALL_BATTLE_RATINGS)
    return getUnitAllBattleRatingsText(unit)
  if (getShopDevMode() == ShopDevModeOption.SHOW_ECONOMIC_RANKS)
    return getUnitEconomikRankText(unit)
  return ""
}

return {
  setShopDevMode
  getShopDevMode
  getUnitDebugRankText
  getUnitDebugCostText
  getUnitDebugBattleRatingsText
  getShopDevModeOptions
  ShopDevModeOption
}
