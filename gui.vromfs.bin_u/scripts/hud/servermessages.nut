from "%scripts/dagui_library.nut" import *

let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_time_msec } = require("dagor.time")
let { eventbus_subscribe } = require("eventbus")
let { get_char_extended_error } = require("chard")
let { EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS } = require("chardConst")
let { format } = require("string")

local serverMessageText = ""
local serverMessageEndTime = 0

function showAasNotify(text, timeseconds) {
  serverMessageText = loc(text)
  serverMessageEndTime = get_time_msec() + timeseconds * 1000
  broadcastEvent("ServerMessage")
  ::update_gamercards()
}
eventbus_subscribe("show_aas_notify", @(params) showAasNotify(params.text, params.timeseconds))

function serverMessageUpdateScene(scene) {
  if (!checkObj(scene))
    return false

  let serverMessageObject = scene.findObject("server_message")
  if (!checkObj(serverMessageObject))
    return false

  local text = ""
  if (get_time_msec() < serverMessageEndTime)
    text = serverMessageText

  serverMessageObject.setValue(text)
  return text != ""
}

function getErrorText(result) {
  local text = loc($"charServer/updateError/{result.tostring()}")
  if (result == EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS) {
    let notAllowedChars = get_char_extended_error()
    text = format(text, notAllowedChars)
  }
  return text
}

return {
  serverMessageUpdateScene
  getErrorText
}