let DataBlock = require("DataBlock")
let json = require_optional("json")
let toJson = json?.to_string ?? getroottable()?.save_to_json

assert(toJson!=null, "no json module found")

let nativeApi = require_optional("sony.webapi")
let {abortAllPendingRequests= @() null,
  getPreferredVersion = @() 2,
  subscribeToBlocklistUpdates= @(...) null,
  subscribeToFriendsUpdates = @(...) null,
  unsubscribeFromBlocklistUpdates = @(...) null,
  unsubscribeFromFriendsUpdates = @(...) null
  } = nativeApi

let nativeSend = nativeApi?.send ?? @(...) null

let { dgs_get_settings } = require("dagor.system")
let { get_platform_string_id } = require("platform")
let platformId = dgs_get_settings().getStr("platform", get_platform_string_id())

let webApiMimeTypeBinary = "application/octet-stream"
let webApiMimeTypeImage = "image/jpeg"
let webApiMimeTypeJson = "application/json; encoding=utf-8"

let webApiMethodGet = 0
let webApiMethodPost = 1
let webApiMethodPut = 2
let webApiMethodDelete = 3
let webApiMethodPatch = 4

let function createRequest(api, method, path=null, params={}, data=null, forceBinary=false, headers = {}) {
  let request = DataBlock()
  request.apiGroup = api.group
  request.method = method
  request.path = path != null ? $"{api.path}/{path}" : $"{api.path}"
  request.forceBinary = forceBinary

  request.params = DataBlock()
  foreach(key,val in params) {
    if (type(val) == "array") {
      foreach(v in val)
        request.params[key] <- v
    }
    else
      request.params[key] = val
  }

  if (type(data) == "string")
    request.request = data
  if (type(data) == "table")
    request.request = toJson(data)
  else if (type(data) == "array")
    foreach(part in data)
      request.part <- part

  if (headers.len()) {
    request.reqHeaders = DataBlock()
    foreach(k, v in headers)
      request.reqHeaders[k] <- v
  }
  return request
}

let function createPart(mimeType, name, data) {
  let part = DataBlock()
  part.reqHeaders = DataBlock()
  part.reqHeaders["Content-Type"] = mimeType
  part.reqHeaders["Content-Description"] = name
  if (mimeType == webApiMimeTypeImage || mimeType == webApiMimeTypeBinary)
    part.reqHeaders["Content-Disposition"] = "attachment"

  if (mimeType == webApiMimeTypeImage)
    part.filePath = data
  else
    part.data = (type(data) == "table") ? toJson(data) : data
  return part
}

let function makeIterable(request, pos, size) {
  // Some APIs accept either start (majority) or offset (friendlist), other param is ignored
  request.params.start = pos
  request.params.offset = request.params.start
  request.params.size = size
  request.params.limit = request.params.size
  return request
}

let function noOpCb(_response, _err) { /* NO OP */ }


// ------------ Session actions
let sessionApi = { group = "sdk:sessionInvitation", path = "/v1/sessions" }
let session = {
  function create(info, image, data) {
    let parts = [createPart(webApiMimeTypeJson, "session-request", info)]
    if (image != null && image.len() > 0)
      parts.append(createPart(webApiMimeTypeImage, "session-image", image))
    if (data != null && data.len() > 0)
      parts.append(createPart(webApiMimeTypeBinary, "changeable-session-data", data))
    return createRequest(sessionApi, webApiMethodPost, null, {}, parts)
  }

  function update(sessionId, sessionInfo) {
    return createRequest(sessionApi, webApiMethodPut, sessionId, {}, sessionInfo)
  }

  function join(sessionId, index=0) {
    return createRequest(sessionApi, webApiMethodPost, $"{sessionId}/members", {index=index})
  }

  function leave(sessionId) {
    return createRequest(sessionApi, webApiMethodDelete, $"{sessionId}/members/me")
  }

  function data(sessionId) {
    return createRequest(sessionApi, webApiMethodGet, $"{sessionId}/changeableSessionData")
  }

  function change(sessionId, changedata) {
    return createRequest(sessionApi, webApiMethodPut, $"{sessionId}/changeableSessionData", {}, changedata, true)
  }

  function invite(sessionId, accounts, invitedata={}) {
    if (type(accounts) == "string")
      accounts = [accounts]
    let parts = [createPart(webApiMimeTypeJson, "invitation-request", {to=accounts})]
    if (invitedata != null && invitedata.len() > 0)
      parts.append(createPart(webApiMimeTypeBinary, "invitation-data", invitedata))
    return createRequest(sessionApi, webApiMethodPost, $"{sessionId}/invitations", {}, parts)
  }
}


let sessionManagerApi = { group = "sessionManager", path = "/v1/playerSessions" }
let sessionManager = {
  function create(data) {
    return createRequest(sessionManagerApi, webApiMethodPost, null, {}, data)
  }
  function update(sessionId, param) {
    //Allow to update only one parameter at a time
    return createRequest(sessionManagerApi, webApiMethodPatch, $"{sessionId}", {}, param)
  }
  function leave(sessionId) {
    return createRequest(sessionManagerApi, webApiMethodDelete, $"{sessionId}/members/me")
  }
  function joinAsPlayer(sessionId, data) {
    return createRequest(sessionManagerApi, webApiMethodPost, $"{sessionId}/member/players", {}, data)
  }
  function joinAsSpectator(sessionId, data) {
    return createRequest(sessionManagerApi, webApiMethodPost, $"{sessionId}/member/spectators", {}, data)
  }
  function list(sessionIds = []) {
    return createRequest(sessionManagerApi, webApiMethodGet, null, {fields="customData1,sessionId"},
      null, false, {["X-PSN-SESSION-MANAGER-SESSION-IDS"] = ",".join(sessionIds)})
  }

  function changeLeader(sessionId, accountId, platform) {
    return createRequest(sessionManagerApi, webApiMethodPut, $"{sessionId}/leader",
      {}, { accountId = accountId, platform = platform })
  }
  function invite(sessionId, accountIds) {
    let data = { invitations = accountIds.map(@(id) { to = { accountId = id }})}
    return createRequest(sessionManagerApi, webApiMethodPost, $"{sessionId}/invitations", {}, data)
  }
}

// ------------ Game Sessions actions
let gameSessionManagerApi = { group = "sessionManager", path = "/v1/gameSessions" }
let gameSessionManager = {
  function create(data) {
    return createRequest(gameSessionManagerApi, webApiMethodPost, null, {}, data)
  }
  function update(sessionId, param) {
    //Allow to update only one parameter at a time
    return createRequest(gameSessionManagerApi, webApiMethodPatch, $"{sessionId}", {}, param)
  }
  function leave(sessionId) {
    return createRequest(gameSessionManagerApi, webApiMethodDelete, $"{sessionId}/members/me")
  }
  function joinAsPlayer(sessionId, data) {
    return createRequest(gameSessionManagerApi, webApiMethodPost, $"{sessionId}/member/players", {}, data)
  }
  function joinAsSpectator(sessionId, data) {
    return createRequest(gameSessionManagerApi, webApiMethodPost, $"{sessionId}/member/spectators", {}, data)
  }
}

// ------------ Invitation actions
let invitationApi = { group = "sdk:sessionInvitation", path = "/v1/users/me/invitations" }
let invitation = {
  function use(invitationId) {
    return createRequest(invitationApi, webApiMethodPut, invitationId, {}, {usedFlag = true})
  }

  function list() {
    return createRequest(invitationApi, webApiMethodGet, null, {fields="@default,sessionId"})
  }
}

let playerSessionInvitationsApi = {
  group = "sessionManager"
  path = "/v1/users/me/playerSessionsInvitations"
}
let playerSessionInvitations = {
  function list() {
    return createRequest(playerSessionInvitationsApi, webApiMethodGet)
  }
}

// ------------ Profile actions
let profileApi = { group = "sdk:userProfile", path = "/v1/users/me" }
let profile = {
  function listFriends() {
    let params = { friendStatus = "friend", presenceType = "incontext" }
    return createRequest(profileApi, webApiMethodGet, "friendList", params)
  }

  function listBlockedUsers() {
    return createRequest(profileApi, webApiMethodGet, "blockingUsers", {})
  }
}

let userProfileApi = { group = "userProfile", path = "/v1/users" }
let userProfile = {
  function listFriends(params = {}) {
    return createRequest(userProfileApi, webApiMethodGet, "me/friends", params)
  }

  function listBlockedUsers() {
    return createRequest(userProfileApi, webApiMethodGet, "me/blocks")
  }

  function getPublicProfiles(accountIds) {
    let users = {accountIds = ",".join(accountIds)}
    return createRequest(userProfileApi, webApiMethodGet, "profiles", users)
  }

  function getBasicPresences(accountIds) {
    let users = {accountIds = ",".join(accountIds)}
    return createRequest(userProfileApi, webApiMethodGet, "basicPresences", users)
  }
}

let communicationRestrictionsApi = {
  group = "communicationRestrictionStatus"
  path = "/v3/users/me/communication/restriction/status"
}
let communicationRestrictionStatus = {
  function get() {
    return createRequest(communicationRestrictionsApi, webApiMethodGet)
  }
}


// ------------ Activity Feed actions
let feedApi = { group = "sdk:activityFeed", path = "/v1/users/me" }
let feed = {
  function post(message) {
    return createRequest(feedApi, webApiMethodPost, "feed", {}, message)
  }
}

// ----------- Commerce actions
let commerceApi = { group = "sdk:commerce" path = "/v1/users/me/container" }
let commerce = {
  function detail(products, params={}) {
    let path = ":".join(products)
    return createRequest(commerceApi, webApiMethodGet, path, params)
  }

  // listing multiple categories at once requires multiple iterators, one per category. We have one.
  function listCategory(category, params={}) {
    assert(type(category) == "string", "[PSWA] only one category can be listed at a time")
    return createRequest(commerceApi, webApiMethodGet, category, params)
  }
}


let inGameCatalogApi = { group = "inGameCatalog" path = "/v5/container" }
let inGameCatalog = {
  // Service label is now mandatory due to the way PS5 can be setup (with two stores)
  function get(ids, serviceLabel, params={}) {
    params["serviceLabel"] <- serviceLabel
    params["containerIds"] <- ":".join(ids)
    return createRequest(inGameCatalogApi, webApiMethodGet, null, params)
  }
}

// ---------- Entitlement actions
// XXX: Entitilements WebApi is no longer available on PS5, it's only for App Servers
let entitlementsApi = { group = "sdk:entitlement", path = "/v1/users/me/entitlements"}
let entitlements = {
  function granted() {
    let params = { entitlement_type = ["service", "unified"] }
    return createRequest(entitlementsApi, webApiMethodGet, null, params)
  }
}


// ---------- Matches actions
let matchesApi = { group = "matches", path = "/v1/matches" }

let function psnMatchCreate(data) {
  return createRequest(matchesApi, webApiMethodPost, null, {}, data)
}

let function psnMatchUpdateStatus(id, status) {
  let data = { status = status }
  return createRequest(matchesApi, webApiMethodPut, $"{id}/status", {}, data)
}
let function psnMatchJoin(id, player) {
  let data = { players = [ player ] }
  return createRequest(matchesApi, webApiMethodPost, $"{id}/players/actions/add", {}, data)
}

let function psnMatchLeave(id, player) {
  let data = { players = [ player ] }
  return createRequest(matchesApi, webApiMethodPost, $"{id}/players/actions/remove", {}, data)
}

let function psnMatchReportResults(id, result) {
  let data = {matchResults = {version = "1", competitiveResult = result}}
  return createRequest(matchesApi, webApiMethodPost, $"{id}/results", {}, data)
}

const PSN_MATCH_LEAVE_REASON_QUIT = "QUIT"
const PSN_MATCH_LEAVE_REASON_FINISHED = "FINISHED"
const PSN_MATCH_LEAVE_REASON_DISCONNECTED = "DISCONNECTED"
const PSN_MATCH_STATUS_PLAYING = "PLAYING"
let PSN_LEAVE_MATCH_REASONS = {
  QUIT = PSN_MATCH_LEAVE_REASON_QUIT
  FINISHED = PSN_MATCH_LEAVE_REASON_FINISHED
  DISCONNECTED = PSN_MATCH_LEAVE_REASON_DISCONNECTED
}

let matches = {
  create = psnMatchCreate
  updateStatus = psnMatchUpdateStatus
  join = psnMatchJoin
  leave = psnMatchLeave
  reportResults = psnMatchReportResults
  LeaveReason = PSN_LEAVE_MATCH_REASONS
}


// ---------- Utility functions and wrappers
let function is_http_success(code) { return code >= 200 && code < 300 }

let function send(action, onResponse=noOpCb) {
  let cb = function(r) {
    local err = r?.error
    let httpErr = (!is_http_success(r?.httpStatus ?? 0)) ? (r?.httpStatus ?? 0) : null
    if (httpErr != null && err == null)
      err = { }
    if (err && err?.code == null)
      err.code <- httpErr ? httpErr : "undefined";

    onResponse(r?.response, err)
  }

  nativeSend(action, cb)
}

let function fetch(action, onChunkReceived, chunkSize = 20) {
  let function onResponse(response, err) {
    // PSN responses are somewhat inconsistent, but we need proper iterators
    let entry = ((type(response) == "array") ? response?[0] : response) || {}
    let received = (getPreferredVersion() == 2)
                   ? (entry?.nextOffset || entry?.totalItemCount)
                   : (entry?.start||0) + (entry?.size||0)
    let total = entry?.total_results || entry?.totalResults || entry?.totalItemCount || received

    if (err == null && received < total)
      send(makeIterable(action, received, chunkSize), callee())

    onChunkReceived(response, err)
  }

  send(makeIterable(action, 0, chunkSize), onResponse);
}


return {
  psnSend = send
  psnMatchCreate
  psnMatchJoin
  psnMatchLeave
  psnMatchReportResults
  psnMatchUpdateStatus
  PSN_MATCH_LEAVE_REASON_DISCONNECTED
  PSN_MATCH_LEAVE_REASON_FINISHED
  PSN_MATCH_LEAVE_REASON_QUIT
  PSN_MATCH_STATUS_PLAYING

  send
  fetch
  abortAllPendingRequests = abortAllPendingRequests ?? @() null
  getPreferredVersion = getPreferredVersion

  session
  sessionManager
  gameSessionManager

  invitation
  playerSessionInvitations
  matches

  profile = (getPreferredVersion() == 2) ? userProfile : profile
  communicationRestrictionStatus

  feed

  commerce
  inGameCatalog
  entitlements

  noOpCb

  subscribe = {
    friendslist = subscribeToFriendsUpdates
    blocklist = subscribeToBlocklistUpdates
  }
  unsubscribe = {
    friendslist = unsubscribeFromFriendsUpdates
    blocklist = unsubscribeFromBlocklistUpdates
  }

  serviceLabel = platformId == "ps5"? 1 : 0
}
