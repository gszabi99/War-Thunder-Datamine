//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this
let userstat = require("userstat")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { APP_ID } = require("app")
let { APP_ID_CUSTOM_LEADERBOARD
} = require("%scripts/leaderboard/requestLeaderboardData.nut")
let DataBlock = require("DataBlock")
let { json_to_string } = require("json")

const STATS_REQUEST_TIMEOUT = 45000
const STATS_UPDATE_INTERVAL = 60000 //unlocks progress update interval
const FREQUENCY_MISSING_STATS_UPDATE_SEC = 300

let function makeUpdatable(persistName, request, defValue, forceRefreshEvents = {}) {
  let data = Watched(defValue)
  let lastTime = Watched({ request = 0, update = 0 })
  let isRequestInProgress = @() lastTime.value.request > lastTime.value.update
    && lastTime.value.request + STATS_REQUEST_TIMEOUT > get_time_msec()
  let canRefresh = @() !isRequestInProgress()
    && (!lastTime.value.update || (lastTime.value.update + STATS_UPDATE_INTERVAL < get_time_msec()))

  let function processResult(result, cb) {
    if (cb)
      cb(result)

    if (result?.error) {
      data(defValue)
      return
    }
    data(result?.response ?? defValue)
  }

  let function prepareToRequest() {
    lastTime.mutate(@(v) v.request = get_time_msec())
  }

  let function refresh(cb = null) {
    if (!::g_login.isLoggedIn()) {
      data.update(defValue)
      if (cb)
        cb({ error = "not logged in" })
      return
    }
    if (!canRefresh())
      return

    prepareToRequest()

    request(function(result) {
      processResult(result, cb)
    })
  }

  let function forceRefresh(cb = null) {
    lastTime.mutate(@(v) v.__update({ update = 0, request = 0 }))
    refresh(cb)
  }

  let function invalidateConfig(_p) {
    data(defValue)
    forceRefresh()
  }

  addListenersWithoutEnv(forceRefreshEvents.map(@(_v) invalidateConfig),
    ::g_listener_priority.CONFIG_VALIDATION)

  if (lastTime.value.request >= lastTime.value.update)
    forceRefresh()

  return {
    id = persistName
    data = data
    refresh = refresh
    forceRefresh = forceRefresh
    processResult = processResult
    prepareToRequest = prepareToRequest
    lastUpdateTime = Computed(@() lastTime.value.update)
  }
}

let descListUpdatable = makeUpdatable("GetUserStatDescList",
  @(cb) userstat.request({
    add_token = true
    headers = {
      appid = APP_ID,
      language = ::g_language.getCurrentSteamLanguage()
    }
    action = "GetUserStatDescList"
  }, cb),
  {},
  { GameLocalizationChanged = true, LoginComplete = true })

let statsUpdatable = makeUpdatable("GetStats",
  @(cb) userstat.request({
      add_token = true
      headers = { appid = APP_ID }
      action = "GetStats"
    }, cb),
  {},
  { LoginComplete = true })

let unlocksUpdatable = makeUpdatable("GetUnlocks",
  @(cb) userstat.request({
      add_token = true
      headers = { appid = APP_ID }
      action = "GetUnlocks"
    }, cb),
  {},
  { LoginComplete = true })

let customLeaderboardStatsUpdatable = makeUpdatable("GetCustomLeaderboardStats",
  @(cb) userstat.request({
      add_token = true
      headers = { appid = APP_ID_CUSTOM_LEADERBOARD }
      action = "GetStats"
    }, cb),
  {})

let function receiveUnlockRewards(unlockName, stage, cb = null, cbError = null, taskOptions = {}) {
  let resultCb = function(result) {
    if (result?.error) {
      if (cbError != null)
        cbError(result.error)
      return
    }
    unlocksUpdatable.processResult(result, cb)
  }

  let blk = DataBlock()
  blk.addInt("appid", APP_ID)

  let taskId = ::char_send_custom_action("cln_userstat_grant_rewards",
    EATT_JSON_REQUEST, blk,
    json_to_string({ unlock = unlockName, stage }, false),
    -1)
  ::g_tasker.addTask(taskId, taskOptions, resultCb, @(result) cbError?(result), TASK_CB_TYPE.REQUEST_DATA)
}

::userstatsDataUpdated <- function userstatsDataUpdated() {
  unlocksUpdatable.forceRefresh()
  statsUpdatable.forceRefresh()
}

let userstatUnlocks = unlocksUpdatable.data
let userstatDescList = descListUpdatable.data
let userstatStats = statsUpdatable.data

let isUserstatMissingData = Computed(@() userstatUnlocks.value.len() == 0
  || userstatDescList.value.len() == 0
  || userstatStats.value.len() == 0)

let canUpdateUserstat = @() ::g_login.isLoggedIn() && !::is_in_flight() && hasFeature("BattlePass") // userstat used only for battle pass.

local validateTaskTimer = -1
let function validateUserstatData(_dt = 0) {
  if (validateTaskTimer >= 0) {
    ::periodic_task_unregister(validateTaskTimer)
    validateTaskTimer = -1
  }

  if (!canUpdateUserstat() || !isUserstatMissingData.value)
    return

  if (unlocksUpdatable.data.value.len() == 0)
    unlocksUpdatable.refresh()
  if (descListUpdatable.data.value.len() == 0)
    descListUpdatable.refresh()
  if (statsUpdatable.data.value.len() == 0)
    statsUpdatable.refresh()

  validateTaskTimer = ::periodic_task_register(this,
    validateUserstatData, FREQUENCY_MISSING_STATS_UPDATE_SEC)
}

isUserstatMissingData.subscribe(function(_v) {
  validateUserstatData()
})

addListenersWithoutEnv({
  ProfileUpdated = @(_p) validateUserstatData()
  BattleEnded    = @(_p) validateUserstatData()
})

let userstatCustomLeaderboardStats = customLeaderboardStatsUpdatable.data
userstatCustomLeaderboardStats.subscribe(
  @(_) broadcastEvent("UserstatCustomLeaderboardStats"))

return {
  userstatUnlocks
  userstatDescList
  userstatStats
  refreshUserstatUnlocks = @() unlocksUpdatable.forceRefresh()
  refreshUserstatDescList = @() descListUpdatable.forceRefresh()
  refreshUserstatStats = @() statsUpdatable.forceRefresh()
  receiveUnlockRewards
  isUserstatMissingData
  validateUserstatData
  userstatCustomLeaderboardStats
  refreshUserstatCustomLeaderboardStats = @() customLeaderboardStatsUpdatable.refresh()
}
