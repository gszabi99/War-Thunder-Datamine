from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { setBlkValueByPath } = require("%globalScripts/dataBlockExt.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { broadcastEvent } = subscriptions
let api = require("dagor.webpoll")
let { get_time_msec } = require("dagor.time")
let DataBlock = require("DataBlock")
let { web_rpc } = require("%scripts/webRPC.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { isProfileReceived } = require("%appGlobals/login/loginState.nut")

const WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS = 3000000
const REQUEST_AUTHORIZATION_TIMEOUT_MS = 3600000
const VOTED_POLLS_SAVE_ID = "voted_polls"

let cachedTokenById = {}
let tokenInvalidationTimeById = {}
local votedPolls = null
let pollBaseUrlById = {}
let pollIdByFullUrl = {}
let authorizedPollsRequestTimeOut = {}  //0 when already authorized

function setPollBaseUrl(pollId, pollUrl) {
  if (!(pollId in pollBaseUrlById))
    pollBaseUrlById[pollId] <- pollUrl
}

function getPollBaseUrl(pollId) {
  return pollBaseUrlById?[pollId]
}

function canRequestAuthorization(pollId) {
  let requestTimeOut = authorizedPollsRequestTimeOut?[pollId]
  if (requestTimeOut == null)
    return true

  return requestTimeOut < get_time_msec()
}

function loadVotedPolls() {
  if (!isProfileReceived.get())
    return
  votedPolls = loadLocalAccountSettings(VOTED_POLLS_SAVE_ID, DataBlock())
}

function saveVotedPolls() {
  if (!isProfileReceived.get())
    return
  saveLocalAccountSettings(VOTED_POLLS_SAVE_ID, votedPolls)
}

function getVotedPolls() {
  if (!isProfileReceived.get())
    return DataBlock()
  if (votedPolls == null)
    loadVotedPolls()
  return votedPolls
}

function webpollEvent(id, token, voted) {
  id = to_integer_safe(id)
  if (!id || token == null)
    return

  cachedTokenById[id] <- token
  let isInvalidateToken = token == ""
  tokenInvalidationTimeById[id] <- isInvalidateToken ? -1
    : get_time_msec() + WEBPOLL_TOKENS_VALIDATION_TIMEOUT_MS
  authorizedPollsRequestTimeOut[id] <- isInvalidateToken ? null : 0

  let idString = id.tostring()
  if (voted) {
    setBlkValueByPath(getVotedPolls(), idString, true)
    saveVotedPolls()
  }
  broadcastEvent("WebPollAuthResult", { pollId = idString })
}

function onCanVoteResponse(response) {
  if (response?.status == "OK" && response?.data != null)
    foreach (id, data in response.data)
      if (data?.can_vote ?? false)
        webpollEvent(id, data?.disposable_token, data?.has_vote ?? false)
}

function onSurveyVoteResult(params) {
  webpollEvent(params.survey_id, "", params.has_vote)
}

function invalidateTokensCache(pollId = null) {

  if (pollId == null) { //invalidate all tokens
    cachedTokenById.clear()
    tokenInvalidationTimeById.clear()
  }
  else {
    cachedTokenById.$rawdelete(pollId)
    tokenInvalidationTimeById.$rawdelete(pollId)
  }

  get_cur_gui_scene().performDelayed(this,
    function() { broadcastEvent("WebPollTokenInvalidated", { pollId = pollId?.tostring() }) })
}

function checkTokensCacheTimeout(pollId) {
  if ((cachedTokenById?[pollId] ?? "") != ""
    && (tokenInvalidationTimeById?[pollId] ?? -1) < get_time_msec())
    invalidateTokensCache(pollId)
}

function getPollToken(pollId) {
  checkTokensCacheTimeout(pollId)
  return cachedTokenById?[pollId] ?? ""
}

function getPollIdByFullUrl(url) {
  return pollIdByFullUrl?[url]
}

function requestPolls() {
  let pollsForRequestByBaseUrl = {}
  foreach (pollId, baseUrl in pollBaseUrlById) {
    let pollIdInt = pollId.tointeger()
    if (canRequestAuthorization(pollIdInt)) {
      authorizedPollsRequestTimeOut[pollIdInt] <- get_time_msec() + REQUEST_AUTHORIZATION_TIMEOUT_MS
      pollsForRequestByBaseUrl[baseUrl] <- (pollsForRequestByBaseUrl?[baseUrl] ?? []).append(pollIdInt)
    }
  }

  foreach (baseUrl, pollsArray in pollsForRequestByBaseUrl) {
    api.canVote($"{baseUrl}/api/v1/survey/can_vote/", pollsArray, onCanVoteResponse)
  }
}

function generatePollUrl(pollId, needAuthorization = true) {
  let pollBaseUrl = getPollBaseUrl(pollId)
  if (pollBaseUrl == null)
    return ""

  let pollIdInt = pollId.tointeger()
  let cachedToken = getPollToken(pollIdInt)
  if (cachedToken == "") {
    if (needAuthorization && canRequestAuthorization(pollIdInt))
      requestPolls()
    return ""
  }

  if (authorizedPollsRequestTimeOut?[pollIdInt] == 0) {
    let url = loc("url/webpoll_url",
      { base_url = pollBaseUrl, survey_id = pollId, disposable_token = cachedToken })
    pollIdByFullUrl[url] <- pollId
    return url
  }

  return ""
}

function isPollVoted(pollId) {
  return pollId in getVotedPolls()
}

function clearOldVotedPolls(pollsTable) {
  let votedCount = getVotedPolls().paramCount() - 1
  for (local i = votedCount; i >= 0; i--) {
    let savedId = getVotedPolls().getParamName(i)
    if (!(savedId in pollsTable))
      setBlkValueByPath(getVotedPolls(), savedId, null)
  }
  saveVotedPolls()
}

function invalidateData() {
  votedPolls = null
  authorizedPollsRequestTimeOut.clear()
  invalidateTokensCache()
  pollIdByFullUrl.clear()
}

subscriptions.addListenersWithoutEnv({
  LoginComplete = @(_p) invalidateData()
  SignOut = @(_p) invalidateData()
}, g_listener_priority.CONFIG_VALIDATION)

web_rpc.register_handler("survey_vote_result", onSurveyVoteResult)

return {
  setPollBaseUrl
  getPollIdByFullUrl
  generatePollUrl
  isPollVoted
  clearOldVotedPolls
  invalidateTokensCache
}
