from "%scripts/dagui_library.nut" import *
let { APP_ID } = require("app")
let { eventbus_subscribe } = require("eventbus")
let { get_time_msec } = require("dagor.time")
let { resetTimeout, defer } = require("dagor.workcycle")
let { httpRequest, HTTP_SUCCESS } = require("dagor.http")
let { object_to_json_string } = require("json")
let { getPlayerTokenGlobal } = require("auth_wt")
let { get_cur_circuit_block } = require("blkGetters")
let logBQ = log_with_prefix("[BQ] ")
let { hardPersistWatched } = require("%sqstd/globalState.nut")
let { shuffle } = require("%sqStdLibs/helpers/u.nut")
let DataBlock = require("DataBlock")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_charserver_time_sec } = require("chard")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { isMatchingOnline } = require("%scripts/clientState/clientStates.nut")

const MAX_TIME_STAMP_VALUE_SEC = 2145916800 
const MIN_TIME_BETWEEN_MSEC = 5000 
const RETRY_MSEC = 30000 
const RETRY_ON_URL_ERROR_MSEC = 3000
const MAX_COUNT_MSG_IN_ONE_SEND = 150
const RESPONSE_EVENT = "bq.requestResponse"
let queueByUserId = hardPersistWatched("bqQueue.queueByUserId", {})
let queue = Computed(@() queueByUserId.get()?[userIdStr.get()] ?? [])
let nextCanSendMsec = hardPersistWatched("bqQueue.nextCanSendMsec", -1)
let currentUrlIndex = hardPersistWatched("bqQueue.currentUrlIndex", 0)

let urls = Watched([])
let url = Computed(@() urls.get()?[currentUrlIndex.get()] ?? urls.get()?[0])

function getValidServerTime() {
  let serverTime = get_charserver_time_sec()
  if (serverTime < 0 || serverTime > MAX_TIME_STAMP_VALUE_SEC)
    return 0
  return serverTime
}

function initUrl() {
  urls.set(shuffle((get_cur_circuit_block() ?? DataBlock()) % "charServer"))
  currentUrlIndex.set(0)
}

initUrl()

function changeUrl() {
  currentUrlIndex.set((currentUrlIndex.get() + 1) % max(urls.get().len(), 1))
}

function sendAll() {
  if (queue.get().len() == 0)
    return

  if(!isLoggedIn.get() || !isMatchingOnline.get())
    return

  let list = {}
  let remainingMsg = []
  let sendedMsg = []
  local count = 0
  foreach(msg in queue.get()) {
    let { tableId = null, data = null } = msg
    if (type(tableId) != "string" || type(data) != "table") {
      logerr($"[BQ] Bad type of tableId or data for event: tableId = {tableId}, type of data = {type(data)}")
      continue
    }
    if (count >= MAX_COUNT_MSG_IN_ONE_SEND) {
      remainingMsg.append(msg)
      continue
    }
    if (tableId not in list)
      list[tableId] <- []
    list[tableId].append(data)
    sendedMsg.append(msg)
    count++
  }

  queueByUserId.mutate(@(v) v[userIdStr.get()] <- remainingMsg)
  if (count == 0)
    return

  nextCanSendMsec.set(max(nextCanSendMsec.get(), get_time_msec() + MIN_TIME_BETWEEN_MSEC))
  let token = getPlayerTokenGlobal()
  let headers = {
    action = token == "" ? "noa_bigquery_client_noauth" : "cln_bq_put_batch_json"
    appid = APP_ID
    token
  }

  let remainingCount = remainingMsg.len()
  logBQ($"Request BQ events (total = {count}, remainig = {remainingCount})")
  if (remainingCount > 0)
    logerr($"[BQ] Too many events piled up to send to BQ. More then {MAX_COUNT_MSG_IN_ONE_SEND}.")

  httpRequest({
    url = url.get()
    headers
    waitable = true
    data = object_to_json_string(list)
    respEventId = RESPONSE_EVENT
    context = {
      userId = userIdStr.get()
      list = sendedMsg
      isAllSent = remainingCount == 0
    }
  })
}

function startSendTimer() {
  if (queue.get().len() == 0)
    return
  let timeLeft = nextCanSendMsec.get() - get_time_msec()
  if (timeLeft > 0)
    resetTimeout(0.001 * timeLeft, sendAll)
  else
    defer(sendAll)
}
startSendTimer()

eventbus_subscribe(RESPONSE_EVENT, function(res) {
  let { status = -1, http_code = -1, context = null } = res
  if (status == HTTP_SUCCESS && http_code >= 200 && http_code < 300) {
    logBQ($"Success send {context?.list.len()} events")
    if (!(context?.isAllSent ?? true))
      startSendTimer()
    return
  }

  changeUrl()

  if(currentUrlIndex.get() == 0) {
    logerr($"[BQ] Failed to send data. All servers down. Retry after {0.001 * RETRY_MSEC} sec")
    nextCanSendMsec.set(get_time_msec() + RETRY_MSEC)
    initUrl()
  }
  else {
    logBQ($"Failed to send {context?.list.len()} events to BQ. status = {status}, http_code = {http_code}. Retry after {0.001 * RETRY_ON_URL_ERROR_MSEC} sec")
    nextCanSendMsec.set(get_time_msec() + RETRY_ON_URL_ERROR_MSEC)
  }

  if (context != null) {
    let { userId, list } = context
    queueByUserId.mutate(@(v) v[userId] <- (clone list).extend(v?[userId] ?? []))
  }
})

local wasQueueLen = queue.get().len()
queue.subscribe(function(v) {
  if (wasQueueLen == 0 && v.len() != 0)
    startSendTimer()
  wasQueueLen = v.len()
})

eventbus_subscribe("app.shutdown", @(_) sendAll())
isMatchingOnline.subscribe(@(v) v ? sendAll() : null)

let addToQueue = @(msg) queueByUserId.mutate(
  @(v) v[userIdStr.get()] <- (clone (v?[userIdStr.get()] ?? [])).append(msg))

function sendBqEvent(tableId, event, data = {}) {
  let msg = { tableId, data = { clientTime = getValidServerTime(), event, params = object_to_json_string(data) } }
  addToQueue(msg)
}

eventbus_subscribe("sendBqEvent", function(p) {
  let { tableId, event, data = {} } = p
  sendBqEvent(tableId, event, data)
})

addListenersWithoutEnv({
  LoginComplete = @(_p) startSendTimer()
})

return {
  sendBqEvent
  forceSendBqQueue = sendAll
}