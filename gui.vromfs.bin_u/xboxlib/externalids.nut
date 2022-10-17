let { subscribe, send } = require("eventbus")
let { updateUidsMapping } = require("%xboxLib/userIds.nut")
let {rnd_int} = require("dagor.random")
let logX = require("%sqstd/log.nut")().with_prefix("[EXT_IDS] ")

let eventNameXuids = "XBOX_EXTERNAL_IDS_REQUEST_EVENT"
let eventNameUids = "XBOX_EXTERNAL_IDS_BATCH_REQUEST_EVENT"
let cachedDataXuids = persist("cachedDataXuids", @() { callbacks = {}, cachedNulls = {} })
let cachedDataUids = persist("cachedDataUids", @() { callbacks = {}})


let function subscribe_to_xuid_requests(callback) {
  subscribe(eventNameXuids, function(res) {
    callback?(res?.uid)
  })
}


let function request_xuid_for_uid(uid, callback) {
  if (uid in cachedDataXuids.cachedNulls) {
    logX($"UserID {uid} was requested already and doesn't have known xuid")
    callback?(uid, null)
    return
  }

  logX($"Requesting xuid for {uid}")
  cachedDataXuids.callbacks[uid] <- callback
  send(eventNameXuids, { uid = uid })
}


let function on_xuid_request_response(uid, xuid) {
  local callback = null
  if (uid in cachedDataXuids.callbacks) {
    callback = cachedDataXuids.callbacks[uid]
    delete cachedDataXuids.callbacks[uid]
  }

  if (xuid) {
    updateUidsMapping({ [xuid] = uid })
    logX($"UserID {uid} has known xuid {xuid}")
    callback?(uid, xuid)
  } else {
    cachedDataXuids.cachedNulls[uid] <- true
    logX($"UserID {uid} doesn't have known xuid -> remembering")
    callback?(uid, null)
  }
}


let function subscribe_to_batch_uids_requests(callback) {
  subscribe(eventNameUids, function(res) {
    callback?(res?.xuids, res?.requestId)
  })
}


let function batch_request_uids_by_xuids(xuids, callback) {
  let REQUEST_ID_MAX = 100000
  local requestId = rnd_int(0, REQUEST_ID_MAX)
  while (requestId in cachedDataUids.callbacks) {
    requestId = rnd_int(0, REQUEST_ID_MAX)
  }

  logX($"Requesting {xuids.len()} uids by xuids. RequestId: {requestId}")
  cachedDataUids.callbacks[requestId] <- callback
  send(eventNameUids, {xuids = xuids, requestId = requestId})
}


let function on_batch_uids_request_response(xuids2uids, requestId) {
  local callback = null
  if (requestId in cachedDataUids.callbacks) {
    callback = cachedDataUids.callbacks[requestId]
    delete cachedDataUids.callbacks[requestId]
  }

  callback?(xuids2uids)
}


return {
  subscribe_to_xuid_requests
  request_xuid_for_uid
  on_xuid_request_response

  subscribe_to_batch_uids_requests
  batch_request_uids_by_xuids
  on_batch_uids_request_response
}