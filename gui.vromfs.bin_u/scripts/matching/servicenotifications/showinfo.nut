local callbackWhenAppWillActive = require("scripts/clientState/callbackWhenAppWillActive.nut")
local { openUrl } = require("scripts/onlineShop/url.nut")

local function showMessageBox(params)
{
  if (::is_in_flight())
    return { error = { message = "Can not be shown in battle" }}

  local title = params?.title ?? ""
  local message = params?.message ?? ""
  if (title == "" && message == "")
    return { error = { message = "Title and message is empty" }}

  local closeFunction = (params?.logout_on_close ?? false)
    ? ::exit_game
    : @() null

  ::scene_msg_box("show_message_from_matching", null,
    ::g_string.implode([::colorize("activeTextColor", title), message], "\n"),
    [["ok", @() closeFunction() ]], "ok", { cancel_fn = @() closeFunction() })

  return { result = "ok" }
}

local function showUrl(params)
{
  if (::is_in_flight())
    return { error = { message = "Can not be shown in battle" }}

  local url = params?.url ?? ""
  if (url == "")
    return { error = { message = "url is empty" }}

  if (params?.logout_on_close ?? false)
    callbackWhenAppWillActive(@() ::exit_game())

  openUrl(url)

  return { result = "ok" }
}


web_rpc.register_handler("show_message_box", showMessageBox)
web_rpc.register_handler("open_url", showUrl)
