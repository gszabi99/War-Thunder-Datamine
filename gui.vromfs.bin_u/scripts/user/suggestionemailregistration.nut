let sonyUser = require("sony.user")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { havePlayerTag } = require("%scripts/user/userUtils.nut")
let { setColoredDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")

let countriesWithRecommendEmailRegistration = {
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

let canEmailRegistration = isPlatformSony ? @() havePlayerTag("psnlogin")
  : isPlatformXboxOne ? @() havePlayerTag("livelogin") && ::has_feature("AllowXboxAccountLinking")
  : ::steam_is_running() ? @() havePlayerTag("steamlogin") && ::has_feature("AllowSteamAccountLinking")
  : @() false

let function launchSteamEmailRegistration() {
  let token = ::get_steam_link_token()
  if (token == "")
    return ::dagor.debug("Steam Email Registration: empty token")

  openUrl(::loc("url/steam_bind_url",
    {
      token = token,
      langAbbreviation = ::g_language.getShortName()
    }),
    false, false, "profile_page")
}

let function checkAutoShowSteamEmailRegistration() {
  if (!canEmailRegistration())
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

let launchPS4EmailRegistration = @()
  ::ps4_open_url_logged_in(::loc("url/ps4_bind_url"), ::loc("url/ps4_bind_redirect"))

let function checkAutoShowPS4EmailRegistration() {
  if (!canEmailRegistration())
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

let sendXboxEmailBind = @(val) ::xbox_link_email(val, function(status) {
  ::g_popups.add("", ::colorize(
    status == ::YU2_OK ? "activeTextColor" : "warningTextColor",
    ::loc($"mainmenu/XboxOneEmailRegistration/result/{status}")
  ))
})

let function launchXboxEmailRegistration(override = {}) {
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
    okFunc = @(val) sendXboxEmailBind(val)
  }.__update(override))
}

let function xboxGetCountryCode() {
  let xbox_code = ::xbox_get_region()
  if (xbox_code != "")
    return xbox_code.toupper()
  return ::get_country_code()
}

let getPlayerCountryCode = isPlatformSony ? @() sonyUser?.country.toupper() ?? ::get_country_code()
  : isPlatformXboxOne ? xboxGetCountryCode
  : @() ::get_country_code()

let function reqUnlockForStartEmailBind() {
  let unlockId = ::get_gui_regional_blk()?.unlockOnStartEmailBind
  if (unlockId == null || ::is_unlocked_scripted(::UNLOCKABLE_ACHIEVEMENT, unlockId))
    return
  ::req_unlock_by_client(unlockId, true)
}

let forceLauncheSuggestionEmailRegistration =
  isPlatformSony ? function() {
    let bindBtnId = "bind"
    let msgBox = ::scene_msg_box("recommend_email_registration", null, ::loc("mainmenu/recommendEmailRegistration"),
        [
          [bindBtnId, function() {
            reqUnlockForStartEmailBind()
            launchPS4EmailRegistration()
          }],
          ["later", function() {}]
        ], null)
      if (!(msgBox?.isValid() ?? false))
        return

      local btnTextArea = "textarea { id:t='bind_text';class:t='buttonText';text:t=''}"
      ::get_cur_gui_scene().appendWithBlk(msgBox.findObject(bindBtnId), btnTextArea, null)
      setColoredDoubleTextToButton(msgBox, bindBtnId, ::loc("msgbox/bind_and_recieve"))
      return
    }
  : isPlatformXboxOne ? @() launchXboxEmailRegistration({
      leftAlignedLabel = false
      label = ::loc("mainmenu/recommendEmailRegistration")
      okBtnText = ::loc("msgbox/bind_and_recieve")
      okFunc = function(val) {
        reqUnlockForStartEmailBind()
        sendXboxEmailBind(val)
      }
    })
  : @() null

let function checkForceSuggestionEmailRegistration() {
  if (!canEmailRegistration())
    return

  if (getPlayerCountryCode() not in countriesWithRecommendEmailRegistration)
    return
  forceLauncheSuggestionEmailRegistration()
}

let checkAutoShowEmailRegistration = isPlatformSony ? checkAutoShowPS4EmailRegistration
 : ::steam_is_running() ? checkAutoShowSteamEmailRegistration
 : @() null

let emailRegistrationTooltip = isPlatformSony ? loc("mainmenu/PS4EmailRegistration/desc")
  : isPlatformXboxOne ? loc("mainmenu/XboxOneEmailRegistration/desc")
  : loc("mainmenu/SteamEmailRegistration/desc")

let launchEmailRegistration = isPlatformSony ? launchPS4EmailRegistration
  : isPlatformXboxOne ? launchXboxEmailRegistration
  : ::steam_is_running() ? launchSteamEmailRegistration
  : @() null

addPromoAction("email_registration", @(handler, params, obj) launchEmailRegistration())

let promoButtonId = "email_registration_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  getText = @() ::loc("promo/btnXBOXAccount_linked")
  image = isPlatformSony ? "https://static.warthunder.ru/upload/image/Promo/2022_03_psn_promo.jpg?P1"
    : isPlatformXboxOne ? "https://static.warthunder.ru/upload/image/Promo/2022_03_xbox_promo.jpg?P1"
    : ::steam_is_running() ? "https://static.warthunder.ru/upload/image/Promo/2022_03_steam_promo.jpg?P1"
    : ""
  aspect_ratio = 2.07
  updateFunctionInHandler = function() {
    let isVisible = isShowAllCheckBoxEnabled()
      || (canEmailRegistration() && ::g_promo.getVisibilityById(promoButtonId))
    ::showBtn(promoButtonId, isVisible, scene)
  }
})

return {
  launchEmailRegistration
  canEmailRegistration
  emailRegistrationTooltip
  checkAutoShowEmailRegistration
  checkForceSuggestionEmailRegistration
}
