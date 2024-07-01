//-file:plus-string
from "%scripts/dagui_natives.nut" import send_error_log, use_embedded_browser
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { split_by_chars } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shell_launch } = require("url")
let { clearBorderSymbols, lastIndexOf } = require("%sqstd/string.nut")
let base64 = require("base64")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getCurLangShortName } = require("%scripts/langUtils/language.nut")
let samsung = require("samsung")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { eventbus_subscribe, eventbus_send } = require("eventbus")
let { g_url_type } = require("%scripts/onlineShop/urlType.nut")
let { steam_is_running } = require("steam")
let { get_authenticated_url_sso } = require("auth_wt")
let { object_to_json_string, parse_json } = require("json")
let { defer } = require("dagor.workcycle")

const URL_TAGS_DELIMITER = " "
const URL_TAG_AUTO_LOCALIZE = "auto_local"
const URL_TAG_AUTO_LOGIN = "auto_login"
const URL_TAG_SSO_SERVICE = "sso_service="
const URL_TAG_NO_ENCODING = "no_encoding"

const AUTH_ERROR_LOG_COLLECTION = "log"

let qrRedirectSupportedLangs = ["ru", "en", "fr", "de", "es", "pl", "cs", "pt", "ko", "tr"]
const QR_REDIRECT_URL = "https://login.gaijin.net/{0}/qr/{1}"

function getUrlWithQrRedirect(url) {
  local lang = getCurLangShortName()
  if (!isInArray(lang, qrRedirectSupportedLangs))
    lang = "en"
  return QR_REDIRECT_URL.subst(lang, base64.encodeString(url))
}

let canAutoLogin = @() ::g_login.isAuthorized()

eventbus_subscribe("onAuthenticatedUrlResult", function(msg) {
  let { status, contextStr = "", url = null } = msg
  let { baseUrl = "", notAuthUrl = "", urlTags = [], urlWithoutTags = "",
    useExternalBrowser = true, shouldEncode = false, cbEventbusName = "" } = contextStr != "" ? parse_json(contextStr) : null
  if (cbEventbusName == "") {
    logerr("onAuthenticatedUrlResult missing cbEventbusName")
    return
  }

  local urlToOpen = url
  if (status == YU2_OK) {
    if (shouldEncode)
      urlToOpen = $"{url}&ret_enc=1" //This parameter is needed for coded complex links.
  }
  else {
    urlToOpen = notAuthUrl
    send_error_log($"Authorize url: failed to get authenticated url with error {status}",
      false, AUTH_ERROR_LOG_COLLECTION)
    if (urlToOpen == "")
      return
  }

  eventbus_send(cbEventbusName, { baseUrl, urlToOpen, urlTags, urlWithoutTags, useExternalBrowser })
})

function requestAuthenticatedUrl(baseUrl, cbEventbusName, isAlreadyAuthenticated = false, useExternalBrowser = false) {
  if (baseUrl == null || baseUrl == "") {
    log("Error: tried to open an empty url")
    return null
  }

  local url = clearBorderSymbols(baseUrl, [URL_TAGS_DELIMITER])
  let urlTags = split_by_chars(baseUrl, URL_TAGS_DELIMITER)
  if (!urlTags.len()) {
    log("Error: tried to open an empty url")
    return null
  }
  let urlWithoutTags = urlTags.remove(urlTags.len() - 1)
  url = urlWithoutTags

  let urlType = g_url_type.getByUrl(url)
  if (isInArray(URL_TAG_AUTO_LOCALIZE, urlTags))
    url = urlType.applyCurLang(url)

  let shouldLogin = isInArray(URL_TAG_AUTO_LOGIN, urlTags)
  if (isAlreadyAuthenticated || !shouldLogin || !canAutoLogin()) {
    eventbus_send(cbEventbusName, { baseUrl, urlToOpen = url, urlTags, urlWithoutTags, useExternalBrowser })
    return
  }

  let shouldEncode = !isInArray(URL_TAG_NO_ENCODING, urlTags)
  local autoLoginUrl = url
  if (shouldEncode)
    autoLoginUrl = base64.encodeString(autoLoginUrl)

  let ssoServiceTag = urlTags.filter(@(v) v.indexof(URL_TAG_SSO_SERVICE) == 0);
  let ssoService = ssoServiceTag.len() != 0 ? ssoServiceTag.pop().slice(URL_TAG_SSO_SERVICE.len()) : ""
  get_authenticated_url_sso(autoLoginUrl, "", ssoService, "onAuthenticatedUrlResult",
    object_to_json_string({ baseUrl, notAuthUrl = autoLoginUrl, urlTags, urlWithoutTags,
      useExternalBrowser, cbEventbusName, shouldEncode }))
}

eventbus_subscribe("openUrlImpl", function(urlConfig) {
  let { baseUrl, urlToOpen, urlTags, useExternalBrowser, urlWithoutTags } = urlConfig
  let urlType = g_url_type.getByUrl(urlWithoutTags)

  log($"[URL] Open url with urlType = {urlType.typeName}: {urlToOpen}")
  log($"[URL] Base Url = {baseUrl}")
  let hasFeat = urlType.isOnlineShop ? hasFeature("EmbeddedBrowserOnlineShop")
    : hasFeature("EmbeddedBrowser")
  if (!useExternalBrowser && ::use_embedded_browser() && !steam_is_running() && hasFeat) {
    // Embedded browser
    ::open_browser_modal(urlToOpen, urlTags, baseUrl)
    broadcastEvent("BrowserOpened", { url = urlToOpen, external = false })
    return
  }

  //shell_launch can be long sync function so call it delayed to avoid broke current call.
  defer(function() {
    // External browser
    let response = shell_launch(urlToOpen)
    if (response > 0) {
      let errorText = ::get_yu2_error_text(response)
      showInfoMsgBox(errorText, "errorMessageBox")
      log($"shell_launch() have returned {response} for URL: {urlToOpen}")
    }
    broadcastEvent("BrowserOpened", { url = urlToOpen, external = true })
  })
})

function open(baseUrl, forceExternal = false, isAlreadyAuthenticated = false) {
  if (!hasFeature("AllowExternalLink"))
    return

  let guiScene = get_cur_gui_scene()
  if (guiScene.isInAct()) {
    let openImpl = callee()
    defer(@() openImpl(baseUrl, forceExternal, isAlreadyAuthenticated))
    return
  }

  let browser = forceExternal ? "external" : "any"
  let authenticated = isAlreadyAuthenticated ? " authenticated" : ""
  log($"[URL] open {browser} browser for{authenticated} '{baseUrl}'")
  requestAuthenticatedUrl(baseUrl, "openUrlImpl", isAlreadyAuthenticated, forceExternal)
}

function openUrlByObj(obj, forceExternal = false, isAlreadyAuthenticated = false) {
  if (!checkObj(obj) || obj?.link == null || obj.link == "")
    return

  let link = (obj.link.slice(0, 1) == "#") ? loc(obj.link.slice(1)) : obj.link
  open(link, forceExternal, isAlreadyAuthenticated)
}

function validateLink(link) {
  if (link == null)
    return null

  if (!u.isString(link)) {
    log("CHECK LINK result: " + toString(link))
    assert(false, "CHECK LINK: Link received not as text")
    return null
  }

  link = clearBorderSymbols(link, [URL_TAGS_DELIMITER])
  local linkStartIdx = lastIndexOf(link, URL_TAGS_DELIMITER)
  if (linkStartIdx < 0)
    linkStartIdx = 0

  if (link.indexof("://", linkStartIdx) != null)
    return link

  if (link.indexof("www.", linkStartIdx) != null)
    return link

  let localizedLink = loc(link, "")
  if (localizedLink != "")
    return localizedLink

  log("CHECK LINK: Not found any localization string for link: " + link)
  return null
}

function openUrl(baseUrl, forceExternal = false, isAlreadyAuthenticated = false, biqQueryKey = "") {
  if (!hasFeature("AllowExternalLink"))
    return

  let bigQueryInfoObject = { url = baseUrl }
  if (! u.isEmpty(biqQueryKey))
    bigQueryInfoObject["from"] <- biqQueryKey

  sendBqEvent("CLIENT_POPUP_1", forceExternal ? "player_opens_external_browser" : "player_opens_browser", bigQueryInfoObject)

  if(samsung.is_running()) {
    handlersManager.loadHandler(gui_handlers.qrWindow, {
      headerText = ""
      qrCodesData = [
        {url = baseUrl}
      ]
      needUrlWithQrRedirect = true
      needShowUrlLink = false
    })
  }
  else
    open(baseUrl, forceExternal, isAlreadyAuthenticated)
}

eventbus_subscribe("open_url", @(p) openUrl(p.baseUrl, p?.forceExternal ?? false,
  p?.isAlreadyAuthenticated ?? false, p?.biqQueryKey ?? ""))

return {
  openUrl
  openUrlByObj
  validateLink
  requestAuthenticatedUrl
  getUrlWithQrRedirect
}
