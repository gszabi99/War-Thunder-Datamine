from "%scripts/dagui_natives.nut" import browser_reload_page, browser_go, browser_get_current_url, browser_go_back
from "%scripts/dagui_library.nut" import *

let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let statsd = require("statsd")
let { getPollIdByFullUrl, generatePollUrl } = require("%scripts/web/webpoll.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { startsWith, stripTags } = require("%sqstd/string.nut")
let { addTask } = require("%scripts/tasker.nut")
let { updateEntitlementsLimited } = require("%scripts/onlineShop/entitlementsUpdate.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { eventbus_subscribe } = require("eventbus")

eventbus_subscribe("notify_browser_window", @(params) broadcastEvent("EmbeddedBrowser", params))

gui_handlers.BrowserModalHandler <- class (BaseGuiHandler) {
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
    browser_go(this.url)
  }

  function browserCloseAndUpdateEntitlements() {
    addTask(updateEntitlementsLimited(),
                       {
                         showProgressBox = true
                         progressBoxText = loc("charServer/checking")
                       },
                       @() updateGamercards())
    this.goBack()
  }

  function browserGoBack() {
    browser_go_back()
  }

  function onBrowserBtnReload() {
    browser_reload_page()
  }

  function browserForceExternal() {
    local taggedUrl = this.isLoadingPage
      ? this.lastLoadedUrl
      : browser_get_current_url()
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
    let { eventType, url = "", title = "", errorDesc = "" } = params
    if (eventType == BROWSER_EVENT_DOCUMENT_READY) {
      this.lastLoadedUrl = browser_get_current_url()
      this.toggleWaitAnimation(false)
    }
    else if (eventType == BROWSER_EVENT_FAIL_LOADING_FRAME) {
      this.toggleWaitAnimation(false)
      let message = "".concat(loc("browser/error_load_url"), loc("ui/dot"),
        "\n", loc("browser/error_code"), loc("ui/colon"), errorDesc)
      let urlCommentMarkup = this.getUrlCommentMarkupForMsgbox(url)
      this.msgBox("error_load_url", message, [["ok", @() null ]], "ok", { data_below_text = urlCommentMarkup })
    }
    else if (eventType == BROWSER_EVENT_NEED_RESEND_FRAME) {
      this.toggleWaitAnimation(false)

      this.msgBox("error", loc("browser/error_should_resend_data"),
          [["#mainmenu/btnBack", this.browserGoBack],
           ["#mainmenu/btnRefresh",  function() { browser_go(url) }]],
           "#mainmenu/btnBack")
    }
    else if (eventType == BROWSER_EVENT_CANT_DOWNLOAD) {
      this.toggleWaitAnimation(false)
      showInfoMsgBox(loc("browser/error_cant_download"))
    }
    else if (eventType == BROWSER_EVENT_BEGIN_LOADING_FRAME) {
      this.toggleWaitAnimation(true)
      this.setTitle(title)
    }
    else if (eventType == BROWSER_EVENT_FINISH_LOADING_FRAME) {
      this.lastLoadedUrl = browser_get_current_url()
      this.toggleWaitAnimation(false)
      this.setTitle(title)
    }
    else if (eventType == BROWSER_EVENT_BROWSER_CRASHED) {
      log("[BRWS] embedded browser crashed, forcing external")
      statsd.send_counter("sq.browser.crash", 1, { reason = errorDesc })
      this.browserForceExternal()
      this.goBack()
    }
    else {
      log("[BRWS] onEventEmbeddedBrowser: unknown event type", eventType)
    }
  }

  function onEventWebPollAuthResult(_param) {
    
    let currentUrl = u.isEmpty(browser_get_current_url()) ? this.url : browser_get_current_url()
    if (u.isEmpty(currentUrl))
      return
    
    
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
