//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let statsd = require("statsd")
let { getPollIdByFullUrl, generatePollUrl } = require("%scripts/web/webpoll.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { startsWith, stripTags } = require("%sqstd/string.nut")
let { addTask } = require("%scripts/tasker.nut")

::embedded_browser_event <- function embedded_browser_event(event_type, url, error_desc, error_code,
  is_main_frame) {
  broadcastEvent(
    "EmbeddedBrowser",
    { eventType = event_type, url = url, errorDesc = error_desc,
    errorCode = error_code, isMainFrame = is_main_frame, title = "" }
  );
}

::notify_browser_window <- function notify_browser_window(params) {
  broadcastEvent("EmbeddedBrowser", params)
}

::is_builtin_browser_active <- function is_builtin_browser_active() {
  return ::isHandlerInScene(gui_handlers.BrowserModalHandler)
}

::open_browser_modal <- function open_browser_modal(url = "", tags = [], baseUrl = "") {
  ::gui_start_modal_wnd(gui_handlers.BrowserModalHandler, { url, urlTags = tags, baseUrl })
}

::close_browser_modal <- function close_browser_modal() {
  let handler = handlersManager.findHandlerClassInScene(
    gui_handlers.BrowserModalHandler)

  if (handler == null) {
    log("[BRWS] Couldn't find embedded browser modal handler")
    return
  }

  handler.goBack()
}

::browser_set_external_url <- function browser_set_external_url(url) {
  let handler = handlersManager.findHandlerClassInScene(
    gui_handlers.BrowserModalHandler);
  if (handler)
    handler.externalUrl = url;
}

gui_handlers.BrowserModalHandler <- class extends ::BaseGuiHandler {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/browser.blk"
  sceneNavBlkName = null
  url = ""
  externalUrl = ""
  lastLoadedUrl = ""
  baseUrl = ""
  needVoiceChat = false
  urlTags = []
  isLoadingPage = true

  function initScreen() {
    let browserObj = this.scene.findObject("browser_area")
    browserObj.url = this.url
    this.lastLoadedUrl = this.baseUrl
    ::browser_go(this.url)
  }

  function browserCloseAndUpdateEntitlements() {
    addTask(::update_entitlements_limited(),
                       {
                         showProgressBox = true
                         progressBoxText = loc("charServer/checking")
                       },
                       @() ::update_gamercards())
    this.goBack()
  }

  function browserGoBack() {
    ::browser_go_back()
  }

  function onBrowserBtnReload() {
    ::browser_reload_page()
  }

  function browserForceExternal() {
    local taggedUrl = this.isLoadingPage
      ? this.lastLoadedUrl
      : ::browser_get_current_url()
    if (!u.isEmpty(this.urlTags) && taggedUrl != "") {
      let tagsStr = " ".join(this.urlTags)
      if (!startsWith(taggedUrl, tagsStr))
        taggedUrl = " ".concat(tagsStr, taggedUrl)
    }

    let newUrl = u.isEmpty(this.externalUrl) ? taggedUrl : this.externalUrl
    openUrl(u.isEmpty(newUrl) ? this.baseUrl : newUrl, true, false, "internal_browser")
  }

  function setTitle(title) {
    if (u.isEmpty(title))
      return

    let titleObj = this.scene.findObject("wnd_title")
    if (checkObj(titleObj))
      titleObj.setValue(title)
  }

  function onEventEmbeddedBrowser(params) {
    switch (params.eventType) {
      case BROWSER_EVENT_DOCUMENT_READY:
        this.lastLoadedUrl = ::browser_get_current_url()
        this.toggleWaitAnimation(false)
        break;
      case BROWSER_EVENT_FAIL_LOADING_FRAME:
        if (params.isMainFrame) {
          this.toggleWaitAnimation(false)
          let message = "".concat(loc("browser/error_load_url"), loc("ui/dot"),
            "\n", loc("browser/error_code"), loc("ui/colon"), params.errorCode, loc("ui/comma"), params.errorDesc)
          let urlCommentMarkup = this.getUrlCommentMarkupForMsgbox(params.url)
          this.msgBox("error_load_url", message, [["ok", @() null ]], "ok", { data_below_text = urlCommentMarkup })
        }
        break;
      case BROWSER_EVENT_NEED_RESEND_FRAME:
        this.toggleWaitAnimation(false)

        this.msgBox("error", loc("browser/error_should_resend_data"),
            [["#mainmenu/btnBack", this.browserGoBack],
             ["#mainmenu/btnRefresh",  function() { ::browser_go(params.url) }]],
             "#mainmenu/btnBack")
        break;
      case BROWSER_EVENT_CANT_DOWNLOAD:
        this.toggleWaitAnimation(false)
        showInfoMsgBox(loc("browser/error_cant_download"))
        break;
      case BROWSER_EVENT_BEGIN_LOADING_FRAME:
        if (params.isMainFrame) {
          this.toggleWaitAnimation(true)
          this.setTitle(params.title)
        }
        break;
      case BROWSER_EVENT_FINISH_LOADING_FRAME:
        this.lastLoadedUrl = ::browser_get_current_url()
        if (params.isMainFrame) {
          this.toggleWaitAnimation(false)
          this.setTitle(params.title)
        }
        break;
      case BROWSER_EVENT_BROWSER_CRASHED:
        log("[BRWS] embedded browser crashed, forcing external")
        statsd.send_counter("sq.browser.crash", 1, { reason = params.errorDesc })
        this.browserForceExternal()
        this.goBack()
        break;
      default:
        log("[BRWS] onEventEmbeddedBrowser: unknown event type "
          + params.eventType);
        break;
    }
  }

  function onEventWebPollAuthResult(_param) {
    // WebPollAuthResult event may come before browser opens the page
    let currentUrl = u.isEmpty(::browser_get_current_url()) ? this.url : ::browser_get_current_url()
    if (u.isEmpty(currentUrl))
      return
    // we have to update externalUrl for any pollId
    // so we don't care about pollId from param
    let pollId = getPollIdByFullUrl(currentUrl)
    if (! pollId)
      return
    this.externalUrl = generatePollUrl(pollId, false)
  }

  function toggleWaitAnimation(show) {
    this.isLoadingPage = show

    let waitSpinner = this.scene.findObject("browserWaitAnimation");
    if (checkObj(waitSpinner))
      waitSpinner.show(show);
  }

  function onDestroy() {
    broadcastEvent("DestroyEmbeddedBrowser")
  }

  function wordWrapText(str, width) {
    if (type(str) != "string" || str == "" || width <= 0)
      return str
    let wrapped = []
    let lines = str.split("\n")
    foreach (line in lines) {
      let unicodeLine = utf8(line)
      let strLen = unicodeLine.charCount()
      for (local pos = 0; pos < strLen; pos += width)
        wrapped.append(unicodeLine.slice(pos, pos + width))
    }
    return "\n".join(wrapped)
  }

  function getUrlCommentMarkupForMsgbox(urlStr) {
    if (urlStr == "")
      return ""

    // Splitting too long URL because daGUI textarea don't break words on word-wrap.
    let fontSizePropName = "smallFont"
    let fontSizeCssId = "fontSmall"
    let maxWidthPx = to_pixels("0.8@rw")
    let textWidthPx = getStringWidthPx(urlStr, fontSizeCssId, this.guiScene)
    if (textWidthPx != 0 && textWidthPx > maxWidthPx) {
      let splitByChars = (1.0 * maxWidthPx / textWidthPx * utf8(urlStr).charCount()).tointeger()
      urlStr = this.wordWrapText(urlStr, splitByChars)
    }
    return format("textareaNoTab { %s:t='yes'; overlayTextColor:t='faded'; text:t='%s'; }",
      fontSizePropName, stripTags(urlStr))
  }
}
