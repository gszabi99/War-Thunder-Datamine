local sonyUser = require("sony.user")
local { openUrl } = require("scripts/onlineShop/url.nut")
local { isPlatformSony, isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local { addPromoAction } = require("scripts/promo/promoActions.nut")
local { havePlayerTag } = require("scripts/user/userUtils.nut")
local { setColoredDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

local countriesWithRecommendEmailRegistration = {
  AZ = "Azerbaijan"
  AM = "Armenia"
  BY = "Belarus"
  GE = "Georgia"
  KZ = "Kazakhstan"
  KG = "Kyrgyzstan"
  LV = "Latvia"
  LT = "Lithuania"
  MD = "Moldova"
  RU = "Russia"
  TJ = "Tajikistan"
  TM = "Turkmenistan"
  UZ = "Uzbekistan"
  UA = "Ukraine"
  EE = "Estonia"
}

local function launchSteamEmailRegistration() {
  local token = ::get_steam_link_token()
  if (token == "")
    return ::dagor.debug("Steam Email Registration: empty token")

  openUrl(::loc("url/steam_bind_url",
    {
      token = token,
      langAbbreviation = ::g_language.getShortName()
    }),
    false, false, "profile_page")
}

local function checkAutoShowSteamEmailRegistration() {
  if (!::steam_is_running() || !havePlayerTag("steamlogin") || !::has_feature("AllowSteamAccountLinking"))
    return

  if (::g_language.getLanguageName() != "Japanese") {
    if (::loadLocalByAccount("SteamEmailRegistrationShowed", false))
      return

    ::saveLocalByAccount("SteamEmailRegistrationShowed", true)
  }

  ::showUnlockWnd({
    name = ::loc("mainmenu/SteamEmailRegistration")
    desc = ::loc("mainmenu/SteamEmailRegistration/desc")
    popupImage = "ui/images/invite_big.jpg?P1"
    onOkFunc = launchSteamEmailRegistration
    okBtnText = "msgbox/btn_bind"
  })
}

local launchPS4EmailRegistration = @()
  ::ps4_open_url_logged_in(::loc("url/ps4_bind_url"), ::loc("url/ps4_bind_redirect"))

local canEmailRegistration = isPlatformSony ? @() havePlayerTag("psnlogin")
  : isPlatformXboxOne ? @() havePlayerTag("livelogin")
  : @() false

local function checkAutoShowPS4EmailRegistration() {
  if (!isPlatformSony || !canEmailRegistration())
    return

  if (::loadLocalByAccount("PS4EmailRegistrationShowed", false))
    return

  ::saveLocalByAccount("PS4EmailRegistrationShowed", true)

  ::showUnlockWnd({
    name = ::loc("mainmenu/PS4EmailRegistration")
    desc = ::loc("mainmenu/PS4EmailRegistration/desc")
    popupImage = "ui/images/invite_big.jpg?P1"
    onOkFunc = launchPS4EmailRegistration
    okBtnText = "msgbox/btn_bind"
  })
}

local function launchXboxEmailRegistration(override = {}) {
  ::gui_modal_editbox_wnd({
    leftAlignedLabel = true
    title = ::loc("mainmenu/XboxOneEmailRegistration")
    label = ::loc("mainmenu/XboxOneEmailRegistration/desc")
    checkWarningFunc = ::g_string.validateEmail
    allowEmpty = false
    needOpenIMEonInit = false
    editBoxEnableFunc = canEmailRegistration
    editBoxTextOnDisable = ::loc("mainmenu/alreadyBinded")
    editboxWarningTooltip = ::loc("tooltip/invalidEmail/possibly")
    okFunc = @(val) ::xbox_link_email(val, function(status) {
      ::g_popups.add("", ::colorize(
        status == ::YU2_OK? "activeTextColor" : "warningTextColor",
        ::loc("mainmenu/XboxOneEmailRegistration/result/" + status)
      ))
    })
  }.__update(override))
}

local getPlayerCountryCode = isPlatformSony ? @() sonyUser?.country.toupper() ?? ::get_country_code()
  : @() ::get_country_code()

local function checkForceSuggestionEmailRegistration() {
  if (!canEmailRegistration())
    return

  if (getPlayerCountryCode() not in countriesWithRecommendEmailRegistration)
    return

  if (isPlatformSony) {
    local bindBtnId = "bind"
    local msgBox = ::scene_msg_box("recommend_email_registration", null, ::loc("mainmenu/recommendEmailRegistration"),
      [
        [bindBtnId, @() launchPS4EmailRegistration()],
        ["later", function() {}]
      ], null)
    if (!(msgBox?.isValid() ?? false))
      return

    local btnTextArea = "textarea { id:t='bind_text';class:t='buttonText';text:t=''}"
    ::get_cur_gui_scene().appendWithBlk(msgBox.findObject(bindBtnId), btnTextArea, null)
    setColoredDoubleTextToButton(msgBox, bindBtnId, ::loc("msgbox/bind_and_recieve"))
    return
  }

  launchXboxEmailRegistration({
    leftAlignedLabel = false
    label = ::loc("mainmenu/recommendEmailRegistration")
    okBtnText = ::loc("msgbox/bind_and_recieve")
  })
}

local emailRegistrationFunctionsByPlatform = {
  PS4 = launchPS4EmailRegistration
  Xbox = launchXboxEmailRegistration
  Steam = launchSteamEmailRegistration
}

local function onLaunchEmailRegistration(params) {
  local platformName = params?[0] ?? ""
  if (platformName == "")
    return

  local launchFunction = emailRegistrationFunctionsByPlatform?[platformName]
  if (launchFunction)
    launchFunction()
}

addPromoAction("email_registration", @(handler, params, obj) onLaunchEmailRegistration(params))

return {
  launchPS4EmailRegistration
  launchXboxEmailRegistration
  launchSteamEmailRegistration
  checkAutoShowPS4EmailRegistration
  checkAutoShowSteamEmailRegistration
  checkForceSuggestionEmailRegistration
}
