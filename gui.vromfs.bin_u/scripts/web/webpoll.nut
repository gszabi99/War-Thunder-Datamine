local { set_blk_value_by_path } = require("sqStdLibs/helpers/datablockUtils.nut")
local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local api = require("dagor.webpoll")

const WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS = 3000000
const REQUEST_AUTHORIZATION_TIMEOUT_MS = 3600000
const VOTED_POLLS_SAVE_ID = "voted_polls"

local cachedTokenById = {}
local tokenInvalidationTimeById = {}
local votedPolls = null
local pollBaseUrlById = {}
local pollIdByFullUrl = {}
local authorizedPollsRequestTimeOut = {}  //0 when already authorized

local function setPollBaseUrl(pollId, pollUrl) {
  if (!(pollId in pollBaseUrlById))
    pollBaseUrlById[pollId] <- pollUrl
}

local function getPollBaseUrl(pollId) {
  return pollBaseUrlById?[pollId]
}

local function canRequestAuthorization(pollId) {
  local requestTimeOut = authorizedPollsRequestTimeOut?[pollId]
  if (requestTimeOut == null)
    return true

  return requestTimeOut < ::dagor.getCurTime()
}

local function loadVotedPolls() {
  if (!::g_login.isProfileReceived())
    return
  votedPolls = ::load_local_account_settings(VOTED_POLLS_SAVE_ID, ::DataBlock())
}

local function saveVotedPolls() {
  if (!::g_login.isProfileReceived())
    return
  ::save_local_account_settings(VOTED_POLLS_SAVE_ID, votedPolls)
}

local function getVotedPolls() {
  if (!::g_login.isProfileReceived())
    return ::DataBlock()
  if (votedPolls == null)
    loadVotedPolls()
  return votedPolls
}

local function webpollEvent(id, token, voted) {
  id = ::to_integer_safe(id)
  if (!id || token == null)
    return

  cachedTokenById[id] <- token
  local isInvalidateToken = token == ""
  tokenInvalidationTimeById[id] <- isInvalidateToken ? -1
    : ::dagor.getCurTime() + WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS
  authorizedPollsRequestTimeOut[id] <- isInvalidateToken ? null : 0

  local idString = id.tostring()
  if (voted) {
    set_blk_value_by_path(getVotedPolls(), idString, true)
    saveVotedPolls()
  }
  ::broadcastEvent("WebPollAuthResult", {pollId = idString})
}

local function onCanVoteResponse(response) {
  if (response?.status == "OK" && response?.data != null)
    foreach (id, data in response.data)
      if (data?.can_vote ?? false)
        webpollEvent(id, data?.disposable_token, data?.has_vote ?? false)
}

local function onSurveyVoteResult(params) {
  webpollEvent(params.survey_id, "", params.has_vote)
}

local function invalidateTokensCache(pollId = null) {

  if (pollId == null) { //invalidate all tokens
    cachedTokenById.clear()
    tokenInvalidationTimeById.clear()
  }
  else {
    cachedTokenById.rawdelete(pollId)
    tokenInvalidationTimeById.rawdelete(pollId)
  }

  ::get_cur_gui_scene().performDelayed(this,
    function(){ ::broadcastEvent("WebPollTokenInvalidated", { pollId = pollId?.tostring() }) })
}

local function checkTokensCacheTimeout(pollId) {
  if((cachedTokenById?[pollId] ?? "") != ""
    && (tokenInvalidationTimeById?[pollId] ?? -1) < ::dagor.getCurTime())
    invalidateTokensCache(pollId)
}

local function getPollToken(pollId) {
  checkTokensCacheTimeout(pollId)
  return cachedTokenById?[pollId] ?? ""
}

local function getPollIdByFullUrl(url) {
  return pollIdByFullUrl?[url]
}

local function requestPolls() {
  local pollsForRequestByBaseUrl = {}
  foreach (pollId, baseUrl in pollBaseUrlById) {
    local pollIdInt = pollId.tointeger()
    if (canRequestAuthorization(pollIdInt)) {
      authorizedPollsRequestTimeOut[pollIdInt] <- ::dagor.getCurTime() + REQUEST_AUTHORIZATION_TIMEOUT_MS
      pollsForRequestByBaseUrl[baseUrl] <- (pollsForRequestByBaseUrl?[baseUrl] ?? []).append(pollIdInt)
    }
  }

  foreach (baseUrl, pollsArray in pollsForRequestByBaseUrl) {
    api.canVote($"{baseUrl}/api/v1/survey/can_vote/", pollsArray, onCanVoteResponse)
  }
}

local function generatePollUrl(pollId, needAuthorization = true) {
  local pollBaseUrl = getPollBaseUrl(pollId)
  if (pollBaseUrl == null)
    return ""

  local pollIdInt = pollId.tointeger()
  local cachedToken = getPollToken(pollIdInt)
  if (cachedToken == "") {
    if (needAuthorization && canRequestAuthorization(pollIdInt))
      requestPolls()
    return ""
  }

  if (authorizedPollsRequestTimeOut?[pollIdInt] == 0) {
    local url = ::loc("url/webpoll_url",
      { base_url = pollBaseUrl, survey_id = pollId, disposable_token = cachedToken })
    pollIdByFullUrl[url] <- pollId
    return url
  }

  return ""
}

local function isPollVoted(pollId) {
  return pollId in getVotedPolls()
}

local function clearOldVotedPolls(pollsTable) {
  local votedCount = getVotedPolls().paramCount() - 1
  for (local i = votedCount; i >= 0; i--) {
    local savedId = getVotedPolls().getParamName(i)
    if (!(savedId in pollsTable))
      set_blk_value_by_path(getVotedPolls(), savedId, null)
  }
  saveVotedPolls()
}

local function invalidateData() {
  votedPolls = null
  authorizedPollsRequestTimeOut.clear()
  invalidateTokensCache()
  pollIdByFullUrl.clear()
}

subscriptions.addListenersWithoutEnv({
  LoginComplete = @(p) invalidateData()
  SignOut = @(p) invalidateData()
}, ::g_listener_priority.CONFIG_VALIDATION)

web_rpc.register_handler("survey_vote_result", onSurveyVoteResult)

::webpoll_event <- function webpoll_event(id, token, voted) { //use in native code
  webpollEvent(id, token, voted)
}

return {
  setPollBaseUrl = setPollBaseUrl
  getPollIdByFullUrl = getPollIdByFullUrl
  generatePollUrl = generatePollUrl
  isPollVoted = isPollVoted
  clearOldVotedPolls = clearOldVotedPolls
  invalidateTokensCache = invalidateTokensCache
}
