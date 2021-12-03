local emptySceneWithDarg = require("scripts/wndLib/emptySceneWithDarg.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { targetPlatform } = require("scripts/clientState/platform.nut")
local {mkVersionFromString, versionToInt} = require("std/version.nut")
local { isInBattleState } = require("scripts/clientState/clientStates.nut")
local eventbus = require("eventbus")
local http = require("dagor.http")
local json = require("json")
local { send_counter } = require("statsd")
local { get_time_msec } = require("dagor.time")

const MSEC_BETWEEN_REQUESTS = 600000
const maxVersionsAmount = 5
const SAVE_SEEN_ID = "changelog/lastSeenVersionInfoNum"
const SAVE_LOADED_ID = "changelog/lastLoadedVersionInfoNum"
const BASE_URL = "https://warthunder.com/"
const PatchnoteIds = "PatchnoteIds"
const PatchnoteReceived = "PatchnoteReceived"

local chosenPatchnote = ::Watched(null)
local chosenPatchnoteLoaded = persist("chosenPatchnoteLoaded", @()::Watched(false))
local chosenPatchnoteContent = persist("chosenPatchnoteContent",
  @()::Watched({title = "", text = ""}))
local patchnotesReceived = persist("patchnotesReceived", @()::Watched(false))
local patchnotesCache = persist("patchnotesCache", @() ::Watched({}))
local versions = persist("versions", @() ::Watched([]))
local requestMadeTime = persist("requestMadeTime", @() {value = null})
local lastSeenVersionInfoNum = ::Watched(-1)
local lastLoadedVersionInfoNum = ::Watched(-1)

local function loadSavedVersionInfoNum() {
  if (!::g_login.isProfileReceived())
    return

  lastSeenVersionInfoNum(::load_local_account_settings(SAVE_SEEN_ID, 0))
  lastLoadedVersionInfoNum(::load_local_account_settings(SAVE_LOADED_ID, 0))
}

local platformMap = {
  win32 = "pc"
  win64  ="pc"
}

local function logError(event, params = {}) {
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
local remapPlatform = @(v) platformMap?[v] ?? v

local getUrl = @(p)
  "".concat(BASE_URL, ::g_language.getShortName(), "/patchnotes/", p, "platform=",
    remapPlatform(targetPlatform), "&target=game")

local function mkVersion(v){
  local tVersion = v?.version ?? ""
  local versionl = tVersion.split(".").len()
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
  local version = mkVersionFromString(tVersion)
  local title = v?.title ?? tVersion
  local titleshort = v?.titleshort ?? "undefined"
  if (titleshort=="undefined" || titleshort.len() > 50 )
    titleshort = null
  local date = v?.date ?? ""
  return {version, title, tVersion, versionType, titleshort, iVersion = versionToInt(version), id = v.id, date }
}

local function filterVersions(vers){
  local res = []
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

local function processPatchnotesList(response){
  local status = response?.status ?? -1
  local http_code = response?.http_code ?? -1
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
    result = response?.body ? json.parse(response.body.tostring())?.result ?? [] : []
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

local function requestAllPatchnotes() {
  local currTimeMsec = get_time_msec()
  if(requestMadeTime.value
    && (currTimeMsec - requestMadeTime.value < MSEC_BETWEEN_REQUESTS))
    return

  local request = {
    method = "GET"
    url = getUrl("?page=1&")
  }

  request.respEventId <- PatchnoteIds
  patchnotesReceived(false)
  http.request(request)
  requestMadeTime.value = currTimeMsec
}

local function clearCache() {
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
local haveNewVersions = ::Computed(@() versions.value?[0].iVersion
  ? lastLoadedVersionInfoNum.value < versions.value[0].iVersion : false)
local unseenPatchnote = ::Computed(function() {
  if (lastSeenVersionInfoNum.value == -1)
    return null
  return findBestVersionToshow(versions.value, lastSeenVersionInfoNum.value)
})

local curPatchnote = ::Computed(@()
  chosenPatchnote.value ?? unseenPatchnote.value ?? versions.value?[0])
local curPatchnoteIdx = ::Computed(
  @() versions.value.findindex(@(inst) inst.iVersion == curPatchnote.value.iVersion) ?? 0)
local haveUnseenVersions = ::Computed(@() unseenPatchnote.value != null)
local needShowChangelog = @() !isInBattleState.value && ::has_feature("Changelog")
  && haveNewVersions.value && !::my_stats.isMeNewbie()

local function afterGetRequestedPatchnote(result){
  chosenPatchnoteContent({title = result?.title ?? "", text = result?.content ?? []})
  chosenPatchnoteLoaded(true)

  local v = curPatchnote.value
  if (v == null || v.iVersion <= lastSeenVersionInfoNum.value)
    return

  ::save_local_account_settings(SAVE_SEEN_ID, v.iVersion)
  lastSeenVersionInfoNum(v.iVersion)
}

local function cachePatchnote(response){
  local status = response?.status ?? -1
  local http_code = response?.http_code ?? -1
  if (status != http.SUCCESS || http_code < 200 || 300 <= http_code) {
    logError("changelog_receive_errors", {
      reason = "Error in patchnotes response"
      stage = "get_patchnote",
      http_code = http_code
      status = status
    })
    return
  }
  local result = json.parse((response?.body ?? "").tostring())?.result
  if (result==null) {
    logError("changelog_parse_errors",
      { reason = "Incorrect json in patchnotes response", stage = "get_patchnote" })
    return
  }
  afterGetRequestedPatchnote(result)
  logError("changelog_success_patchnote", { reason = "Patchnotes received successfully" })
  if (result?.id)
    patchnotesCache.value[result.id] <- result
}

local function requestPatchnote(v = curPatchnote.value) {
  if (!v)
    return

  if (v.id in patchnotesCache.value) {
    return afterGetRequestedPatchnote(patchnotesCache.value[v.id])
  }
  local request = {
    method = "GET"
    url = getUrl($"patchnote/{v.id}?")
  }
  request.respEventId <- PatchnoteReceived
  chosenPatchnoteLoaded(false)
  http.request(request)
}

local function choosePatchnote(v) {
  if (!v)
    return
  requestPatchnote(v)
  chosenPatchnote(v)
}

local function changePatchNote(delta=1) {
  if (versions.value.len() == 0)
    return
  local nextIdx = clamp(curPatchnoteIdx.value-delta, 0, versions.value.len()-1)
  local patchnote = versions.value[nextIdx]
  choosePatchnote(patchnote)
}

local function openChangelog() {
  local curr = curPatchnote.value
  if(haveNewVersions.value)
  {
    curr = versions.value[0]
    local loadedVersionInfoNum = versionToInt(curr.tVersion)
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
