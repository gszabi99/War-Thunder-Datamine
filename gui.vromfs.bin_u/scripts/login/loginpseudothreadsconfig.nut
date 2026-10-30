import "%scripts/unlocks/checkUnlocksByAbTest.nut" as checkUnlocksByAbTest
from "%scripts/unit/unitsData.nut" import getAllUnits
from "%scripts/g_listener_priority.nut" import LOGIN_PROCESS
from "%scripts/utils/pseudoThread.nut" import startPseudoThread
from "%sqstd/platform.nut" import isSony, isXbox
from "%scripts/user/profileStates.nut" import userIdStr, havePlayerTag
from "%appGlobals/login/loginState.nut" import hasLoginState
from "%scripts/user/newbieTutorialDisplay.nut" import saveVersion
from "%scripts/clientState/contentState.nut" import updateConsoleClientDownloadStatus
from "%scripts/user/userInfoStats.nut" import getProfileInfo, updatePlayerRankByCountries
from "%scripts/slotbar/slotbarState.nut" import initSelectedCrews
from "%scripts/options/fontChoiceWnd.nut" import FontChoiceWnd
from "%scripts/options/firstGpuBenchmarkWnd.nut" import FirstGpuBenchmarkWnd
from "%scripts/firstChoice/unitTypeChoiceHandler.nut" import UnitTypeChoiceHandler
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/userLog/userlogUtils.nut" import shownUserlogNotifications, collectOldNotifications, collectUserlogItemdefs
from "%scripts/shop/shopTree.nut" import checkShopBlk
from "%scripts/firstChoice/firstChoice.nut" import reqFirstUnitTypeChoice, clearUnlockedCountries, checkUnlockedCountries, checkUnlockedCountriesByAirs
from "%scripts/eulaWnd.nut" import LOCAL_AGREED_EULA_VERSION_SAVE_ID, getEulaVersion, openEulaWnd, localAgreedEulaVersion
from "%appGlobals/clientState/localProfile.nut" import saveLocalSharedSettings, loadLocalSharedSettings, saveLocalAccountSettings, NEED_SHOW_GRAPHICS_AA_SETTINGS_MODIFIED
from "%scripts/bqQueue/bqQueue.nut" import sendBqEvent
from "%scripts/options/fxOptions.nut" import needShowHdrSettingsOnStart, openHdrSettings
from "%scripts/seen/markSeenResources.nut" import disableMarkSeenAllResourcesForNewUser
from "%scripts/matching/matchingGameModes.nut" import forceUpdateGameModes
from "%scripts/login/logout.nut" import startLogout
from "%scripts/slotbar/slotbarPresets.nut" import initSlotbarPresets
from "%scripts/discounts/discounts.nut" import updateDiscountData
from "%scripts/loadScriptsAfterLogin.nut" import loadScriptsAfterLoginOnce
from "%scripts/options/gpuBenchmarkUtils.nut" import needShowGpuBenchmark
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv
from "%globalScripts/clientState/initialState.nut" import disableNetwork
from "steam" import steam_is_running
from "steam_wt" import steam_process_dlc
from "sqEulaUtils" import getAgreedEulaVersion, setAgreedEulaVersion
from "gpuBenchmark" import isGpuBenchmarkRunning
from "%scripts/dagui_natives.nut" import run_reactive_gui, get_player_user_id_str, set_show_attachables
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE
from "%scripts/options/fonts.nut" import validateSavedConfigFonts
let { PT_STEP_STATUS } = require("%scripts/utils/pseudoThread.nut")
let { PRICE, ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")

let loginWTState = persist("loginWTState", @(){ initOptionsPseudoThread = null })

local isFirstLoginOnSystem = false

function requestLoginItemdefs() {
  collectUserlogItemdefs()
  let arr = []
  foreach (unit in getAllUnits())
    if (unit.marketplaceItemdefId != null)
      arr.append(unit.marketplaceItemdefId)

  inventoryClient.requestItemdefsByIds(arr)
}

function initLoginPseudoThreadsConfig(cb) {
  broadcastEvent("AuthorizeComplete")
  loadScriptsAfterLoginOnce()
  userIdStr.set(get_player_user_id_str())

  
  
  
  let { initOptionsSteps } = require("%scripts/options/initOptions.nut")
  loginWTState.initOptionsPseudoThread = [run_reactive_gui].extend(initOptionsSteps)
  loginWTState.initOptionsPseudoThread.append(
    function() {
      if (!hasLoginState(LOGIN_STATE.PROFILE_RECEIVED | LOGIN_STATE.CONFIGS_RECEIVED))
        return PT_STEP_STATUS.SUSPEND

      PRICE.checkUpdate()
      ENTITLEMENTS_PRICE.checkUpdate()
      return null
    }
    function() {
      updateConsoleClientDownloadStatus()
      getProfileInfo() 
      initSelectedCrews(true)
      set_show_attachables(true)

      validateSavedConfigFonts()
      if (handlersManager.checkPostLoadCss(true))
        log("Login: forced to reload waitforLogin window.")
      return null
    }
    function() {
      if (!hasLoginState(LOGIN_STATE.MATCHING_CONNECTED))
        return PT_STEP_STATUS.SUSPEND

      shownUserlogNotifications.mutate(@(v) v.clear())
      collectOldNotifications()
      return null
    }
    requestLoginItemdefs
    function() {
      updateDiscountData(true)
    }
    initSlotbarPresets
    function() {
      if (steam_is_running())
        steam_process_dlc()

      if (is_dev_version())
        checkShopBlk()

      updatePlayerRankByCountries()
    }
    function() {
      clearUnlockedCountries() 
      checkUnlockedCountries()
      checkUnlockedCountriesByAirs()

      if (reqFirstUnitTypeChoice())
        broadcastEvent("AccountReset")
    }
    function() {
      checkUnlocksByAbTest()
    }
    function() {
      let localSharedAgreedEulaVersion = loadLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, 0)
      isFirstLoginOnSystem = localSharedAgreedEulaVersion == 0
      if (disableNetwork)
        return
      let currentEulaVersion = getEulaVersion()
      let agreedEulaVersion = getAgreedEulaVersion()

      if (agreedEulaVersion >= currentEulaVersion) {
        if (localSharedAgreedEulaVersion < currentEulaVersion)
          saveLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, currentEulaVersion)
      } else {
        if ((isSony || isXbox || steam_is_running())
            && (agreedEulaVersion == 0 || localAgreedEulaVersion.get() >= currentEulaVersion)) {
          setAgreedEulaVersion(currentEulaVersion)
          if (agreedEulaVersion == 0)
            sendBqEvent("CLIENT_NEW_USER_1", "acceptEula", { details = "acceptEula" })
          sendBqEvent("CLIENT_GAMEPLAY_1", "eula_screen", "accept")
        } else {
          openEulaWnd({
            isForView = false
            isNewEulaVersion = agreedEulaVersion > 0
            doOnlyLocalSave = false
          })
        }
      }
    }
    function() {
      if (!disableNetwork && getAgreedEulaVersion() < getEulaVersion())
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function() {
      if (needShowHdrSettingsOnStart())
        openHdrSettings()
    }
    function() {
      if (needShowHdrSettingsOnStart())
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function() {
      if (isFirstLoginOnSystem && needShowGpuBenchmark())
        loadHandler(FirstGpuBenchmarkWnd)
    }
    function() {
      if (isGpuBenchmarkRunning())
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function() {
      if (reqFirstUnitTypeChoice()) {
        disableMarkSeenAllResourcesForNewUser()
        saveLocalAccountSettings(NEED_SHOW_GRAPHICS_AA_SETTINGS_MODIFIED, false)
        forceUpdateGameModes()
        loadHandler(UnitTypeChoiceHandler)
        FontChoiceWnd.markSeen()
        saveVersion()

        if(havePlayerTag("steamlogin"))
          saveLocalAccountSettings("disabledReloginSteamAccount", true)
      }
      else
        saveVersion(0)
    }
    function() {
      if (reqFirstUnitTypeChoice())
        return PT_STEP_STATUS.SUSPEND
      return null
    }
    function() {
      loginWTState.initOptionsPseudoThread = null
      cb()
    }
  )

  startPseudoThread(loginWTState.initOptionsPseudoThread, startLogout)
}

function clearLoginPseudoThreads() {
  if (loginWTState.initOptionsPseudoThread)
    loginWTState.initOptionsPseudoThread.clear()
}

addListenersWithoutEnv({
  SignOut = @(_) clearLoginPseudoThreads
}, LOGIN_PROCESS)

return freeze({
  initLoginPseudoThreadsConfig
  requestLoginItemdefs
})
