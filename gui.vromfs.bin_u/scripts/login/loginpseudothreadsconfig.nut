from "%scripts/dagui_natives.nut" import run_reactive_gui, get_player_user_id_str, set_show_attachables, disable_network
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE

let { LOGIN_PROCESS } = require("%scripts/g_listener_priority.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { deferOnce } = require("dagor.workcycle")
let { steam_is_running } = require("steam")
let { steam_process_dlc } = require("steam_wt")
let { getAgreedEulaVersion, setAgreedEulaVersion } = require("sqEulaUtils")
let { PT_STEP_STATUS, startPseudoThread } = require("%scripts/utils/pseudoThread.nut")
let { isPlatformSony, isPlatformXboxOne
} = require("%scripts/clientState/platform.nut")
let { userIdStr, havePlayerTag } = require("%scripts/user/profileStates.nut")
let { hasLoginState } = require("%scripts/login/loginStates.nut")
let { PRICE, ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let tutorialModule = require("%scripts/user/newbieTutorialDisplay.nut")
let { updateConsoleClientDownloadStatus } = require("%scripts/clientState/contentState.nut")
let checkUnlocksByAbTest = require("%scripts/unlocks/checkUnlocksByAbTest.nut")
let { getProfileInfo, updatePlayerRankByCountries } = require("%scripts/user/userInfoStats.nut")
let { initSelectedCrews } = require("%scripts/slotbar/slotbarState.nut")
let g_font = require("%scripts/options/fonts.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { shownUserlogNotifications, collectOldNotifications } = require("%scripts/userLog/userlogUtils.nut")
let { checkBadWeapons } = require("%scripts/weaponry/weaponryInfo.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { checkShopBlk } = require("%scripts/shop/shopTree.nut")
let { isNeedFirstCountryChoice, clearUnlockedCountries, checkUnlockedCountries,
  checkUnlockedCountriesByAirs } = require("%scripts/firstChoice/firstChoice.nut")
let { LOCAL_AGREED_EULA_VERSION_SAVE_ID, getEulaVersion, openEulaWnd, localAgreedEulaVersion } = require("%scripts/eulaWnd.nut")
let { saveLocalSharedSettings, loadLocalSharedSettings, saveLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { needShowHdrSettingsOnStart, openHdrSettings } = require("%scripts/options/fxOptions.nut")
let { disableMarkSeenAllResourcesForNewUser } = require("%scripts/seen/markSeenResources.nut")
let { forceUpdateGameModes } = require("%scripts/matching/matchingGameModes.nut")
let { startLogout } = require("%scripts/login/logout.nut")

let loginWTState = persist("loginWTState", @(){ initOptionsPseudoThread = null, shouldRestartPseudoThread = true})

function initLoginPseudoThreadsConfig(cb) {
  broadcastEvent("AuthorizeComplete")
  ::load_scripts_after_login_once()
  run_reactive_gui()
  userIdStr.set(get_player_user_id_str())

  loginWTState.initOptionsPseudoThread = [].extend(::init_options_steps)
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
      getProfileInfo() //update userName
      initSelectedCrews(true)
      set_show_attachables(hasFeature("AttachablesUse"))

      g_font.validateSavedConfigFonts()
      if (handlersManager.checkPostLoadCss(true))
        log("Login: forced to reload waitforLogin window.")
      return null
    }
    function() {
      if (!hasLoginState(LOGIN_STATE.MATCHING_CONNECTED))
        return PT_STEP_STATUS.SUSPEND

      shownUserlogNotifications.mutate(@(v) v.clear())
      collectOldNotifications()
      checkBadWeapons()
      return null
    }
    function() {
      ::ItemsManager.collectUserlogItemdefs()
      let arr = []
      foreach (unit in getAllUnits())
        if (unit.marketplaceItemdefId != null)
          arr.append(unit.marketplaceItemdefId)

      ::ItemsManager.requestItemsByItemdefIds(arr)
    }
    function() {
      ::g_discount.updateDiscountData(true)
    }
    function() {
     ::slotbarPresets.init()
    }
    function() {
      if (steam_is_running())
        steam_process_dlc()

      if (is_dev_version())
        checkShopBlk()

      updatePlayerRankByCountries()
    }
    function() {
      clearUnlockedCountries() //reinit countries
      checkUnlockedCountries()
      checkUnlockedCountriesByAirs()

      if (isNeedFirstCountryChoice())
        broadcastEvent("AccountReset")
    }
    function() {
      checkUnlocksByAbTest()
    }
    function() {
      if (disable_network())
        return
      let currentEulaVersion = getEulaVersion()
      let agreedEulaVersion = getAgreedEulaVersion()

      if (agreedEulaVersion >= currentEulaVersion) {
        if (loadLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, 0) < currentEulaVersion)
          saveLocalSharedSettings(LOCAL_AGREED_EULA_VERSION_SAVE_ID, currentEulaVersion)
      } else {
        if ((isPlatformSony || isPlatformXboxOne || steam_is_running())
            && (agreedEulaVersion == 0 || localAgreedEulaVersion.value >= currentEulaVersion)) {
          setAgreedEulaVersion(currentEulaVersion)
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
      if (!disable_network() && getAgreedEulaVersion() < getEulaVersion())
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
      if (isNeedFirstCountryChoice()) {
        disableMarkSeenAllResourcesForNewUser()
        forceUpdateGameModes()
        loadHandler(gui_handlers.CountryChoiceHandler)
        gui_handlers.FontChoiceWnd.markSeen()
        tutorialModule.saveVersion()

        if(havePlayerTag("steamlogin"))
          saveLocalAccountSettings("disabledReloginSteamAccount", true)
      }
      else
        tutorialModule.saveVersion(0)
    }
    function() {
      if (isNeedFirstCountryChoice())
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

function startLoginPseudoThread() {
  handlersManager.loadHandler(gui_handlers.WaitForLoginWnd)
  startPseudoThread(loginWTState.initOptionsPseudoThread, startLogout)
}

function clearLoginPseudoThreads() {
  if (loginWTState.initOptionsPseudoThread)
    loginWTState.initOptionsPseudoThread.clear()
}

function restartLoginPseudoThreads() {
  if (loginWTState.initOptionsPseudoThread)
    loginWTState.shouldRestartPseudoThread = true
}

addListenersWithoutEnv({
  function GuiSceneCleared(_) {
    //work only after scripts reload
    if (!loginWTState.shouldRestartPseudoThread)
      return
    loginWTState.shouldRestartPseudoThread = false
    if (!loginWTState.initOptionsPseudoThread)
      return

    deferOnce(startLoginPseudoThread)
  }
  SignOut = @(_) clearLoginPseudoThreads
}, LOGIN_PROCESS)

return {
  initLoginPseudoThreadsConfig
  restartLoginPseudoThreads
}
