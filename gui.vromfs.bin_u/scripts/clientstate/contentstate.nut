local platformModule = require("scripts/clientState/platform.nut")

local PS4_CHUNK_FULL_CLIENT_DOWNLOADED = 19
local PS4_CHUNK_HISTORICAL_CAMPAIGN = 11

local persistentData = {
  isConsoleClientFullOnStart = !platformModule.isPlatformXboxOne && !platformModule.isPlatformPS4
}
::g_script_reloader.registerPersistentData("contentState", persistentData,
  ["isConsoleClientFullOnStart"])

local isConsoleClientFullyDownloaded = @() true
local getClientDownloadProgressText = @() ""
local isHistoricalCampaignDownloading = @() false
if (platformModule.isPlatformPS4)
{
  isConsoleClientFullyDownloaded = @() ::ps4_is_chunk_available(PS4_CHUNK_FULL_CLIENT_DOWNLOADED)
  getClientDownloadProgressText = function() {
    local percent = ::ps4_get_chunk_progress_percent(PS4_CHUNK_FULL_CLIENT_DOWNLOADED)
    local text = ::loc("msgbox/downloadPercent", {percent = percent})
    if (percent == 100)
      text += "\n" + ::loc("msgbox/relogin_required")
    return text
  }

  isHistoricalCampaignDownloading = @() !::ps4_is_chunk_available(PS4_CHUNK_HISTORICAL_CAMPAIGN)
}
else if (platformModule.isPlatformXboxOne)
{
  isConsoleClientFullyDownloaded = @() ::package_get_status("pkg_main") == ::PACKAGE_STATUS_OK
  getClientDownloadProgressText = @() isConsoleClientFullyDownloaded()
      ? (::loc("download/finished") + "\n" + ::loc("msgbox/relogin_required"))
      : ::loc("download/inProgress")
}

local updateConsoleClientDownloadStatus = @() persistentData.isConsoleClientFullOnStart = isConsoleClientFullyDownloaded()

return {
  isConsoleClientFullyDownloaded = isConsoleClientFullyDownloaded
  updateConsoleClientDownloadStatus = updateConsoleClientDownloadStatus
  getConsoleClientDownloadStatusOnStart = @() persistentData.isConsoleClientFullOnStart
  getClientDownloadProgressText = getClientDownloadProgressText
  isHistoricalCampaignDownloading = isHistoricalCampaignDownloading
}
