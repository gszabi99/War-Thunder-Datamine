import "DataBlock" as DataBlock
from "eventbus" import eventbus_subscribe_onehit, eventbus_subscribe, eventbus_unsubscribe
from "dagor.system" import dgs_get_settings
from "platform" import get_platform_string_id
let {object_to_json_string=null} = require_optional("json")
let toJson = object_to_json_string ?? getroottable()?.save_to_json

assert(toJson!=null, "no json module found")

let nativeApi = require_optional("sony.webapi")
let {abortAllPendingRequests= @() null,
  getNewRequestId = @() 0,
  getPreferredVersion = @() 2,
  subscribeToBlocklistUpdates= @(...) null,
  subscribeToFriendsUpdates = @(...) null,
  subscribeToPresenceUpdates = @(...) null,
  unsubscribeFromBlocklistUpdates = @(...) null,
  unsubscribeFromFriendsUpdates = @(...) null,
  unsubscribeFromPresenceUpdates = @(...) null,
  FRIENDS_CHANGE_EVENT_NAME = "",
  BLOCKLIST_CHANGE_EVENT_NAME = "",
  PRESENCE_CHANGE_EVENT_NAME = ""
  } = nativeApi

let nativeSend = nativeApi?.send ?? @(...) null

let platformId = dgs_get_settings().getStr("platform", get_platform_string_id())

let webApiMethodGet = 0
let webApiMethodPost = 1
let webApiMethodPut = 2
let webApiMethodDelete = 3
let webApiMethodPatch = 4

function createRequest(api, method, path=null, params={}, data=null, forceBinary=false, headers = {}) {
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

function makeIterable(request, pos, size) {
  
  request.params.start = pos
  request.params.offset = request.params.start
  request.params.size = size
  request.params.limit = request.params.size
  return request
}

function noOpCb(_response, _err) {  }



let sessionManagerApi = { group = "sessionManager", path = "/v1/playerSessions" }
let sessionManager = {
  function create(data) {
    return createRequest(sessionManagerApi, webApiMethodPost, null, {}, data)
  }
  function update(sessionId, param) {
    
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


let gameSessionManagerApi = { group = "sessionManager", path = "/v1/gameSessions" }
let gameSessionManager = {
  function create(data) {
    return createRequest(gameSessionManagerApi, webApiMethodPost, null, {}, data)
  }
  function update(sessionId, param) {
    
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



let feedApi = { group = "sdk:activityFeed", path = "/v1/users/me" }
let feed = {
  function post(message) {
    return createRequest(feedApi, webApiMethodPost, "feed", {}, message)
  }
}


let commerceApi = { group = "sdk:commerce" path = "/v1/users/me/container" }
let commerce = {
  function detail(products, params={}) {
    let path = ":".join(products)
    return createRequest(commerceApi, webApiMethodGet, path, params)
  }

  
  function listCategory(category, params={}) {
    assert(type(category) == "string", "[PSWA] only one category can be listed at a time")
    return createRequest(commerceApi, webApiMethodGet, category, params)
  }
}


let inGameCatalogApi = { group = "inGameCatalog" path = "/v5/container" }
let inGameCatalog = {
  
  function get(ids, serviceLabel, params={}) {
    params["serviceLabel"] <- serviceLabel
    params["containerIds"] <- ":".join(ids)
    return createRequest(inGameCatalogApi, webApiMethodGet, null, params)
  }
}



let entitlementsApi = { group = "sdk:entitlement", path = "/v1/users/me/entitlements"}
let entitlements = {
  function granted() {
    let params = { entitlement_type = ["service", "unified"] }
    return createRequest(entitlementsApi, webApiMethodGet, null, params)
  }
}



let matchesApi = { group = "matches", path = "/v1/matches" }

function psnMatchCreate(data) {
  return createRequest(matchesApi, webApiMethodPost, null, {}, data)
}

function psnMatchUpdateStatus(id, status) {
  let data = { status = status }
  return createRequest(matchesApi, webApiMethodPut, $"{id}/status", {}, data)
}
function psnMatchJoin(id, player) {
  let data = { players = [ player ] }
  return createRequest(matchesApi, webApiMethodPost, $"{id}/players/actions/add", {}, data)
}

function psnMatchLeave(id, player) {
  let data = { players = [ player ] }
  return createRequest(matchesApi, webApiMethodPost, $"{id}/players/actions/remove", {}, data)
}

function psnMatchReportResults(id, result) {
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



function isHttpSuccess(code) { return code >= 200 && code < 300 }

function getNewRequestIdImpl() {
  let reqId = getNewRequestId()
  return $"sony_webapi_request_{reqId}"
}

function send(action, onResponse=null) {
  let eventId = getNewRequestIdImpl()
  eventbus_subscribe_onehit(eventId, function(r) {
    local err = r?.error
    let httpErr = (!isHttpSuccess(r?.httpStatus ?? 0)) ? (r?.httpStatus ?? 0) : null
    if (httpErr != null && err == null)
      err = { }
    if (err && err?.code == null)
      err.code <- httpErr ? httpErr : "undefined";

    onResponse?(r?.response, err)
  })

  nativeSend(action, eventId)
}

function fetch(action, onChunkReceived, chunkSize = 20) {
  function onResponse(response, err) {
    
    let entry = ((type(response) == "array") ? response?[0] : response) ?? {}
    let received = (getPreferredVersion() == 2)
                   ? (entry?.nextOffset ?? entry?.totalItemCount ?? 0)
                   : (entry?.start ?? 0) + (entry?.size ?? 0)
    let total = entry?.total_results ?? entry?.totalResults ?? entry?.totalItemCount ?? received

    if (err == null && received < total)
      send(makeIterable(action, received, chunkSize), callee())

    onChunkReceived(response, err)
  }

  send(makeIterable(action, 0, chunkSize), onResponse);
}

function subscribeToFriendsUpdatesImpl(on_update) {
  eventbus_subscribe(FRIENDS_CHANGE_EVENT_NAME, on_update)
  subscribeToFriendsUpdates()
}

function subscribeToBlocklistUpdatesImpl(on_update) {
  eventbus_subscribe(BLOCKLIST_CHANGE_EVENT_NAME, on_update)
  subscribeToBlocklistUpdates()
}

function unsubscribeFromFriendsUpdatesImpl(on_update) {
  unsubscribeFromFriendsUpdates()
  eventbus_unsubscribe(FRIENDS_CHANGE_EVENT_NAME, on_update)
}

function unsubscribeFromBlocklistUpdatesImpl(on_update) {
  unsubscribeFromBlocklistUpdates()
  eventbus_unsubscribe(BLOCKLIST_CHANGE_EVENT_NAME, on_update)
}

function subscribeToPresenceUpdatesImpl(on_update) {
  eventbus_subscribe(PRESENCE_CHANGE_EVENT_NAME, on_update)
  subscribeToPresenceUpdates()
}

function unsubscribeFromPresenceUpdatesImpl(on_update) {
  unsubscribeFromPresenceUpdates()
  eventbus_unsubscribe(PRESENCE_CHANGE_EVENT_NAME, on_update)
}


return freeze({
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
    friendslist = subscribeToFriendsUpdatesImpl
    blocklist = subscribeToBlocklistUpdatesImpl
  }
  unsubscribe = {
    friendslist = unsubscribeFromFriendsUpdatesImpl
    blocklist = unsubscribeFromBlocklistUpdatesImpl
  }

  subscribeToPresenceUpdates = subscribeToPresenceUpdatesImpl
  unsubscribeFromPresenceUpdates = unsubscribeFromPresenceUpdatesImpl

  serviceLabel = platformId == "ps5"? 1 : 0
})
