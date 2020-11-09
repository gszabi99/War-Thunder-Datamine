local statsd = require("statsd")
local { getPollIdByFullUrl, generatePollUrl } = require("scripts/web/webpoll.nut")
local { openUrl } = require("scripts/onlineShop/url.nut")
local { getStringWidthPx } = require("scripts/viewUtils/daguiFonts.nut")

::embedded_browser_event <- function embedded_browser_event(event_type, url, error_desc, error_code,
  is_main_frame)
{
  ::broadcastEvent(
    "EmbeddedBrowser",
    { eventType = event_type, url = url, errorDesc = error_desc,
    errorCode = error_code, isMainFrame = is_main_frame, title = "" }
  );
}

::notify_browser_window <- function notify_browser_window(params)
{
  ::broadcastEvent("EmbeddedBrowser", params)
}

::is_builtin_browser_active <- function is_builtin_browser_active()
{
  return ::isHandlerInScene(::gui_handlers.BrowserModalHandler)
}

::open_browser_modal <- function open_browser_modal(url="", tags=[], baseUrl = "")
{
  ::gui_start_modal_wnd(::gui_handlers.BrowserModalHandler, { url = url, urlTags = tags, baseUrl = baseUrl })
}

::close_browser_modal <- function close_browser_modal()
{
  local handler = ::handlersManager.findHandlerClassInScene(
    ::gui_handlers.BrowserModalHandler);

  if (handler == null)
  {
    dagor.debug("Couldn't find embedded browser modal handler");
    return
  }

  handler.goBack()
}

::browser_set_external_url <- function browser_set_external_url(url)
{
  local handler = ::handlersManager.findHandlerClassInScene(
    ::gui_handlers.BrowserModalHandler);
  if (handler)
    handler.externalUrl = url;
}

class ::gui_handlers.BrowserModalHandler extends ::BaseGuiHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/browser.blk"
  sceneNavBlkName = null
  url = ""
  externalUrl = ""
  lastLoadedUrl = ""
  baseUrl = ""
  needVoiceChat = false
  urlTags = []
  isLoadingPage = true

  function initScreen()
  {
    local browserObj = scene.findObject("browser_area")
    browserObj.url=url
    browserObj.select()
    lastLoadedUrl = baseUrl
    browser_go(url)
  }

  function browserCloseAndUpdateEntitlements()
  {
    ::g_tasker.addTask(::update_entitlements_limited(),
                       {
                         showProgressBox = true
                         progressBoxText = ::loc("charServer/checking")
                       },
                       @() ::update_gamercards())
    goBack();
  }

  function browserGoBack()
  {
    ::browser_go_back();
  }

  function onBrowserBtnReload()
  {
    ::browser_reload_page();
  }

  function browserForceExternal()
  {
    local taggedUrl = isLoadingPage
      ? lastLoadedUrl
      : ::browser_get_current_url()
    if (!u.isEmpty(urlTags) && taggedUrl != "")
    {
      local tagsStr = " ".join(urlTags)
      if (!::g_string.startsWith(taggedUrl, tagsStr))
        taggedUrl = " ".concat(tagsStr, taggedUrl)
    }

    local newUrl = u.isEmpty(externalUrl) ? taggedUrl : externalUrl
    openUrl(u.isEmpty(newUrl) ? baseUrl : newUrl, true, false, "internal_browser")
  }

  function setTitle(title)
  {
    if (u.isEmpty(title))
      return;

    local titleObj = scene.findObject("wnd_title")
    if (::checkObj(titleObj))
      titleObj.setValue(title)
  }

  function onEventEmbeddedBrowser(params)
  {
    switch (params.eventType)
    {
      case ::BROWSER_EVENT_DOCUMENT_READY:
        lastLoadedUrl = ::browser_get_current_url()
        toggleWaitAnimation(false)
        break;
      case ::BROWSER_EVENT_FAIL_LOADING_FRAME:
        if (params.isMainFrame)
        {
          toggleWaitAnimation(false)
          local message = "".concat(::loc("browser/error_load_url"), ::loc("ui/dot"),
            "\n", ::loc("browser/error_code"), ::loc("ui/colon"), params.errorCode, ::loc("ui/comma"), params.errorDesc)
          local urlCommentMarkup = getUrlCommentMarkupForMsgbox(params.url)
          msgBox("error_load_url", message, [["ok", @() null ]], "ok", { data_below_text = urlCommentMarkup })
        }
        break;
      case ::BROWSER_EVENT_NEED_RESEND_FRAME:
        toggleWaitAnimation(false)

        msgBox("error", ::loc("browser/error_should_resend_data"),
            [["#mainmenu/btnBack", browserGoBack()],
             ["#mainmenu/btnRefresh", (@(params) function() { ::browser_go(params.url) })(params)]],
             "#mainmenu/btnBack")
        break;
      case ::BROWSER_EVENT_CANT_DOWNLOAD:
        toggleWaitAnimation(false)
        showInfoMsgBox(::loc("browser/error_cant_download"))
        break;
      case ::BROWSER_EVENT_BEGIN_LOADING_FRAME:
        if (params.isMainFrame)
        {
          toggleWaitAnimation(true)
          setTitle(params.title)
        }
        break;
      case ::BROWSER_EVENT_FINISH_LOADING_FRAME:
        lastLoadedUrl = ::browser_get_current_url()
        if (params.isMainFrame)
        {
          toggleWaitAnimation(false)
          setTitle(params.title)
        }
        break;
      case ::BROWSER_EVENT_BROWSER_CRASHED:
        statsd.send_counter("sq.browser.crash", 1, {reason = params.errorDesc})
        browserForceExternal()
        goBack()
        break;
      default:
        dagor.debug("onEventEmbeddedBrowser: unknown event type "
          + params.eventType);
        break;
    }
  }

  function onEventWebPollAuthResult(param)
  {
    // WebPollAuthResult event may come before browser opens the page
    local currentUrl = ::u.isEmpty(::browser_get_current_url()) ? url : ::browser_get_current_url()
    if(::u.isEmpty(currentUrl))
      return
    // we have to update externalUrl for any pollId
    // so we don't care about pollId from param
    local pollId = getPollIdByFullUrl(currentUrl)
    if( ! pollId)
      return
    externalUrl = generatePollUrl(pollId, false)
  }

  function toggleWaitAnimation(show)
  {
    isLoadingPage = show

    local waitSpinner = scene.findObject("browserWaitAnimation");
    if (::checkObj(waitSpinner))
      waitSpinner.show(show);
  }

  function onDestroy()
  {
    ::broadcastEvent("DestroyEmbeddedBrowser")
  }

  function wordWrapText(str, width)
  {
    if (::type(str) != "string" || str == "" || width <= 0)
      return str
    local wrapped = []
    local lines = str.split("\n")
    foreach (line in lines)
    {
      local unicodeLine = ::utf8(line)
      local strLen = unicodeLine.charCount()
      for (local pos = 0; pos < strLen; pos += width)
        wrapped.append(unicodeLine.slice(pos, pos + width))
    }
    return "\n".join(wrapped)
  }

  function getUrlCommentMarkupForMsgbox(urlStr)
  {
    if (urlStr == "")
      return ""

    // Splitting too long URL because daGUI textarea don't break words on word-wrap.
    local fontSizePropName = "smallFont"
    local fontSizeCssId = "fontSmall"
    local maxWidthPx = ::to_pixels("0.8@rw")
    local textWidthPx = getStringWidthPx(urlStr, fontSizeCssId, guiScene)
    if (textWidthPx != 0 && textWidthPx > maxWidthPx)
    {
      local splitByChars = (1.0 * maxWidthPx / textWidthPx * ::utf8(urlStr).charCount()).tointeger()
      urlStr = wordWrapText(urlStr, splitByChars)
    }
    return ::format("textareaNoTab { %s:t='yes'; overlayTextColor:t='faded'; text:t='%s'; }",
      fontSizePropName, ::g_string.stripTags(urlStr))
  }
}
