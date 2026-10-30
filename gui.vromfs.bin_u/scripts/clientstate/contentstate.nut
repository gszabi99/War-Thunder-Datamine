from "contentpacks" import getContentPackStatus, ContentPackStatus
from "%scripts/dagui_natives.nut" import ps4_get_chunk_progress_percent, ps4_is_chunk_available
from "%sqstd/platform.nut" import is_ps5, is_gdk, is_ps4, is_xbox, is_sony, is_xbox_scarlett
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *
from "%scripts/crossModuleEvents.nut" import CONSOLE_PACKS_READY_CHANGED

let persistentData = mkHardPersist("clientState.contentState")("persistentData", {isConsoleClientFullOnStart = !is_xbox && !is_sony})

local isConsoleClientFullyDownloaded = @() true
local getClientDownloadProgressText = @() ""
local isHistoricalCampaignDownloading = @() false

let packsReady       = Watched({})

local requestContentReadyState = @(_chunk, cb) cb(true)
local requestContentInstall    = @(_chunk, cb = null) cb?(true)
local requestContentProgress   = @(_chunk, cb) cb(100)

let pkgToChunk = {}
let isConsoleContentPackCanBeChecked = @(packName) packName in pkgToChunk


function getSonyTotalProgress(chunks) {
  local downloaded = 0.0
  local total = 100.0 * chunks.len()
  foreach (chunk in chunks)
    downloaded += ps4_get_chunk_progress_percent(chunk)

  return 100 * (downloaded / total)
}

function getSonyProgressText(chunks) {
  let percent = getSonyTotalProgress(chunks)
  local text = [loc("msgbox/downloadPercent", { percent = percent })]
  if (percent >= 100)
    text.append("\n", loc("msgbox/relogin_required"))
  return "".join(text)
}


if (is_ps4) {
  const PS4_CHUNK_COCKPITS = 10
  const PS4_CHUNK_HQ_GENERIC = 19 
  const PS4_CHUNK_HQ_AIRCRAFT = 20
  const PS4_CHUNK_HQ_TANKS = 21
  const PS4_CHUNK_HQ_SHIPS = 22
  const PS4_CHUNK_HISTORICAL_CAMPAIGN = 11

  let fullClientChunks = [
    PS4_CHUNK_COCKPITS
    PS4_CHUNK_HQ_GENERIC
    PS4_CHUNK_HQ_AIRCRAFT
    PS4_CHUNK_HQ_TANKS
    PS4_CHUNK_HQ_SHIPS
  ]

  isConsoleClientFullyDownloaded = @() ps4_is_chunk_available(PS4_CHUNK_HQ_GENERIC)
  getClientDownloadProgressText = @() getSonyProgressText(fullClientChunks)
  isHistoricalCampaignDownloading = @() !ps4_is_chunk_available(PS4_CHUNK_HISTORICAL_CAMPAIGN)
}
else if (is_ps5) {
  const PS5_CHUNK_FULL_CLIENT = 1
  const PS5_CHUNK_HISTORICAL_CAMPAIGN = 2
  const PS5_INFANTRY_INSTALL_SCENARIO = 2
  const PS5_INFANTRY_STATUS_CHUNK = 3

  let { requestChunkStatus, requestScenarioInstall, requestChunkProgress, ChunkStatus
  } = require("sony.playgo")
  let { mkNativeResultReceiver } = require("%scripts/utils/nativeRequests.nut")
  const PLAYGO_RESULT_EVENT = "sonyPlayGoResult"
  let onPlayGoResult = mkNativeResultReceiver(PLAYGO_RESULT_EVENT)

  isConsoleClientFullyDownloaded = @() ps4_is_chunk_available(PS5_CHUNK_FULL_CLIENT)
  getClientDownloadProgressText = @() getSonyProgressText([PS5_CHUNK_FULL_CLIENT])
  isHistoricalCampaignDownloading = @() !ps4_is_chunk_available(PS5_CHUNK_HISTORICAL_CAMPAIGN)

  requestContentReadyState = @(chunk, cb) onPlayGoResult(requestChunkStatus(chunk, PLAYGO_RESULT_EVENT),
    @(status) cb(status == ChunkStatus.DOWNLOADED))
  requestContentInstall    = @(scenario, cb = null) onPlayGoResult(requestScenarioInstall(scenario, PLAYGO_RESULT_EVENT), cb)
  requestContentProgress   = @(chunk, cb) onPlayGoResult(requestChunkProgress(chunk, PLAYGO_RESULT_EVENT), cb)
  pkgToChunk.infantry <- { install = PS5_INFANTRY_INSTALL_SCENARIO, status = PS5_INFANTRY_STATUS_CHUNK }
}
else if (is_xbox) {
  isConsoleClientFullyDownloaded = @() getContentPackStatus("pkg_main") == ContentPackStatus.OK
  getClientDownloadProgressText = @() isConsoleClientFullyDownloaded()
      ? ("".concat(loc("download/finished"), "\n", loc("guiHints/restart_required")))
      : loc("download/inProgress")

  if (is_gdk && is_xbox_scarlett) { 
    let { is_feature_ready, install_feature, feature_progress } = require("%gdkLib/package.nut")
    requestContentReadyState = @(feature, cb) cb(is_feature_ready(feature))
    requestContentInstall    = @(feature, cb = null) cb ? cb(install_feature(feature)) : install_feature(feature)
    requestContentProgress   = @(feature, cb) cb(feature_progress(feature).percent)
    pkgToChunk.infantry <- { install = "Infantry", status = "Infantry" }
  }
}

let updateConsoleClientDownloadStatus = @() persistentData.isConsoleClientFullOnStart = isConsoleClientFullyDownloaded()

let isPackReadyCached = @(packName) packsReady.get()?[packName] ?? false

packsReady.subscribe(@(_) broadcastEvent(CONSOLE_PACKS_READY_CHANGED))

function setPackReady(packName, isReady) {
  if (packsReady.get()?[packName] == isReady)
    return

  packsReady.mutate(@(v) v[packName] <- isReady)
}

function refreshPacks(packNames = null, cb = null) {
  let toCheck = (packNames ?? pkgToChunk.keys()).filter(isConsoleContentPackCanBeChecked)
  if (toCheck.len() == 0) {
    cb?()
    return
  }

  local left = toCheck.len()
  foreach (packName in toCheck) {
    requestContentReadyState(pkgToChunk[packName].status, function(isReady) {
      setPackReady(packName, isReady)
      if (--left == 0)
        cb?()
    })
  }
}

function requestConsoleContentPackInstall(packName, cb = null) {
  if (isConsoleContentPackCanBeChecked(packName))
    requestContentInstall(pkgToChunk?[packName].install, cb)
}

function requestConsoleContentPackProgress(packName, cb) {
  if (!isConsoleContentPackCanBeChecked(packName)) {
    cb(100)
    return
  }

  requestContentProgress(pkgToChunk[packName].status, cb)
}


function gatherConsolePacksProgress(packNames, cb) {
  let toCheck = packNames.filter(isConsoleContentPackCanBeChecked)
  let result = {}
  if (toCheck.len() == 0) {
    cb(result)
    return
  }
  local left = toCheck.len()
  foreach (packName in toCheck)
    requestConsoleContentPackProgress(packName, function(percent) {
      result[packName] <- percent
      if (--left == 0)
        cb(result)
    })
}

return freeze({
  isConsoleClientFullyDownloaded = isConsoleClientFullyDownloaded
  updateConsoleClientDownloadStatus = updateConsoleClientDownloadStatus
  getConsoleClientDownloadStatusOnStart = @() persistentData.isConsoleClientFullOnStart
  getClientDownloadProgressText = getClientDownloadProgressText
  isHistoricalCampaignDownloading = isHistoricalCampaignDownloading

  isConsoleContentPackCanBeChecked
  isPackReadyCached
  refreshPacks
  requestConsoleContentPackInstall
  gatherConsolePacksProgress
})
