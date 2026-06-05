let { showInfoMsgBox } = require("%sqDagui/framework/msgBox.nut")
let { loc } = require("dagor.localize")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { getPlayerSsoShortTokenAsync, getNickOrig } = require("auth_wt")
let { eventbus_subscribe } = require("eventbus")
let { log } = require("%sqstd/log.nut")()
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")
let { format } = require("string")
let regexp2 = require("regexp2")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")

const EXTERNAL_DEEPLINK_URL_PARAM_NAME = "parameterizedDeeplinkURL"

local pendingQrParams = null

function hasExternalAssistantDeepLink() {
  return getCurCircuitOverride(EXTERNAL_DEEPLINK_URL_PARAM_NAME) != null
}

function isExternalOperator() {
  return getCurCircuitOverride("operatorName") != null
}

function getAssistantExternalName() {
  let publisher = getCurCircuitOverride("publisher")
  if (publisher != null)
    return publisher

  let operatorName = getCurCircuitOverride("operatorName")
  if (operatorName != null)
    return operatorName

  return "gaijin"
}

function mergeAssistantDeeplinkQueryParams(extraQueryParams) {
  let merged = { external = getAssistantExternalName() }
  if (extraQueryParams != null)
    foreach (key, value in extraQueryParams)
      if (value != null)
        merged[key] <- value
  return merged
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

function appendQueryParams(url, queryParams) {
  if ((queryParams?.len() ?? 0) == 0)
    return url

  let parts = []
  foreach (key, value in queryParams) {
    if (value == null)
      continue

    parts.append($"{urlEncodeString(key)}={urlEncodeString($"{value}")}")
  }

  if (parts.len() == 0)
    return url

  return $"{url}{url.indexof("?") != null ? "&" : "?"}{("&").join(parts)}"
}

function buildDefaultWTAssistantDeeplink(stoken, place) {
  return format("https://warthunder.com/%s/loginQR/?stoken=%s&stat=%s&nick=%s&login=%s",
    loc("current_lang"),
    urlEncodeString(stoken),
    urlEncodeString(place),
    urlEncodeString(getNickOrig()),
    urlEncodeString(userIdStr.get()))
}

function buildWTAssistantDeeplink(stoken, place, extraQueryParams = null) {
  let externalDeeplink = getCurCircuitOverride(EXTERNAL_DEEPLINK_URL_PARAM_NAME)
  let baseLink = externalDeeplink == null
    ? buildDefaultWTAssistantDeeplink(stoken, place)
    : externalDeeplink.subst({
        stokenParam = urlEncodeString(stoken),
        deeplinkPlaceParam = urlEncodeString(place),
        nickParam = urlEncodeString(getNickOrig()),
        userIdParam = urlEncodeString(userIdStr.get())
      })

  return appendQueryParams(baseLink, mergeAssistantDeeplinkQueryParams(extraQueryParams))
}

function openWTAssistantDeeplinkQr(params = {}) {
  pendingQrParams = {
    place = params?.place ?? ""
    extraQueryParams = params?.extraQueryParams
    headerText = params?.headerText ?? loc("wtassistant_deeplink/title")
    infoText = params?.infoText ?? loc("wtassistant_deeplink/descr")
    autoRefreshAuthenticatedUrl = params?.autoRefreshAuthenticatedUrl ?? true
    onQrOpened = params?.onQrOpened
    onQrClosed = params?.onQrClosed
    assistantMapSessionQr = params?.assistantMapSessionQr ?? false
  }

  getPlayerSsoShortTokenAsync("onGetStokenForWTAssistantlDeeplink")
}

function openModalWTAssistantlDeeplink(place) {
  openWTAssistantDeeplinkQr({ place })
}

eventbus_subscribe("onGetStokenForWTAssistantlDeeplink", function(msg) {
  let { status, stoken = null } = msg

  if (status != YU2_OK) {
    log("ERROR: on get short token for wt assistant deeplink = ", status)
    showInfoMsgBox(loc("msgbox/notAvailbleShortToken"))
    return
  }

  let {
    place = ""
    extraQueryParams = null
    headerText = loc("wtassistant_deeplink/title")
    infoText = loc("wtassistant_deeplink/descr")
    autoRefreshAuthenticatedUrl = true
    onQrOpened = null
    onQrClosed = null
    assistantMapSessionQr = false
  } = pendingQrParams ?? {}

  log("SUCCESS: on get short token for wt assistant deeplink from = ", place)

  let link = buildWTAssistantDeeplink(stoken, place, extraQueryParams)

  openQrWindow({
    headerText = headerText
    infoText = infoText
    qrCodesData = [
      { url = link }
    ]
    needShowUrlLink = false
    autoRefreshAuthenticatedUrl = autoRefreshAuthenticatedUrl
    onQrClosed = onQrClosed
    assistantMapSessionQr = assistantMapSessionQr
  })

  onQrOpened?()
  pendingQrParams = null
})

addPromoAction("show_wta_baner", @(_handler, _params, _obj) openModalWTAssistantlDeeplink("PROMO"))

return {
  openModalWTAssistantlDeeplink
  openWTAssistantDeeplinkQr
  hasExternalAssistantDeepLink
  isExternalOperator
}