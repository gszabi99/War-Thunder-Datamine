from "%scripts/dagui_natives.nut" import wp_get_unlock_cost, has_entitlement, req_unlock, get_unlock_type, is_unlocked, wp_get_unlock_cost_gold
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType
let { Cost } = require("%scripts/money.nut")
let { isPlatformSony, isPlatformXboxOne, isPlatformPC
} = require("%scripts/clientState/platform.nut")
let { number_of_set_bits } = require("%sqstd/math.nut")
let psnUser = require("sony.user")
let { getUnlockConditions, getTimeRangeCondition, isBitModeType
} = require("%scripts/unlocks/unlocksConditions.nut")
let { getTimestampFromStringUtc, daysToSeconds, isInTimerangeByUtcStrings
} = require("%scripts/time.nut")
let { strip, split_by_chars, format } = require("string")
let { isUnlockReadyToOpen, get_charserver_time_sec } = require("chard")
let { getUnlockById, getAllUnlocksWithBlkOrder, getAllUnlocks
} = require("%scripts/unlocks/unlocksCache.nut")
let { isInstance, isEmpty } = require("%sqStdLibs/helpers/u.nut")
let { getUnlockTypeById } = require("unlocks")
let { isRegionalUnlock, isRegionalUnlockReadyToOpen, getRegionalUnlockTypeById,
  regionalUnlocks, isRegionalUnlockCompleted
} = require("%scripts/unlocks/regionalUnlocks.nut")
let { Status, get_status } = require("%xboxLib/impl/achievements.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { isPsnTrophyUnlocked, getPsnTrophyIdByName } = require("sony.trophies")

let multiStageLocIdConfig = {
  multi_kill_air =    { [2] = "double_kill_air",    [3] = "triple_kill_air",    def = "multi_kill_air" }
  multi_kill_ship =   { [2] = "double_kill_ship",   [3] = "triple_kill_ship",   def = "multi_kill_ship" }
  multi_kill_ground = { [2] = "double_kill_ground", [3] = "triple_kill_ground", def = "multi_kill_ground" }
}

let hasMultiStageLocId = @(unlockId) unlockId in multiStageLocIdConfig

// Has not default multistage id. Used to combine similar unlocks
function hasSpecialMultiStageLocId(unlockId, repeatInARow) {
  return hasMultiStageLocId(unlockId) && (repeatInARow in multiStageLocIdConfig[unlockId])
}

function hasSpecialMultiStageLocIdByStage(unlockId, stage) {
  let repeatInARow = stage + (getUnlockById(unlockId)?.stage.param ?? 0)
  return hasSpecialMultiStageLocId(unlockId, repeatInARow)
}

function getMultiStageLocId(unlockId, repeatInARow) {
  if (!hasMultiStageLocId(unlockId))
    return unlockId

  let config = multiStageLocIdConfig[unlockId]
  return getTblValue(repeatInARow, config) || getTblValue("def", config, unlockId)
}

let getUnlockType = @(unlockId) isRegionalUnlock(unlockId)
  ? getRegionalUnlockTypeById(unlockId)
  : getUnlockTypeById(unlockId)

function isUnlockExist(unlockId) {
  return isRegionalUnlock(unlockId) || (getUnlockType(unlockId) != UNLOCKABLE_UNKNOWN)
}

function isUnlockOpened(unlockId, unlockType = -1) {
  if (isRegionalUnlock(unlockId))
    return isRegionalUnlockCompleted(unlockId)

  if (!is_unlocked(unlockType, unlockId))
    return false

  if (unlockType == -1)
    unlockType = getUnlockType(unlockId)

  if (isPlatformSony && unlockType == UNLOCKABLE_TROPHY_PSN)
    return isPsnTrophyUnlocked(getPsnTrophyIdByName(unlockId))
  if (isPlatformXboxOne && unlockType == UNLOCKABLE_TROPHY_XBOXONE)
    return (get_status(unlockId) == Status.Achieved)
  return true
}

function isUnlockComplete(cfg) {
  return isBitModeType(cfg.type)
    ? number_of_set_bits(cfg.curVal) >= number_of_set_bits(cfg.maxVal)
    : cfg.curVal >= cfg.maxVal
}

function isUnlockExpired(unlockBlk) {
  let timeCond = getTimeRangeCondition(unlockBlk)
  return timeCond && !isEmpty(timeCond.endDate)
    && getTimestampFromStringUtc(timeCond.endDate) <= get_charserver_time_sec()
}

function canDoUnlock(unlockBlk) {
  if (unlockBlk?.mode == null || isUnlockOpened(unlockBlk.id))
    return false

  let timeCond = getTimeRangeCondition(unlockBlk)
  return !timeCond || isInTimerangeByUtcStrings(timeCond.beginDate, timeCond.endDate)
}

let canClaimUnlockReward = @(unlockId) isRegionalUnlock(unlockId)
  ? isRegionalUnlockReadyToOpen(unlockId)
  : isUnlockReadyToOpen(unlockId)

function canOpenUnlockManually(unlockBlk) {
  return (unlockBlk?.manualOpen ?? false)
    && !unlockBlk?.hidden
    && canClaimUnlockReward(unlockBlk.id)
}

function findUnusableUnitForManualUnlock(unlockId) {
  let unlockBlk = getUnlockById(unlockId)
  if (!unlockBlk)
    return null

  if (!unlockBlk?.userLogId)
    return null

  let item = ::ItemsManager.findItemById(unlockBlk.userLogId)
  if (item?.iType != itemType.TROPHY)
    return null

  let content = item.getContent()
  if (content.len() == 0)
    return null

  foreach (prize in content) {
    if (("modification" not in prize) || ("forUnit" not in prize))
      continue

    let unit = getAircraftByName(prize.forUnit)
    if (!unit || !unit.isUsable())
      return unit
  }

  return null
}

let canClaimUnlockRewardForUnit = @(unlockId) findUnusableUnitForManualUnlock(unlockId) == null

function checkDependingUnlocks(unlockBlk) {
  if (!unlockBlk || !unlockBlk?.hideUntilPrevUnlocked)
    return true

  let prevUnlocksArray = split_by_chars(unlockBlk.hideUntilPrevUnlocked, "; ")
  foreach (prevUnlockId in prevUnlocksArray)
    if (!isUnlockOpened(prevUnlockId))
      return false

  return true
}

function isUnlockVisibleByTime(id, hasIncludTimeBefore = true, resWhenNoTimeLimit = true) {
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

function isHiddenByUnlockedUnlocks(unlockBlk) {
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

function isUnlockVisibleOnCurPlatform(unlockBlk) {
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

function isUnlockVisible(unlockBlk, needCheckVisibilityByPlatform = true) {
  if (!unlockBlk || unlockBlk?.hidden)
    return false

  if (unlockBlk?.hideFeature != null && hasFeature(unlockBlk.hideFeature))
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

function debugLogVisibleByTimeInfo(id) {
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

function getUnlockCost(id) {
  return Cost(wp_get_unlock_cost(id), wp_get_unlock_cost_gold(id))
}

function getUnlockRewardCost(unlock) {
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

function getUnlockRewardCostByName(unlockName) {
  let unlock = getUnlockById(unlockName)
  return unlock != null
    ? getUnlockRewardCost(unlock)
    : Cost()
}

function getUnlockRewardText(unlockName) {
  let cost = getUnlockRewardCostByName(unlockName)
  return cost.isZero() ? "" : ::buildRewardText("", cost, true, true)
}

function checkUnlockString(string) {
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

function reqUnlockByClient(id, disableLog = false) {
  let unlock = getUnlockById(id)
  let featureName = getTblValue("check_client_feature", unlock, null)
  if (featureName == null || hasFeature(featureName))
    req_unlock(id, disableLog)
}

let defaultUnlockData = {
  id = ""
  type = -1
  title = ""
  name = ""
  image = "#ui/gameuiskin#unlocked.svg"
  image2 = ""
  rewardText = ""
  wp = 0
  gold = 0
  rp = 0
  frp = 0
  exp = 0
  amount = 1 //for multiple awards such as streaks x3, x4...
  aircraft = []
  stage = -1
  desc = ""
  link = ""
  forceExternalBrowser = false
}

let cloneDefaultUnlockData = @() clone defaultUnlockData

function getFakeUnlockData(config) {
  let res = {}
  foreach (key, value in defaultUnlockData)
    res[key] <- (key in config) ? config[key] : value
  foreach (key, value in config)
    if (!(key in res))
      res[key] <- value
  return res
}

let showNextAwardModeTypes = { // modeTypeName = localizationId
  char_versus_battles_end_count_and_rank_test = "battle_participate_award"
  char_login_count                            = "day_login_award"
}

function checkAwardsAmountPeerSession(res, config, streak, name) {
  local maxStreak = streak

  res.similarAwardNamesList <- {}
  foreach (simAward in config.similarAwards) {
    let simUnlock = getUnlockById(simAward.unlockId)
    let simStreak = simUnlock.stage.param.tointeger() + simAward.stage
    maxStreak = max(simStreak, maxStreak)
    let simAwName = format(name, simStreak)
    if (simAwName in res.similarAwardNamesList)
      res.similarAwardNamesList[simAwName]++
    else
      res.similarAwardNamesList[simAwName] <- 1
  }

  let mainAwName = format(name, streak)
  if (mainAwName in res.similarAwardNamesList)
    res.similarAwardNamesList[mainAwName]++
  else
    res.similarAwardNamesList[mainAwName] <- 1
  res.similarAwardNamesList.maxStreak <- maxStreak
}

function getNextAwardText(unlockId) {
  local res = ""
  if (!hasFeature("ShowNextUnlockInfo"))
    return res

  let unlockBlk = getUnlockById(unlockId)
  if (!unlockBlk)
    return res

  local modeType = null
  local num = 0
  foreach (mode in unlockBlk % "mode") {
    let mType = mode.getStr("type", "")
    if (mType in showNextAwardModeTypes) {
      modeType = mType
      num = mode.getInt("num", 0)
      break
    }
    if (mType == "char_unlocks") { //for unlocks unlocked by other unlock
      foreach (uId in mode % "unlock") {
        res = getNextAwardText(uId)
        if (res != "")
          return res
      }
      break
    }
  }
  if (!modeType)
    return res

  local nextUnlock = null
  local nextStage = -1
  local nextNum = -1
  foreach (cb in getAllUnlocksWithBlkOrder())
    if (!cb.hidden || (cb.type && get_unlock_type(cb.type) == UNLOCKABLE_AUTOCOUNTRY))
      foreach (modeIdx, mode in cb % "mode")
        if (mode.getStr("type", "") == modeType) {
          let n = mode.getInt("num", 0)
          if (n > num && (!nextUnlock || n < nextNum)) {
            nextUnlock = cb
            nextNum = n
            nextStage = modeIdx
            break
          }
        }
  if (!nextUnlock)
    return res

  let { name, rewardText } = ::build_log_unlock_data({ id = nextUnlock.id, stage = nextStage })
  res = loc("next_award", { awardName = name })
  if (rewardText != "") {
      let amount = nextNum - num
      let locId = "/".concat(
        showNextAwardModeTypes[modeType],
        (amount == 1) ? "one_more" : "several")
      res = $"{res}{"\n".concat(loc("ui/colon"), loc(locId, { amount, reward = rewardText }))}"
  }
  return res
}

function combineSimilarAwards(awardsList) {
  let res = []

  foreach (award in awardsList) {
    local found = false
    if ("unlockType" in award && award.unlockType == UNLOCKABLE_STREAK) {
      let unlockId = award.unlockId
      let isMultiStageLoc = hasMultiStageLocId(unlockId)
      let stage = getTblValue("stage", award, 0)
      let hasSpecialMultiStageLoc = hasSpecialMultiStageLocIdByStage(unlockId, stage)
      foreach (approvedAward in res) {
        if (unlockId != approvedAward.unlockId)
          continue
        if (isMultiStageLoc) {
          let approvedStage = getTblValue("stage", approvedAward, 0)
          if (stage != approvedStage
              && (hasSpecialMultiStageLoc || hasSpecialMultiStageLocIdByStage(unlockId, approvedStage)))
            continue
        }
        approvedAward.amount++
        approvedAward.similarAwards.append(award)
        foreach (name in ["wp", "exp", "gold"])
          if (name in approvedAward && name in award)
            approvedAward[name] += award[name]
        found = true
        break
      }
    }

    if (found)
      continue

    res.append(award)
    let tbl = res.top()
    tbl.amount <- 1
    tbl.similarAwards <- []
  }

  return res
}

function isAnyAwardReceivedByModeType(modeType) {
  foreach (cb in getAllUnlocks()) {
    let { mode = null } = cb
    if (mode != null && mode.type == modeType && cb.id && isUnlockOpened(cb.id))
      return true
  }
  return false
}

return {
  canDoUnlock
  canClaimUnlockReward
  findUnusableUnitForManualUnlock
  canClaimUnlockRewardForUnit
  canOpenUnlockManually
  isUnlockOpened
  isUnlockComplete
  isUnlockExpired
  isUnlockVisibleOnCurPlatform
  isUnlockVisible
  isUnlockVisibleByTime
  isUnlockExist
  getUnlockType
  getUnlockCost
  getUnlockRewardCost
  getUnlockRewardCostByName
  getUnlockRewardText
  getFakeUnlockData
  cloneDefaultUnlockData
  checkUnlockString
  debugLogVisibleByTimeInfo
  multiStageLocIdConfig
  hasMultiStageLocId
  hasSpecialMultiStageLocId
  hasSpecialMultiStageLocIdByStage
  getMultiStageLocId
  reqUnlockByClient
  isAnyAwardReceivedByModeType
  checkAwardsAmountPeerSession
  getNextAwardText
  combineSimilarAwards
}