from "%scripts/dagui_library.nut" import *

let { get_time_msec } = require("dagor.time")
let { get_char_extended_error } = require("chard")
let { EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS } = require("chardConst")
let { format } = require("string")

local serverMessageText = ""
local serverMessageEndTime = 0

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