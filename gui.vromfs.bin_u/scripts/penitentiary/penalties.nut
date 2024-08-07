//-file:plus-string
from "%scripts/dagui_natives.nut" import is_decals_disabled, get_time_till_decals_disabled
from "%scripts/dagui_library.nut" import *

let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { eventbus_send, eventbus_subscribe } = require("eventbus")
let { format } = require("string")
let time = require("%scripts/time.nut")
let penalty = require("penalty")

//  local penalist = penalty.getPenaltyList()
//  [
//    {...},
//    { "penalty" :  one of "DEVOICE", "BAN", "SILENT_DEVOICE", "DECALS_DISABLE", "WARN"
//      "category" :  one of "FOUL", "ABUSE", "CHEAT", "BOT", "SPAM", "TEAMKILL", "OTHER", "FINGERPRINT", "INGAME"
//      "start": unixtime, when was imputed
//      "duration": seconds, how long it shoud lasts in total
//      "seconds_left": seconds, how long it will lasts from now, updated on each request
//      "comment": text, what to tell user, why he got his penalty
//      },
//    {...}
//  ]
//  Many penalties can be active (seconds_left > 0) at the same time, even of the same type.
//  New interface should be able to show all of them
//  (but only certain types, i.e. "SILENT_DEVOICE" shouldn't be shown to user')


function getDevoiceMessage(activeColor = "chatActiveInfoColor") {
  let st = penalty.getPenaltyStatus()
  //st = { status = penalty.DEVOICE, duration = 360091, category="FOUL", comment="test ban", seconds_left=2012}
  if (st.status != penalty.DEVOICE) {
    return null
  }

  local txt = ""
  if (st.duration >= penalty.BAN_USER_INFINITE_PENALTY) {
    txt += loc("charServer/mute/permanent") + "\n"
  }
  else {
    let durationHours = time.secondsToHours(st.duration)
    local timeText = colorize(activeColor, time.hoursToString(durationHours, false))
    txt += format(loc("charServer/mute/timed"), timeText)

    if (("seconds_left" in st) && st.seconds_left > 0) {
      let leftHours = time.secondsToHours(st.seconds_left)
      timeText = colorize(activeColor, time.hoursToString(leftHours, false, true))
      if (timeText != "") {
        txt += " " + format(loc("charServer/ban/timeLeft"), timeText)
      }
    }
    else if (isInMenu()) {
      ::update_entitlements_limited()
    }

    if (txt != "") {
      txt += "\n"
    }
  }

  txt += loc("charServer/ban/reason") + loc("ui/colon") + " " +
    colorize(activeColor, loc("charServer/ban/reason/" + st.category)) + "\n" +
    loc("charServer/ban/comment") + "\n" + st.comment
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
    ::SessionLobby.leaveRoom()
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

function isMeBanned() {
  return penalty.getPenaltyStatus().status == penalty.BAN
}


return {
  getDevoiceMessage
  getBannedMessage
  showBannedStatusMsgBox
  isMeBanned
}

