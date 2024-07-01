from "%scripts/dagui_library.nut" import *

let { seasonLevel, todayLoginExp, hasBattlePassReward,
  loginStreak, tomorowLoginExp, levelExp
} = require("%scripts/battlePass/seasonState.nut")
let { mainChallengeOfSeason, hasChallengesReward } = require("%scripts/battlePass/challenges.nut")
let { leftSpecialTasksBoughtCount } = require("%scripts/warbonds/warbondShopState.nut")
let { isUserstatMissingData } = require("%scripts/userstat/userstat.nut")
let { number_of_set_bits } = require("%sqstd/math.nut")
let { isBitModeType } = require("%scripts/unlocks/unlocksConditions.nut")
let { isMediumTaskComplete, isEasyTaskComplete, getCurrentBattleTasks, getBattleTaskDifficultyImage
} = require("%scripts/unlocks/battleTasks.nut")

let seasonLvlWatchObj = [{
  watch = seasonLevel
  updateFunc = function(obj, value) {
    obj.findObject("flag_text").setValue(value.tostring())
  }
},
{
  watch = isUserstatMissingData
  updateFunc = function(obj, value) {
    obj.show(!value)
  }
}]

let levelExpWatchObj = {
  watch = levelExp
  updateFunc = function(obj, value) {
    let { curLevelExp, expForLevel } = value
    let progressValue = (curLevelExp.tofloat() / (expForLevel == 0 ? 1 : expForLevel)) * 1000.0
    local stateObj = obj.findObject("progress_bar")
    if (checkObj(stateObj))
      stateObj.setValue(progressValue)
    stateObj = obj.findObject("progress_text")
    if (checkObj(stateObj))
      stateObj.setValue($"{curLevelExp}{loc("weapons_types/short/separator")}{expForLevel}")
  }
}

let todayLoginExpWatchObj = {
  watch = todayLoginExp
  updateFunc = function(obj, value) {
    obj.findObject("text").setValue(loc("battlePass/info/today_login_exp",
      { expNum = colorize("@goodTextColor", value) }))
  }
}

let loginStreakWatchObj = {
  watch = loginStreak
  updateFunc = function(obj, value) {
    obj.findObject("text").setValue(loc("battlePass/info/login_streak",
      { loginNum = colorize("@goodTextColor", value) }))
  }
}

let tomorowLoginExpWatchObj = {
  watch = tomorowLoginExp
  updateFunc = function(obj, value) {
    obj.findObject("text").setValue(loc("battlePass/info/tomorow_login_exp",
      { expNum = colorize("@goodTextColor", value) }))
  }
}

let easyDailyTaskProgressWatchObj = {
  watch = isEasyTaskComplete
  updateFunc = function(obj, value) {
    let statusText = loc($"battlePass/info/task_status/{value ? "done" : "notDone"}")
    obj.status = value ? "done" : "notDone"
    obj.findObject("text").setValue(loc("battlePass/info/easy_daily_task_progress",
      { status = statusText }))
    let imgObj = obj.findObject("task_img")
    if (imgObj?.isValid())
      imgObj["background-image"] = getBattleTaskDifficultyImage(
        getCurrentBattleTasks().findvalue(@(v) v._puType == "Easy"))
  }
}

let mediumDailyTaskProgressWatchObj = {
  watch = isMediumTaskComplete
  updateFunc = function(obj, value) {
    let statusText = loc($"battlePass/info/task_status/{value ? "done" : "notDone"}")
    obj.status = value ? "done" : "notDone"
    obj.findObject("text").setValue(loc("battlePass/info/medium_daily_task_progress",
      { status = statusText }))
    let imgObj = obj.findObject("task_img")
    if (imgObj?.isValid())
      imgObj["background-image"] = getBattleTaskDifficultyImage(
        getCurrentBattleTasks().findvalue(@(v) v._puType == "Medium"))
  }
}

let seasonTasksProgressWatchObj = {
  watch = mainChallengeOfSeason
  updateFunc = function(obj, challenge) {
    //fixme: there must be a more easy way to get a progress.
    let unlockConfig = challenge ? ::build_conditions_config(challenge) : null
    if (unlockConfig==null)
      return
    local { curVal = 0, maxVal = 0 } = unlockConfig
    let isVisible = maxVal > 0
    obj.show(isVisible)
    if (!isVisible)
      return

    let isBitMode = isBitModeType(unlockConfig.type)
    if (isBitMode) {
      curVal = number_of_set_bits(curVal)
      maxVal = number_of_set_bits(maxVal)
    }

    obj.findObject("progress_bar").setValue(1000.0 * curVal / maxVal)
    obj.findObject("progress_text")
      .setValue($"{curVal}{loc("weapons_types/short/separator")}{maxVal}")
  }
}

let leftSpecialTasksBoughtCountWatchObj = {
  watch = leftSpecialTasksBoughtCount
  updateFunc = function(obj, value) {
    let isVisible = value >= 0
    obj.show(isVisible)
    if (!isVisible)
      return

    obj.findObject("text").setValue(loc("battlePass/info/available_special_tasks",
      { tasksNum = colorize("@goodTextColor", value) }))
    let imgObj = obj.findObject("task_img")
    if (imgObj?.isValid())
      imgObj["background-image"] = getBattleTaskDifficultyImage(
        getCurrentBattleTasks().findvalue(@(v) v._puType == "Hard"))
  }
}

let hasBattlePassRewardWatchObj = {
  watch = hasBattlePassReward
  updateFunc = @(obj, value) obj.show(value)
}

let hasChallengesRewardWatchObj = {
  watch = hasChallengesReward
  updateFunc = @(obj, value) obj.show(value)
}

return {
  seasonLvlWatchObj
  levelExpWatchObj
  todayLoginExpWatchObj
  loginStreakWatchObj
  tomorowLoginExpWatchObj
  easyDailyTaskProgressWatchObj
  mediumDailyTaskProgressWatchObj
  seasonTasksProgressWatchObj
  leftSpecialTasksBoughtCountWatchObj
  hasBattlePassRewardWatchObj
  hasChallengesRewardWatchObj
}
