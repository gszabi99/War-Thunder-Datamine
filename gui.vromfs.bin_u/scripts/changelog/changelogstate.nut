let emptySceneWithDarg = require("scripts/wndLib/emptySceneWithDarg.nut")
let { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
let { targetPlatform } = require("scripts/clientState/platform.nut")
let {mkVersionFromString, versionToInt} = require("std/version.nut")
let { isInBattleState } = require("scripts/clientState/clientStates.nut")
let eventbus = require("eventbus")
let http = require("dagor.http")
let { send_counter } = require("statsd")
let { get_time_msec } = require("dagor.time")

const MSEC_BETWEEN_REQUESTS = 600000
const maxVersionsAmount = 5
const SAVE_SEEN_ID = "changelog/lastSeenVersionInfoNum"
const SAVE_LOADED_ID = "changelog/lastLoadedVersionInfoNum"
const BASE_URL = "https://warthunder.com/"
const PatchnoteIds = "PatchnoteIds"
const PatchnoteReceived = "PatchnoteReceived"

let ERROR_PAGE = {
  title = ::loc("matching/SERVER_ERROR_BAD_REQUEST")
  content = {v = ::loc("matching/SERVER_ERROR_INTERNAL")}
}
let chosenPatchnote = ::Watched(null)
let chosenPatchnoteLoaded = persist("chosenPatchnoteLoaded", @()::Watched(false))
let chosenPatchnoteContent = persist("chosenPatchnoteContent",
  @()::Watched({title = "", text = ""}))
let patchnotesReceived = persist("patchnotesReceived", @()::Watched(false))
let patchnotesCache = persist("patchnotesCache", @() ::Watched({}))
let versions = persist("versions", @() ::Watched([]))
let requestMadeTime = persist("requestMadeTime", @() {value = null})
let lastSeenVersionInfoNum = ::Watched(-1)
let lastLoadedVersionInfoNum = ::Watched(-1)

let function loadSavedVersionInfoNum() {
  if (!::g_login.isProfileReceived())
    return

  lastSeenVersionInfoNum(::load_local_account_settings(SAVE_SEEN_ID, 0))
  lastLoadedVersionInfoNum(::load_local_account_settings(SAVE_LOADED_ID, 0))
}

let platformMap = {
  win32 = "pc"
  win64  ="pc"
}

let function logError(event, params = {}) {
  local txt = $"{event}: "
  foreach (idx, p in params)
    if (typeof(p) == "string")
      txt = $"{txt} {idx} = {p}"
  dagor.debug(txt)
  send_counter(event, 1, {
    exe_version = ::get_base_game_version()
    language = ::g_language.getShortName()
  }.__update(params))
}
let remapPlatform = @(v) platformMap?[v] ?? v

let getUrl = @(p)
  "".concat(BASE_URL, ::g_language.getShortName(), "/patchnotes/", p, "platform=",
    remapPlatform(targetPlatform), "&target=game")

let function mkVersion(v){
  local tVersion = v?.version ?? ""
  let versionl = tVersion.split(".").len()
  local versionType = v?.type
  if (versionl!=4) {
    logError("changelog_versions_receive_errors",
      { reason = "Incorrect version", version = tVersion })
    if (versionl==3) {
      tVersion = $"{tVersion}.0"
      if (versionType==null)
        versionType = "major"
    }
    else
      throw null
  }
  let version = mkVersionFromString(tVersion)
  let title = v?.title ?? tVersion
  local titleshort = v?.titleshort ?? "undefined"
  if (titleshort=="undefined" || titleshort.len() > 50 )
    titleshort = null
  let date = v?.date ?? ""
  return {version, title, tVersion, versionType, titleshort, iVersion = versionToInt(version), id = v.id, date }
}

let function filterVersions(vers){
  let res = []
  local foundMajor = false
  foreach (idx, version in vers){
    if (idx >= maxVersionsAmount && foundMajor)
      break
    else if (version.versionType=="major"){
      res.append(version)
      foundMajor=true
    }
    else if (idx < maxVersionsAmount && !foundMajor){
      res.append(version)
    }
  }
  return res
}

let function processPatchnotesList(response){
  let status = response?.status ?? -1
  let http_code = response?.http_code ?? -1
  if (status != http.SUCCESS || http_code < 200 || 300 <= http_code) {
    logError("changelog_versions_receive_errors", {
      reason = "Error in version response"
      stage = "get_versions"
      http_code = response?.http_code
      status = status })
    return
  }
  local result = []
  try {
    result = response?.body ? ::parse_json(response.body.as_string())?.result ?? [] : []
  }
  catch(e) {
  }
  if (result == null) {
    logError("changelog_versions_parse_errors",
      { reason = "Incorrect json in version response", stage = "get_versions" })
    versions([])
    patchnotesReceived(false)
    return
  }
  logError("changelog_success_versions", { reason = "Versions received successfully" })
  versions(filterVersions(result.map(mkVersion)))
  patchnotesReceived(true)
}

let function requestAllPatchnotes() {
  let currTimeMsec = get_time_msec()
  if(requestMadeTime.value
    && (currTimeMsec - requestMadeTime.value < MSEC_BETWEEN_REQUESTS))
    return

  let request = {
    method = "GET"
    url = getUrl("?page=1&")
  }

  request.respEventId <- PatchnoteIds
  patchnotesReceived(false)
  http.request(request)
  requestMadeTime.value = currTimeMsec
}

let function clearCache() {
  requestMadeTime.value = null
  patchnotesCache({})
}

local function findBestVersionToshow(versionsList, lastSeenVersionNum) {
  //here we want to find first unseen Major version or last unseed hotfix version.
  lastSeenVersionNum = lastSeenVersionNum ?? 0
  versionsList = versionsList ?? []
  foreach (version in versionsList) {
    if (lastSeenVersionNum < version.iVersion && version.versionType=="major"){
      return version
    }
  }
  local res = null
  foreach(version in versionsList)
    if (version.iVersion > lastSeenVersionNum)
      res = version
    else
      break
  return res
}
let haveNewVersions = ::Computed(@() versions.value?[0].iVersion
  ? lastLoadedVersionInfoNum.value < versions.value[0].iVersion : false)
let unseenPatchnote = ::Computed(function() {
  if (lastSeenVersionInfoNum.value == -1)
    return null
  return findBestVersionToshow(versions.value, lastSeenVersionInfoNum.value)
})

let curPatchnote = ::Computed(@()
  chosenPatchnote.value ?? unseenPatchnote.value ?? versions.value?[0])
let curPatchnoteIdx = ::Computed(
  @() versions.value.findindex(@(inst) inst.id == curPatchnote.value.id) ?? 0)
let haveUnseenVersions = ::Computed(@() unseenPatchnote.value != null)
let needShowChangelog = @() !isInBattleState.value && ::has_feature("Changelog")
  && haveNewVersions.value && !::my_stats.isMeNewbie()

let function afterGetRequestedPatchnote(result){
  chosenPatchnoteContent({title = result?.title ?? "", text = result?.content ?? []})
  chosenPatchnoteLoaded(true)

  let v = curPatchnote.value
  if (v == null || v.iVersion <= lastSeenVersionInfoNum.value)
    return

  ::save_local_account_settings(SAVE_SEEN_ID, v.iVersion)
  lastSeenVersionInfoNum(v.iVersion)
}

let function cachePatchnote(response){
  let status = response?.status ?? -1
  let http_code = response?.http_code ?? -1
  if (status != http.SUCCESS || http_code < 200 || 300 <= http_code) {
    logError("changelog_receive_errors", {
      reason = "Error in patchnotes response"
      stage = "get_patchnote",
      http_code = http_code
      status = status
    })
    return
  }
  let result = ::parse_json((response?.body ?? "").as_string())?.result
  afterGetRequestedPatchnote(result ?? ERROR_PAGE)
  if (result==null) {
    logError("changelog_parse_errors",
      { reason = "Incorrect json in patchnotes response", stage = "get_patchnote" })
    return
  }
  logError("changelog_success_patchnote", { reason = "Patchnotes received successfully" })
  if (result?.id)
    patchnotesCache.value[result.id] <- result
}

let function requestPatchnote(v = curPatchnote.value) {
  if (!v)
    return

  if (v.id in patchnotesCache.value) {
    return afterGetRequestedPatchnote(patchnotesCache.value[v.id])
  }
  let request = {
    method = "GET"
    url = getUrl($"patchnote/{v.id}?")
  }
  request.respEventId <- PatchnoteReceived
  chosenPatchnoteLoaded(false)
  http.request(request)
}

let function choosePatchnote(v) {
  if (!v)
    return
  requestPatchnote(v)
  chosenPatchnote(v)
}

let function changePatchNote(delta=1) {
  if (versions.value.len() == 0)
    return
  let nextIdx = clamp(curPatchnoteIdx.value-delta, 0, versions.value.len()-1)
  let patchnote = versions.value[nextIdx]
  choosePatchnote(patchnote)
}

let function openChangelog() {
  local curr = curPatchnote.value
  if(haveNewVersions.value)
  {
    curr = versions.value[0]
    let loadedVersionInfoNum = versionToInt(curr.tVersion)
    ::save_local_account_settings(SAVE_LOADED_ID, loadedVersionInfoNum)
    lastLoadedVersionInfoNum(loadedVersionInfoNum)
  }
  choosePatchnote(curr)
  emptySceneWithDarg({ widgetId = DargWidgets.CHANGE_LOG })
}

chosenPatchnoteContent.subscribe(@(value)
  ::call_darg("updateExtWatched", { chosenPatchnoteContent = value }))
versions.subscribe(@(value) ::call_darg("updateExtWatched", { changelogsVersions = value }))
curPatchnote.subscribe(@(value) ::call_darg("updateExtWatched", { curPatchnote = value }))
curPatchnoteIdx.subscribe(@(value) ::call_darg("updateExtWatched", { curPatchnoteIdx = value }))
chosenPatchnoteLoaded.subscribe(function (value) {
    ::call_darg("updateExtWatched", { chosenPatchnoteLoaded = value })
    if (needShowChangelog())
      openChangelog()
  })
patchnotesReceived.subscribe(function(value){
    ::call_darg("updateExtWatched", { patchnotesReceived = value })
    if (!value || !haveUnseenVersions.value)
      return
    requestPatchnote()
  })

addListenersWithoutEnv({
  ProfileReceived = @(p) loadSavedVersionInfoNum()
  GameLocalizationChanged = function (p) {
    clearCache()
    requestAllPatchnotes()
  }
})

::cross_call_api.changelog <- {
  getVersions = @() versions.value
  getChosenPatchnoteContent = @() chosenPatchnoteContent.value
  getCurPatchnote = @() curPatchnote.value
  getCurPatchnoteIdx = @() curPatchnoteIdx.value
  getChosenPatchnoteLoaded = @() chosenPatchnoteLoaded.value
  getPatchnotesReceived = @() patchnotesReceived.value
  choosePatchnote = choosePatchnote
  changePatchNote = changePatchNote
}

loadSavedVersionInfoNum()
eventbus.subscribe(PatchnoteIds, processPatchnotesList)
eventbus.subscribe(PatchnoteReceived, cachePatchnote)

return {
  openChangelog
  needShowChangelog
  requestAllPatchnotes
}
