local { get_time_msec } = require("dagor.time")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")

const STATS_REQUEST_TIMEOUT = 45000
const STATS_UPDATE_INTERVAL = 60000 //unlocks progress update interval
const FREQUENCY_MISSING_STATS_UPDATE_SEC = 300

local function doRequest(request, cb) {
  ::userstat.request(request, @(result) cb(result))
}

local alwaysForceRefreshEvents = {
  LoginComplete = true
}

local function makeUpdatable(persistName, request, defValue, forceRefreshEvents = {}) {
  local data = ::Watched(defValue)
  local lastTime = ::Watched({ request = 0, update = 0 })
  local isRequestInProgress = @() lastTime.value.request > lastTime.value.update
    && lastTime.value.request + STATS_REQUEST_TIMEOUT > get_time_msec()
  local canRefresh = @() !isRequestInProgress()
    && (!lastTime.value.update || (lastTime.value.update + STATS_UPDATE_INTERVAL < get_time_msec()))

  local function processResult(result, cb) {
    if (cb)
      cb(result)

    if (result?.error) {
      data(defValue)
      return
    }
    data(result?.response ?? defValue)
  }

  local function prepareToRequest() {
    lastTime(@(v) v.request = get_time_msec())
  }

  local function refresh(cb = null) {
    if (!::g_login.isLoggedIn()) {
      data.update(defValue)
      if (cb)
        cb({ error = "not logged in" })
      return
    }
    if (!canRefresh())
      return

    prepareToRequest()

    request(function(result){
      processResult(result, cb)
    })
  }

  local function forceRefresh(cb = null) {
    lastTime(@(v) v.__update({ update = 0, request = 0}))
    refresh(cb)
  }

  local function invalidateConfig(p) {
    data(defValue)
    forceRefresh()
  }

  addListenersWithoutEnv(
    alwaysForceRefreshEvents.__merge(forceRefreshEvents).map(@(v) invalidateConfig),
    ::g_listener_priority.CONFIG_VALIDATION
  )

  if (lastTime.value.request >= lastTime.value.update)
    forceRefresh()

  return {
    id = persistName
    data = data
    refresh = refresh
    forceRefresh = forceRefresh
    processResult = processResult
    prepareToRequest = prepareToRequest
    lastUpdateTime = ::Computed(@() lastTime.value.update)
  }
}

local descListUpdatable = makeUpdatable("GetUserStatDescList",
  @(cb) doRequest({
    add_token = true
    headers = {
      appid = ::WT_APPID,
      language = ::g_language.getCurrentSteamLanguage()
    }
    action = "GetUserStatDescList"
  }, cb),
  {},
  { GameLocalizationChanged = true})

local statsUpdatable = makeUpdatable("GetStats",
  @(cb) doRequest({
      add_token = true
      headers = { appid = ::WT_APPID }
      action = "GetStats"
    }, cb),
  {})

local unlocksUpdatable = makeUpdatable("GetUnlocks",
  @(cb) doRequest({
      add_token = true
      headers = { appid = ::WT_APPID }
      action = "GetUnlocks"
    }, cb),
  {})

local function receiveUnlockRewards(unlockName, stage, cb = null, cbError = null, taskOptions = {}) {
  local resultCb = function(result) {
    if (result?.error) {
      if (cbError != null)
        cbError(result.error)
      return
    }
    unlocksUpdatable.processResult(result, cb)
  }

  local blk = ::DataBlock()
  blk.addInt("appid", ::WT_APPID)

  local taskId = ::char_send_custom_action("cln_userstat_grant_rewards",
    ::EATT_JSON_REQUEST, blk,
    ::json_to_string({ unlock = unlockName, stage = stage }, false),
    -1)
  ::g_tasker.addTask(taskId, taskOptions, resultCb, @(result) cbError?(result), TASK_CB_TYPE.REQUEST_DATA)
}

::userstatsDataUpdated <- function userstatsDataUpdated() {
  unlocksUpdatable.forceRefresh()
  statsUpdatable.forceRefresh()
}

local userstatUnlocks = unlocksUpdatable.data
local userstatDescList = descListUpdatable.data
local userstatStats = statsUpdatable.data

local isUserstatMissingData = ::Computed(@() userstatUnlocks.value.len() == 0
  || userstatDescList.value.len() == 0
  || userstatStats.value.len() == 0)

local canUpdateUserstat = @() ::g_login.isLoggedIn() && !::is_in_flight() && ::has_feature("BattlePass") // userstat used only for battle pass.

local validateTaskTimer = -1
local function validateUserstatData(dt = 0) {
  if ( validateTaskTimer >= 0 ) {
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

isUserstatMissingData.subscribe(function(v) {
  validateUserstatData()
})

addListenersWithoutEnv({
  ProfileUpdated = @(p) validateUserstatData()
  BattleEnded    = @(p) validateUserstatData()
})

return {
  userstatUnlocks
  userstatDescList
  userstatStats
  refreshUserstatUnlocks = @() unlocksUpdatable.forceRefresh()
  refreshUserstatStats = @() statsUpdatable.forceRefresh()
  receiveUnlockRewards
  isUserstatMissingData
  validateUserstatData
}
