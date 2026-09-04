from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import isProfileReceived
from "%sqstd/underscore.nut" import isDataBlock
from "%sqstd/datablock.nut" import convertBlk
from "%scripts/dagui_library.nut" import *

let { GAME_LOCALIZATION_CHANGED } = require("%scripts/crossModuleEvents.nut")
let { getCurLoadingBgData } = require("%scripts/loading/loadingBgData.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")

const BANNED_SCREENS_SAVE_ID = "preloaderOptions/bannedScreens"

local bannedScreens = {}
local isInited = false

function initOnce() {
  if (isInited || !isProfileReceived.get())
    return

  isInited = true

  let blk = loadLocalAccountSettings(BANNED_SCREENS_SAVE_ID, null)
  if (!isDataBlock(blk))
    return

  bannedScreens = convertBlk(blk)

  
  foreach (screenId, _w in getCurLoadingBgData().list)
    if (screenId not in bannedScreens)
      return

  bannedScreens.$rawdelete(getCurLoadingBgData().reserveBg)
  saveLocalAccountSettings(BANNED_SCREENS_SAVE_ID, bannedScreens)
}

function invalidateCache() {
  bannedScreens.clear()
  isInited = false
}

function toggleLoadingScreenBan(screenId) {
  initOnce()
  if (!isInited)
    return

  if (screenId in bannedScreens)
    bannedScreens.$rawdelete(screenId)
  else
    bannedScreens[screenId] <- true

  saveLocalAccountSettings(BANNED_SCREENS_SAVE_ID, bannedScreens)
}

function isLoadingScreenBanned(screenId) {
  initOnce()
  return screenId in bannedScreens
}

addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache(),
  [GAME_LOCALIZATION_CHANGED] = @(_p) invalidateCache()
})

return {
  isLoadingScreenBanned
  toggleLoadingScreenBan
}