local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { getCurLoadingBgData } = require("scripts/loading/loadingBgData.nut")

const BANNED_SCREENS_SAVE_ID = "preloaderOptions/bannedScreens"

local bannedScreens = {}
local isInited = false

local function initOnce()
{
  if (isInited || !::g_login.isProfileReceived())
    return

  isInited = true

  local blk = ::load_local_account_settings(BANNED_SCREENS_SAVE_ID, null)
  if (!blk)
    return

  bannedScreens = ::buildTableFromBlk(blk)

  // validation
  foreach (screenId, w in getCurLoadingBgData().list)
    if (screenId not in bannedScreens)
      return

  bannedScreens.rawdelete(getCurLoadingBgData().reserveBg)
  ::save_local_account_settings(BANNED_SCREENS_SAVE_ID, bannedScreens)
}

local function invalidateCache()
{
  bannedScreens.clear()
  isInited = false
}

local function toggleLoadingScreenBan(screenId)
{
  initOnce()
  if (!isInited)
    return

  if (screenId in bannedScreens)
    delete bannedScreens[screenId]
  else
    bannedScreens[screenId] <- true

  ::save_local_account_settings(BANNED_SCREENS_SAVE_ID, bannedScreens)
}

local function isLoadingScreenBanned(screenId)
{
  initOnce()
  return screenId in bannedScreens
}

addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
  GameLocalizationChanged = @(p) invalidateCache()
})

return {
  isLoadingScreenBanned
  toggleLoadingScreenBan
}