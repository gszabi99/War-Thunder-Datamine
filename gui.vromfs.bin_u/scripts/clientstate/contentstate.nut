from "%scripts/dagui_natives.nut" import ps4_get_chunk_progress_percent, ps4_is_chunk_available
from "%scripts/dagui_library.nut" import *

let { registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let platformModule = require("%scripts/clientState/platform.nut")

let { getContentPackStatus, ContentPackStatus } = require("contentpacks")

let persistentData = {
  isConsoleClientFullOnStart = !platformModule.isPlatformXboxOne && !platformModule.isPlatformSony
}
registerPersistentData("contentState", persistentData,
  ["isConsoleClientFullOnStart"])

local isConsoleClientFullyDownloaded = @() true
local getClientDownloadProgressText = @() ""
local isHistoricalCampaignDownloading = @() false


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


if (platformModule.isPlatformPS4) {
  let PS4_CHUNK_COCKPITS = 10
  let PS4_CHUNK_HQ_GENERIC = 19 // Downloaded last
  let PS4_CHUNK_HQ_AIRCRAFT = 20
  let PS4_CHUNK_HQ_TANKS = 21
  let PS4_CHUNK_HQ_SHIPS = 22
  let PS4_CHUNK_HISTORICAL_CAMPAIGN = 11

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
else if (platformModule.isPlatformPS5) {
  let PS5_CHUNK_FULL_CLIENT = 1
  let PS5_CHUNK_HISTORICAL_CAMPAIGN = 2

  isConsoleClientFullyDownloaded = @() ps4_is_chunk_available(PS5_CHUNK_FULL_CLIENT)
  getClientDownloadProgressText = @() getSonyProgressText([PS5_CHUNK_FULL_CLIENT])
  isHistoricalCampaignDownloading = @() !ps4_is_chunk_available(PS5_CHUNK_HISTORICAL_CAMPAIGN)
}
else if (platformModule.isPlatformXboxOne) {
  isConsoleClientFullyDownloaded = @() getContentPackStatus("pkg_main") == ContentPackStatus.OK
  getClientDownloadProgressText = @() isConsoleClientFullyDownloaded()
      ? ("".concat(loc("download/finished"), "\n", loc("msgbox/relogin_required")))
      : loc("download/inProgress")
}

let updateConsoleClientDownloadStatus = @() persistentData.isConsoleClientFullOnStart = isConsoleClientFullyDownloaded()

return {
  isConsoleClientFullyDownloaded = isConsoleClientFullyDownloaded
  updateConsoleClientDownloadStatus = updateConsoleClientDownloadStatus
  getConsoleClientDownloadStatusOnStart = @() persistentData.isConsoleClientFullOnStart
  getClientDownloadProgressText = getClientDownloadProgressText
  isHistoricalCampaignDownloading = isHistoricalCampaignDownloading
}
