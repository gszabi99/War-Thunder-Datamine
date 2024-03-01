from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version

let { g_difficulty } = require("%scripts/difficulty.nut")
let { format } =  require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getShopDiffCode } = require("%scripts/shop/shopDifficulty.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { isUnitGroup } = require("%scripts/unit/unitInfo.nut")
let { getUnitSlotRankText } = require("%scripts/slotbar/slotbarView.nut")

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
    hidden = !is_dev_version()
  }
].filter(@(opt) !opt?.hidden)

function getUnitAllBattleRatingsText(unit) {
  if (isUnitGroup(unit))
    return ""
  return loc("ui/slash").join(g_difficulty.types
    .filter(@(v, _n) v.isAvailable())
    .map(@(v) format("%.1f", unit.getBattleRating(v.getEdiff()))))
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
  getShopDevModeOptions
  ShopDevModeOption
}
