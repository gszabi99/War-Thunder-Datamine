from "%appGlobals/login/loginState.nut" import isLoggedIn
from "dagor.localize" import loc
from "dagor.workcycle" import setInterval, clearTimer
from "assistantMap" import isAssistantMapActive, isAssistantMapAvailable, startAssistantMapSession, getAssistantMapSessionInfo, stopAssistantMapSession

let { get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { openWTAssistantDeeplinkQr } = require("%scripts/user/wtAssistantDeeplink.nut")
let { hasFeature } = require("%scripts/user/features.nut")

const ASSISTANT_MAP_QR_SESSION_POLL_SEC = 1.0

function closeAssistantMapQrWindowIfOpen() {
  let h = handlersManager.findHandlerClassInScene(get_gui_handler("qrWindow"))
  if (h == null || !h.assistantMapSessionQr)
    return
  h.goBack()
}

function tickAssistantMapQrSessionWatch() {
  if (!isAssistantMapActive()) {
    clearTimer(callee())
    closeAssistantMapQrWindowIfOpen()
    return
  }
  let info = getAssistantMapSessionInfo()
  if (info == null || !info.ok) {
    clearTimer(callee())
    closeAssistantMapQrWindowIfOpen()
  }
}

function stopAssistantMapQrSessionWatch() {
  clearTimer(tickAssistantMapQrSessionWatch)
}

function startAssistantMapQrSessionWatch() {
  clearTimer(tickAssistantMapQrSessionWatch)
  setInterval(ASSISTANT_MAP_QR_SESSION_POLL_SEC, tickAssistantMapQrSessionWatch)
}

function isAssistantMapEnabled() {
  return hasFeature("AssistantMap")
}

function guiStartAssistantMapQrWindow() {
  if (!isAssistantMapEnabled() || !isAssistantMapAvailable())
    return

  let sess = isAssistantMapActive() ? getAssistantMapSessionInfo() : startAssistantMapSession()

  if (sess == null || !sess.ok)
    return

  openWTAssistantDeeplinkQr({
    place = "TACTICAL_MAP"
    headerText = loc("wtassistant_deeplink/title")
    infoText = loc("assistant_map_qr/descr")
    autoRefreshAuthenticatedUrl = false
    assistantMapSessionQr = true
    onQrOpened = startAssistantMapQrSessionWatch
    onQrClosed = stopAssistantMapQrSessionWatch
    extraQueryParams = {
      host = sess.host
      port = sess.port
      enettoken = sess.token
    }
  })
}

isLoggedIn.subscribe(function(v) {
  if (!v) {
    stopAssistantMapQrSessionWatch()
    closeAssistantMapQrWindowIfOpen()
    stopAssistantMapSession()
  }
})

return {
  guiStartAssistantMapQrWindow
  isAssistantMapEnabled
  isAssistantMapAvailable
}
