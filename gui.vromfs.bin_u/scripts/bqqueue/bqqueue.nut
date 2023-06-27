from "%scripts/dagui_library.nut" import *
let { APP_ID } = require("app")
let { subscribe } = require("eventbus")
let { get_time_msec } = require("dagor.time")
let { resetTimeout, defer } = require("dagor.workcycle")
let { request, HTTP_SUCCESS } = require("dagor.http")
let { json_to_string } = require("json")
let { getPlayerToken } = require("auth_wt")
let { get_cur_circuit_block } = require("blkGetters")
let logBQ = log_with_prefix("[BQ] ")
let mkHardWatched = require("%globalScripts/mkHardWatched.nut")
let { shuffle } = require("%sqStdLibs/helpers/u.nut")
let DataBlock = require("DataBlock")
let { myUserId } = require("%scripts/user/profileStates.nut")

const MIN_TIME_BETWEEN_MSEC = 5000 //not send events more often than once per 5 sec
const RETRY_MSEC = 30000 //retry send on all servers down
const RETRY_ON_URL_ERROR_MSEC = 3000
const RESPONSE_EVENT = "bq.requestResponse"
let queueByUserId = mkHardWatched("bqQueue.queueByUserId", {})
let queue = Computed(@() queueByUserId.value?[myUserId.value] ?? [])
let nextCanSendMsec = mkHardWatched("bqQueue.nextCanSendMsec", -1)
let currentUrlIndex = mkHardWatched("bqQueue.currentUrlIndex", 0)

let urls = Watched([])
let url = Computed(@() urls.value?[currentUrlIndex.value] ?? urls.value?[0])

let function initUrl() {
  urls(shuffle((get_cur_circuit_block() ?? DataBlock()) % "charServer"))
  currentUrlIndex(0)
}

initUrl()

let function changeUrl() {
  currentUrlIndex((currentUrlIndex.value + 1) % max(urls.value.len(), 1))
}

let function callbackRequest(res) {
  let { status = -1, http_code = -1, context = null } = res
  if (status == HTTP_SUCCESS && http_code >= 200 && http_code < 300) {
    logBQ($"Success send {context?.list.len()} events")
    return
  }

  changeUrl()

  if(currentUrlIndex.value == 0) {
    logerr($"[BQ] Failed to send data. All servers down. Retry after {0.001 * RETRY_MSEC} sec")
    nextCanSendMsec(get_time_msec() + RETRY_MSEC)
    initUrl()
  }
  else {
    logBQ($"Failed to send {context?.list.len()} events to BQ. status = {status}, http_code = {http_code}. Retry after {0.001 * RETRY_ON_URL_ERROR_MSEC} sec")
    nextCanSendMsec(get_time_msec() + RETRY_ON_URL_ERROR_MSEC)
  }

  if (context != null) {
    let { userId, list } = context
    queueByUserId.mutate(@(v) v[userId] <- (clone list).extend(v?[userId] ?? []))
  }
}

let function sendAll() {
  if (queue.value.len() == 0)
    return

  let list = {}
  local count = 0
  foreach(msg in queue.value) {
    let { tableId = null, data = null } = msg
    if (type(tableId) != "string" || type(data) != "table") {
      logerr($"[BQ] Bad type of tableId or data for event: tableId = {tableId}, type of data = {type(data)}")
      continue
    }
    if (tableId not in list)
      list[tableId] <- []
    list[tableId].append(data)
    count++
  }

  let context = {
    userId = myUserId.value
    list = queue.value
  }
  queueByUserId.mutate(@(v) v[myUserId.value] <- [])
  if (count == 0)
    return

  nextCanSendMsec(max(nextCanSendMsec.value, get_time_msec() + MIN_TIME_BETWEEN_MSEC))
  let headers = {
    action = "cln_bq_put_batch_json"
    appid  = APP_ID
    token  = getPlayerToken()
    withAppid = true
    withCircuit = true
  }

  logBQ($"Request BQ events (total = {count})")

  request({
    url = url.value
    headers
    waitable = true
    data = json_to_string(list)
    context
    callback = callbackRequest
  })
}

let function startSendTimer() {
  if (queue.value.len() == 0)
    return
  let timeLeft = nextCanSendMsec.value - get_time_msec()
  if (timeLeft > 0)
    resetTimeout(0.001 * timeLeft, sendAll)
  else
    defer(sendAll)
}
startSendTimer()

local wasQueueLen = queue.value.len()
queue.subscribe(function(v) {
  if (wasQueueLen == 0 && v.len() != 0)
    startSendTimer()
  wasQueueLen = v.len()
})

subscribe("app.shutdown", @(_) sendAll())

let addToQueue = @(msg) queueByUserId.mutate(
  @(v) v[myUserId.value] <- (clone (v?[myUserId.value] ?? [])).append(msg))

let function sendBqEvent(tableId, event, data = {}) {
  let msg = { tableId, data = { clientTime = ::get_charserver_time_sec(), event, params = json_to_string(data) } }
  addToQueue(msg)
}

return {
  sendBqEvent
  forceSendBqQueue = sendAll
}