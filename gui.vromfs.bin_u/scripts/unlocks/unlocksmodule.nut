//checked for plus_string
from "%scripts/dagui_natives.nut" import ps4_is_trophy_unlocked, wp_get_unlock_cost, has_entitlement, req_unlock, get_unlock_type, is_unlocked, wp_get_unlock_cost_gold
from "%scripts/dagui_library.nut" import *
let { Cost } = require("%scripts/money.nut")
let { isPlatformSony, isPlatformXboxOne, isPlatformPC
} = require("%scripts/clientState/platform.nut")
let { number_of_set_bits } = require("%sqstd/math.nut")
let psnUser = require("sony.user")
let { getUnlockConditions, getTimeRangeCondition, isBitModeType
} = require("%scripts/unlocks/unlocksConditions.nut")
let { getTimestampFromStringUtc, daysToSeconds, isInTimerangeByUtcStrings
} = require("%scripts/time.nut")
let { strip, split_by_chars } = require("string")
let { isUnlockReadyToOpen, get_charserver_time_sec } = require("chard")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isInstance, isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { getUnlockTypeById } = require("unlocks")
let { isRegionalUnlock, isRegionalUnlockReadyToOpen, getRegionalUnlockTypeById,
  regionalUnlocks, isRegionalUnlockCompleted
} = require("%scripts/unlocks/regionalUnlocks.nut")
let { Status, get_status } = require("%xboxLib/impl/achievements.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")

let multiStageLocIdConfig = {
  multi_kill_air =    { [2] = "double_kill_air",    [3] = "triple_kill_air",    def = "multi_kill_air" }
  multi_kill_ship =   { [2] = "double_kill_ship",   [3] = "triple_kill_ship",   def = "multi_kill_ship" }
  multi_kill_ground = { [2] = "double_kill_ground", [3] = "triple_kill_ground", def = "multi_kill_ground" }
}

let hasMultiStageLocId = @(unlockId) unlockId in multiStageLocIdConfig

// Has not default multistage id. Used to combine similar unlocks
let function hasSpecialMultiStageLocId(unlockId, repeatInARow) {
  return hasMultiStageLocId(unlockId) && (repeatInARow in multiStageLocIdConfig[unlockId])
}

let function hasSpecialMultiStageLocIdByStage(unlockId, stage) {
  let repeatInARow = stage + (getUnlockById(unlockId)?.stage.param ?? 0)
  return hasSpecialMultiStageLocId(unlockId, repeatInARow)
}

let function getMultiStageLocId(unlockId, repeatInARow) {
  if (!hasMultiStageLocId(unlockId))
    return unlockId

  let config = multiStageLocIdConfig[unlockId]
  return getTblValue(repeatInARow, config) || getTblValue("def", config, unlockId)
}

let getUnlockType = @(unlockId) isRegionalUnlock(unlockId)
  ? getRegionalUnlockTypeById(unlockId)
  : getUnlockTypeById(unlockId)

let function isUnlockOpened(unlockId, unlockType = -1) {
  if (isRegionalUnlock(unlockId))
    return isRegionalUnlockCompleted(unlockId)

  if (!is_unlocked(unlockType, unlockId))
    return false

  if (unlockType == -1)
    unlockType = getUnlockType(unlockId)

  if (isPlatformSony && unlockType == UNLOCKABLE_TROPHY_PSN)
    return ps4_is_trophy_unlocked(unlockId)
  if (isPlatformXboxOne && unlockType == UNLOCKABLE_TROPHY_XBOXONE)
    return (get_status(unlockId) == Status.Achieved)
  return true
}

let function isUnlockComplete(cfg) {
  return isBitModeType(cfg.type)
    ? number_of_set_bits(cfg.curVal) >= number_of_set_bits(cfg.maxVal)
    : cfg.curVal >= cfg.maxVal
}

let function isUnlockExpired(unlockBlk) {
  let timeCond = getTimeRangeCondition(unlockBlk)
  return timeCond && !isEmpty(timeCond.endDate)
    && getTimestampFromStringUtc(timeCond.endDate) <= get_charserver_time_sec()
}

let function canDoUnlock(unlockBlk) {
  if (unlockBlk?.mode == null || isUnlockOpened(unlockBlk.id))
    return false

  let timeCond = getTimeRangeCondition(unlockBlk)
  return !timeCond || isInTimerangeByUtcStrings(timeCond.beginDate, timeCond.endDate)
}

let canClaimUnlockReward = @(unlockId) isRegionalUnlock(unlockId)
  ? isRegionalUnlockReadyToOpen(unlockId)
  : isUnlockReadyToOpen(unlockId)

let function canOpenUnlockManually(unlockBlk) {
  return (unlockBlk?.manualOpen ?? false)
    && !unlockBlk?.hidden
    && canClaimUnlockReward(unlockBlk.id)
}

let function checkDependingUnlocks(unlockBlk) {
  if (!unlockBlk || !unlockBlk?.hideUntilPrevUnlocked)
    return true

  let prevUnlocksArray = split_by_chars(unlockBlk.hideUntilPrevUnlocked, "; ")
  foreach (prevUnlockId in prevUnlocksArray)
    if (!isUnlockOpened(prevUnlockId))
      return false

  return true
}

let function isUnlockVisibleByTime(id, hasIncludTimeBefore = true, resWhenNoTimeLimit = true) {
  let unlock = getUnlockById(id)
  if (!unlock)
    return false

  let hasRangeProp = is_numeric(unlock?.visibleDays)
    || is_numeric(unlock?.visibleDaysBefore)
    || is_numeric(unlock?.visibleDaysAfter)
  if (!hasRangeProp)
    return resWhenNoTimeLimit

  let cond = getTimeRangeCondition(unlock)
  if (!cond)
    return resWhenNoTimeLimit

  let startTime = getTimestampFromStringUtc(cond.beginDate)
    - daysToSeconds(hasIncludTimeBefore ? (unlock?.visibleDaysBefore ?? unlock?.visibleDays ?? 0) : 0)
  let endTime = getTimestampFromStringUtc(cond.endDate)
    + daysToSeconds(unlock?.visibleDaysAfter ?? unlock?.visibleDays ?? 0)
  let currentTime = get_charserver_time_sec()
  return (currentTime > startTime && currentTime < endTime)
}

let function isHiddenByUnlockedUnlocks(unlockBlk) {
  if (isUnlockOpened(unlockBlk?.id))
    return false

  foreach (value in (unlockBlk % "hideWhenUnlocked")) {
    local unlockedCount = 0
    let unlockIds = value.split("; ")
    foreach (id in unlockIds)
      if (isUnlockOpened(id))
        ++unlockedCount

    if (unlockedCount == unlockIds.len())
      return true
  }

  return false
}

let function isUnlockVisibleOnCurPlatform(unlockBlk) {
  if (unlockBlk?.psn && !isPlatformSony)
    return false
  if (unlockBlk?.ps_plus && !psnUser.hasPremium())
    return false
  let excludedPlatformsArray = split_by_chars(unlockBlk?.hide_for_platform ?? "", ";")
  if (excludedPlatformsArray.contains(platformId))
    return false

  let unlockType = get_unlock_type(unlockBlk?.type ?? "")
  if (unlockType == UNLOCKABLE_TROPHY_PSN && !isPlatformSony)
    return false
  if (unlockType == UNLOCKABLE_TROPHY_XBOXONE && !isPlatformXboxOne)
    return false
  if (unlockType == UNLOCKABLE_TROPHY_STEAM && !isPlatformPC)
    return false
  return true
}

let function isUnlockVisible(unlockBlk, needCheckVisibilityByPlatform = true) {
  if (!unlockBlk || unlockBlk?.hidden)
    return false
  if (needCheckVisibilityByPlatform && !isUnlockVisibleOnCurPlatform(unlockBlk))
    return false
  if (!isUnlockVisibleByTime(unlockBlk?.id, true, !unlockBlk?.hideUntilUnlocked)
      && !isUnlockOpened(unlockBlk?.id ?? ""))
    return false
  if (unlockBlk?.showByEntitlement && !has_entitlement(unlockBlk.showByEntitlement))
    return false
  if ((unlockBlk % "hideForLang").indexof(getLanguageName()) != null)
    return false

  foreach (feature in unlockBlk % "reqFeature")
    if (!hasFeature(feature))
      return false

  if (unlockBlk?.mode != null && unlockBlk.mode.blockCount() > 0)
    foreach (cond in getUnlockConditions(unlockBlk.mode))
      if (cond?.type == "playerHasFeature" && cond?.feature != null && !hasFeature(cond.feature))
        return false

  if (!checkDependingUnlocks(unlockBlk))
    return false
  if (isHiddenByUnlockedUnlocks(unlockBlk))
    return false
  if (unlockBlk?.isRegional && (unlockBlk?.id not in regionalUnlocks.value))
    return false

  return true
}

let function debugLogVisibleByTimeInfo(id) {
  let unlock = getUnlockById(id)
  if (!unlock)
    return

  let hasRangeProp = is_numeric(unlock?.visibleDays)
    || is_numeric(unlock?.visibleDaysBefore)
    || is_numeric(unlock?.visibleDaysAfter)
  if (!hasRangeProp)
    return

  let cond = getTimeRangeCondition(unlock)
  if (!cond)
    return

  let startTime = getTimestampFromStringUtc(cond.beginDate)
    - daysToSeconds(unlock?.visibleDaysBefore ?? unlock?.visibleDays ?? 0)
  let endTime = getTimestampFromStringUtc(cond.endDate)
    + daysToSeconds(unlock?.visibleDaysAfter ?? unlock?.visibleDays ?? 0)
  let currentTime = get_charserver_time_sec()
  let isVisibleUnlock = (currentTime > startTime && currentTime < endTime)

  log($"unlock {id} is visible by time ? {isVisibleUnlock}")
  log(", ".concat(
    $"curTime = {currentTime}",
    $"visibleDiapason = {startTime}, {endTime}",
    $"beginDate = {cond.beginDate}, endDate = {cond.endDate}",
    $"visibleDaysBefore = {unlock?.visibleDaysBefore ?? "?"}",
    $"visibleDays = {unlock?.visibleDays ?? "?"}",
    $"visibleDaysAfter = {unlock?.visibleDaysAfter ?? "?"}"
  ))
}

let function getUnlockCost(id) {
  return Cost(::wp_get_unlock_cost(id), wp_get_unlock_cost_gold(id))
}

let function getUnlockRewardCost(unlock) {
  let wpReward = isInstance(unlock?.amount_warpoints)
    ? unlock.amount_warpoints.x.tointeger()
    : unlock.getInt("amount_warpoints", 0)
  let goldReward = isInstance(unlock?.amount_gold)
    ? unlock.amount_gold.x.tointeger()
    : unlock.getInt("amount_gold", 0)
  let xpReward = isInstance(unlock?.amount_exp)
    ? unlock.amount_exp.x.tointeger()
    : unlock.getInt("amount_exp", 0)
  return Cost(wpReward, goldReward, xpReward)
}

let function getUnlockRewardCostByName(unlockName) {
  let unlock = getUnlockById(unlockName)
  return unlock != null
    ? getUnlockRewardCost(unlock)
    : Cost()
}

let function getUnlockRewardText(unlockName) {
  let cost = getUnlockRewardCostByName(unlockName)
  return cost.isZero() ? "" : ::buildRewardText("", cost, true, true)
}

let function checkUnlockString(string) {
  let unlocks = split_by_chars(string, ";")
  foreach (unlockIdSrc in unlocks) {
    local unlockId = strip(unlockIdSrc)
    if (!unlockId.len())
      continue

    local confirmingResult = true
    if (unlockId.len() > 1 && unlockId.slice(0, 1) == "!") {
      confirmingResult = false
      unlockId = unlockId.slice(1)
    }

    if (isUnlockOpened(unlockId) != confirmingResult)
      return false
  }

  return true
}

let function reqUnlockByClient(id, disableLog = false) {
  let unlock = getUnlockById(id)
  let featureName = getTblValue("check_client_feature", unlock, null)
  if (featureName == null || hasFeature(featureName))
    req_unlock(id, disableLog)
}

return {
  canDoUnlock
  canClaimUnlockReward
  canOpenUnlockManually
  isUnlockOpened
  isUnlockComplete
  isUnlockExpired
  isUnlockVisibleOnCurPlatform
  isUnlockVisible
  isUnlockVisibleByTime
  getUnlockType
  getUnlockCost
  getUnlockRewardCost
  getUnlockRewardCostByName
  getUnlockRewardText
  checkUnlockString
  debugLogVisibleByTimeInfo
  multiStageLocIdConfig
  hasMultiStageLocId
  hasSpecialMultiStageLocId
  hasSpecialMultiStageLocIdByStage
  getMultiStageLocId
  reqUnlockByClient
}