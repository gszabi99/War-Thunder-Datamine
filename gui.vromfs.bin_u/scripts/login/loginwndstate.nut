import "%scripts/utils/exitGamePlatform.nut" as exitGamePlatform
import "%sqStdLibs/helpers/u.nut" as u
import "statsd" as statsd
import "%scripts/time.nut" as time
from "%scripts/login/loginState.nut" import get_disable_autorelogin_once, set_disable_autorelogin_once
from "%scripts/onlineShop/url.nut" import openUrl
from "%scripts/viewUtils/getTitleLogo.nut" import getTitleLogo
from "%appGlobals/login/loginScreenState.nut" import focusLoginItem, getLoginValue, setLoginItem,
  setLoginScreenField, resetLoginScreen, loginScreen
from "%scripts/dirtyWordsFilter.nut" import isNamePassing
from "%sqstd/platform.nut" import platformId, is_gdk, is_pc
from "%appGlobals/clientState/platform.nut" import isPlatformShieldTv
from "%appGlobals/clientState/localProfile.nut" import saveLocalSharedSettings, loadLocalSharedSettings
from "%scripts/langUtils/language.nut" import getGameLocalizationInfo, setGameLocalization, canSwitchGameLocalization, getCurLangShortName
from "%scripts/user/profileStates.nut" import havePlayerTag
from "%scripts/bigQuery/bigQueryClient.nut" import bqSendNoAuth, bqSendNoAuthWeb
from "%scripts/onlineShop/browserWndActions.nut" import close_browser_modal, browser_set_external_url
from "%scripts/login/loginManager.nut" import addLoginState
from "%scripts/options/optionsBeforeLogin.nut" import set_autologin_enabled, is_autologin_enabled
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "language" import getLocalLanguage
from "string" import format
from "app" import get_game_version_str
from "auth_wt" import getDistr, convertExternalJwtToAuthJwt, getLoginPass, getTwoStepCodeAsync2, checkLoginPass, setLoginPass, getPlayerTagsGlobalStr
from "dagor.system" import dgs_get_settings
from "sysinfo" import get_user_system_info
from "console" import register_command
from "%sqstd/string.nut" import validateEmail
from "eventbus" import eventbus_subscribe, eventbus_send
from "blkGetters" import get_network_block, get_common_local_settings_blk
from "steam" import steam_is_running
from "webauth" import webauth_start, webauth_stop, webauth_get_url, webauth_completion_event
from "dagor.random" import frnd
from "%globalScripts/yuplay2Consts.nut" import *
from "%scripts/dagui_natives.nut" import dgs_get_argv, get_cur_circuit_name, load_local_settings, is_steam_big_picture, set_network_circuit
from "%scripts/dagui_library.nut" import *
from "%globalScripts/autoSaveFlagConsts.nut" import *
from "%appGlobals/login/loginConsts.nut" import LOGIN_STATE, USE_STEAM_LOGIN_AUTO_SETTING_ID
from "chard" import save_profile
from "types" import Integer, String

const MAX_GET_2STEP_CODE_ATTEMPTS = 10
const GUEST_LOGIN_SAVE_ID = "guestLoginId"
const MIGRATION_URL = "migration.warthunder.com"
const LAST_LOGIN_TYPE_SAVE_ID = "lastLoginType"
const LOGIN_WND_STYLE_SAVE_ID = "loginWndStyle"
const AVAILABLE_CIRCUITS_BLOCK = "multipleAvailableCircuits"
const CIRCUIT_PARAM = "circuit"

enum LoginHelpShowState {
  HIDED = 0,
  WAIT_ANIM = 1,
  SHOWED = 2
}


let keptOnLangChange = persist("keptOnLangChange", @() {})

const KEPT_ON_LANG_CHANGE = ["loginbox_username", "loginbox_password", "loginbox_remote_comp",
  "loginbox_autosave_login", "loginbox_autosave_password", "loginbox_autologin", "sharding_list"]

let mkState = @() {
  owner = null
  hasForm = false
  stoken = "" 
  wasUsingStoken = false
  isRequestInProgress = false
  twoStepAttemptsLeft = 0
  check2StepAuthCode = false
  isSteamAuth = false
  isGuestLogin = false
  initialAutologin = false
  loginHelpState = LoginHelpShowState.HIDED
  shardItems = null
}
let state = mkState()

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

let sendAction = @(action) eventbus_send("loginScreen.action", { action })
let showMsgBox = @(box) eventbus_send("loginScreen.msgBox", box)


let getOwner = @() state.owner
let isOwnerValid = @() getOwner()?.isValid() ?? false
let hasForm = @() state.hasForm && isOwnerValid()

function setLoginOwner(owner) {
  if (getOwner() == owner)
    return
  state.__update(mkState())
  state.owner = owner.weakref()
}

let getFormValue = @(id, defVal) hasForm() ? getLoginValue(id, defVal) : defVal
let setFormValue = @(id, value) setLoginItem(id, "value", value)
let enableFormItem = @(id, isEnabled) setLoginItem(id, "enabled", isEnabled)
let showFormItem = @(id, show) setLoginItem(id, "shown", show)

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

  showMsgBox({
    uid = "errorMessageBox"
    text = "\n".concat(loc("msgbox/error_login_migrated_player_profile"), $"<url={MIGRATION_URL}>{MIGRATION_URL}</url>")
    buttons = [{ id = "exit", action = "exitGame" }, { id = "tryAgain" }]
    defBtn = "tryAgain"
    cancelBtn = "tryAgain"
  })
  return true
}

function setDisableSslCertBox(value) {
  showFormItem("loginbox_disable_ssl_cert", value)
  setFormValue("loginbox_disable_ssl_cert", value)
}

function onChangeAutosave() {
  if (!hasForm())
    return

  if (state.check2StepAuthCode)
    setFormValue("loginbox_remote_comp", !getFormValue("loginbox_code_remember_this_device", false))
  else
    setFormValue("loginbox_code_remember_this_device", !getFormValue("loginbox_remote_comp", false))

  let isRemoteComp = getFormValue("loginbox_remote_comp", false)
  let isAutosaveLogin = getFormValue("loginbox_autosave_login", false)
  let isAutosavePass = getFormValue("loginbox_autosave_password", false)

  setDisableSslCertBox(getFormValue("loginbox_disable_ssl_cert", false))

  enableFormItem("loginbox_autosave_login", !isRemoteComp)
  enableFormItem("loginbox_autosave_password", !isRemoteComp && isAutosaveLogin)
  enableFormItem("loginbox_autologin", !isRemoteComp && isAutosaveLogin && isAutosavePass)

  if (isRemoteComp)
    setFormValue("loginbox_autosave_login", false)
  if (isRemoteComp || !isAutosaveLogin)
    setFormValue("loginbox_autosave_password", false)
  if (isRemoteComp || !isAutosavePass || !isAutosaveLogin)
    setFormValue("loginbox_autologin", false)
}

let isLoginEditsFilled = @() getFormValue("loginbox_username", "") != ""
  && getFormValue("loginbox_password", "") != ""

let setLoginBtnState = @() enableFormItem("login_action_button", isLoginEditsFilled())

function onFormValueChanged(id) {
  if (id == "loginbox_username") {
    setLoginItem(id, "warning", !validateEmail(getFormValue(id, "")) && (state.stoken == ""))
    setLoginBtnState()
  }
  else if (id == "loginbox_password")
    setLoginBtnState()
  else if (id != "sharding_list")
    onChangeAutosave()
}

function showDecorations() {
  setLoginScreenField("versionText", format(loc("mainmenu/version"), get_game_version_str()))
  setLoginScreenField("copyrightText", loc("mainmenu/legal_text", { currentYear = time.getCurrentYear() }))
  setLoginScreenField("titleLogo", getTitleLogo(128))
}

function initLanguageSwitch() {
  let canSwitchLang = canSwitchGameLocalization()
  showFormItem("language_selector", canSwitchLang)
  if (!canSwitchLang)
    return

  let curLangId = getLocalLanguage()
  setLoginScreenField("langs", getGameLocalizationInfo().map(@(l) {
    id = l.id, text = l.title, images = l.icon == null ? null : [{ image = l.icon }], selected = l.id == curLangId
  }))

  local title = loc("profile/language")
  let titleEn = loc("profile/language/en")
  title = "".concat(title, title == titleEn ? "" : loc("ui/parentheses/space", { text = titleEn }), ":")
  setFormValue("label_language", title)
}

function onChangeLanguage(langId) {
  foreach (id in KEPT_ON_LANG_CHANGE)
    keptOnLangChange[id] <- getFormValue(id, null)
  setGameLocalization(langId, true, true)
}

function checkShardingCircuits() {
  local defValue = 0
  let avCircuits = get_network_block().getBlockByName(AVAILABLE_CIRCUITS_BLOCK)

  let configCircuitName = get_cur_circuit_name()
  state.shardItems = [{
    item = configCircuitName
    text = loc($"circuit/{configCircuitName}")
  }]

  if (avCircuits && avCircuits.paramCount() > 0) {
    local defaultCircuit = loc("default_circuit", "")
    if (defaultCircuit == "")
      defaultCircuit = configCircuitName

    state.shardItems = []
    for (local i = 0; i < avCircuits.paramCount(); ++i) {
      let param = avCircuits.getParamName(i)
      let value = avCircuits.getParamValue(i)
      if (param == CIRCUIT_PARAM && value instanceof String) {
        if (value == defaultCircuit)
          defValue = i

        state.shardItems.append({
          item = value
          text = loc($"circuit/{value}")
        })
      }
    }
  }

  showFormItem("sharding_block", state.shardItems.len() > 1)
  setLoginScreenField("shardItems", state.shardItems)
  setFormValue("sharding_list", defValue)
}

function showForm(form) {
  showFormItem("browser_bug_disclaimer", form.showBugDisclaimer)
  setFormValue("loginbox_username", form.login)
  setFormValue("loginbox_password", form.password)
  setFormValue("loginbox_autosave_login", form.autosaveLogin)
  setFormValue("loginbox_autosave_password", form.autosavePassword)
  enableFormItem("loginbox_autosave_password", form.autosaveLogin)
  setFormValue("loginbox_autosave_password_text", form.savePasswordText)
  setDisableSslCertBox(form.disableSslCert)
  showFormItem("steam_login_action_button", form.showSteamLogin)
  showFormItem("sso_login_action_button", form.showWebLogin)
  showFormItem("btn_signUp_link", !form.showSteamLogin)
  enableFormItem("loginbox_autologin", form.autoLoginEnable)
  setFormValue("loginbox_autologin", form.autoLogin)
  showFormItem("links_block", form.showLinks)
}

function setCompactWndStyle() {
  setLoginScreenField("style", "compact")
  setLoginScreenField("isExistingAccountOpened", false)
}

function fillLoginForm() {
  let runCount = get_common_local_settings_blk()?.runCount ?? 0
  let isFirstLogin = !(runCount instanceof Integer) || runCount <= 1
  if (!isFirstLogin) {
    let lastLoginIsGuest = loadLocalSharedSettings(LAST_LOGIN_TYPE_SAVE_ID, null) == "guest"
    if (!lastLoginIsGuest)
      return

    let needCompactWndStyle = loadLocalSharedSettings(LOGIN_WND_STYLE_SAVE_ID, "usual") == "compact"
    if (needCompactWndStyle)
      setCompactWndStyle()
    else
      setLoginScreenField("style", "guestFirst")
    return
  }

  let canShowNewDesign = is_pc && !is_gdk && !steam_is_running()
  if (!canShowNewDesign)
    return

  let newLoginWndStyle = frnd() > 0.5
  bqSendNoAuthWeb(newLoginWndStyle ? "login_style:new" : "login_style:old")

  if (newLoginWndStyle) {
    saveLocalSharedSettings(LOGIN_WND_STYLE_SAVE_ID, "compact")
    setCompactWndStyle()
  }
}

function finishLogin(no_dump_login) {
  if (isShowMessageAboutProfileMoved())
    return
  keptOnLangChange.clear()

  let { shardItems } = state
  if (shardItems) {
    if (shardItems.len() == 1)
      set_network_circuit(shardItems[0].item)
    else if (shardItems.len() > 1)
      set_network_circuit(shardItems[getFormValue("sharding_list", 0)].item)
  }

  let owner = getOwner()
  let autoSaveLogin = getFormValue("loginbox_autosave_login", owner?.defaultSaveLoginFlagVal ?? false)
  let autoSavePassword = getFormValue("loginbox_autosave_password", owner?.defaultSavePasswordFlagVal ?? false)
  let disableSSLCheck = getFormValue("loginbox_disable_ssl_cert", false)
  local autoSave = (autoSaveLogin     ? AUTO_SAVE_FLG_LOGIN     : 0) |
                   (autoSavePassword  ? AUTO_SAVE_FLG_PASS      : 0) |
                   (disableSSLCheck   ? AUTO_SAVE_FLG_NOSSLCERT : 0)

  if (state.wasUsingStoken || state.isSteamAuth || state.isGuestLogin)
    autoSave = autoSave | AUTO_SAVE_FLG_DISABLE

  if (state.isGuestLogin)
    saveLocalSharedSettings(GUEST_LOGIN_SAVE_ID, getGuestLoginId())

  setLoginPass(no_dump_login.tostring(), getFormValue("loginbox_password", ""), autoSave)
  if (!isOwnerValid()) 
    return

  let autoLogin = (autoSaveLogin && autoSavePassword) ?
              getFormValue("loginbox_autologin", owner?.defaultSaveAutologinFlagVal ?? false)
              : false
  set_autologin_enabled(autoLogin)
  if (state.initialAutologin != autoLogin)
    save_profile(false)

  addLoginState(LOGIN_STATE.AUTHORIZED)
}

function continueLogin(no_dump_login) {
  if (isExternalOperator())
    convertExternalJwtToAuthJwt("ConvertExternalJwt")
  else
    finishLogin(no_dump_login)
}

function requestLoginWithCode(no_dump_login, code) {
  statsd.send_counter("sq.game_start.request_login", 1, { login_type = "regular" })
  log("Login: checkLoginPass")
  addLoginState(LOGIN_STATE.LOGIN_STARTED)
  return checkLoginPass(no_dump_login,
                            getFormValue("loginbox_password", ""),
                            state.check2StepAuthCode ? "" : state.stoken, 
                            code,
                            state.check2StepAuthCode
                              ? getFormValue("loginbox_code_remember_this_device", false)
                              : !getFormValue("loginbox_disable_ssl_cert", false),
                            getFormValue("loginbox_remote_comp", false)
                           )
}

function openExistingAccountPanel() {
  if (!loginScreen.get().isExistingAccountOpened)
    setLoginScreenField("isExistingAccountOpened", true)
}

function showLoginHelp() {
  if (!loginScreen.get().isExistingAccountOpened) {
    state.loginHelpState = LoginHelpShowState.WAIT_ANIM
    openExistingAccountPanel()
    return
  }
  saveLocalSharedSettings(LOGIN_WND_STYLE_SAVE_ID, "usual")
  state.loginHelpState = LoginHelpShowState.SHOWED
  setLoginScreenField("isHelpShown", true)
}

function afterOpenExistingAccBlock() {
  if (state.loginHelpState == LoginHelpShowState.WAIT_ANIM)
    showLoginHelp()
}

let mkTryAgainButtons = @(firstButton = null) [firstButton, { id = "exit", action = "exitGame" },
  { id = "tryAgain", action = "tryAgain" }].filter(@(b) b != null)

let showConnectionErrorMessageBox = @(errorCode, firstButton = null) showMsgBox({
  errorCode, buttons = mkTryAgainButtons(firstButton), defBtn = "tryAgain", cancelBtn = "tryAgain"
})

local onGuestAuthorization = null

function proceedAuthorizationResult(result, no_dump_login) {
  state.isRequestInProgress = false
  if (!isOwnerValid()) 
    return

  state.wasUsingStoken = state.stoken != ""
  state.stoken = ""
  if (result == YU2_OK) {
    if (steam_is_running())
      saveLocalSharedSettings(USE_STEAM_LOGIN_AUTO_SETTING_ID, state.isSteamAuth)

    saveLocalSharedSettings(LAST_LOGIN_TYPE_SAVE_ID, state.isGuestLogin ? "guest" : "nonguest")
    continueLogin(no_dump_login)
  }

  else if (result == YU2_2STEP_AUTH) {
    bqSendNoAuth("auth:2step")
    
    state.check2StepAuthCode = true
    showFormItem("loginbox_code_remember_this_device", true)
    showFormItem("loginbox_remote_comp", false)
    eventbus_send("loginScreen.openTwoStep", {})
    onChangeAutosave()
    sendAction("requestTwoStepCode")
  }

  else if (result == YU2_PSN_RESTRICTED) {
    bqSendNoAuth("auth:psn_restricted")
    showMsgBox({ uid = "psn_restricted", text = loc("yn1/login/PSN_RESTRICTED"),
      buttons = [{ id = "exit", action = "exitGame" }], defBtn = "exit", isOwned = true })
  }

  else if (result == YU2_WRONG_LOGIN || result == YU2_WRONG_PARAMETER) {
    bqSendNoAuth(result == YU2_WRONG_LOGIN ? "auth:wrong_login" : "auth:wrong_param")
    if (state.wasUsingStoken)
      return
    showConnectionErrorMessageBox(result, { id = "recovery", action = "recovery" })
  }

  else if (result == YU2_SSL_CACERT) {
    bqSendNoAuth("auth:ssl_error")
    if (state.wasUsingStoken)
      return
    showConnectionErrorMessageBox(result, { id = "disableSSLCheck", action = "disableSslCheck" })
  }

  else if (result == YU2_DOI_INCOMPLETE) {
    bqSendNoAuth("auth:verify_email")
    showMsgBox({ uid = "verification_email_to_complete", text = loc("yn1/login/DOI_INCOMPLETE") })
  }

  else if (result == YU2_NOT_FOUND) {
    if (!state.isGuestLogin) {
      bqSendNoAuth("auth:not_found")
      showConnectionErrorMessageBox(result)
      return
    }

    bqSendNoAuth("auth:not_found:guest")
    saveLocalSharedSettings(GUEST_LOGIN_SAVE_ID, null)
    if (state.loginHelpState == LoginHelpShowState.HIDED) {
      showLoginHelp()
      state.isGuestLogin = false
    }
    else
      onGuestAuthorization()
  }

  else {
    bqSendNoAuth($"auth:error:{result}")
    if (state.wasUsingStoken)
      return

    showConnectionErrorMessageBox(result)
  }
}

function doLoginWaitJob() {
  set_disable_autorelogin_once(false)
  let no_dump_login = getFormValue("loginbox_username", "")
  proceedAuthorizationResult(requestLoginWithCode(no_dump_login, ""), no_dump_login)
}


function doLoginDelayed() {
  state.isRequestInProgress = true
  sendAction("doLogin")
}

function startLogin() {
  state.isRequestInProgress = true
  state.twoStepAttemptsLeft = MAX_GET_2STEP_CODE_ATTEMPTS
  doLoginWaitJob()
}

function confirmSteamRunningWarning(continueAction, continueFn) {
  if (getCurCircuitOverride("publisher") != null && steam_is_running()) {
    showMsgBox({ uid = "login_pixelstorm_steam_running_warning", text = loc("msgbox/login_pixelstorm_steam_running_warning"),
      buttons = [{ id = "ok", action = continueAction }], defBtn = "ok", isOwned = true })
    return
  }

  continueFn()
}

function onOk() {
  if (isLoginEditsFilled())
    confirmSteamRunningWarning("startLogin", startLogin)
}

function onDoneEnter() {
  if (!state.check2StepAuthCode)
    confirmSteamRunningWarning("doLogin", doLoginWaitJob)
}

function onUserNameDoneEnter() {
  if (getFormValue("loginbox_password", "") != "")
    onDoneEnter()
  else
    focusLoginItem("loginbox_password")
}

function requestSteamLogin(steamSpecCode, owner) {
  setLoginOwner(owner)
  state.isSteamAuth = true
  state.isRequestInProgress = true
  set_disable_autorelogin_once(false)
  statsd.send_counter("sq.game_start.request_login", 1, { login_type = "steam" })
  log($"Steam Login: checkLoginPass with code {steamSpecCode}")
  addLoginState(LOGIN_STATE.LOGIN_STARTED)
  return checkLoginPass("", "", "steam", steamSpecCode, false, false)
}

function guestProceedAuthorization(guestLoginId, nick = "", known = false) {
  state.isGuestLogin = true
  state.isRequestInProgress = true
  set_disable_autorelogin_once(false)
  statsd.send_counter("sq.game_start.request_login", 1, { login_type = "guest" })
  log("Guest Login: checkLoginPass")
  bqSendNoAuth("guest:login")
  addLoginState(LOGIN_STATE.LOGIN_STARTED)
  let result = checkLoginPass(guestLoginId, nick, "guest", $"guest{known ? "-known" : ""}", false, false)
  proceedAuthorizationResult(result, "")
}

onGuestAuthorization = function() {
  bqSendNoAuth("guest")

  let guestLoginId = getGuestLoginId()
  if (guestLoginId == loadLocalSharedSettings(GUEST_LOGIN_SAVE_ID)) {
    guestProceedAuthorization(guestLoginId, "", true)
    return
  }
  eventbus_send("loginScreen.openGuestNick", {})
}

function onGuestNick(nick) {
  if (nick != "" && !isNamePassing(nick)) {
    bqSendNoAuth("guest:bad_nick")
    showMsgBox({ uid = "guest_login_invalid_nickname", text = loc("invalid_nickname") })
    return
  }
  guestProceedAuthorization(getGuestLoginId(), nick)
}

function proceedGetTwoStepCode(data) {
  if (state.isRequestInProgress)
    return

  let { status, code = "" } = data
  let no_dump_login = getFormValue("loginbox_username", "")

  if (status == YU2_TIMEOUT && state.twoStepAttemptsLeft-- > 0) {
    doLoginDelayed()
    return
  }

  if (status == YU2_OK) {
    state.isRequestInProgress = true
    proceedAuthorizationResult(requestLoginWithCode(no_dump_login, code), no_dump_login)
  }
}

function onSsoAuthorization() {
  let no_dump_url = webauth_get_url(getFormValue("loginbox_username", ""))
  openUrl(no_dump_url)
  browser_set_external_url(no_dump_url)
}

function onSsoAuthorizationComplete(params) {
  close_browser_modal()

  if (params.success) {
    if (!isExternalOperator())
      load_local_settings()
    continueLogin(getFormValue("loginbox_username", ""))
  }
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

let askQuitGame = @() showMsgBox({ uid = "login_question_quit_game", text = loc("mainmenu/questionQuitGame"),
  buttons = [{ id = "yes", action = "exitGame" }, { id = "no" }], defBtn = "no", cancelBtn = "no", isOwned = true })

function openLoginForm(owner) {
  state.__update(mkState())
  state.owner = owner.weakref()
  state.hasForm = true
  resetLoginScreen()
  showDecorations()
  initLanguageSwitch()
  checkShardingCircuits()

  let lp = getLoginPass()
  let isSteamRunning = steam_is_running()
  let showWebLogin = !isSteamRunning && webauth_start()
  state.initialAutologin = is_autologin_enabled()

  let saveLoginAndPassMask = AUTO_SAVE_FLG_LOGIN | AUTO_SAVE_FLG_PASS
  let autoLoginEnable = (lp.autoSave & saveLoginAndPassMask) == saveLoginAndPassMask
  local autoLogin = (state.initialAutologin && autoLoginEnable) || (dgs_get_settings()?.yunetwork.forceAutoLogin ?? false)
  local savePasswordText = loc("mainmenu/savePassword")
  if (!isPlatformShieldTv())
    savePasswordText = " ".concat(savePasswordText, loc("mainmenu/savePassword/unsecure"))

  showForm({
    showBugDisclaimer = platformId == "linux64" && is_steam_big_picture() 
    login = lp.login
    password = lp.password
    autosaveLogin = (lp.autoSave & AUTO_SAVE_FLG_LOGIN) != 0
    autosavePassword = (lp.autoSave & AUTO_SAVE_FLG_PASS) != 0
    savePasswordText
    disableSslCert = (lp.autoSave & AUTO_SAVE_FLG_NOSSLCERT) != 0
    showSteamLogin = isSteamRunning
    showWebLogin
    autoLogin
    autoLoginEnable
    showLinks = !isPlatformShieldTv()
  })
  foreach (id in KEPT_ON_LANG_CHANGE)
    if (keptOnLangChange?[id] != null)
      setFormValue(id, keptOnLangChange[id])
  if (keptOnLangChange.len() > 0)
    onChangeAutosave()
  keptOnLangChange.clear()
  onFormValueChanged("loginbox_username")

  let s = dgs_get_argv("stoken")
  if (!u.isEmpty(s))
    lp.stoken <- s

  if (("stoken" in lp) && lp.stoken != null && lp.stoken != "") {
    state.stoken = lp.stoken
    doLoginDelayed()
    return
  }

  autoLogin = autoLogin && !get_disable_autorelogin_once()
  if (autoLogin) {
    doLoginDelayed()
    return
  }

  focusLoginItem(lp.login != "" ? "loginbox_password" : "loginbox_username")



}

function onKeyboardLayoutChanged(layout) {
  local layoutCode = layout.toupper()
  if (layoutCode.len() > 2)
    layoutCode = layoutCode.slice(0, 2)
  setFormValue("loginbox_password_layout_indicator", layoutCode)
}

let onKeyboardLocksChanged = @(locks) showFormItem("loginbox_password_caps_indicator", (locks & 1) == 1)


let formActions = {
  ok = @(_) onOk()
  steam = @(_) proceedAuthorizationResult(requestSteamLogin("steam", getOwner()), "")
  sso = @(_) onSsoAuthorization()
  guest = @(_) onGuestAuthorization()
  guestNick = @(p) onGuestNick(p.nick)
  signUp = @(_) onSignUp()
  forgetPassword = @(_) onForgetPassword()
  faq = @(_) openUrl(getCurCircuitOverride("faqURL", loc("url/faq")), false, false, "login_page")
  support = @(_) openUrl(getCurCircuitOverride("supportURL", loc("url/support")), false, false, "login_page")
  exit = @(_) askQuitGame()
  language = @(p) onChangeLanguage(p.langId)
  usernameEnter = @(_) onUserNameDoneEnter()
  passwordEnter = @(_) onDoneEnter()
  existingAccount = @(_) openExistingAccountPanel()
  existingAccountOpened = @(_) afterOpenExistingAccBlock()
  changed = @(p) onFormValueChanged(p.id)
  doLogin = @(_) doLoginWaitJob()
  startLogin = @(_) startLogin()
}


let ownerActions = {
  tryAgain = @(_) getOwner()?.onLoginErrorTryAgain()
  disableSslCheck = @(_) setDisableSslCertBox(true)
  recovery = @(_) openUrl(getCurCircuitOverride("recoveryPasswordURL", loc("url/recovery")), false, false, "login_wnd")
  exitGame = @(_) exitGamePlatform()
  requestTwoStepCode = @(_) getTwoStepCodeAsync2("ProceedGetTwoStepCode")
}

eventbus_subscribe("loginScreen.action", function(p) {
  let { action } = p
  if (action in formActions) {
    if (hasForm())
      formActions[action](p)
  }
  else if (isOwnerValid())
    ownerActions?[action](p)
})

eventbus_subscribe("ProceedGetTwoStepCode", function ProceedGetTwoStepCode(p) {
  if (hasForm())
    proceedGetTwoStepCode(p)
})

eventbus_subscribe("ConvertExternalJwt", function ContinueExternalLogin(p) {
  if (!hasForm())
    return
  let no_dump_login = getFormValue("loginbox_username", "")
  if (p.status == YU2_OK) {
    finishLogin(no_dump_login)
    load_local_settings()
  }
  else
    proceedAuthorizationResult(p.status, no_dump_login)
})

eventbus_subscribe(webauth_completion_event, function ProceedWebAuth(p) {
  if (hasForm())
    onSsoAuthorizationComplete(p)
})

return freeze({
  openLoginForm
  closeLoginForm = @() webauth_stop()
  getFormValue
  continueLogin
  requestSteamLogin
  proceedAuthorizationResult
  askQuitGame
  onKeyboardLayoutChanged
  onKeyboardLocksChanged
})
