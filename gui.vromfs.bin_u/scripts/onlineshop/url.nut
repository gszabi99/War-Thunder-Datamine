//-file:plus-string
from "%scripts/dagui_natives.nut" import send_error_log, use_embedded_browser, steam_is_running
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let { split_by_chars } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { shell_launch, get_authenticated_url_sso } = require("url")
let { clearBorderSymbols, lastIndexOf } = require("%sqstd/string.nut")
let base64 = require("base64")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getCurLangShortName } = require("%scripts/langUtils/language.nut")
let samsung = require("samsung")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { eventbus_subscribe } = require("eventbus")
let { g_url_type } = require("%scripts/onlineShop/urlType.nut")

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

function getAuthenticatedUrlConfig(baseUrl, isAlreadyAuthenticated = false) {
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
  if (!isAlreadyAuthenticated && shouldLogin && canAutoLogin()) {
    let shouldEncode = !isInArray(URL_TAG_NO_ENCODING, urlTags)
    local autoLoginUrl = url
    if (shouldEncode)
      autoLoginUrl = base64.encodeString(autoLoginUrl)

    let ssoServiceTag = urlTags.filter(@(v) v.indexof(URL_TAG_SSO_SERVICE) == 0);
    let ssoService = ssoServiceTag.len() != 0 ? ssoServiceTag.pop().slice(URL_TAG_SSO_SERVICE.len()) : ""
    let authData = get_authenticated_url_sso(autoLoginUrl, ssoService)

    if (authData.yuplayResult == YU2_OK)
      url = authData.url + (shouldEncode ? "&ret_enc=1" : "") //This parameter is needed for coded complex links.
    else
      send_error_log("Authorize url: failed to get authenticated url with error " + authData.yuplayResult,
        false, AUTH_ERROR_LOG_COLLECTION)
  }

  return {
    url
    urlWithoutTags
    urlTags
    urlType
  }
}

function open(baseUrl, forceExternal = false, isAlreadyAuthenticated = false) {
  if (!hasFeature("AllowExternalLink"))
    return

  let guiScene = get_cur_gui_scene()
  if (guiScene.isInAct()) {
    let openImpl = callee()
    guiScene.performDelayed({}, @() openImpl(baseUrl, forceExternal, isAlreadyAuthenticated))
    return
  }

  let browser = forceExternal ? "external" : "any"
  let authenticated = isAlreadyAuthenticated ? " authenticated" : ""
  log($"[URL] open {browser} browser for{authenticated} '{baseUrl}'")

  let urlConfig = getAuthenticatedUrlConfig(baseUrl, isAlreadyAuthenticated)
  if (urlConfig == null)
    return

  let url = urlConfig.url
  let urlType = urlConfig.urlType

  log("[URL] Open url with urlType = " + urlType.typeName + ": " + url)
  log("[URL] Base Url = " + baseUrl)
  let hasFeat = urlType.isOnlineShop
                     ? hasFeature("EmbeddedBrowserOnlineShop")
                     : hasFeature("EmbeddedBrowser")
  if (!forceExternal && ::use_embedded_browser() && !steam_is_running() && hasFeat) {
    // Embedded browser
    ::open_browser_modal(url, urlConfig.urlTags, baseUrl)
    broadcastEvent("BrowserOpened", { url = url, external = false })
    return
  }

  //shell_launch can be long sync function so call it delayed to avoid broke current call.
  get_gui_scene().performDelayed(getroottable(), function() {
    // External browser
    let response = shell_launch(url)
    if (response > 0) {
      let errorText = ::get_yu2_error_text(response)
      showInfoMsgBox(errorText, "errorMessageBox")
      log("shell_launch() have returned " + response + " for URL:" + url)
    }
    broadcastEvent("BrowserOpened", { url = url, external = true })
  })
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
  getAuthenticatedUrlConfig
  getUrlWithQrRedirect
}
