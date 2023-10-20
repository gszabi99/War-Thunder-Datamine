//checked for plus_string
from "%scripts/dagui_library.nut" import *


let callbackWhenAppWillActive = require("%scripts/clientState/callbackWhenAppWillActive.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { web_rpc } = require("%scripts/webRPC.nut")
let { isInFlight } = require("gameplayBinding")

let function showMessageBox(params) {
  if (isInFlight())
    return { error = { message = "Can not be shown in battle" } }

  let title = params?.title ?? ""
  let message = params?.message ?? ""
  if (title == "" && message == "")
    return { error = { message = "Title and message is empty" } }

  let closeFunction = (params?.logout_on_close ?? false)
    ? exitGame
    : @() null

  scene_msg_box("show_message_from_matching", null,
    "\n".join([colorize("activeTextColor", title), message], true),
    [["ok", @() closeFunction() ]], "ok", { cancel_fn = @() closeFunction() })

  return { result = "ok" }
}

let function showUrl(params) {
  if (isInFlight())
    return { error = { message = "Can not be shown in battle" } }

  let url = params?.url ?? ""
  if (url == "")
    return { error = { message = "url is empty" } }

  if (params?.logout_on_close ?? false)
    callbackWhenAppWillActive(exitGame)

  openUrl(url)

  return { result = "ok" }
}


web_rpc.register_handler("show_message_box", showMessageBox)
web_rpc.register_handler("open_url", showUrl)
