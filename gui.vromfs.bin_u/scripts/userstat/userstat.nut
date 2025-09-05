from "%scripts/dagui_natives.nut" import char_send_custom_action, periodic_task_unregister, periodic_task_register
from "%scripts/dagui_library.nut" import *

let { eventbus_subscribe } = require("eventbus")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let userstat = require("userstat")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { APP_ID } = require("app")
let { APP_ID_CUSTOM_LEADERBOARD
} = require("%scripts/leaderboard/requestLeaderboardData.nut")
let DataBlock = require("DataBlock")
let { object_to_json_string } = require("json")
let { TASK_CB_TYPE, addTask } = require("%scripts/tasker.nut")
let { isInFlight } = require("gameplayBinding")
let { getCurrentSteamLanguage } = require("%scripts/langUtils/language.nut")
let { mnSubscribe } = require("%scripts/matching/serviceNotifications/mrpc.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

const STATS_REQUEST_TIMEOUT = 45000
const STATS_UPDATE_INTERVAL = 60000 
const FREQUENCY_MISSING_STATS_UPDATE_SEC = 300

function updateGetUnlocksValue(watchValue, response) {
  foreach (key, value in response) {
    if (key not in watchValue) {
      watchValue[key] <- value
      continue
    }
    if (type(value) == "table")
      watchValue[key].__update(value)
    else
      watchValue[key] = value
  }
}

function makeUpdatable(persistName, request, defValue, forceRefreshEvents = {}) {
  let data = Watched(clone defValue)
  let lastTime = Watched({ request = 0, update = 0 })
  let isRequestInProgress = @() lastTime.get().request > lastTime.get().update
    && lastTime.get().request + STATS_REQUEST_TIMEOUT > get_time_msec()
  let canRefresh = @() !isRequestInProgress()
    && (!lastTime.get().update || (lastTime.get().update + STATS_UPDATE_INTERVAL < get_time_msec()))

  function processResult(result, cb) {
    if (cb)
      cb(result)

    if (result?.error) {
      data.set(clone defValue)
      return
    }

    if (persistName == "GetUnlocks") { 
      let { response = {} } = result
      if (response.len() > 0)
        data.mutate(@(v) updateGetUnlocksValue(v, response))
    }
    else
      data.set(result?.response ?? (clone defValue))
  }

  function prepareToRequest() {
    lastTime.mutate(@(v) v.request = get_time_msec())
  }

  function refresh(cb = null) {
    if (!isLoggedIn.get()) {
      data.set(clone defValue)
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

  function forceRefresh(cb = null) {
    lastTime.mutate(@(v) v.__update({ update = 0, request = 0 }))
    refresh(cb)
  }

  function invalidateConfig(_p) {
    data.set(clone defValue)
    forceRefresh()
  }

  addListenersWithoutEnv(forceRefreshEvents.map(@(_v) invalidateConfig),
    g_listener_priority.CONFIG_VALIDATION)

  if (lastTime.get().request >= lastTime.get().update)
    forceRefresh()

  return {
    id = persistName
    data = data
    refresh = refresh
    forceRefresh = forceRefresh
    processResult = processResult
    prepareToRequest = prepareToRequest
    lastUpdateTime = Computed(@() lastTime.get().update)
  }
}

let descListUpdatable = makeUpdatable("GetUserStatDescList",
  @(cb) userstat.request({
    add_token = true
    headers = {
      appid = APP_ID,
      language = getCurrentSteamLanguage()
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

local unlocksUpdatable
unlocksUpdatable = makeUpdatable("GetUnlocks",
  function(cb) {
    let unlocksData = unlocksUpdatable?.data.get()
    let changedSince = (unlocksData?.len() ?? 0) == 0 ? -1 : (unlocksData?.timestamp ?? -1)
    userstat.request({
      add_token = true
      headers = { appid = APP_ID }.__update(changedSince == -1 ? {} : { changedSince })
      action = "GetUnlocks"
    }, cb)
  },
  {},
  { LoginComplete = true })

let customLeaderboardStatsUpdatable = makeUpdatable("GetCustomLeaderboardStats",
  @(cb) userstat.request({
      add_token = true
      headers = { appid = APP_ID_CUSTOM_LEADERBOARD }
      action = "GetStats"
    }, cb),
  {})

function receiveUnlockRewards(unlockName, stage, cb = null, cbError = null, taskOptions = {}) {
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

  let taskId = char_send_custom_action("cln_userstat_grant_rewards",
    EATT_JSON_REQUEST, blk,
    object_to_json_string({ unlock = unlockName, stage }, false),
    -1)
  addTask(taskId, taskOptions, resultCb, @(result) cbError?(result), TASK_CB_TYPE.REQUEST_DATA)
}

function userstatsDataUpdated() {
  unlocksUpdatable.forceRefresh()
  statsUpdatable.forceRefresh()
}

let userstatUnlocks = unlocksUpdatable.data
let userstatDescList = descListUpdatable.data
let userstatStats = statsUpdatable.data

let isUserstatMissingData = Computed(@() userstatUnlocks.value.len() == 0
  || userstatDescList.value.len() == 0
  || userstatStats.value.len() == 0)

let canUpdateUserstat = @() isLoggedIn.get() && !isInFlight()

local validateTaskTimer = -1
function validateUserstatData(_dt = 0) {
  if (validateTaskTimer >= 0) {
    periodic_task_unregister(validateTaskTimer)
    validateTaskTimer = -1
  }

  if (!canUpdateUserstat() || !isUserstatMissingData.get())
    return

  if (unlocksUpdatable.data.get().len() == 0)
    unlocksUpdatable.refresh()
  if (descListUpdatable.data.get().len() == 0)
    descListUpdatable.refresh()
  if (statsUpdatable.data.get().len() == 0)
    statsUpdatable.refresh()

  validateTaskTimer = periodic_task_register(this,
    validateUserstatData, FREQUENCY_MISSING_STATS_UPDATE_SEC)
}

isUserstatMissingData.subscribe(function(_v) {
  validateUserstatData()
})

addListenersWithoutEnv({
  ProfileUpdated  = @(_p) validateUserstatData()
  BattleEnded     = @(_p) validateUserstatData()
  ScriptsReloaded = @(_p) validateUserstatData()
})

let userstatCustomLeaderboardStats = customLeaderboardStatsUpdatable.data
userstatCustomLeaderboardStats.subscribe(
  @(_) broadcastEvent("UserstatCustomLeaderboardStats"))

mnSubscribe("userStat", function(ev) {
  if (ev?.func == "changed")
    unlocksUpdatable.forceRefresh()
})

eventbus_subscribe("userstatsDataUpdated", @(_p) userstatsDataUpdated())

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
