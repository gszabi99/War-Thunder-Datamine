local DataBlock = require("DataBlock")
local json = require_optional("json")
local toJson = json?.to_string ?? ::save_to_json
local nativeApi = require_optional("sony.webapi")
local {abortAllPendingRequests= @() null,
  getPreferredVersion = @() 2,
  subscribeToBlocklistUpdates= @(...) null,
  subscribeToFriendsUpdates = @(...) null,
  unsubscribeFromBlocklistUpdates = @(...) null,
  unsubscribeFromFriendsUpdates = @(...) null
  } = nativeApi

local nativeSend = nativeApi?.send ?? @(...) null

local { dgs_get_settings } = require("dagor.system")
local { get_platform_string_id } = require("platform")
local platformId = dgs_get_settings().getStr("platform", get_platform_string_id())

local webApiMimeTypeBinary = "application/octet-stream"
local webApiMimeTypeImage = "image/jpeg"
local webApiMimeTypeJson = "application/json; encoding=utf-8"

local webApiMethodGet = 0
local webApiMethodPost = 1
local webApiMethodPut = 2
local webApiMethodDelete = 3
local webApiMethodPatch = 4

local function createRequest(api, method, path=null, params={}, data=null, forceBinary=false, headers = {}) {
  local request = DataBlock()
  request.apiGroup = api.group
  request.method = method
  request.path = path != null ? $"{api.path}/{path}" : $"{api.path}"
  request.forceBinary = forceBinary

  request.params = DataBlock()
  foreach(key,val in params) {
    if (::type(val) == "array") {
      foreach(v in val)
        request.params[key] <- v
    }
    else
      request.params[key] = val
  }

  if (::type(data) == "string")
    request.request = data
  if (::type(data) == "table")
    request.request = toJson(data)
  else if (::type(data) == "array")
    foreach(part in data)
      request.part <- part

  if (headers.len()) {
    request.reqHeaders = DataBlock()
    foreach(k, v in headers)
      request.reqHeaders[k] <- v
  }
  return request
}

local function createPart(mimeType, name, data) {
  local part = DataBlock()
  part.reqHeaders = DataBlock()
  part.reqHeaders["Content-Type"] = mimeType
  part.reqHeaders["Content-Description"] = name
  if (mimeType == webApiMimeTypeImage || mimeType == webApiMimeTypeBinary)
    part.reqHeaders["Content-Disposition"] = "attachment"

  if (mimeType == webApiMimeTypeImage)
    part.filePath = data
  else
    part.data = (::type(data) == "table") ? toJson(data) : data
  return part
}

local function makeIterable(request, pos, size) {
  // Some APIs accept either start (majority) or offset (friendlist), other param is ignored
  request.params.start = pos
  request.params.offset = request.params.start
  request.params.size = size
  request.params.limit = request.params.size
  return request
}

local function noOpCb(response, err) { /* NO OP */ }


// ------------ Session actions
local sessionApi = { group = "sdk:sessionInvitation", path = "/v1/sessions" }
local session = {
  function create(info, image, data) {
    local parts = [createPart(webApiMimeTypeJson, "session-request", info)]
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
    if (::type(accounts) == "string")
      accounts = [accounts]
    local parts = [createPart(webApiMimeTypeJson, "invitation-request", {to=accounts})]
    if (invitedata != null && invitedata.len() > 0)
      parts.append(createPart(webApiMimeTypeBinary, "invitation-data", invitedata))
    return createRequest(sessionApi, webApiMethodPost, $"{sessionId}/invitations", {}, parts)
  }
}


local sessionManagerApi = { group = "sessionManager", path = "/v1/playerSessions" }
local sessionManager = {
  function create(params) {
    return createRequest(sessionManagerApi, webApiMethodPost, null, {}, params)
  }
  function update(sessionId, param) {
    //Allow to update only one parameter at a time
    return createRequest(sessionManagerApi, webApiMethodPatch, $"{sessionId}", {}, param)
  }
  function leave(sessionId) {
    return createRequest(sessionManagerApi, webApiMethodDelete, $"{sessionId}/members/me")
  }
  function joinAsPlayer(sessionId, params) {
    return createRequest(sessionManagerApi, webApiMethodPost, $"{sessionId}/member/players", {}, params)
  }
  function joinAsSpectator(sessionId, params) {
    return createRequest(sessionManagerApi, webApiMethodPost, $"{sessionId}/member/spectators", {}, params)
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
    local params = { invitations = accountIds.map(@(id) { to = { accountId = id }})}
    return createRequest(sessionManagerApi, webApiMethodPost, $"{sessionId}/invitations", {}, params)
  }
}

// ------------ Game Sessions actions
local gameSessionManagerApi = { group = "sessionManager", path = "/v1/gameSessions" }
local gameSessionManager = {
  function create(params) {
    return createRequest(gameSessionManagerApi, webApiMethodPost, null, {}, params)
  }
  function update(sessionId, param) {
    //Allow to update only one parameter at a time
    return createRequest(gameSessionManagerApi, webApiMethodPatch, $"{sessionId}", {}, param)
  }
  function leave(sessionId) {
    return createRequest(gameSessionManagerApi, webApiMethodDelete, $"{sessionId}/members/me")
  }
  function joinAsPlayer(sessionId, params) {
    return createRequest(gameSessionManagerApi, webApiMethodPost, $"{sessionId}/member/players", {}, params)
  }
  function joinAsSpectator(sessionId, params) {
    return createRequest(gameSessionManagerApi, webApiMethodPost, $"{sessionId}/member/spectators", {}, params)
  }
}

// ------------ Invitation actions
local invitationApi = { group = "sdk:sessionInvitation", path = "/v1/users/me/invitations" }
local invitation = {
  function use(invitationId) {
    return createRequest(invitationApi, webApiMethodPut, invitationId, {}, {usedFlag = true})
  }

  function list() {
    return createRequest(invitationApi, webApiMethodGet, null, {fields="@default,sessionId"})
  }
}

local playerSessionInvitationsApi = {
  group = "sessionManager"
  path = "/v1/users/me/playerSessionsInvitations"
}
local playerSessionInvitations = {
  function list() {
    return createRequest(playerSessionInvitationsApi, webApiMethodGet)
  }
}

// ------------ Profile actions
local profileApi = { group = "sdk:userProfile", path = "/v1/users/me" }
local profile = {
  function listFriends() {
    local params = { friendStatus = "friend", presenceType = "incontext" }
    return createRequest(profileApi, webApiMethodGet, "friendList", params)
  }

  function listBlockedUsers() {
    return createRequest(profileApi, webApiMethodGet, "blockingUsers", {})
  }
}

local userProfileApi = { group = "userProfile", path = "/v1/users" }
local userProfile = {
  function listFriends(params = {}) {
    return createRequest(userProfileApi, webApiMethodGet, "me/friends", params)
  }

  function listBlockedUsers() {
    return createRequest(userProfileApi, webApiMethodGet, "me/blocks")
  }

  function getPublicProfiles(accountIds) {
    local users = {accountIds = ",".join(accountIds)}
    return createRequest(userProfileApi, webApiMethodGet, "profiles", users)
  }

  function getBasicPresences(accountIds) {
    local users = {accountIds = ",".join(accountIds)}
    return createRequest(userProfileApi, webApiMethodGet, "basicPresences", users)
  }
}

local communicationRestrictionsApi = {
  group = "communicationRestrictionStatus"
  path = "/v3/users/me/communication/restriction/status"
}
local communicationRestrictionStatus = {
  function get() {
    return createRequest(communicationRestrictionsApi, webApiMethodGet)
  }
}


// ------------ Activity Feed actions
local feedApi = { group = "sdk:activityFeed", path = "/v1/users/me" }
local feed = {
  function post(message) {
    return createRequest(feedApi, webApiMethodPost, "feed", {}, message)
  }
}

// ----------- Commerce actions
local commerceApi = { group = "sdk:commerce" path = "/v1/users/me/container" }
local commerce = {
  function detail(products, params={}) {
    local path = ":".join(products)
    return createRequest(commerceApi, webApiMethodGet, path, params)
  }

  // listing multiple categories at once requires multiple iterators, one per category. We have one.
  function listCategory(category, params={}) {
    assert(::type(category) == "string", "[PSWA] only one category can be listed at a time")
    return createRequest(commerceApi, webApiMethodGet, category, params)
  }
}


local inGameCatalogApi = { group = "inGameCatalog" path = "/v5/container" }
local inGameCatalog = {
  // Service label is now mandatory due to the way PS5 can be setup (with two stores)
  function get(ids, serviceLabel, params={}) {
    params["serviceLabel"] <- serviceLabel
    params["containerIds"] <- ":".join(ids)
    return createRequest(inGameCatalogApi, webApiMethodGet, null, params)
  }
}

// ---------- Entitlement actions
// XXX: Entitilements WebApi is no longer available on PS5, it's only for App Servers
local entitlementsApi = { group = "sdk:entitlement", path = "/v1/users/me/entitlements"}
local entitlements = {
  function granted() {
    local params = { entitlement_type = ["service", "unified"] }
    return createRequest(entitlementsApi, webApiMethodGet, null, params)
  }
}


// ---------- Matches actions
local matchesApi = { group = "matches", path = "/v1/matches" }

local function psnMatchCreate(data) {
  return createRequest(matchesApi, webApiMethodPost, null, {}, data)
}

local function psnMatchUpdateStatus(id, status) {
  local data = { status = status }
  return createRequest(matchesApi, webApiMethodPut, $"{id}/status", {}, data)
}
local function psnMatchJoin(id, player) {
  local data = { players = [ player ] }
  return createRequest(matchesApi, webApiMethodPost, $"{id}/players/actions/add", {}, data)
}

local function psnMatchLeave(id, player) {
  local data = { players = [ player ] }
  return createRequest(matchesApi, webApiMethodPost, $"{id}/players/actions/remove", {}, data)
}

local function psnMatchReportResults(id, result) {
  local data = {matchResults = {version = 1, competitiveResult = result}}
  return createRequest(matchesApi, webApiMethodPost, $"{id}/results", {}, data)
}

const PSN_MATCH_LEAVE_REASON_QUIT = "QUIT"
const PSN_MATCH_LEAVE_REASON_FINISHED = "FINISHED"
const PSN_MATCH_LEAVE_REASON_DISCONNECTED = "DISCONNECTED"
const PSN_MATCH_STATUS_PLAYING = "PLAYING"
local PSN_LEAVE_MATCH_REASONS = {
  QUIT = PSN_MATCH_LEAVE_REASON_QUIT
  FINISHED = PSN_MATCH_LEAVE_REASON_FINISHED
  DISCONNECTED = PSN_MATCH_LEAVE_REASON_DISCONNECTED
}

local matches = {
  create = psnMatchCreate
  updateStatus = psnMatchUpdateStatus
  join = psnMatchJoin
  leave = psnMatchLeave
  reportResults = psnMatchReportResults
  LeaveReason = PSN_LEAVE_MATCH_REASONS
}


// ---------- Utility functions and wrappers
local function is_http_success(code) { return code != null && code >= 200 && code < 300 }

local function send(action, onResponse=noOpCb) {
  local cb = function(r) {
    local err = r?.error
    local httpErr = (!is_http_success(r?.httpStatus)) ? r.httpStatus : null
    if (httpErr && err == null)
      err = { }
    if (err && err?.code == null)
      err.code <- httpErr ? httpErr : "undefined";

    onResponse(r?.response, err)
  }

  nativeSend(action, cb)
}

local function fetch(action, onChunkReceived, chunkSize = 20) {
  local function onResponse(response, err) {
    // PSN responses are somewhat inconsistent, but we need proper iterators
    local entry = ((::type(response) == "array") ? response?[0] : response) || {}
    local received = (getPreferredVersion() == 2)
                   ? (entry?.nextOffset || entry?.totalItemCount)
                   : (entry?.start||0) + (entry?.size||0)
    local total = entry?.total_results || entry?.totalResults || entry?.totalItemCount || received

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
