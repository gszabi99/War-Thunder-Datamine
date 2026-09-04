from "gameplayBinding" import isInFlight
from "%scripts/dagui_library.nut" import *
from "%scripts/webRPC.nut" import webRpcRegister
let callbackWhenAppWillActive = require("%scripts/clientState/callbackWhenAppWillActive.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let exitGamePlatform = require("%scripts/utils/exitGamePlatform.nut")

function showMessageBox(params) {
  if (isInFlight())
    return { error = { message = "Can not be shown in battle" } }

  let title = params?.title ?? ""
  let message = params?.message ?? ""
  if (title == "" && message == "")
    return { error = { message = "Title and message is empty" } }

  let closeFunction = (params?.logout_on_close ?? false)
    ? exitGamePlatform
    : @() null

  scene_msg_box("show_message_from_matching", null,
    "\n".join([colorize("activeTextColor", title), message], true),
    [["ok", @() closeFunction() ]], "ok", { cancel_fn = @() closeFunction() })

  return { result = "ok" }
}

function showUrl(params) {
  if (isInFlight())
    return { error = { message = "Can not be shown in battle" } }

  let url = params?.url ?? ""
  if (url == "")
    return { error = { message = "url is empty" } }

  if (params?.logout_on_close ?? false)
    callbackWhenAppWillActive(exitGamePlatform)

  openUrl(url)

  return { result = "ok" }
}


webRpcRegister("show_message_box", showMessageBox)
webRpcRegister("open_url", showUrl)
