let { showInfoMsgBox } = require("%sqDagui/framework/msgBox.nut")
let { loc } = require("dagor.localize")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { getPlayerSsoShortTokenAsync, getNickOrig } = require("auth_wt")
let { eventbus_subscribe } = require("eventbus")
let { log } = require("%sqstd/log.nut")()
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let regexp2 = require("regexp2")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")

const BASE_URL =  "https://warthunder.com/loginQR/?stoken={stokenParam}&stat={deeplinkPlaceParam}&nick={nickParam}&login={userIdParam}" 

const EXTERNAL_DEEPLINK_URL_PARAM_NAME = "parameterizedDeeplinkURL"

local deeplinkPlace = ""

function hasExternalAssistantDeepLink() {
  return getCurCircuitOverride(EXTERNAL_DEEPLINK_URL_PARAM_NAME) != null
}

function isExternalOperator() {
  return getCurCircuitOverride("operatorName") != null
}

function openModalWTAssistantlDeeplink(place) {
  deeplinkPlace = place
  getPlayerSsoShortTokenAsync("onGetStokenForWTAssistantlDeeplink")
}

function intToHexChar(value) {
  let hexDigits = "0123456789ABCDEF"
  return hexDigits[value & 0x0F].tochar()
}

function urlEncodeChar(ch) {
  if (regexp2(@"[a-zA-Z0-9_.~-]").match(ch.tochar())) {
    return ch.tochar()
  }

  let highNibble = (ch >> 4) & 0x0F
  let lowNibble = ch & 0x0F
  return $"%{intToHexChar(highNibble) + intToHexChar(lowNibble)}"
}

function urlEncodeString(input) {
  local encoded = ""
  foreach(ch in input) {
    encoded += urlEncodeChar(ch)
  }

  return encoded
}

eventbus_subscribe("onGetStokenForWTAssistantlDeeplink", function(msg) {
  let { status, stoken = null } = msg

  if (status != YU2_OK) {
    log("ERROR: on get short token for wt assistant deeplink = ", status)
    showInfoMsgBox(loc("msgbox/notAvailbleShortToken"))
    return
  }

  log("SUCCESS: on get short token for wt assistant deeplink from = ", deeplinkPlace)

  let link = getCurCircuitOverride(EXTERNAL_DEEPLINK_URL_PARAM_NAME, BASE_URL).subst({
    stokenParam = urlEncodeString(stoken),
    deeplinkPlaceParam = urlEncodeString(deeplinkPlace),
    nickParam = urlEncodeString(getNickOrig()),
    userIdParam = userIdStr.value
  })

  openQrWindow({
    headerText = loc("wtassistant_deeplink/title")
    infoText = loc("wtassistant_deeplink/descr")
    qrCodesData = [
      { url = link }
    ]
    needShowUrlLink = false
  })
})

addPromoAction("show_wta_baner", @(_handler, _params, _obj) openModalWTAssistantlDeeplink("PROMO"))

return {
  openModalWTAssistantlDeeplink
  hasExternalAssistantDeepLink
  isExternalOperator
}