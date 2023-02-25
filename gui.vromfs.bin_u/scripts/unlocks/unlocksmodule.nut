//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { isPlatformSony, isPlatformXboxOne,
  isPlatformPC } = require("%scripts/clientState/platform.nut")
let psnUser = require("sony.user")
let { getUnlockConditions, isTimeRangeCondition } = require("%scripts/unlocks/unlocksConditions.nut")
let { getTimestampFromStringUtc, daysToSeconds } = require("%scripts/time.nut")
let { split_by_chars } = require("string")
let DataBlock = require("DataBlock")
let { charSendBlk } = require("chard")

let function checkDependingUnlocks(unlockBlk) {
  if (!unlockBlk || !unlockBlk?.hideUntilPrevUnlocked)
    return true

  let prevUnlocksArray = split_by_chars(unlockBlk.hideUntilPrevUnlocked, "; ")
  foreach (prevUnlockId in prevUnlocksArray)
    if (!::is_unlocked_scripted(-1, prevUnlockId))
      return false

  return true
}

let function isUnlockVisibleByTime(id, hasIncludTimeBefore = true, resWhenNoTimeLimit = true) {
  let unlock = ::g_unlocks.getUnlockById(id)
  if (!unlock)
    return false

  local isVisibleUnlock = resWhenNoTimeLimit
  if (::is_numeric(unlock?.visibleDays)
      || ::is_numeric(unlock?.visibleDaysBefore)
      || ::is_numeric(unlock?.visibleDaysAfter))
    foreach (cond in getUnlockConditions(unlock?.mode)) {
      if (!isTimeRangeCondition(cond.type))
        continue

      let startTime = getTimestampFromStringUtc(cond.beginDate)
        - daysToSeconds(hasIncludTimeBefore ? (unlock?.visibleDaysBefore ?? unlock?.visibleDays ?? 0) : 0)
      let endTime = getTimestampFromStringUtc(cond.endDate)
        + daysToSeconds(unlock?.visibleDaysAfter ?? unlock?.visibleDays ?? 0)
      let currentTime = ::get_charserver_time_sec()

      isVisibleUnlock = (currentTime > startTime && currentTime < endTime)
      break
    }

  return isVisibleUnlock
}

let function isHiddenByUnlockedUnlocks(unlockBlk) {
  if (::is_unlocked_scripted(-1, unlockBlk?.id))
    return false

  foreach (value in (unlockBlk % "hideWhenUnlocked")) {
    local unlockedCount = 0
    let unlockIds = value.split("; ")
    foreach (id in unlockIds)
      if (::is_unlocked_scripted(-1, id))
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
  if (unlockBlk?.hide_for_platform == platformId)
    return false

  let unlockType = ::get_unlock_type(unlockBlk?.type ?? "")
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
      && !::is_unlocked_scripted(-1, unlockBlk?.id ?? ""))
    return false
  if (unlockBlk?.showByEntitlement && !::has_entitlement(unlockBlk.showByEntitlement))
    return false
  if ((unlockBlk % "hideForLang").indexof(::g_language.getLanguageName()) != null)
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

  return true
}

let function openUnlockManually(unlockId, onSuccess = null) {
  let blk = DataBlock()
  blk.addStr("unlock", unlockId)
  let taskId = charSendBlk("cln_manual_reward_unlock", blk)
  ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess)
}

return {
  isUnlockVisibleOnCurPlatform
  isUnlockVisible
  isUnlockVisibleByTime
  openUnlockManually
}