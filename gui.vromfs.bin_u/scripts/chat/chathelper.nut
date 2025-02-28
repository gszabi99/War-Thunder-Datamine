from "%scripts/dagui_natives.nut" import gchat_is_connected
from "%scripts/dagui_library.nut" import *

let { get_time_msec } = require("dagor.time")
let { addPopup } = require("%scripts/popups/popups.nut")
let { USEROPT_SHOW_SOCIAL_NOTIFICATIONS, OPTIONS_MODE_GAMEPLAY
} = require("%scripts/options/optionsExtNames.nut")
let { get_gui_option_in_mode } = require("%scripts/options/options.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

const CHAT_SYSTEM_MESSAGE_TIMEOUT_MSEC = 60000
const SYSTEM_COLOR = "@chatInfoColor"

local nextSystemMessageTime = 0

function systemMessage(msg, needPopup = true, forceMessage = false) {
  if ((!forceMessage) && (nextSystemMessageTime > get_time_msec()))
    return

  nextSystemMessageTime = get_time_msec() + CHAT_SYSTEM_MESSAGE_TIMEOUT_MSEC

  broadcastEvent("ChatAddRoomMsg", { roomId = "", from = "", msg })
  if (needPopup && get_gui_option_in_mode(USEROPT_SHOW_SOCIAL_NOTIFICATIONS, OPTIONS_MODE_GAMEPLAY))
    addPopup(null, colorize(SYSTEM_COLOR, msg))
}

function checkChatConnected() {
  if (gchat_is_connected())
    return true

  systemMessage(loc("chat/not_connected"))
  return false
}

return {
  checkChatConnected
  systemMessage
}
