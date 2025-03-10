from "%scripts/dagui_natives.nut" import is_decals_disabled, get_time_till_decals_disabled
from "%scripts/dagui_library.nut" import *

let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { format } = require("string")
let time = require("%scripts/time.nut")
let penalty = require("penalty")
let { leaveSessionRoom } = require("%scripts/matchingRooms/sessionLobbyManager.nut")


















function getDevoiceMessage(activeColor = "chatActiveInfoColor") {
  let st = penalty.getPenaltyStatus()
  
  if (st.status != penalty.DEVOICE) {
    return null
  }

  local txt = ""
  if (st.duration >= penalty.BAN_USER_INFINITE_PENALTY) {
    txt = "".concat(txt, loc("charServer/mute/permanent"), "\n")
  }
  else {
    let durationHours = time.secondsToHours(st.duration)
    local timeText = colorize(activeColor, time.hoursToString(durationHours, false))
    txt = "".concat(txt, format(loc("charServer/mute/timed"), timeText))

    if (("seconds_left" in st) && st.seconds_left > 0) {
      let leftHours = time.secondsToHours(st.seconds_left)
      timeText = colorize(activeColor, time.hoursToString(leftHours, false, true))
      if (timeText != "") {
        txt = "".concat(txt, " ", format(loc("charServer/ban/timeLeft"), timeText))
      }
    }
    else if (isInMenu()) {
      ::update_entitlements_limited()
    }

    if (txt != "") {
      txt = $"{txt}\n"
    }
  }

  txt = "".concat(txt, loc("charServer/ban/reason"), loc("ui/colon"), " ",
    colorize(activeColor, loc($"charServer/ban/reason/{st.category}")), "\n",
    loc("charServer/ban/comment"), "\n", st.comment)
  return txt
}

function getBannedMessage(status = null, banType = "ban") {
  let { duration, seconds_left, category, comment } = status ?? penalty.getPenaltyStatus()
  let onlyDecalsDisabled = banType == "decal"
  let txtArr = []
  if (duration >= penalty.BAN_USER_INFINITE_PENALTY || onlyDecalsDisabled) {
    txtArr.append(loc($"charServer/{banType}/permanent"))
  }
  else {
    let timeLeft = time.secondsToHours(get_time_till_decals_disabled() || seconds_left)
    let durationHours = time.secondsToHours(duration)
    txtArr.append(" ".concat(
      format(loc($"charServer/{banType}/timed"), time.hoursToString(durationHours, false))
      format(loc("charServer/ban/timeLeft"), time.hoursToString(timeLeft, false, true))
    ))
  }

  if (!onlyDecalsDisabled) {
    txtArr.append(
      "".concat(loc("charServer/ban/reason"), loc("ui/colon"),
        colorize("highlightedTextColor", loc($"charServer/ban/reason/{category}"))),
      "", loc("charServer/ban/comment"), comment)
  }

  return "\n".join(txtArr)
}


function showBannedStatusMsgBox(showBanOnly = false) {
  let st = penalty.getPenaltyStatus()
  if (showBanOnly && st.status != penalty.BAN) {
    return
  }

  debugTableData(st, { recursionLevel = -1, addStr = "BAN " })

  local fn = function() {}
  local banType = ""
  if (st.status == penalty.BAN) {
    banType  = "ban"
    fn = @() eventbus_send("request_logout", {})
    ::queues.leaveAllQueuesSilent()
    leaveSessionRoom()
  }
  else if (st.status == penalty.DEVOICE) {
    if (is_decals_disabled()) {
      banType = "mutedecal"
    }
    else {
      banType = "mute"
    }
  }
  else if (is_decals_disabled()) {
    banType = "decal"
  }
  else {
    return
  }

  let txt = getBannedMessage(st, banType)
  if (txt != "") {
    scene_msg_box("banned", null, txt, [["ok", fn ]], "ok", { saved = true, cancel_fn = fn })
  }
}

eventbus_subscribe("request_show_banned_status_msgbox", @(event) showBannedStatusMsgBox(event?.showBanOnly ?? false))

return {
  getDevoiceMessage
  getBannedMessage
  showBannedStatusMsgBox
}

