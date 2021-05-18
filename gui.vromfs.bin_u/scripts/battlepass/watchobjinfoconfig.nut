local { seasonLevel, todayLoginExp, hasBattlePassReward,
  loginStreak, tomorowLoginExp, levelExp
} = require("scripts/battlePass/seasonState.nut")
local { mainChallengeOfSeason, hasChallengesReward } = require("scripts/battlePass/challenges.nut")
local { leftSpecialTasksBoughtCount } = require("scripts/warbonds/warbondShopState.nut")
local { isUserstatMissingData } = require("scripts/userstat/userstat.nut")

local seasonLvlWatchObj = [{
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

local levelExpWatchObj = {
  watch = levelExp
  updateFunc = function(obj, value) {
    local { curLevelExp, expForLevel } = value
    local progressValue = (curLevelExp.tofloat() / (expForLevel == 0 ? 1 : expForLevel)) * 1000.0
    local stateObj = obj.findObject("progress_bar")
    if (::check_obj(stateObj))
      stateObj.setValue(progressValue)
    stateObj = obj.findObject("progress_text")
    if (::check_obj(stateObj))
      stateObj.setValue($"{curLevelExp}{::loc("weapons_types/short/separator")}{expForLevel}")
  }
}

local todayLoginExpWatchObj = {
  watch = todayLoginExp
  updateFunc = function(obj, value) {
    obj.findObject("text").setValue(::loc("battlePass/info/today_login_exp",
      { expNum = ::colorize("@goodTextColor", value) }))
  }
}

local loginStreakWatchObj = {
  watch = loginStreak
  updateFunc = function(obj, value) {
    obj.findObject("text").setValue(::loc("battlePass/info/login_streak",
      { loginNum = ::colorize("@goodTextColor", value) }))
  }
}

local tomorowLoginExpWatchObj = {
  watch = tomorowLoginExp
  updateFunc = function(obj, value) {
    obj.findObject("text").setValue(::loc("battlePass/info/tomorow_login_exp",
      { expNum = ::colorize("@goodTextColor", value) }))
  }
}

local easyDailyTaskProgressWatchObj = {
  watch = ::g_battle_tasks.isCompleteEasyTask
  updateFunc = function(obj, value) {
    local statusText = ::loc($"battlePass/info/task_status/{value ? "done" : "notDone"}")
    obj.status = value ? "done" : "notDone"
    obj.findObject("text").setValue(::loc("battlePass/info/easy_daily_task_progress",
      { status = statusText }))
    local imgObj = obj.findObject("task_img")
    if (imgObj?.isValid())
      imgObj["background-image"] = ::g_battle_tasks.getDifficultyImage(
        ::g_battle_tasks.currentTasksArray.findvalue(@(v) v._puType == "Easy"))
  }
}

local mediumDailyTaskProgressWatchObj = {
  watch = ::g_battle_tasks.isCompleteMediumTask
  updateFunc = function(obj, value) {
    local statusText = ::loc($"battlePass/info/task_status/{value ? "done" : "notDone"}")
    obj.status = value ? "done" : "notDone"
    obj.findObject("text").setValue(::loc("battlePass/info/medium_daily_task_progress",
      { status = statusText }))
    local imgObj = obj.findObject("task_img")
    if (imgObj?.isValid())
      imgObj["background-image"] = ::g_battle_tasks.getDifficultyImage(
        ::g_battle_tasks.currentTasksArray.findvalue(@(v) v._puType == "Medium"))
  }
}

local seasonTasksProgressWatchObj = {
  watch = mainChallengeOfSeason
  updateFunc = function(obj, challenge) {
    local unlockConfig = null
    if (challenge) { //fixme: there must be a more easy way to get a progress.
      unlockConfig = ::build_conditions_config(challenge)
      ::build_unlock_desc(unlockConfig)
    }
    local { curVal = 0, maxVal = 0 } = unlockConfig
    local isVisible = maxVal > 0
    obj.show(isVisible)
    if (!isVisible)
      return

    obj.findObject("progress_bar").setValue(1000.0 * curVal / maxVal)
    obj.findObject("progress_text")
      .setValue($"{curVal}{::loc("weapons_types/short/separator")}{maxVal}")
  }
}

local leftSpecialTasksBoughtCountWatchObj = {
  watch = leftSpecialTasksBoughtCount
  updateFunc = function(obj, value) {
    local isVisible = value >= 0
    obj.show(isVisible)
    if (!isVisible)
      return

    obj.findObject("text").setValue(::loc("battlePass/info/available_special_tasks",
      { tasksNum = ::colorize("@goodTextColor", value) }))
    local imgObj = obj.findObject("task_img")
    if (imgObj?.isValid())
      imgObj["background-image"] = ::g_battle_tasks.getDifficultyImage(
        ::g_battle_tasks.currentTasksArray.findvalue(@(v) v._puType == "Hard"))
  }
}

local hasBattlePassRewardWatchObj = {
  watch = hasBattlePassReward
  updateFunc = @(obj, value) obj.show(value)
}

local hasChallengesRewardWatchObj = {
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
