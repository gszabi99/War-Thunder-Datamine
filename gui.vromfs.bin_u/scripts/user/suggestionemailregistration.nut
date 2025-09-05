from "%scripts/dagui_natives.nut" import ps4_open_url_logged_in, xbox_link_email, get_steam_link_token
from "%scripts/dagui_library.nut" import *

let { is_gdk } = require("%sqstd/platform.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { isPlatformSony, isPlatformPC
} = require("%scripts/clientState/platform.nut")
let { havePlayerTag } = require("%scripts/user/profileStates.nut")
let { register_command } = require("console")
let { getPlayerSsoShortTokenAsync } = require("auth_wt")
let { TIME_DAY_IN_SECONDS } = require("%scripts/time.nut")
let { validateEmail } = require("%sqstd/string.nut")
let { eventbus_subscribe, eventbus_subscribe_onehit } = require("eventbus")
let { get_charserver_time_sec } = require("chard")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getCurLangShortName, getLanguageName } = require("%scripts/langUtils/language.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { steam_is_running } = require("steam")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { showUnlockWnd } = require("%scripts/unlocks/showUnlockWnd.nut")
let { showWaitScreen, closeWaitScreen } = require("%scripts/waitScreen/waitScreen.nut")
let { showErrorMessageBox } = require("%scripts/utils/errorMsgBox.nut")

let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")

let needShowGuestEmailRegistration = @() isPlatformPC && havePlayerTag("guestlogin")

function launchGuestEmailRegistration(stoken) {
  let language = getCurLangShortName()
  let url = getCurCircuitOverride("guestBindURL", loc("url/pc_bind_url")).subst({ language, stoken })
  openUrl(url, false, false, "profile_page")
}

eventbus_subscribe("onGetStokenForGuestEmail", function(msg) {
  let { status, stoken = null } = msg
  if (status != YU2_OK)
    showErrorMessageBox("yn1/connect_error", status, [["ok"]], "ok")
  else
    launchGuestEmailRegistration(stoken)
})

function showGuestEmailRegistration() {
  showUnlockWnd({
    name = loc("mainmenu/SteamEmailRegistration")
    desc = loc("mainmenu/guestEmailRegistration/desc")
    popupImage = "ui/images/invite_big?P1"
    onOkFunc = @() getPlayerSsoShortTokenAsync("onGetStokenForGuestEmail")
    okBtnText = "msgbox/btn_bind"
  })
}

function checkShowGuestEmailRegistrationAfterLogin() {
  if (!needShowGuestEmailRegistration())
    return

  let firstCheckTime = loadLocalAccountSettings("GuestEmailRegistrationCheckTime")
  if (firstCheckTime == null) {
    saveLocalAccountSettings("GuestEmailRegistrationCheckTime", get_charserver_time_sec())
    return
  }

  let timeSinceFirstCheck = get_charserver_time_sec() - firstCheckTime
  if (timeSinceFirstCheck < TIME_DAY_IN_SECONDS)
    return

  showGuestEmailRegistration()
}

let canEmailRegistration = isPlatformSony ? @() havePlayerTag("psnlogin")
  : is_gdk ? @() havePlayerTag("livelogin") && hasFeature("AllowXboxAccountLinking")
  : steam_is_running() ? @() havePlayerTag("steamlogin") && hasFeature("AllowSteamAccountLinking")
  : @() false

function launchSteamEmailRegistration() {
  let token = get_steam_link_token()
  if (token == "")
    return log("Steam Email Registration: empty token")

  openUrl(loc("url/steam_bind_url",
    {
      token = token,
      langAbbreviation = getCurLangShortName()
    }),
    false, false, "profile_page")
}

function checkShowSteamEmailRegistration() {
  if (!canEmailRegistration())
    return

  if (getLanguageName() != "Japanese") {
    if (loadLocalByAccount("SteamEmailRegistrationShowed", false))
      return

    saveLocalByAccount("SteamEmailRegistrationShowed", true)
  }

  showUnlockWnd({
    name = loc("mainmenu/SteamEmailRegistration")
    desc = loc("mainmenu/SteamEmailRegistration/desc")
    popupImage = "ui/images/invite_big?P1"
    onOkFunc = launchSteamEmailRegistration
    okBtnText = "msgbox/btn_bind"
  })
}

let launchPS4EmailRegistration = @()
  ps4_open_url_logged_in(loc("url/ps4_bind_url"), loc("url/ps4_bind_redirect"))

function checkShowPS4EmailRegistration() {
  if (!canEmailRegistration())
    return

  if (loadLocalByAccount("PS4EmailRegistrationShowed", false))
    return

  saveLocalByAccount("PS4EmailRegistrationShowed", true)

  showUnlockWnd({
    name = loc("mainmenu/PS4EmailRegistration")
    desc = loc("mainmenu/PS4EmailRegistration/desc")
    popupImage = "ui/images/invite_big?P1"
    onOkFunc = launchPS4EmailRegistration
    okBtnText = "msgbox/btn_bind"
  })
}

function sendXboxEmailBind(val) {
  showWaitScreen("msgbox/please_wait")
  let eventName = "xbox_link_email_event"
  eventbus_subscribe_onehit(eventName, function(data) {
    let status = data?.status ?? YU2_FAIL
    closeWaitScreen()
    addPopup("", colorize(
      status == YU2_OK ? "activeTextColor" : "warningTextColor",
      loc($"mainmenu/XboxOneEmailRegistration/result/{status}")
    ))
  })
  xbox_link_email(val, eventName)
}

function launchXboxEmailRegistration(override = {}) {
  openEditBoxDialog({
    leftAlignedLabel = true
    title = loc("mainmenu/XboxOneEmailRegistration")
    label = loc("mainmenu/XboxOneEmailRegistration/desc")
    checkWarningFunc = validateEmail
    allowEmpty = false
    needOpenIMEonInit = false
    editBoxEnableFunc = canEmailRegistration
    editBoxTextOnDisable = loc("mainmenu/alreadyBinded")
    editboxWarningTooltip = loc("tooltip/invalidEmail/possibly")
    okFunc = @(val) sendXboxEmailBind(val)
  }.__update(override))
}

let forceLauncheXboxSuggestionEmailRegistration = @()
  launchXboxEmailRegistration({
    leftAlignedLabel = false
    label = loc("mainmenu/recommendEmailRegistration")
    okBtnText = loc("msgbox/bind_and_receive")
    okFunc = sendXboxEmailBind
  })

function checkShowXboxEmailRegistration() {
  if (!canEmailRegistration())
    return

  if (loadLocalByAccount("XboxEmailRegistrationShowed", false))
    return

  saveLocalByAccount("XboxEmailRegistrationShowed", true)

  forceLauncheXboxSuggestionEmailRegistration()
}

let checkShowEmailRegistration = isPlatformSony ? checkShowPS4EmailRegistration
  : steam_is_running() ? checkShowSteamEmailRegistration
  : is_gdk ? checkShowXboxEmailRegistration
  : @() null

let emailRegistrationTooltip = isPlatformSony ? loc("mainmenu/PS4EmailRegistration/desc")
  : is_gdk ? loc("mainmenu/XboxOneEmailRegistration/desc")
  : loc("mainmenu/SteamEmailRegistration/desc")

let launchEmailRegistration = isPlatformSony ? launchPS4EmailRegistration
  : is_gdk ? launchXboxEmailRegistration
  : steam_is_running() ? launchSteamEmailRegistration
  : @() null

register_command(function(platform) {
  let fn = platform == "xbox" ? forceLauncheXboxSuggestionEmailRegistration
    : @() console_print($"is missing suggestion for platform {platform}, available 'xbox', 'sony'")
  fn()
  return console_print($"show suggestion for platform {platform}")
}, "emailRegistration.showForceSuggestion")

return {
  launchEmailRegistration
  canEmailRegistration
  emailRegistrationTooltip
  checkShowEmailRegistration
  needShowGuestEmailRegistration
  showGuestEmailRegistration
  checkShowGuestEmailRegistrationAfterLogin
}
