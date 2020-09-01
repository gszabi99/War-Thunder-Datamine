local time = require("scripts/time.nut")
local penalty = require_native("penalty")


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


local getDevoiceMessage = function (activeColor = "chatActiveInfoColor") {
  local st = penalty.getPenaltyStatus()
  //st = { status = penalty.DEVOICE, duration = 360091, category="FOUL", comment="test ban", seconds_left=2012}
  if (st.status != penalty.DEVOICE) {
    return null
  }

  local txt = ""
  if (st.duration >= penalty.BAN_USER_INFINITE_PENALTY) {
    txt += ::loc("charServer/mute/permanent") + "\n"
  } else {
    local durationHours = time.secondsToHours(st.duration)
    local timeText = ::colorize(activeColor, time.hoursToString(durationHours, false))
    txt += ::format(::loc("charServer/mute/timed"), timeText)

    if (("seconds_left" in st) && st.seconds_left > 0) {
      local leftHours = time.secondsToHours(st.seconds_left)
      timeText = ::colorize(activeColor, time.hoursToString(leftHours, false, true))
      if (timeText != "") {
        txt += " " + ::format(::loc("charServer/ban/timeLeft"), timeText)
      }
    } else if (::isInMenu()) {
      ::update_entitlements_limited()
    }

    if (txt != "") {
      txt += "\n"
    }
  }

  txt += ::loc("charServer/ban/reason") + ::loc("ui/colon") + " " +
    ::colorize(activeColor, ::loc("charServer/ban/reason/"+st.category)) + "\n" +
    ::loc("charServer/ban/comment") + "\n" + st.comment
  return txt
}


local showBannedStatusMsgBox = function(showBanOnly = false) {
  local st = penalty.getPenaltyStatus()
  if (showBanOnly && st.status != penalty.BAN) {
    return
  }

  debugTableData(st, {recursionLevel = -1, addStr = "BAN "})

  local txt = ""
  local fn = function() {}
  local banType = ""
  local onlyDecalsDisabled = false

  if (st.status == penalty.BAN) {
    banType  = "ban"
    fn = function() { ::gui_start_logout() }
    ::queues.leaveAllQueuesSilent()
    ::SessionLobby.leaveRoom()
  } else if (st.status == penalty.DEVOICE) {
    if (is_decals_disabled()) {
      banType = "mutedecal"
    } else {
      banType = "mute"
    }
  } else if (is_decals_disabled()) {
    onlyDecalsDisabled = true
    banType = "decal"
  } else {
    return
  }

  if (st.duration >= penalty.BAN_USER_INFINITE_PENALTY || onlyDecalsDisabled) {
    txt += ::loc("charServer/" + banType + "/permanent")
  } else {
    local timeLeft = time.secondsToHours(::get_time_till_decals_disabled() || st.seconds_left)
    local durationHours = time.secondsToHours(st.duration)
    txt += ::format(::loc("charServer/" + banType + "/timed"), time.hoursToString(durationHours, false))
    txt += " " + ::format(::loc("charServer/ban/timeLeft"), time.hoursToString(timeLeft, false, true))
  }

  if (!onlyDecalsDisabled) {
    txt += "\n" + ::loc("charServer/ban/reason") + ::loc("ui/colon") + " " +
      ::colorize("highlightedTextColor", ::loc("charServer/ban/reason/"+st.category)) + "\n\n"
    txt += ::loc("charServer/ban/comment") + "\n" + st.comment
  }

  if (txt != "") {
    ::scene_msg_box("banned", null, txt, [["ok", fn ]], "ok", { saved = true, cancel_fn = fn })
  }
}

local isMeBanned = function() {
  return penalty.getPenaltyStatus().status == penalty.BAN
}


local export = {
  getDevoiceMessage = getDevoiceMessage
  showBannedStatusMsgBox = showBannedStatusMsgBox
  isMeBanned = isMeBanned
}


return export
