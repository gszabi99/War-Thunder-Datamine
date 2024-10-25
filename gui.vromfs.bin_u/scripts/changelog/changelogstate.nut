from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { get_base_game_version } = require("app")
let emptySceneWithDarg = require("%scripts/wndLib/emptySceneWithDarg.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { targetPlatform } = require("%scripts/clientState/platform.nut")
let { mkVersionFromString, versionToInt } = require("%sqstd/version.nut")
let { isInBattleState } = require("%scripts/clientState/clientStates.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { httpRequest, HTTP_SUCCESS } = require("dagor.http")
let { send_counter } = require("statsd")
let { get_time_msec } = require("dagor.time")
let { deferOnce } = require("dagor.workcycle")
let { parse_json } = require("json")
let { getCurLangShortName } = require("%scripts/langUtils/language.nut")
let { isNewbieInited, isMeNewbie } = require("%scripts/myStats.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")

const MSEC_BETWEEN_REQUESTS = 600000
const maxVersionsAmount = 5
const SAVE_SEEN_ID = "changelog/lastSeenVersionInfoNum"
const SAVE_LOADED_ID = "changelog/lastLoadedVersionNum"
let BASE_URL = getCurCircuitOverride("patchnotesURL", "https://newsfeed.gap.gaijin.net/api/patchnotes/warthunder/")
const PatchnoteIds = "PatchnoteIds"
const PatchnoteReceived = "PatchnoteReceived"

let ERROR_PAGE = {
  title = loc("matching/SERVER_ERROR_BAD_REQUEST")
  content = [ { v = loc("matching/SERVER_ERROR_INTERNAL") } ]
}
let chosenPatchnote = Watched(null)
let chosenPatchnoteLoaded = mkWatched(persist, "chosenPatchnoteLoaded", false)
let chosenPatchnoteContent = mkWatched(persist, "chosenPatchnoteContent", { title = "", text = "" })
let patchnotesReceived = mkWatched(persist, "patchnotesReceived", false)
let patchnotesCache = mkWatched(persist, "patchnotesCache", {})
let versions = mkWatched(persist, "versions", [])
let requestMadeTime = persist("requestMadeTime", @() { value = null })
let lastSeenVersionInfoNum = Watched(-1)
let lastLoadedVersionInfoNum = Watched(-1)

function loadSavedVersionInfoNum() {
  if (!::g_login.isProfileReceived())
    return

  lastSeenVersionInfoNum(loadLocalAccountSettings(SAVE_SEEN_ID, 0))
  lastLoadedVersionInfoNum(loadLocalAccountSettings(SAVE_LOADED_ID, 0))
}

let platformMap = {
  win32 = "pc"
  win64  = "pc"
}

function logError(event, params = {}) {
  local txt = $"{event}: "
  foreach (idx, p in params)
    if (type(p) == "string")
      txt = $"{txt} {idx} = {p}"
  log(txt)
  send_counter(event, 1, {
    exe_version = get_base_game_version()
    language = getCurLangShortName()
  }.__update(params))
}
let remapPlatform = @(v) platformMap?[v] ?? v

let getUrl = @(p = "")
  $"{BASE_URL}{getCurLangShortName()}{p}/?platform={remapPlatform(targetPlatform)}"

function mkVersion(v) {
  local tVersion = v?.version ?? ""
  let versionl = tVersion.split(".").len()
  local versionType = v?.type
  if (versionl != 4) {
    logError("changelog_versions_receive_errors",
      { reason = "Incorrect version", version = tVersion })
    if (versionl == 3) {
      tVersion = $"{tVersion}.0"
      if (versionType == null)
        versionType = "major"
    }
    else
      throw null
  }
  let version = mkVersionFromString(tVersion)
  let title = v?.title ?? tVersion
  local titleshort = v?.titleshort ?? "undefined"
  if (titleshort == "undefined" || utf8(titleshort).charCount() > 50)
    titleshort = null
  let date = v?.date ?? ""
  return { version, title, tVersion, versionType, titleshort,
    iVersion = versionToInt(version), id = v.id, date, customData = v?.customData }
}

function filterVersions(vers) {
  let res = []
  local foundMajor = false
  foreach (idx, version in vers) {
    if (idx >= maxVersionsAmount && foundMajor)
      break
    else if (version.versionType == "major") {
      res.append(version)
      foundMajor = true
    }
    else if (idx < maxVersionsAmount && !foundMajor) {
      res.append(version)
    }
  }
  return res
}

function processPatchnotesList(response) {
  let status = response?.status ?? -1
  let http_code = response?.http_code ?? -1
  if (status != HTTP_SUCCESS || http_code < 200 || 300 <= http_code) {
    logError("changelog_versions_receive_errors", {
      reason = "Error in version response"
      stage = "get_versions"
      http_code = response?.http_code
      status = status })
    return
  }
  local result = []
  try {
    result = response?.body ? parse_json(response.body.as_string())?.result ?? [] : []
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

function requestAllPatchnotes() {
  let currTimeMsec = get_time_msec()
  if (requestMadeTime.value
    && (currTimeMsec - requestMadeTime.value < MSEC_BETWEEN_REQUESTS))
    return

  let request = {
    method = "GET"
    url = getUrl()
    respEventId = PatchnoteIds
  }

  patchnotesReceived(false)
  httpRequest(request)
  requestMadeTime.value = currTimeMsec
}

function clearCache() {
  requestMadeTime.value = null
  patchnotesCache({})
}

function findBestVersionToshow(versionsList, lastSeenVersionNum) {
  //here we want to find first unseen Major version or last unseed hotfix version.
  lastSeenVersionNum = lastSeenVersionNum ?? 0
  versionsList = versionsList ?? []
  foreach (version in versionsList) {
    if (lastSeenVersionNum < version.iVersion && version.versionType == "major") {
      return version
    }
  }
  local res = null
  foreach (version in versionsList)
    if (version.iVersion > lastSeenVersionNum)
      res = version
    else
      break
  return res
}
let haveNewVersions = Computed(@() versions.value?[0].iVersion
  ? lastLoadedVersionInfoNum.value < versions.value[0].iVersion : false)
let unseenPatchnote = Computed(function() {
  if (lastSeenVersionInfoNum.value == -1)
    return null
  return findBestVersionToshow(versions.value, lastSeenVersionInfoNum.value)
})

let curPatchnote = Computed(@()
  chosenPatchnote.value ?? unseenPatchnote.value ?? versions.value?[0])
let curPatchnoteIdx = Computed(
  @() versions.value.findindex(@(inst) inst.id == curPatchnote.value.id) ?? 0)
let haveUnseenVersions = Computed(@() unseenPatchnote.value != null)
let needShowChangelog = @() !isInBattleState.value && hasFeature("Changelog")
  && haveNewVersions.value && isNewbieInited() && !isMeNewbie()

function afterGetRequestedPatchnote(result) {
  chosenPatchnoteContent({ title = result?.title ?? "", text = result?.content ?? [] })
  chosenPatchnoteLoaded(true)

  let v = curPatchnote.value
  if (v == null || v.iVersion <= lastSeenVersionInfoNum.value)
    return

  saveLocalAccountSettings(SAVE_SEEN_ID, v.iVersion)
  lastSeenVersionInfoNum(v.iVersion)
}

function cachePatchnote(response) {
  let status = response?.status ?? -1
  let http_code = response?.http_code ?? -1
  if (status != HTTP_SUCCESS || http_code < 200 || 300 <= http_code) {
    logError("changelog_receive_errors", {
      reason = "Error in patchnotes response"
      stage = "get_patchnote",
      http_code = http_code
      status = status
    })
    return
  }
  let result = parse_json((response?.body ?? "").as_string())?.result
  afterGetRequestedPatchnote(result ?? ERROR_PAGE)
  if (result == null) {
    logError("changelog_parse_errors",
      { reason = "Incorrect json in patchnotes response", stage = "get_patchnote" })
    return
  }
  logError("changelog_success_patchnote", { reason = "Patchnotes received successfully" })
  if (result?.id)
    patchnotesCache.mutate(@(value) value[result.id] <- result)
}

function requestPatchnote(v) {
  if (!v)
    return

  if (v.id in patchnotesCache.value) {
    return afterGetRequestedPatchnote(patchnotesCache.value[v.id])
  }
  let request = {
    method = "GET"
    url = getUrl($"/{v.id}")
  }
  request.respEventId <- PatchnoteReceived
  chosenPatchnoteLoaded(false)
  httpRequest(request)
}

function choosePatchnote(v) {
  if (!v)
    return
  requestPatchnote(v)
  chosenPatchnote(v)
}

function changePatchNote(delta = 1) {
  if (versions.value.len() == 0)
    return
  let nextIdx = clamp(curPatchnoteIdx.value - delta, 0, versions.value.len() - 1)
  let patchnote = versions.value[nextIdx]
  choosePatchnote(patchnote)
}

function openChangelog() {
  local curr = curPatchnote.value
  if (haveNewVersions.value) {
    curr = versions.value[0]
    saveLocalAccountSettings(SAVE_LOADED_ID, curr.iVersion)
    lastLoadedVersionInfoNum(curr.iVersion)
  }
  choosePatchnote(curr)
  emptySceneWithDarg({ widgetId = DargWidgets.CHANGE_LOG })
}

let canShowChangelog = @() handlersManager.findHandlerClassInScene(
  gui_handlers.MainMenu)?.isSceneActiveNoModals() ?? false

function openChangelogInActiveMainMenuImpl() {
  if (!canShowChangelog())
    return

  openChangelog()
}

function openChangelogInActiveMainMenuIfNeed() {
  if (!needShowChangelog() || !canShowChangelog())
    return

  deferOnce(openChangelogInActiveMainMenuImpl)
}

chosenPatchnoteContent.subscribe(@(value) eventbus_send("updateChosenPatchnoteContent", { value }))
versions.subscribe(@(value) eventbus_send("updateChangelogsVersions", { value }))
curPatchnote.subscribe(@(value) eventbus_send("updateCurPatchnote", { value }))
chosenPatchnoteLoaded.subscribe(function (value) {
  eventbus_send("updateChosenPatchnoteLoaded", { value })
  openChangelogInActiveMainMenuIfNeed()
})
patchnotesReceived.subscribe(function(value) {
  eventbus_send("updatePatchnotesReceived", { value })
  if (!value || !haveUnseenVersions.value)
    return
  requestPatchnote(curPatchnote.value)
})

addListenersWithoutEnv({
  ProfileReceived = @(_p) loadSavedVersionInfoNum()
  GameLocalizationChanged = function (_p) {
    clearCache()
    requestAllPatchnotes()
  }
  ActiveHandlersChanged = @(_) openChangelogInActiveMainMenuIfNeed()
})

loadSavedVersionInfoNum()

eventbus_subscribe("getChangeLogsStates", @(_) eventbus_send("updateChangeLogsStates", {
  versions = versions.value
  chosenPatchnoteContent = chosenPatchnoteContent.value
  curPatchnote = curPatchnote.value
  chosenPatchnoteLoaded = chosenPatchnoteLoaded.value
  patchnotesReceived = patchnotesReceived.value
}))
eventbus_subscribe("choosePatchnote", @(data) choosePatchnote(data.value))
eventbus_subscribe("changePatchNote", @(data) changePatchNote(data.delta))

eventbus_subscribe(PatchnoteIds, processPatchnotesList)
eventbus_subscribe(PatchnoteReceived, cachePatchnote)

return {
  openChangelog
  needShowChangelog
  requestAllPatchnotes
}
