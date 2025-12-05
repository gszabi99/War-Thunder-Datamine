from "%scripts/dagui_natives.nut" import dgs_get_argv, get_cur_circuit_name, load_local_settings, enable_keyboard_layout_change_tracking, is_steam_big_picture, enable_keyboard_locks_change_tracking, set_network_circuit
from "%scripts/dagui_library.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE, USE_STEAM_LOGIN_AUTO_SETTING_ID
from "%scripts/options/optionsCtors.nut" import create_option_combobox
from "chard" import save_profile

let { platformId } = require("%sqstd/platform.nut")
let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { get_disable_autorelogin_once, set_disable_autorelogin_once } = require("loginState.nut")
let { getLocalLanguage } = require("language")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let statsd = require("statsd")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let twoStepModal = require("%scripts/login/twoStepModal.nut")
let exitGamePlatform = require("%scripts/utils/exitGamePlatform.nut")
let { select_editbox, setFocusToNextObj, getObjValue } = require("%sqDagui/daguiUtil.nut")
let { setGuiOptionsMode } = require("guiOptions")
let { getDistr, convertExternalJwtToAuthJwt, getLoginPass, getTwoStepCodeAsync2,
  checkLoginPass, setLoginPass, getPlayerTagsGlobalStr } = require("auth_wt")
let { dgs_get_settings } = require("dagor.system")
let { get_user_system_info } = require("sysinfo")
let regexp2 = require("regexp2")
let { register_command } = require("console")
let { isNamePassing } = require("%scripts/dirtyWordsFilter.nut")
let { validateEmail } = require("%sqstd/string.nut")
let { eventbus_subscribe } = require("eventbus")
let { isPlatformShieldTv } = require("%scripts/clientState/platform.nut")
let { saveLocalSharedSettings, loadLocalSharedSettings
} = require("%scripts/clientState/localProfile.nut")
let { OPTIONS_MODE_GAMEPLAY } = require("%scripts/options/optionsExtNames.nut")
let { getGameLocalizationInfo, setGameLocalization, canSwitchGameLocalization, getCurLangShortName
} = require("%scripts/langUtils/language.nut")
let { get_network_block } = require("blkGetters")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { steam_is_running } = require("steam")
let { havePlayerTag } = require("%scripts/user/profileStates.nut")
let { bqSendNoAuth, bqSendNoAuthWeb } = require("%scripts/bigQuery/bigQueryClient.nut")
let { webauth_start, webauth_stop, webauth_get_url, webauth_completion_event } = require("webauth")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")
let { close_browser_modal, browser_set_external_url } = require("%scripts/onlineShop/browserWndActions.nut")
let { addLoginState } = require("%scripts/login/loginManager.nut")
let { set_autologin_enabled, is_autologin_enabled } = require("%scripts/options/optionsBeforeLogin.nut")
let { setProjectAwards } = require("%scripts/viewUtils/projectAwards.nut")
let { showErrorMessageBox } = require("%scripts/utils/errorMsgBox.nut")

const MAX_GET_2STEP_CODE_ATTEMPTS = 10
const GUEST_LOGIN_SAVE_ID = "guestLoginId"
const MIGRATION_URL = "migration.warthunder.com"

let validateNickRegexp = regexp2(@"[^_0-9a-zA-Z]")

local dbgGuestLoginIdPrefix = ""

function getGuestLoginId() {
  let { uuid0 = "", uuid1 = "", uuid2 = "" } = get_user_system_info()
  return $"{dbgGuestLoginIdPrefix}{uuid0}_{uuid1}_{uuid2}"
}

function setDbgGuestLoginIdPrefix(prefix) {
  dbgGuestLoginIdPrefix = $"{prefix}_"
  console_print(getGuestLoginId())
}
register_command(setDbgGuestLoginIdPrefix, "debug.set_guest_login_id_prefix")

function isExternalOperator() {
  return getCurCircuitOverride("operatorName") != null
}

function isPlayerProfileMoved() {
  return havePlayerTag("extop_wt")
}

let isMigratedAccount = @() havePlayerTag("migrated_from_gj")

function haveNotMovedProfile() {
  let globalTags = getPlayerTagsGlobalStr().split(";")
  return !globalTags.contains("extop_wt")
    && (globalTags.contains("player_wt") || globalTags.contains("customer_wt"))
}

function isShowMessageAboutProfileMoved() {
  let isExtOperator = isExternalOperator()
  if (!isExtOperator && !isPlayerProfileMoved())
    return false

  if (isExtOperator && (!isMigratedAccount() || !haveNotMovedProfile()))
    return false

  scene_msg_box("errorMessageBox", get_gui_scene(),
    "\n".concat(loc("msgbox/error_login_migrated_player_profile"), $"<url={MIGRATION_URL}>{MIGRATION_URL}</url>"),
    [["exit", exitGamePlatform], ["tryAgain", @() null]], "tryAgain", { cancel_fn = @() null })
  return true
}

gui_handlers.LoginWndHandler <- class (BaseGuiHandler) {
  sceneBlkName = "%gui/loginBox.blk"

  check2StepAuthCode = false
  availableCircuitsBlockName = "multipleAvailableCircuits"
  paramName = "circuit"
  shardItems = null
  localizationInfo = null

  initial_autologin = false
  stoken = "" 
  was_using_stoken = false
  isLoginRequestInprogress = false
  requestGet2stepCodeAtempt = 0
  isSteamAuth = false
  isGuestLogin = false

  defaultSaveLoginFlagVal = false
  defaultSavePasswordFlagVal = false
  defaultSaveAutologinFlagVal = false

  tabFocusArray = [
    "loginbox_username",
    "loginbox_password"
  ]

  function initScreen() {
    animBgLoad()
    setVersionText()
    setProjectAwards(this)
    showTitleLogo(this.scene, 128)
    this.initLanguageSwitch()
    this.checkShardingCircuits()
    setGuiOptionsMode(OPTIONS_MODE_GAMEPLAY)

    enable_keyboard_layout_change_tracking(true)
    enable_keyboard_locks_change_tracking(true)

    let bugDiscObj = this.scene.findObject("browser_bug_disclaimer")
    if (checkObj(bugDiscObj))
      bugDiscObj.show(platformId == "linux64" && is_steam_big_picture()) 

    let lp = getLoginPass()
    let disableSSLCheck = lp.autoSave & AUTO_SAVE_FLG_NOSSLCERT

    let unObj = this.scene.findObject("loginbox_username")
    if (checkObj(unObj))
      unObj.setValue(lp.login)

    let psObj = this.scene.findObject("loginbox_password")
    if (checkObj(psObj)) {
      psObj["password-smb"] = loc("password_mask_char", "*")
      psObj.setValue(lp.password)
    }

    let alObj = this.scene.findObject("loginbox_autosave_login")
    if (checkObj(alObj))
      alObj.setValue(lp.autoSave & AUTO_SAVE_FLG_LOGIN)

    let spObj = this.scene.findObject("loginbox_autosave_password")
    if (checkObj(spObj)) {
      spObj.show(true)
      spObj.setValue(lp.autoSave & AUTO_SAVE_FLG_PASS)
      spObj.enable((lp.autoSave & AUTO_SAVE_FLG_LOGIN) != 0 )
      local text = loc("mainmenu/savePassword")
      if (!isPlatformShieldTv())
        text = " ".concat(text, loc("mainmenu/savePassword/unsecure"))
      spObj.findObject("loginbox_autosave_password_text").setValue(text)
    }

    this.setDisableSslCertBox(disableSSLCheck)
    let isSteamRunning = steam_is_running()
    let showSteamLogin = isSteamRunning
    let showWebLogin = !isSteamRunning && webauth_start()
    showObjById("steam_login_action_button", showSteamLogin, this.scene)
    showObjById("sso_login_action_button", showWebLogin, this.scene)
    showObjById("btn_signUp_link", !showSteamLogin, this.scene)

    this.initial_autologin = is_autologin_enabled()

    let saveLoginAndPassMask = AUTO_SAVE_FLG_LOGIN | AUTO_SAVE_FLG_PASS
    let autoLoginEnable = (lp.autoSave & saveLoginAndPassMask) == saveLoginAndPassMask
    local autoLogin = (this.initial_autologin && autoLoginEnable) || (dgs_get_settings()?.yunetwork.forceAutoLogin ?? false)
    let autoLoginObj = this.scene.findObject("loginbox_autologin")
    if (checkObj(autoLoginObj)) {
      autoLoginObj.show(true)
      autoLoginObj.enable(autoLoginEnable)
      autoLoginObj.setValue(autoLogin)
    }

    let isVisibleLinks = !isPlatformShieldTv()
    let linksObj = showObjById("links_block", isVisibleLinks, this.scene)
    if (isVisibleLinks && (linksObj?.isValid() ?? false)) {
      linksObj.findObject("btn_faq_link").link = getCurCircuitOverride("faqURL", loc("url/faq"))
      linksObj.findObject("btn_support_link").link = getCurCircuitOverride("supportURL", loc("url/support"))
    }

    let s = dgs_get_argv("stoken")
    if (!u.isEmpty(s))
      lp.stoken <- s

    if (("stoken" in lp) && lp.stoken != null && lp.stoken != "") {
      this.stoken = lp.stoken
      this.doLoginDelayed()
      return
    }

    let disableAutoRelogin = get_disable_autorelogin_once()
    autoLogin = autoLogin && !disableAutoRelogin
    if (autoLogin) {
      this.doLoginDelayed()
      return
    }

    select_editbox(this.scene.findObject(this.tabFocusArray[ lp.login != "" ? 1 : 0 ]))
  }

  function onDestroy() {
    webauth_stop()
    enable_keyboard_layout_change_tracking(false)
    enable_keyboard_locks_change_tracking(false)
  }

  function setDisableSslCertBox(value) {
    let dcObj = showObjById("loginbox_disable_ssl_cert", value, this.scene)
    if (checkObj(dcObj))
      dcObj.setValue(value)
  }

  function checkShardingCircuits() {
    local defValue = 0
    let networkBlk = get_network_block()
    let avCircuits = networkBlk.getBlockByName(this.availableCircuitsBlockName)

    let configCircuitName = get_cur_circuit_name()
    this.shardItems = [{
                    item = configCircuitName
                    text = loc($"circuit/{configCircuitName}")
                 }]

    if (avCircuits && avCircuits.paramCount() > 0) {
      local defaultCircuit = loc("default_circuit", "")
      if (defaultCircuit == "")
        defaultCircuit = configCircuitName

      this.shardItems = []
      for (local i = 0; i < avCircuits.paramCount(); ++i) {
        let param = avCircuits.getParamName(i)
        let value = avCircuits.getParamValue(i)
        if (param == this.paramName && type(value) == "string") {
          if (value == defaultCircuit)
            defValue = i

          this.shardItems.append({
                              item = value
                              text = loc($"circuit/{value}")
                           })
        }
      }
    }

    let show = this.shardItems.len() > 1
    let shardObj = showObjById("sharding_block", show, this.scene)
    if (show && checkObj(shardObj)) {
      let dropObj = shardObj.findObject("sharding_dropright_block")
      let shardData = create_option_combobox("sharding_list", this.shardItems, defValue, null, true)
      this.guiScene.replaceContentFromText(dropObj, shardData, shardData.len(), this)
    }
  }

  function onChangeAutosave() {
    if (!this.isValid())
      return

    let remoteCompObj = this.scene.findObject("loginbox_remote_comp")
    let rememberDeviceObj = this.scene.findObject("loginbox_code_remember_this_device")
    let savePassObj = this.scene.findObject("loginbox_autosave_password")
    let saveLoginObj = this.scene.findObject("loginbox_autosave_login")
    let autoLoginObj = this.scene.findObject("loginbox_autologin")
    let disableCertObj = this.scene.findObject("loginbox_disable_ssl_cert")

    if (rememberDeviceObj.isVisible())
      remoteCompObj.setValue(!rememberDeviceObj.getValue())
    else
      rememberDeviceObj.setValue(!remoteCompObj.getValue())

    let isRemoteComp = remoteCompObj.getValue()
    let isAutosaveLogin = saveLoginObj.getValue()
    let isAutosavePass = savePassObj.getValue()

    this.setDisableSslCertBox(disableCertObj.getValue())

    saveLoginObj.enable(!isRemoteComp)
    savePassObj.enable(!isRemoteComp && isAutosaveLogin)
    autoLoginObj.enable(!isRemoteComp && isAutosaveLogin && isAutosavePass)

    if (isRemoteComp)
      saveLoginObj.setValue(false)
    if (isRemoteComp || !isAutosaveLogin)
      savePassObj.setValue(false)
    if (isRemoteComp || !isAutosavePass || !isAutosaveLogin)
      autoLoginObj.setValue(false)
  }

  function initLanguageSwitch() {
    let canSwitchLang = canSwitchGameLocalization()
    showObjById("language_selector", canSwitchLang, this.scene)
    if (!canSwitchLang)
      return

    this.localizationInfo = this.localizationInfo || getGameLocalizationInfo()
    let curLangId = getLocalLanguage()
    local lang = this.localizationInfo[0]
    foreach (l in this.localizationInfo)
      if (l.id == curLangId)
        lang = l

    let objLangLabel = this.scene.findObject("label_language")
    if (checkObj(objLangLabel)) {
      local title = loc("profile/language")
      let titleEn = loc("profile/language/en")
      title = "".concat(title, title == titleEn ? "" : loc("ui/parentheses/space", { text = titleEn }), ":")
      objLangLabel.setValue(title)
    }
    let objLangIcon = this.scene.findObject("btn_language_icon")
    if (checkObj(objLangIcon))
      objLangIcon["background-image"] = lang.icon
    let objLangName = this.scene.findObject("btn_language_text")
    if (checkObj(objLangName))
      objLangName.setValue(lang.title)
  }

  function onPopupLanguages(obj) {
    if (gui_handlers.ActionsList.hasActionsListOnObject(obj))
      return this.onClosePopups()

    this.localizationInfo = this.localizationInfo || getGameLocalizationInfo()
    if (!checkObj(obj) || this.localizationInfo.len() < 2)
      return

    let curLangId = getLocalLanguage()
    let menu = {
      handler = this
      closeOnUnhover = true
      actions = []
      cssParams = {
        hasAnim = "yes"
      }
    }
    for (local i = 0; i < this.localizationInfo.len(); i++) {
      let lang = this.localizationInfo[i]
      menu.actions.append({
        actionName  = lang.id
        text        = lang.title
        icon        = lang.icon
        action      = @() this.onChangeLanguage(lang.id)
        selected    = lang.id == curLangId
      })
    }
    gui_handlers.ActionsList.open(obj, menu)
  }

  function onClosePopups() {
    let obj = this.scene.findObject("btn_language")
    if (checkObj(obj))
      gui_handlers.ActionsList.removeActionsListFromObject(obj, true)
  }

  function onChangeLanguage(langId) {
    let no_dump_login = this.scene.findObject("loginbox_username").getValue() ?? ""
    let no_dump_pass = this.scene.findObject("loginbox_password").getValue() ?? ""
    let isRemoteComp = this.scene.findObject("loginbox_remote_comp").getValue()
    let code_remember_this_device = this.scene.findObject("loginbox_code_remember_this_device").getValue()
    let isAutosaveLogin = this.scene.findObject("loginbox_autosave_login").getValue()
    let isAutosavePass = this.scene.findObject("loginbox_autosave_password").getValue()
    let autologin = this.scene.findObject("loginbox_autologin").getValue()
    let shardingListObj = this.scene.findObject("sharding_list")
    let shard = shardingListObj ? shardingListObj.getValue() : -1

    setGameLocalization(langId, true, true)

    let handler = handlersManager.findHandlerClassInScene(gui_handlers.LoginWndHandler)
    this.scene = handler ? handler.scene : null
    if (!checkObj(this.scene))
      return

    this.scene.findObject("loginbox_username").setValue(no_dump_login)
    this.scene.findObject("loginbox_password").setValue(no_dump_pass)
    this.scene.findObject("loginbox_remote_comp").setValue(isRemoteComp)
    this.scene.findObject("loginbox_code_remember_this_device").setValue(code_remember_this_device)
    this.scene.findObject("loginbox_autosave_login").setValue(isAutosaveLogin)
    this.scene.findObject("loginbox_autosave_password").setValue(isAutosavePass)
    this.scene.findObject("loginbox_autologin").setValue(autologin)
    handler.onChangeAutosave()
    if (shardingListObj)
      shardingListObj.setValue(shard)
  }

  function requestLogin(no_dump_login) {
    return this.requestLoginWithCode(no_dump_login, "");
  }

  function requestLoginWithCode(no_dump_login, code) {
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "regular" })
    log("Login: checkLoginPass")
    addLoginState(LOGIN_STATE.LOGIN_STARTED)
    return checkLoginPass(no_dump_login,
                              getObjValue(this.scene, "loginbox_password", ""),
                              this.check2StepAuthCode ? "" : this.stoken, 
                              code,
                              this.check2StepAuthCode
                                ? getObjValue(this.scene, "loginbox_code_remember_this_device", false)
                                : !getObjValue(this.scene, "loginbox_disable_ssl_cert", false),
                              getObjValue(this.scene, "loginbox_remote_comp", false)
                             )
  }

  function continueLogin(no_dump_login) {
    if (isExternalOperator())
      convertExternalJwtToAuthJwt("ConvertExternalJwt")
    else
      this.finishLogin(no_dump_login)
  }

  function finishLogin(no_dump_login) {
    if (isShowMessageAboutProfileMoved())
      return

    if (this.shardItems) {
      if (this.shardItems.len() == 1)
        set_network_circuit(this.shardItems[0].item)
      else if (this.shardItems.len() > 1)
        set_network_circuit(this.shardItems[this.scene.findObject("sharding_list").getValue()].item)
    }

    let autoSaveLogin = getObjValue(this.scene, "loginbox_autosave_login", this.defaultSaveLoginFlagVal)
    let autoSavePassword = getObjValue(this.scene, "loginbox_autosave_password", this.defaultSavePasswordFlagVal)
    let disableSSLCheck = getObjValue(this.scene, "loginbox_disable_ssl_cert", false)
    local autoSave = (autoSaveLogin     ? AUTO_SAVE_FLG_LOGIN     : 0) |
                     (autoSavePassword  ? AUTO_SAVE_FLG_PASS      : 0) |
                     (disableSSLCheck   ? AUTO_SAVE_FLG_NOSSLCERT : 0)

    if (this.was_using_stoken || this.isSteamAuth || this.isGuestLogin)
      autoSave = autoSave | AUTO_SAVE_FLG_DISABLE

    if (this.isGuestLogin)
      saveLocalSharedSettings(GUEST_LOGIN_SAVE_ID, getGuestLoginId())

    setLoginPass(no_dump_login.tostring(), getObjValue(this.scene, "loginbox_password", ""), autoSave)
    if (!checkObj(this.scene)) 
      return

    let autoLogin = (autoSaveLogin && autoSavePassword) ?
                getObjValue(this.scene, "loginbox_autologin", this.defaultSaveAutologinFlagVal)
                : false
    set_autologin_enabled(autoLogin)
    if (this.initial_autologin != autoLogin)
      save_profile(false)

    addLoginState(LOGIN_STATE.AUTHORIZED)
  }

  function onOk() {
    if (!this.isLoginEditsFilled())
      return

    this.isLoginRequestInprogress = true
    this.requestGet2stepCodeAtempt = MAX_GET_2STEP_CODE_ATTEMPTS
    this.doLoginWaitJob()
  }

  function doLoginDelayed() {
    this.isLoginRequestInprogress = true
    this.guiScene.performDelayed(this, this.doLoginWaitJob)
  }

  function doLoginWaitJob() {
    set_disable_autorelogin_once(false)
    let no_dump_login = getObjValue(this.scene, "loginbox_username", "")
    local result = this.requestLogin(no_dump_login)
    this.proceedAuthorizationResult(result, no_dump_login)
  }

  function steamAuthorization(steamSpecCode = "steam") {
    this.isSteamAuth = true
    this.isLoginRequestInprogress = true
    set_disable_autorelogin_once(false)
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "steam" })
    log($"Steam Login: checkLoginPass with code {steamSpecCode}")
    addLoginState(LOGIN_STATE.LOGIN_STARTED)
    let result = checkLoginPass("", "", "steam", steamSpecCode, false, false)
    this.proceedAuthorizationResult(result, "")
  }

  onSteamAuthorization = @() this.steamAuthorization()

  function onSsoAuthorization() {
    let no_dump_login = getObjValue(this.scene, "loginbox_username", "")
    let no_dump_url = webauth_get_url(no_dump_login)
    openUrl(no_dump_url)
    browser_set_external_url(no_dump_url)
  }

  function onSsoAuthorizationComplete(params) {
    close_browser_modal()

    if (params.success) {
      let no_dump_login = getObjValue(this.scene, "loginbox_username", "")
      if (!isExternalOperator())
        load_local_settings()
      this.continueLogin(no_dump_login);
    }
  }

  function proceedGetTwoStepCode(data) {
    if (!this.isValid() || this.isLoginRequestInprogress) {
      return
    }

    let result = data.status
    let code = data.code
    let no_dump_login = getObjValue(this.scene, "loginbox_username", "")

    if (result == YU2_TIMEOUT && this.requestGet2stepCodeAtempt-- > 0) {
      this.doLoginDelayed()
      return
    }

    if (result == YU2_OK) {
      this.isLoginRequestInprogress = true
      let loginResult = this.requestLoginWithCode(no_dump_login, code)
      this.proceedAuthorizationResult(loginResult, no_dump_login)
    }
  }

  function showConnectionErrorMessageBox(errorMsg) {
    let onTryAgain = Callback(this.onLoginErrorTryAgain, this)
    showErrorMessageBox("yn1/connect_error", errorMsg,
      [["exit", exitGamePlatform], ["tryAgain", onTryAgain]], "tryAgain", { cancel_fn = onTryAgain })
  }

  function proceedAuthorizationResult(result, no_dump_login) {
    this.isLoginRequestInprogress = false
    if (!checkObj(this.scene)) 
      return

    this.was_using_stoken = (this.stoken != "")
    this.stoken = ""
    if (result == YU2_OK) {
      if (steam_is_running())
        saveLocalSharedSettings(USE_STEAM_LOGIN_AUTO_SETTING_ID, this.isSteamAuth)
      this.continueLogin(no_dump_login)
    }

    else if ( result == YU2_2STEP_AUTH) {
      bqSendNoAuth("auth:2step")
      
      this.check2StepAuthCode = true
      showObjById("loginbox_code_remember_this_device", true, this.scene)
      showObjById("loginbox_remote_comp", false, this.scene)
      twoStepModal.open({
        loginScene           = this.scene,
        continueLogin        = this.continueLogin.bindenv(this)
      })
      this.onChangeAutosave()
      this.guiScene.performDelayed(this, function() {
        if (!checkObj(this.scene))
          return

        getTwoStepCodeAsync2("ProceedGetTwoStepCode")
      })
    }

    else if ( result == YU2_PSN_RESTRICTED) {
      bqSendNoAuth("auth:psn_restricted")
      this.msgBox("psn_restricted", loc("yn1/login/PSN_RESTRICTED"),
         [["exit", exitGamePlatform ]], "exit")
    }

    else if ( result == YU2_WRONG_LOGIN || result == YU2_WRONG_PARAMETER) {
      bqSendNoAuth(result == YU2_WRONG_LOGIN ? "auth:wrong_login" : "auth:wrong_param")
      if (this.was_using_stoken)
        return;
      showErrorMessageBox("yn1/connect_error", result, 
      [
        ["recovery", @() openUrl(getCurCircuitOverride("recoveryPasswordURL", loc("url/recovery")), false, false, "login_wnd")],
        ["exit", exitGamePlatform],
        ["tryAgain", Callback(this.onLoginErrorTryAgain, this)]
      ], "tryAgain", { cancel_fn = Callback(this.onLoginErrorTryAgain, this) })
    }

    else if ( result == YU2_SSL_CACERT) {
      bqSendNoAuth("auth:ssl_error")
      if (this.was_using_stoken)
        return;
      showErrorMessageBox("yn1/connect_error", result,
      [
        ["disableSSLCheck", Callback(function() { this.setDisableSslCertBox(true) }, this)],
        ["exit", exitGamePlatform],
        ["tryAgain", Callback(this.onLoginErrorTryAgain, this)]
      ], "tryAgain", { cancel_fn = Callback(this.onLoginErrorTryAgain, this) })
    }

    else if ( result == YU2_DOI_INCOMPLETE) {
      bqSendNoAuth("auth:verify_email")
      showInfoMsgBox(loc("yn1/login/DOI_INCOMPLETE"), "verification_email_to_complete")
    }

    else if ( result == YU2_NOT_FOUND) {
      if (!this.isGuestLogin) {
        bqSendNoAuth("auth:not_found")
        this.showConnectionErrorMessageBox(result)
        return
      }

      bqSendNoAuth("auth:not_found:guest")
      saveLocalSharedSettings(GUEST_LOGIN_SAVE_ID, null)
      this.onGuestAuthorization()
    }

    else {
      bqSendNoAuth($"auth:error:{result}")
      if (this.was_using_stoken)
        return

      this.showConnectionErrorMessageBox(result)
    }
  }

  function onLoginErrorTryAgain() {}

  function onKbdWrapDown() {
    setFocusToNextObj(this.scene, this.tabFocusArray, 1)
  }

  function onEventKeyboardLayoutChanged(params) {
    let layoutIndicator =
      this.scene.findObject("loginbox_password_layout_indicator")

    if (!checkObj(layoutIndicator))
      return

    local layoutCode = params.layout.toupper()
    if (layoutCode.len() > 2)
      layoutCode = layoutCode.slice(0, 2)

    layoutIndicator.setValue(layoutCode)
  }

  function onEventKeyboardLocksChanged(params) {
    let capsIndicator = this.scene.findObject("loginbox_password_caps_indicator")
    if (checkObj(capsIndicator))
      capsIndicator.show((params.locks & 1) == 1)
  }

  function onSignUp() {
    local urlLocId, platform = ""
    if (steam_is_running()) {
      platform = ":steam"
      urlLocId = "url/signUpSteam"
    }
    else if (isPlatformShieldTv()) {
      platform = ":shield_tv"
      urlLocId = "url/signUpShieldTV"
    }
    else
      urlLocId = "url/signUp"
    bqSendNoAuthWeb($"sign_up{platform}")
    openUrl(getCurCircuitOverride("signUpURL", loc(urlLocId)).subst({ distr = getDistr(), lang = getCurLangShortName() }), false, false, "login_wnd")
  }

  function onForgetPassword() {
    bqSendNoAuthWeb("forget_pass")
    openUrl(getCurCircuitOverride("recoveryPasswordURL", loc("url/recovery")), false, false, "login_wnd")
  }

  function onChangeLogin(obj) {
    
    let res = !validateEmail(obj.getValue()) && (this.stoken == "")
    obj.warning = res ? "yes" : "no"
    obj.warningText = res ? "yes" : "no"
    obj.tooltip = res ? loc("tooltip/invalidEmail/possibly") : ""
    this.setLoginBtnState()
  }

  function onDoneEnter() {
    if (!this.check2StepAuthCode)
      this.doLoginWaitJob()
  }

  function onDoneCode() {
    this.doLoginWaitJob()
  }

  function onExit() {
    this.msgBox("login_question_quit_game", loc("mainmenu/questionQuitGame"),
      [
        ["yes", exitGamePlatform],
        ["no", @() null]
      ], "no", { cancel_fn = @() null })
  }

  isLoginEditsFilled = @() getObjValue(this.scene, "loginbox_username", "") != ""
    && getObjValue(this.scene, "loginbox_password", "") != ""

  function setLoginBtnState () {
    let loginBtnObj = this.scene.findObject("login_action_button")
    if (!checkObj(loginBtnObj))
      return false

    loginBtnObj.enable = this.isLoginEditsFilled() ? "yes" : "no"
  }

  function goBack() {
    this.onExit()
  }

  function guestProceedAuthorization(guestLoginId, nick = "", known = false) {
    this.isGuestLogin = true
    this.isLoginRequestInprogress = true
    set_disable_autorelogin_once(false)
    statsd.send_counter("sq.game_start.request_login", 1, { login_type = "guest" })
    log("Guest Login: checkLoginPass")
    bqSendNoAuth("guest:login")
    addLoginState(LOGIN_STATE.LOGIN_STARTED)
    let result = checkLoginPass(guestLoginId, nick, "guest", $"guest{known ? "-known" : ""}", false, false)
    this.proceedAuthorizationResult(result, "")
  }

  function onGuestAuthorization() {
    bqSendNoAuth("guest")

    let guestLoginId = getGuestLoginId()
    if (guestLoginId == loadLocalSharedSettings(GUEST_LOGIN_SAVE_ID)) {
      this.guestProceedAuthorization(guestLoginId, "", true)
      return
    }

    openEditBoxDialog({
      title = loc("mainmenu/chooseName")
      label = loc("choose_nickname_req")
      maxLen = 16
      validateFunc = @(nick) validateNickRegexp.replace("", nick)
      editboxWarningTooltip = loc("invalid_nickname")
      checkWarningFunc = isNamePassing
      canCancel = true
      owner = this
      function okFunc(nick) {
        if (nick != "" && !isNamePassing(nick)) {
          bqSendNoAuth("guest:bad_nick")
          showInfoMsgBox(loc("invalid_nickname"), "guest_login_invalid_nickname")
          return
        }
        this.guestProceedAuthorization(guestLoginId, nick)
      }
    })
  }
}

eventbus_subscribe("ProceedGetTwoStepCode", function ProceedGetTwoStepCode(p) {
  let loginWnd = handlersManager.findHandlerClassInScene(gui_handlers.LoginWndHandler)
  if (loginWnd == null)
    return
  loginWnd.proceedGetTwoStepCode(p)
})

eventbus_subscribe("ConvertExternalJwt", function ContinueExternalLogin(p) {
  let loginWnd = handlersManager.findHandlerClassInScene(gui_handlers.LoginWndHandler)
  if (loginWnd == null)
    return
  let no_dump_login = getObjValue(loginWnd.scene, "loginbox_username", "")
  if (p.status == YU2_OK) {
    loginWnd.finishLogin(no_dump_login)
    load_local_settings()
  }
  else
    loginWnd.proceedAuthorizationResult(p.status, no_dump_login)
})

eventbus_subscribe(webauth_completion_event, function ProceedWebAuth(p) {
  let loginWnd = handlersManager.findHandlerClassInScene(gui_handlers.LoginWndHandler)
  if (loginWnd == null)
    return
  loginWnd.onSsoAuthorizationComplete(p)
})
